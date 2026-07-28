import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/error_translator.dart';

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
    final salary = job?['salary'] ?? job?['salary_range'] ?? 'Non spécifié';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.report_problem_outlined, color: Colors.red),
            tooltip: 'Signaler cette offre',
            onPressed: () => _showReportDialog(context, job?['id']),
          ),
        ],
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
        final hasNoCv = cvUrl == null ||
            cvUrl.trim().isEmpty ||
            cvUrl.trim().toLowerCase() == 'null' ||
            cvUrl.trim().toLowerCase() == 'undefined';
        if (hasNoCv) {
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
              content: Text(ErrorTranslator.translate(e)),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } else if (hasWhatsapp && whatsapp != null) {
      final List<String> numbers = _extractPhoneNumbers(whatsapp.toString());
      if (numbers.isNotEmpty) {
        final String firstNum = numbers.first;
        final String num = firstNum.length <= 10 ? '225$firstNum' : firstNum;
        final Uri waAppUri = Uri.parse('whatsapp://send?phone=$num');
        final Uri waWebUri = Uri.parse('https://wa.me/$num');

        try {
          if (await canLaunchUrl(waAppUri)) {
            await launchUrl(waAppUri, mode: LaunchMode.externalApplication);
          } else if (await canLaunchUrl(waWebUri)) {
            await launchUrl(waWebUri, mode: LaunchMode.externalApplication);
          } else {
            await launchUrl(waWebUri, mode: LaunchMode.externalNonBrowserApplication);
          }
        } catch (e) {
          debugPrint('Primary WhatsApp launch failed, trying webUrl fallback: $e');
          try {
            await launchUrl(waWebUri, mode: LaunchMode.externalApplication);
          } catch (e2) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Impossible d'ouvrir WhatsApp sur cet appareil.")),
              );
            }
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

  void _showReportDialog(BuildContext context, String? jobId) {
    if (jobId == null) return;
    
    String selectedReason = 'money_asked';
    final detailsController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              title: Row(
                children: [
                  const Icon(Icons.report_problem, color: Colors.red),
                  SizedBox(width: 8.w),
                  const Text('Signaler cette offre'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pourquoi signalez-vous cette offre ?',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    RadioListTile<String>(
                      title: const Text('Le recruteur demande de l\'argent / des frais'),
                      value: 'money_asked',
                      groupValue: selectedReason,
                      activeColor: Colors.red,
                      onChanged: (val) {
                        if (val != null) setState(() => selectedReason = val);
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Cette offre est fausse ou mensongère'),
                      value: 'scam',
                      groupValue: selectedReason,
                      activeColor: Colors.red,
                      onChanged: (val) {
                        if (val != null) setState(() => selectedReason = val);
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Comportement suspect ou inapproprié'),
                      value: 'suspicious_behavior',
                      groupValue: selectedReason,
                      activeColor: Colors.red,
                      onChanged: (val) {
                        if (val != null) setState(() => selectedReason = val);
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Autre raison'),
                      value: 'other',
                      groupValue: selectedReason,
                      activeColor: Colors.red,
                      onChanged: (val) {
                        if (val != null) setState(() => selectedReason = val);
                      },
                    ),
                    SizedBox(height: 16.h),
                    TextField(
                      controller: detailsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Détails complémentaires (Optionnel)',
                        hintText: 'Décrivez ce qui s\'est passé...',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(color: Color(0xFFF97316)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setState(() => isSubmitting = true);
                          try {
                            final userId = _supabase.auth.currentUser?.id;
                            if (userId == null) throw Exception('Utilisateur non connecté');

                            await _supabase.from('job_reports').insert({
                              'user_id': userId,
                              'job_id': jobId,
                              'reason': selectedReason,
                              'details': detailsController.text.trim().isNotEmpty
                                  ? detailsController.text.trim()
                                  : null,
                              'created_at': DateTime.now().toUtc().toIso8601String(),
                            });

                            if (context.mounted) {
                              Navigator.pop(context); // Close dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Signalement enregistré. Merci pour votre vigilance !'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur lors du signalement : ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            setState(() => isSubmitting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? SizedBox(
                          height: 16.h,
                          width: 16.h,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Signaler'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<String> _extractPhoneNumbers(String raw) {
    final List<String> numbers = [];
    final String cleaned = raw.replaceAll(RegExp(r'[\s\-\.\(\)]+'), '');
    final Iterable<Match> digitBlocks = RegExp(r'\d+').allMatches(cleaned);

    for (final block in digitBlocks) {
      final String digits = block.group(0)!;
      String remaining = digits;

      while (remaining.isNotEmpty) {
        if (remaining.startsWith('225')) {
          if (remaining.length >= 13) {
            numbers.add(remaining.substring(0, 13));
            remaining = remaining.substring(13);
          } else if (remaining.length >= 11) {
            numbers.add(remaining.substring(0, 11));
            remaining = remaining.substring(11);
          } else {
            if (remaining.length >= 8) {
              numbers.add(remaining);
            }
            remaining = '';
          }
        } else {
          if (remaining.length >= 10) {
            numbers.add(remaining.substring(0, 10));
            remaining = remaining.substring(10);
          } else if (remaining.length >= 8) {
            numbers.add(remaining);
            remaining = '';
          } else {
            remaining = '';
          }
        }
      }
    }
    return numbers;
  }
}
