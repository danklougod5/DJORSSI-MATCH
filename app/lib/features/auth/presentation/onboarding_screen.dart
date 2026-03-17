import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  PageController? _pageController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _customSkillController = TextEditingController();
  int _currentPage = 0;
  bool _isEditMode = false;

  final List<String> _availableTags = [
    'Informatique', 'Marketing', 'Vente', 'Ressources Humaines',
    'Finance', 'Logistique', 'Ingénierie', 'Design', 'Administration',
    'Télécommunications', 'BTP', 'Santé', 'Éducation', 'Juridique',
    'Banque & Assurance', 'Commerce', 'Transport', 'Hôtellerie',
  ];
  
  final Set<String> _selectedTags = {};
  bool _isLoading = false;
  bool _isCheckingProfile = true;
  String? _cvUrl;
  bool _isUploadingCV = false;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _nameController.dispose();
    _customSkillController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        // Ajout d'un timeout pour éviter d'être bloqué sur le spinner
        final profile = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));

        if (profile != null) {
          final hasSkills = (profile['skills'] as List?)?.isNotEmpty ?? false;
          
          setState(() {
            _selectedTags.clear();
            _customSkillController.clear();
            _nameController.text = profile['full_name'] ?? '';
            _cvUrl = profile['cv_url'];
            
            if (profile['skills'] != null) {
              final skills = List<String>.from(profile['skills']);
              List<String> customSkills = [];
              for (var skill in skills) {
                final trimmedSkill = skill.toString().trim();
                // Recherche insensible à la casse dans les tags disponibles
                final tagMatch = _availableTags.where((t) => t.toLowerCase().trim() == trimmedSkill.toLowerCase()).firstOrNull;
                
                if (tagMatch != null) {
                  _selectedTags.add(tagMatch);
                } else if (trimmedSkill.isNotEmpty) {
                  customSkills.add(trimmedSkill);
                }
              }
            if (customSkills.isNotEmpty) {
                _customSkillController.text = customSkills.join(', ');
              }
            }
          });

          // On active le mode édition si le profil est déjà complet
          if (profile['full_name'] != null && profile['full_name'].toString().isNotEmpty) {
            _isEditMode = true;
            _currentPage = 2; // Jump to Profile Setup (now index 2)
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement profil: $e');
    } finally {
      if (mounted) {
        setState(() {
          _pageController = PageController(initialPage: _currentPage);
          _isCheckingProfile = false;
        });
      }
    }
  }

  void _onBackAction() {
    if (_currentPage > 0) {
      _pageController?.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else if (_isEditMode) {
      context.go('/');
    }
  }

  Future<void> _pickAndUploadCV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result != null) {
        setState(() => _isUploadingCV = true);
        
        final file = File(result.files.single.path!);
        final fileExt = result.files.single.extension;
        final userId = Supabase.instance.client.auth.currentUser!.id;
        final fileName = '${userId}_cv.$fileExt';
        final filePath = 'cvs/$fileName';

        await Supabase.instance.client.storage.from('cv_files').upload(
          filePath,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

        final String publicUrl = Supabase.instance.client.storage.from('cv_files').getPublicUrl(filePath);

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
      debugPrint('Erreur upload CV: $e');
      setState(() => _isUploadingCV = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'upload du CV: $e')),
        );
      }
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        if (_selectedTags.length < 5) {
          _selectedTags.add(tag);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vous pouvez sélectionner jusqu\'à 5 secteurs.')),
          );
        }
      }
    });
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer votre nom complet.')),
      );
      return;
    }

    if (_selectedTags.isEmpty && _customSkillController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner au moins un secteur.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final finalSkills = _selectedTags.toList();
        if (_customSkillController.text.isNotEmpty) {
          final custom = _customSkillController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
          finalSkills.addAll(custom);
        }

        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'full_name': name,
          'skills': finalSkills,
          'cv_url': _cvUrl,
          'updated_at': DateTime.now().toIso8601String(),
        });
        
        if (mounted) {
          context.go('/?tab=profile');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil mis à jour ! 🌟'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Utilisateur non connecté -> rediriger vers auth
        if (mounted) {
          context.go('/auth');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingProfile) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _isEditMode 
        ? AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: _onBackAction,
            ),
            title: Text(_currentPage == 2 ? 'Modifier mon profil' : 'Aide', style: const TextStyle(color: Colors.black)),
          )
        : null,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController!,
                onPageChanged: (index) => setState(() => _currentPage = index),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildMarketingSlide(
                    image: 'onboarding_swipe',
                    title: 'Swippez les meilleures offres',
                    description: "À droite pour postuler, à gauche pour ignorer. C'est aussi simple que ça.",
                  ),
                  _buildMarketingSlide(
                    image: 'onboarding_match',
                    title: 'Un match = Une postulation',
                    description: "Dès qu'un recruteur valide votre profil, c'est un match ! Votre candidature est alors envoyée.",
                  ),
                  _buildProfileSetupSlide(),
                ],
              ),
            ),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }


  Widget _buildMarketingSlide({required String image, required String title, required String description}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/$image.png', height: 300.h, fit: BoxFit.contain),
          SizedBox(height: 40.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSetupSlide() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isEditMode) 
            Text(
              'Finalisons votre profil',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
            ),
          SizedBox(height: 24.h),
          
          _buildInputLabel('Votre Nom Complet'),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Ex: Koffi Kouassi',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          SizedBox(height: 24.h),
          
          _buildInputLabel('Votre CV'),
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.description, color: _cvUrl != null ? Colors.blue : Colors.grey),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    _cvUrl != null ? 'CV Envoyé' : 'Aucun fichier sélectionné',
                    style: TextStyle(fontSize: 14.sp, color: _cvUrl != null ? Colors.black : Colors.grey),
                  ),
                ),
                if (_isUploadingCV)
                  const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  TextButton(
                    onPressed: _pickAndUploadCV,
                    child: Text(_cvUrl != null ? 'Remplacer' : 'Ajouter'),
                  ),
              ],
            ),
          ),
          SizedBox(height: 32.h),
          
          _buildInputLabel('Vos Secteurs d\'Intérêt'),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: _availableTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () => _toggleTag(tag),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF97316) : Colors.white,
                    borderRadius: BorderRadius.circular(30.r),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFF97316) : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 20.h),
          TextField(
            controller: _customSkillController,
            decoration: InputDecoration(
              hintText: 'Autre(s) secteur(s) (ex: Menuiserie, Couture)',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.add_circle_outline),
            ),
          ),
          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        label,
        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    if (_isEditMode && _currentPage == 2) {
      return Padding(
        padding: EdgeInsets.all(24.w),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
            ),
            child: _isLoading 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Mettre à jour le profil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Skip Button
          if (_currentPage < 2 && !_isEditMode)
            TextButton(
              onPressed: () {
                _pageController?.jumpToPage(2);
              },
              child: Text(
                'PASSER',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            )
          else
            SizedBox(width: 80.w), // Spacer to keep indicators centered/aligned

          // Progress Indicators
          Row(
            children: List.generate(3, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.only(right: 8.w),
                height: 8.h,
                width: _currentPage == index ? 24.w : 8.w,
                decoration: BoxDecoration(
                  color: _currentPage == index ? const Color(0xFFF97316) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              );
            }),
          ),

          // Next / Start Button
          if (_currentPage < 2)
            ElevatedButton(
              onPressed: () {
                _pageController?.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              },
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.all(16.r),
                backgroundColor: const Color(0xFFF97316),
              ),
              child: const Icon(Icons.arrow_forward, color: Colors.white),
            )
          else
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 32.w),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Commencer', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
