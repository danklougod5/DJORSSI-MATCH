import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecruiterPostJobScreen extends StatefulWidget {
  const RecruiterPostJobScreen({super.key});

  @override
  State<RecruiterPostJobScreen> createState() => _RecruiterPostJobScreenState();
}

class _RecruiterPostJobScreenState extends State<RecruiterPostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final _companyController = TextEditingController();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _levelController = TextEditingController();
  final _salaryController = TextEditingController();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _coverLetterController = TextEditingController();
  final _deadlineController = TextEditingController();

  String _contractType = 'CDI';
  bool _requiresCoverLetter = false;
  bool _isLoading = false;
  bool _isSuccess = false;

  final List<String> _contractTypes = [
    'CDI',
    'CDD',
    'Stage',
    'Alternance',
    'Freelance',
    'Intérim',
  ];

  @override
  void dispose() {
    _companyController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    _levelController.dispose();
    _salaryController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _coverLetterController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }

  String _cleanPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length == 10) {
      return '225$cleaned';
    } else if (cleaned.length == 8) {
      return '22507$cleaned';
    }
    return cleaned;
  }

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final randomSuffix = Random().nextInt(1000000).toString().padLeft(6, '0');
    final uniqueSourceUrl = 'recruiter_post_${DateTime.now().millisecondsSinceEpoch}_$randomSuffix';

    final tags = _tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // Add contract type to tags for filtering if it's not already there
    if (!tags.contains(_contractType)) {
      tags.add(_contractType);
    }

    final rawData = {
      'company_name': _companyController.text.trim(),
      'job_title': _titleController.text.trim(),
      'location': _locationController.text.trim(),
      'required_level': _levelController.text.trim(),
      'salary_range': _salaryController.text.trim(),
      'contact_email': _emailController.text.trim(),
      'whatsapp_number': _whatsappController.text.trim(),
      'description': _descriptionController.text.trim(),
      'tags': tags,
      'contract_type': _contractType,
      'requires_cover_letter': _requiresCoverLetter,
      'cover_letter_instructions': _requiresCoverLetter ? _coverLetterController.text.trim() : null,
      'deadline': _deadlineController.text.trim().isNotEmpty ? _deadlineController.text.trim() : null,
    };

    final jobData = {
      'company_name': rawData['company_name'],
      'job_title': rawData['job_title'],
      'location': rawData['location'] ?? "Abidjan",
      'required_level': rawData['required_level'],
      'salary_range': rawData['salary_range'] != "" ? rawData['salary_range'] : null,
      'contact_email': rawData['contact_email'] != "" ? rawData['contact_email'] : null,
      'whatsapp_number': _cleanPhone(rawData['whatsapp_number'] as String),
      'description': rawData['description'],
      'tags': tags,
      'contract_type': _contractType,
      'requires_cover_letter': _requiresCoverLetter,
      'cover_letter_instructions': rawData['cover_letter_instructions'],
      'deadline': rawData['deadline'],
      'is_ai_verified': false, // Scammers prevention: all recruiter jobs start unverified
      'is_approved': false, // Scammers prevention: recruiter jobs must be approved by admin
      'source_url': uniqueSourceUrl,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'raw_data': rawData,
    };

    try {
      final response = await _supabase.from('jobs').insert(jobData);
      debugPrint("Job Insertion Success: $response");
      setState(() {
        _isSuccess = true;
      });
    } catch (e) {
      debugPrint("Error inserting recruiter job: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la publication : ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Espace Recruteurs',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _isSuccess ? _buildSuccessView() : _buildFormView(),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 50,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'Offre publiée avec succès !',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'Votre offre est enregistrée et visible par les candidats.\n\nNote: Notre équipe va réviser votre offre sous peu pour lui attribuer le label de confiance "Vérifié".',
              style: TextStyle(
                fontSize: 14.sp,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40.h),
            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: Text(
                  'Retour à la connexion',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Safety reminder
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFD97706),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rappel Anti-Fraude important',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Tous les recrutements sur Djorssi Match sont gratuits pour les candidats. Les demandes de frais de dossier, de formation payante ou d\'argent pour passer un entretien sont strictement interdites. Tout compte suspect sera banni.',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: const Color(0xFFB45309),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Form inputs
            Text(
              'Informations de l\'entreprise',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 12.h),

            _buildTextField(
              controller: _companyController,
              label: 'Nom de l\'entreprise',
              hint: 'Ex: Orange CI, Boutique Ivoire...',
              icon: Icons.business,
              validator: (v) => v!.isEmpty ? 'Veuillez entrer le nom de l\'entreprise' : null,
            ),
            SizedBox(height: 16.h),

            Text(
              'Détails du poste',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 12.h),

            _buildTextField(
              controller: _titleController,
              label: 'Titre du poste',
              hint: 'Ex: Comptable, Chauffeur, Développeur...',
              icon: Icons.work_outline,
              validator: (v) => v!.isEmpty ? 'Veuillez entrer le titre du poste' : null,
            ),
            SizedBox(height: 16.h),

            // Contract Type Dropdown
            DropdownButtonFormField<String>(
              value: _contractType,
              decoration: InputDecoration(
                labelText: 'Type de contrat',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.description_outlined, color: Color(0xFF94A3B8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: const BorderSide(color: Color(0xFFF97316), width: 2),
                ),
              ),
              items: _contractTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _contractType = val);
                }
              },
            ),
            SizedBox(height: 16.h),

            _buildTextField(
              controller: _locationController,
              label: 'Ville / Localisation',
              hint: 'Ex: Abidjan - Cocody, Bouaké...',
              icon: Icons.location_on_outlined,
              validator: (v) => v!.isEmpty ? 'Veuillez entrer le lieu du poste' : null,
            ),
            SizedBox(height: 16.h),

            _buildTextField(
              controller: _levelController,
              label: 'Niveau d\'études requis',
              hint: 'Ex: BAC, BAC+2, CAP, Sans diplôme...',
              icon: Icons.school_outlined,
              validator: (v) => v!.isEmpty ? 'Veuillez entrer le niveau requis' : null,
            ),
            SizedBox(height: 16.h),

            _buildTextField(
              controller: _salaryController,
              label: 'Rémunération mensuelle (Optionnel)',
              hint: 'Ex: 150 000 FCFA, À négocier...',
              icon: Icons.payments_outlined,
            ),
            SizedBox(height: 16.h),

            _buildTextField(
              controller: _deadlineController,
              label: 'Date limite (Optionnel)',
              hint: 'Format: JJ/MM/AAAA (ex: 20/06/2026)',
              icon: Icons.calendar_today_outlined,
            ),
            SizedBox(height: 16.h),

            _buildTextField(
              controller: _descriptionController,
              label: 'Description du poste & prérequis',
              hint: 'Décrivez les tâches et profil recherché...',
              icon: Icons.info_outline,
              maxLines: 4,
              validator: (v) => v!.isEmpty ? 'Veuillez entrer une description' : null,
            ),
            SizedBox(height: 16.h),

            _buildTextField(
              controller: _tagsController,
              label: 'Compétences clés / Tags (séparés par virgules)',
              hint: 'Ex: Comptabilité, Excel, Vente, Accueil',
              icon: Icons.label_outline,
              validator: (v) => v!.isEmpty ? 'Veuillez entrer au moins un tag de compétence' : null,
            ),
            SizedBox(height: 24.h),

            Text(
              'Moyens de contact',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Où souhaitez-vous recevoir les candidatures ? (Au moins un e-mail ou WhatsApp requis)',
              style: TextStyle(
                fontSize: 12.sp,
                color: const Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 12.h),

            _buildTextField(
              controller: _emailController,
              label: 'Adresse e-mail de contact (Pour recevoir les CV)',
              hint: 'Ex: recrutement@entreprise.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v!.isEmpty && _whatsappController.text.trim().isEmpty) {
                  return 'Veuillez renseigner un e-mail ou un numéro WhatsApp';
                }
                if (v.isNotEmpty) {
                  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!emailRegex.hasMatch(v)) {
                    return 'Adresse e-mail invalide';
                  }
                }
                return null;
              },
            ),
            SizedBox(height: 16.h),

            _buildTextField(
              controller: _whatsappController,
              label: 'Numéro de téléphone WhatsApp (Pour échanger)',
              hint: 'Ex: 07070707',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v!.isEmpty && _emailController.text.trim().isEmpty) {
                  return 'Veuillez renseigner un e-mail ou un numéro WhatsApp';
                }
                return null;
              },
            ),
            SizedBox(height: 24.h),

            // Motivation Letter Switch
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SwitchListTile(
                title: Text(
                  'Exiger une lettre de motivation',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                subtitle: Text(
                  'Le candidat devra rédiger une lettre lors du swipe.',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: const Color(0xFF64748B),
                  ),
                ),
                value: _requiresCoverLetter,
                activeColor: const Color(0xFFF97316),
                onChanged: (val) {
                  setState(() => _requiresCoverLetter = val);
                },
              ),
            ),
            if (_requiresCoverLetter) ...[
              SizedBox(height: 16.h),
              _buildTextField(
                controller: _coverLetterController,
                label: 'Instructions pour la lettre de motivation',
                hint: 'Ex: Expliquez vos motivations et votre expérience de chauffeur...',
                icon: Icons.edit_note,
                validator: (v) => _requiresCoverLetter && v!.isEmpty
                    ? 'Veuillez entrer des consignes pour la lettre'
                    : null,
              ),
            ],
            SizedBox(height: 40.h),

            // Submit Button
            SizedBox(
              height: 56.h,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitJob,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20.h,
                        width: 20.h,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Publier l\'offre d\'emploi',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Color(0xFFF97316), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
}
