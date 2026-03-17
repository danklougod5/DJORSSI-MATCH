import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _customSkillController = TextEditingController();
  final List<String> _availableTags = [
    'Informatique', 'Marketing', 'Vente', 'Ressources Humaines',
    'Finance', 'Logistique', 'Ingénierie', 'Design', 'Administration',
    'Télécommunications', 'BTP', 'Santé', 'Éducation', 'Juridique',
    'Banque & Assurance', 'Commerce', 'Transport', 'Hôtellerie',
  ];
  
  final Set<String> _selectedTags = {};
  bool _isLoading = false;
  String? _cvUrl;
  bool _isUploadingCV = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (profile != null && mounted) {
      setState(() {
        _nameController.text = profile['full_name'] ?? '';
        _cvUrl = profile['cv_url'];
        if (profile['skills'] != null) {
          final skills = List<String>.from(profile['skills']);
          for (var skill in skills) {
             if (_availableTags.contains(skill)) {
               _selectedTags.add(skill);
             }
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customSkillController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadCV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result != null) {
        setState(() => _isUploadingCV = true);
        final path = result.files.single.path;
        if (path == null) return;

        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;

        final file = File(path);
        final fileExt = result.files.single.extension ?? 'pdf';
        final fileName = '${user.id}_cv.$fileExt';
        const filePath = 'cvs';

        await Supabase.instance.client.storage.from('cv_files').upload(
          '$filePath/$fileName',
          file,
          fileOptions: const FileOptions(upsert: true),
        );

        final String publicUrl = Supabase.instance.client.storage.from('cv_files').getPublicUrl('$filePath/$fileName');

        setState(() {
          _cvUrl = publicUrl;
          _isUploadingCV = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CV téléchargé avec succès !')),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingCV = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload CV: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || (_selectedTags.isEmpty && _customSkillController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir votre nom et choisir un secteur.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final skills = _selectedTags.toList();
        if (_customSkillController.text.isNotEmpty) {
          skills.addAll(_customSkillController.text.split(',').map((e) => e.trim()));
        }

        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'full_name': name,
          'skills': skills,
          'cv_url': _cvUrl,
          'updated_at': DateTime.now().toIso8601String(),
        });
        
        if (mounted) context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 20.h),
              Text(
                'Finalisons votre profil',
                style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text(
                'Ces informations sont nécessaires pour postuler aux offres.',
                style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40.h),
              
              _buildLabel('Nom Complet'),
              TextField(
                controller: _nameController,
                decoration: _inputStyle('Ex: Jean Marc', Icons.person_outline),
              ),
              
              SizedBox(height: 24.h),
              _buildLabel('Votre CV (Obligatoire)'),
              GestureDetector(
                onTap: _pickAndUploadCV,
                child: Container(
                  padding: EdgeInsets.all(20.r),
                  decoration: BoxDecoration(
                    color: _cvUrl != null ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: _cvUrl != null ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0), width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: _cvUrl != null ? const Color(0xFF22C55E) : const Color(0xFFF97316)),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Text(
                          _cvUrl != null ? 'CV déjà ajouté !' : 'Cliquez pour ajouter votre CV',
                          style: TextStyle(fontWeight: FontWeight.w600, color: _cvUrl != null ? const Color(0xFF166534) : const Color(0xFF0F172A)),
                        ),
                      ),
                      if (_isUploadingCV) const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 24.h),
              _buildLabel('Secteurs d\'activité'),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: _availableTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  final themeColor = Theme.of(context).primaryColor;
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (_) => setState(() => isSelected ? _selectedTags.remove(tag) : _selectedTags.add(tag)),
                    selectedColor: themeColor.withValues(alpha: 0.15),
                    checkmarkColor: themeColor,
                    labelStyle: TextStyle(
                      color: isSelected ? themeColor : const Color(0xFF64748B),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13.sp,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100.r),
                      side: BorderSide(
                        color: isSelected ? themeColor : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              SizedBox(height: 40.h),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                  elevation: 4,
                  shadowColor: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                ),
                child: _isLoading 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('ENREGISTRER LE PROFIL', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(padding: EdgeInsets.only(bottom: 8.h), child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)));

  InputDecoration _inputStyle(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: Colors.grey),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: BorderSide.none),
  );
}
