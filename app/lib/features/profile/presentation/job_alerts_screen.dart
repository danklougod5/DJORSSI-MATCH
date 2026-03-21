import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class JobAlertsScreen extends StatefulWidget {
  const JobAlertsScreen({super.key});

  @override
  State<JobAlertsScreen> createState() => _JobAlertsScreenState();
}

class _JobAlertsScreenState extends State<JobAlertsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPremium = false;
  bool _alertsEnabled = true;
  final Set<String> _selectedSectors = {};

  List<String> _availableSectors = [];

  @override
  void initState() {
    super.initState();
    _loadAlertsAndProfile();
  }

  Future<void> _loadAlertsAndProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Fetch dynamic tags
      try {
        final tagsResponse = await _supabase.from('jobs').select('tags').timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Délai d\'attente dépassé (secteurs)'),
        );
        final Set<String> uniqueTags = {};
        for (var row in tagsResponse as List) {
          if (row['tags'] != null) {
            uniqueTags.addAll(List<String>.from(row['tags']));
          }
        }
        _availableSectors = uniqueTags.toList()..sort();
      } catch (e) {
        debugPrint('Erreur lors du chargement des tags dynamiques: $e');
        // Garder une liste vide ou fallback
      }

      // 2. Check if user is premium
      final profile = await _supabase
          .from('profiles')
          .select('is_premium, skills')
          .eq('id', user.id)
          .maybeSingle();
      
      if (profile != null) {
        _isPremium = profile['is_premium'] ?? false;
      }

      // 2. Load alerts
      final response = await _supabase
          .from('job_alerts')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _alertsEnabled = response['is_active'] ?? true;
          final sectors = List<String>.from(response['sectors'] ?? []);
          // On ne garde que les secteurs qui existent toujours
          for (var s in sectors) {
            if (_availableSectors.contains(s)) _selectedSectors.add(s);
          }
          
          // Fallback : si rien n'est sélectionné mais que l'alerte est active, on pourrait pré-remplir
          if (_selectedSectors.isEmpty && profile != null && profile['skills'] != null) {
             for (var s in List<String>.from(profile['skills'])) {
               if (_availableSectors.contains(s)) _selectedSectors.add(s);
             }
          }
        });
      } else if (profile != null && profile['skills'] != null) {
        // Default: use sectors from profile
        setState(() {
          final profileSkills = List<String>.from(profile['skills']);
          for (var s in profileSkills) {
            if (_availableSectors.contains(s)) _selectedSectors.add(s);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading alerts: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAlerts() async {
    if (!_isPremium) return;

    setState(() => _isSaving = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('job_alerts').upsert({
        'user_id': user.id,
        'is_active': _alertsEnabled,
        'sectors': _selectedSectors.toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paramètres d\'alertes enregistrés !'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving alerts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'enregistrement : $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Alertes Emplois',
          style: TextStyle(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.all(24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNotificationToggle(),
                      SizedBox(height: 32.h),
                      Text(
                        'Secteurs d\'intérêt',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'Choisissez les domaines pour lesquels vous souhaitez recevoir des alertes par email.',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      _availableSectors.isEmpty 
                        ? const Text("Aucun secteur disponible pour le moment.", style: TextStyle(color: Colors.grey))
                        : _buildSectorsGrid(),
                      SizedBox(height: 48.h),
                      _buildSaveButton(),
                    ],
                  ),
                ),
                if (!_isPremium) _buildPremiumLocker(),
              ],
            ),
    );
  }

  Widget _buildPremiumLocker() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white.withOpacity(0.7),
      child: Center(
        child: Container(
          margin: EdgeInsets.all(32.w),
          padding: EdgeInsets.all(32.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  color: const Color(0xFFF97316),
                  size: 48.r,
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'Fonctionnalité Premium',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text(
                'Les alertes emploi par email sont réservées aux membres Premium. Ne ratez plus aucune opportunité !',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/premium'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    elevation: 0,
                  ),
                  child: Text(
                    'PASSER AU PREMIUM',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.sp,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Plus tard',
                  style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 13.sp),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationToggle() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: const Color(0xFFF97316),
              size: 24.r,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activer les alertes',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Recevez un email quand un job correspond',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _alertsEnabled,
            activeColor: const Color(0xFFF97316),
            onChanged: _isPremium ? (val) => setState(() => _alertsEnabled = val) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSectorsGrid() {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: _availableSectors.map((sector) {
        final isSelected = _selectedSectors.contains(sector);
        return FilterChip(
          label: Text(sector),
          selected: isSelected,
          onSelected: (_isPremium && _alertsEnabled)
              ? (val) {
                  setState(() {
                    if (val) {
                      _selectedSectors.add(sector);
                    } else {
                      _selectedSectors.remove(sector);
                    }
                  });
                }
              : null,
          selectedColor: const Color(0xFFF97316).withOpacity(0.15),
          checkmarkColor: const Color(0xFFF97316),
          labelStyle: TextStyle(
            color: isSelected ? const Color(0xFFF97316) : const Color(0xFF64748B),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13.sp,
          ),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100.r),
            side: BorderSide(
              color: isSelected ? const Color(0xFFF97316) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isSaving || !_isPremium) ? null : _saveAlerts,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 20.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                'ENREGISTRER LES PRÉFÉRENCES',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }
}
