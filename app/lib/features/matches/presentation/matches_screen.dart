import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isPremium = false;
  List<Map<String, dynamic>> _matches = [];

  String _selectedFilter = 'Tous';

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profileResponse = await _supabase
          .from('profiles')
          .select('is_premium')
          .eq('id', userId)
          .maybeSingle();
          
      final isPremium = profileResponse?['is_premium'] ?? false;
      final premiumUntilRaw = profileResponse?['premium_until'];
      if (isPremium && premiumUntilRaw != null) {
        final premiumUntil = DateTime.parse(premiumUntilRaw);
        _isPremium = premiumUntil.isAfter(DateTime.now());
      } else {
        _isPremium = isPremium;
      }

      final response = await _supabase
          .from('applications')
          .select('*, jobs(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _matches = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement matches: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredMatches {
    if (_selectedFilter == 'Tous') return _matches;

    final now = DateTime.now();
    return _matches.where((match) {
      final date = DateTime.parse(match['created_at']);
      final difference = now.difference(date).inDays;

      if (_selectedFilter == 'Aujourd\'hui') {
        return difference == 0 && date.day == now.day;
      } else if (_selectedFilter == '7 derniers jours') {
        return difference <= 7;
      } else if (_selectedFilter == '30 derniers jours') {
        return difference <= 30;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)));
    }

    final filtered = _filteredMatches;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Mes Matches',
          style: TextStyle(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 22.sp,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadMatches,
                    child: ListView.separated(
                      padding: EdgeInsets.all(16.r),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => SizedBox(height: 12.h),
                      itemBuilder: (context, index) {
                        final match = filtered[index];
                        final job = match['jobs'];
                        final date = DateTime.parse(match['created_at']);
                        
                        // Limit to 3 matches if Freemium
                        final isLocked = !_isPremium && index >= 3;
                        return _buildMatchCard(job, date, isLocked: isLocked);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ['Tous', 'Aujourd\'hui', '7 derniers jours', '30 derniers jours'];
    return Container(
      height: 60.h,
      color: Colors.white,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return Center(
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedFilter = filter);
                }
              },
              backgroundColor: Colors.grey.shade50,
              selectedColor: const Color(0xFFF97316).withOpacity(0.1),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFFF97316) : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13.sp,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
                side: BorderSide(
                  color: isSelected ? const Color(0xFFF97316) : Colors.grey.shade200,
                  width: 1,
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80.r, color: Colors.grey.shade300),
          SizedBox(height: 16.h),
          Text(
            _selectedFilter == 'Tous' 
              ? 'Aucun match pour le moment'
              : 'Aucun match pour cette période',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          SizedBox(height: 8.h),
          Text(
            _selectedFilter == 'Tous'
              ? 'Continuez à swiper pour trouver votre Djossi !'
              : 'Essayez un autre filtre ou continuez à swiper.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic>? job, DateTime date, {bool isLocked = false}) {
    if (isLocked) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3), width: 1.5),
        ),
        child: InkWell(
          onTap: () => context.push('/premium'),
          child: Padding(
            padding: EdgeInsets.all(20.r),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_rounded, color: const Color(0xFFF59E0B), size: 24.r),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ancien Match Bloqué',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Passez au Premium pour voir tout votre historique.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: InkWell(
          onTap: () {
            // Afficher détails si besoin
          },
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Row(
              children: [
                Container(
                  width: 60.r,
                  height: 60.r,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Center(
                    child: Text(
                      ((job?['company_name']?.toString().isNotEmpty == true) 
                          ? job!['company_name'].toString()[0] 
                          : 'C').toUpperCase(),
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF97316),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job?['job_title'] ?? 'Inconnu',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        job?['company_name'] ?? 'Inconnu',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12.r, color: Colors.grey.shade400),
                          SizedBox(width: 4.w),
                          Text(
                            'Matché le ${DateFormat('dd/MM/yyyy').format(date)}',
                            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    'CV Envoyé',
                    style: TextStyle(
                      color: const Color(0xFFF97316),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
