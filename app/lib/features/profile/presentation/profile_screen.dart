import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isUploading = false;
  Map<String, dynamic>? _profileData;
  List<String> _skills = [];
  String? _fullName;
  String? _cvUrl;
  
  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _setupRealtime();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Recharger quand l'app revient au premier plan
    if (state == AppLifecycleState.resumed) {
      _loadProfile();
    }
  }

  @override 
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recharger à chaque fois qu'on revient sur cet écran (navigation)
    if (_hasLoadedOnce) {
      _loadProfile();
    }
    _hasLoadedOnce = true;
  }

  /// Abonnement realtime pour que le profil se mette à jour automatiquement
  void _setupRealtime() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _profileSubscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
      if (data.isNotEmpty && mounted) {
        setState(() {
          _profileData = data.first;
          _skills = List<String>.from(data.first['skills'] ?? []);
          _fullName = data.first['full_name'];
          _cvUrl = data.first['cv_url'];
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _profileData = response;
          _skills = List<String>.from(response['skills'] ?? []);
          _fullName = response['full_name'];
          _cvUrl = response['cv_url'];
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement du profil: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadCV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result != null) {
        setState(() => _isUploading = true);
        
        final path = result.files.single.path;
        if (path == null) {
          debugPrint('Erreur: Le chemin du fichier est null');
          setState(() => _isUploading = false);
          return;
        }

        final user = _supabase.auth.currentUser;
        if (user == null) {
          debugPrint('Erreur: Utilisateur non connecté');
          setState(() => _isUploading = false);
          return;
        }

        final file = File(path);
        final fileExt = result.files.single.extension ?? 'pdf';
        final fileName = '${user.id}_cv.$fileExt';
        final filePath = 'cvs/$fileName';

        // Upload to Supabase Storage (bucket: cv_files)
        await _supabase.storage.from('cv_files').upload(
          filePath,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

        // Get public URL
        final String publicUrl = _supabase.storage.from('cv_files').getPublicUrl(filePath);

        // Update profile in DB
        await _supabase.from('profiles').update({
          'cv_url': publicUrl,
        }).eq('id', user.id);

        setState(() {
          _cvUrl = publicUrl;
          _isUploading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CV mis à jour avec succès !')),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur upload CV: $e');
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'upload : $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Se déconnecter', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _supabase.auth.signOut();
      if (mounted) {
        context.go('/auth');
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer mon compte', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
          'Cette action est irréversible. Toutes vos candidatures, vos matches et vos informations personnelles seront définitivement supprimés.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer définitivement', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final userId = _supabase.auth.currentUser?.id;
        final accessToken = _supabase.auth.currentSession?.accessToken;
        if (userId == null || accessToken == null) {
          throw 'Utilisateur non identifié ou session expirée. Veuillez vous reconnecter.';
        }

        // 1. Appeler l'Edge Function pour supprimer le compte définitivement (Auth + Profil)
        await _supabase.functions.invoke(
          'delete-account',
          headers: {
            'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken}',
          },
        );

        // 2. Déconnexion locale pour forcer le nettoyage de la session
        await _supabase.auth.signOut();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Votre compte a été définitivement supprimé. Bonne continuation !'),
              backgroundColor: Colors.black,
            ),
          );
          // 3. Rediriger vers l'écran d'authentification
          context.go('/auth');
        }
      } catch (e) {
        debugPrint('Erreur lors de la suppression du compte: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Impossible de supprimer le compte : $e')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)));
    }

    final user = _supabase.auth.currentUser;
    final contactInfo = user?.phone ?? user?.email ?? 'Contact non disponible';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Mon Profil',
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
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: const Color(0xFFF97316),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
          children: [
            // Section Avatar & Nom
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 120.r,
                        height: 120.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: (_profileData?['is_premium'] ?? false) 
                                ? const Color(0xFFF59E0B) 
                                : Colors.white, 
                            width: 4,
                          ),
                          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Icon(
                            Icons.person, 
                            size: 60.r, 
                            color: (_profileData?['is_premium'] ?? false) 
                                ? const Color(0xFFF59E0B).withOpacity(0.5) 
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => context.push('/complete-profile'),
                          child: Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: Icon(Icons.edit, color: Colors.white, size: 18.r),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Bienvenue, ${_fullName ?? 'Utilisateur Djossi'}',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (_profileData?['is_premium'] ?? false)
                        Padding(
                          padding: EdgeInsets.only(left: 8.w),
                          child: Icon(Icons.verified, color: const Color(0xFFF59E0B), size: 24.r),
                        ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      gradient: (_profileData?['is_premium'] ?? false) 
                          ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
                          : null,
                      color: (_profileData?['is_premium'] ?? false) 
                          ? null
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: (_profileData?['is_premium'] ?? false)
                          ? [BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_profileData?['is_premium'] ?? false)
                          Padding(
                            padding: EdgeInsets.only(right: 6.w),
                            child: Icon(Icons.workspace_premium, color: Colors.white, size: 14.r),
                          ),
                        Text(
                          (_profileData?['is_premium'] ?? false) ? 'MEMBRE VIP' : 'Utilisateur Freemium',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: (_profileData?['is_premium'] ?? false) ? 1 : 0,
                            color: (_profileData?['is_premium'] ?? false) 
                                ? Colors.white 
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    contactInfo,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32.h),

            // Premium Banner
            _buildPremiumBanner(),

            SizedBox(height: 16.h),

            // Section Secteurs d'intérêt (Skills)
            _buildCardSection(
              title: 'Mes Secteurs',
              onEdit: () => context.push('/complete-profile'),
              child: InkWell(
                onTap: () => context.push('/complete-profile'),
                child: _skills.isEmpty
                    ? Text('Aucun secteur sélectionné', style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 14.sp))
                    : Wrap(
                        spacing: 8.w,
                          runSpacing: 8.h,
                          children: _skills.map((skill) => Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(100.r),
                            ),
                            child: Text(
                              skill,
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )).toList(),
                        ),
              ),
            ),

            SizedBox(height: 16.h),

            // Section CV
            _buildCardSection(
              title: 'Mon CV',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.description, color: const Color(0xFFF97316), size: 24.r),
                ),
                title: Text(
                  _cvUrl != null ? 'CV déjà téléchargé' : 'Aucun CV ajouté',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
                ),
                subtitle: Text(
                  _cvUrl != null ? 'Cliquez pour remplacer' : 'Ajoutez votre CV pour postuler',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                ),
                trailing: _isUploading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.upload_file, color: Theme.of(context).primaryColor),
                onTap: _isUploading ? null : _pickAndUploadCV,
              ),
            ),

            SizedBox(height: 16.h),

            // Autres Options
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Column(
                children: [
                  _buildOptionTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Alertes Emplois',
                    subtitle: 'Gérer mes notifications',
                    trailing: (_profileData?['is_premium'] ?? false) 
                        ? null 
                        : Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              'PREMIUM',
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFF97316),
                              ),
                            ),
                          ),
                    onTap: () => context.push('/job-alerts'),
                  ),
                  _buildOptionTile(
                    icon: Icons.logout_rounded,
                    title: 'Se déconnecter',
                    color: Colors.red,
                    showArrow: false,
                    onTap: _signOut,
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _buildOptionTile(
                    icon: Icons.delete_forever_rounded,
                    title: 'Supprimer mon compte',
                    color: Colors.red.shade900,
                    showArrow: false,
                    onTap: _deleteAccount,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBanner() {
    final isPremium = _profileData?['is_premium'] ?? false;

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium 
            ? [const Color(0xFF0F172A), const Color(0xFF1E293B)] 
            : [const Color(0xFFF97316), const Color(0xFFEA580C)],
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: (isPremium ? const Color(0xFF0F172A) : const Color(0xFFF97316)).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPremium ? Icons.workspace_premium_rounded : Icons.workspace_premium_outlined,
              color: isPremium ? const Color(0xFFF59E0B) : Colors.white,
              size: 28.r,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? 'M E M B R E   P R E M I U M' : 'PASSEZ AU PREMIUM',
                  style: TextStyle(
                    color: isPremium ? const Color(0xFFF59E0B) : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.sp,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  isPremium 
                    ? 'Tous vos avantages sont activés.' 
                    : 'Boostez votre profil et matchez plus vite !',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          if (!isPremium)
            ElevatedButton(
              onPressed: () => context.push('/premium'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFF97316),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                elevation: 0,
              ),
              child: Text(
                'VOIR',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardSection({required String title, VoidCallback? onEdit, required Widget child}) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  icon: Icon(Icons.edit, size: 18.r, color: Theme.of(context).primaryColor),
                  onPressed: onEdit,
                ),
            ],
          ),
          SizedBox(height: 8.h),
          child,
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? color,
    bool showArrow = true,
    Widget? trailing,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: (color ?? const Color(0xFFF97316)).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color ?? const Color(0xFFF97316), size: 20.r),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
          color: color ?? const Color(0xFF0F172A),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 12.sp, color: const Color(0xFF64748B)),
            )
          : null,
      trailing: trailing ?? (showArrow ? Icon(Icons.chevron_right, size: 20.r, color: const Color(0xFF94A3B8)) : null),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
    );
  }
}
