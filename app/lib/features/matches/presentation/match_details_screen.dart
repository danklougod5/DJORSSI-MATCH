import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class MatchDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> match;

  const MatchDetailsScreen({super.key, required this.match});

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final job = widget.match['jobs'] as Map<String, dynamic>?;
    final date = DateTime.parse(widget.match['created_at']);
    final companyName = job?['company_name'] ?? 'Inconnu';
    final jobTitle = job?['job_title'] ?? 'Poste Inconnu';
    final salary = job?['salary'] ?? 'Non spécifié';
    final location = job?['location'] ?? 'Non spécifiée';
    final description = job?['description'] ?? 'Aucune description disponible.';
    final contractType = job?['contract_type'];
    final experience = job?['experience'];
    final requiredLevel = job?['required_level'];

    final whatsapp = job?['whatsapp_number'];
    final email = job?['contact_email'];
    final appLink =
        job?['application_link'] ??
        (job?['raw_data'] != null
            ? job!['raw_data']['application_link']
            : null);

    final hasEmail = email != null && email.toString().trim().isNotEmpty;
    final hasWhatsapp =
        whatsapp != null && whatsapp.toString().trim().isNotEmpty;
    final hasLink = appLink != null && appLink.toString().trim().isNotEmpty;

    final actionTaken = widget.match['status'] == 'action_taken';

    String statusText = 'Candidature envoyée';
    IconData statusIcon = Icons.check_circle_outline;
    Color statusColor = Colors.green;

    if (!hasEmail) {
      if (hasWhatsapp) {
        statusText = actionTaken
            ? 'Contact initié sur WhatsApp'
            : 'Contacter le recruteur';
        statusIcon = actionTaken
            ? Icons.check_circle_outline
            : Icons.chat_bubble_outline;
        statusColor = actionTaken ? Colors.green : const Color(0xFFF97316);
      } else if (hasLink) {
        statusText = actionTaken
            ? 'Lien de candidature visité'
            : 'Lien externe (à finaliser)';
        statusIcon = actionTaken ? Icons.check_circle_outline : Icons.link;
        statusColor = actionTaken ? Colors.green : Colors.blue;
      } else {
        statusText = 'Profil envoyé au recruteur';
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Détails du Match',
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
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: EdgeInsets.all(20.r),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                            companyName.isNotEmpty
                                ? companyName[0].toUpperCase()
                                : 'C',
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
                              jobTitle,
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              companyName,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  const Divider(),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16.r,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Matché le ${DateFormat('dd MMMM yyyy', 'fr_FR').format(date)}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(statusIcon, size: 16.r, color: statusColor),
                      SizedBox(width: 8.w),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // Job Infos
            Text(
              'Informations sur le poste',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 12.h),
            _buildInfoTile(Icons.payments_outlined, 'Salaire', salary),
            _buildInfoTile(
              Icons.location_on_outlined,
              'Localisation',
              location,
            ),
            if (contractType != null)
              _buildInfoTile(
                Icons.description_outlined,
                'Type de contrat',
                contractType,
              ),
            if (experience != null)
              _buildInfoTile(Icons.history, 'Expérience', experience),
            if (requiredLevel != null)
              _buildInfoTile(Icons.school, 'Niveau requis', requiredLevel),

            SizedBox(height: 24.h),

            // Description
            Text(
              'Description',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF334155),
                  height: 1.5,
                ),
              ),
            ),

            SizedBox(height: 40.h),

            if (hasWhatsapp || hasLink || hasEmail)
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: () => _handleApplyAgain(
                    context,
                    hasEmail,
                    email?.toString(),
                    hasWhatsapp,
                    whatsapp?.toString(),
                    hasLink,
                    appLink?.toString(),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Postuler à nouveau',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApplyAgain(
    BuildContext context,
    bool hasEmail,
    String? email,
    bool hasWhatsapp,
    String? whatsapp,
    bool hasLink,
    String? appLink,
  ) async {
    if (hasEmail && email != null) {
      try {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Candidature en cours de renvoi...'),
          ),
        );

        // 1. Refresh session
        await _supabase.auth.refreshSession();

        final userId = _supabase.auth.currentUser?.id;
        final session = _supabase.auth.currentSession;

        if (userId == null || session == null) {
          throw Exception('Auth session missing or user not found');
        }

        // 2. Fetch profile
        final profile = await _supabase
            .from('profiles')
            .select('cv_url, full_name, sexe')
            .eq('id', userId)
            .single();

        final String? cvUrl = profile['cv_url'];
        if (cvUrl == null || cvUrl.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Veuillez ajouter votre CV sur votre profil'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final job = widget.match['jobs'];

        // 3. Invoke function WITHOUT explicit headers first
        // as it works in swipe_screen.dart
        final response = await _supabase.functions.invoke(
          'apply-to-job',
          body: {
            'jobTitle': job['job_title'],
            'jobCompany': job['company_name'],
            'jobContactEmail': email.trim(),
            'cvUrl': cvUrl,
            'userName': profile['full_name'],
            'userSexe': profile['sexe'],
            'message': null,
            'requiresCoverLetter': job['requires_cover_letter'] ?? false,
            'coverLetterInstructions': job['cover_letter_instructions'],
            'jobDescription': job['description'],
          },
        );

        debugPrint('RESPONSE APPLY AGAIN: ${response.status} - ${response.data}');

        if (response.status == 200 || response.status == 201) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Candidature renvoyée avec succès !'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Server returned ${response.status}: ${response.data}');
        }
      } catch (e) {
        debugPrint('ERROR APPLY AGAIN: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Détail : $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } else if (hasWhatsapp && whatsapp != null) {
      final cleaned = whatsapp.replaceAll(RegExp(r'[\s\-\.\(\)]+'), '');
      final matchNums = RegExp(r'\d+').allMatches(cleaned);
      if (matchNums.isNotEmpty) {
        String num = matchNums.first.group(0)!;
        if (num.length <= 10) num = '225$num';
        final Uri waAppUri = Uri.parse('whatsapp://send?phone=$num');
        final Uri waWebUri = Uri.parse('https://wa.me/$num');

        try {
          if (await canLaunchUrl(waAppUri)) {
            await launchUrl(waAppUri, mode: LaunchMode.externalApplication);
          } else if (await canLaunchUrl(waWebUri)) {
            await launchUrl(waWebUri, mode: LaunchMode.externalApplication);
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Application WhatsApp non trouvée")),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Erreur d'ouverture WhatsApp")),
            );
          }
        }
      }
    } else if (hasLink && appLink != null) {
      try {
        final Uri url = Uri.parse(appLink);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Impossible d'ouvrir le lien externe"),
            ),
          );
        }
      } catch (_) {}
    }
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, size: 20.r, color: const Color(0xFFF97316)),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
