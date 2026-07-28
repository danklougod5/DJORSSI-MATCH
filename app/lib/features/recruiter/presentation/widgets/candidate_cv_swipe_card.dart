import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:djossimatch/features/cv_generator/models/cv_model.dart';
import 'package:djossimatch/features/cv_generator/services/cv_ai_import_service.dart';

class CandidateCvSwipeCard extends StatefulWidget {
  final String? candidateId;
  final String fullName;
  final List<String> skills;
  final String? biography;
  final String? cvUrl;
  final String? sexe;
  final List<Map<String, dynamic>>? experiences;
  final List<Map<String, dynamic>>? educations;
  final bool isBlurred;

  const CandidateCvSwipeCard({
    super.key,
    this.candidateId,
    required this.fullName,
    required this.skills,
    this.biography,
    this.cvUrl,
    this.sexe,
    this.experiences,
    this.educations,
    this.isBlurred = false,
  });

  @override
  State<CandidateCvSwipeCard> createState() => _CandidateCvSwipeCardState();
}

class _CandidateCvSwipeCardState extends State<CandidateCvSwipeCard> {
  Future<Uint8List>? _pdfFuture;
  String? _rawExtractedText;
  List<Map<String, dynamic>>? _autoExperiences;
  List<Map<String, dynamic>>? _autoEducations;
  String? _autoBiography;
  List<String>? _autoSkills;

  @override
  void initState() {
    super.initState();
    _loadParsedCvFromDatabase();
    if (widget.cvUrl != null && widget.cvUrl!.isNotEmpty) {
      _pdfFuture = _loadPdfBytes(widget.cvUrl!);
    }
  }

  Future<Uint8List> _loadPdfBytes(String url) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Délai d\'attente dépassé'),
        );
    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      if (bytes.length < 5 ||
          bytes[0] != 0x25 ||
          bytes[1] != 0x50 ||
          bytes[2] != 0x44 ||
          bytes[3] != 0x46) {
        throw Exception('Fichier non-PDF ou corrompu');
      }
      return bytes;
    } else {
      throw Exception('Erreur de téléchargement (${response.statusCode})');
    }
  }

  Future<void> _loadParsedCvFromDatabase() async {
    if (widget.candidateId == null) return;
    try {
      final profileRes = await Supabase.instance.client
          .from('profiles')
          .select('parsed_cv')
          .eq('id', widget.candidateId!)
          .maybeSingle();

      if (profileRes != null && profileRes['parsed_cv'] != null) {
        final parsedMap = profileRes['parsed_cv'] as Map<String, dynamic>;
        final parsedStr = parsedMap.toString();
        if (!parsedStr.contains('Djossi Tech') &&
            !parsedStr.contains('Silicon Abidjan')) {
          final cvModel = CvModel.fromJson(parsedMap);
          if (mounted) {
            setState(() {
              _autoBiography = cvModel.personalInfo.summary;
              _autoExperiences = cvModel.experiences
                  .map((e) => e.toJson())
                  .toList();
              _autoEducations = cvModel.educations
                  .map((e) => e.toJson())
                  .toList();
              _autoSkills = cvModel.skills
                  .split('\n')
                  .where((s) => s.trim().isNotEmpty)
                  .toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur lecture parsed_cv BDD recruteur: $e');
    }
  }

  String get candidateJobTitle {
    final experiences = widget.experiences ?? _autoExperiences;
    final educations = widget.educations ?? _autoEducations;
    final skills = widget.skills.isNotEmpty ? widget.skills : _autoSkills;

    if (experiences != null && experiences.isNotEmpty) {
      for (var exp in experiences) {
        final title = (exp['jobTitle'] ?? exp['job_title'] ?? '')
            .toString()
            .trim();
        final lower = title.toLowerCase();
        if (title.isNotEmpty &&
            !lower.contains('membre') &&
            !lower.contains('stagiaire') &&
            !lower.contains('bénévol') &&
            title != 'Poste') {
          return title;
        }
      }
      for (var exp in experiences) {
        final title = (exp['jobTitle'] ?? exp['job_title'] ?? '')
            .toString()
            .trim();
        final company = (exp['company'] ?? '').toString().trim();
        if (title.isNotEmpty && title.toLowerCase() != 'poste') {
          if (company.isNotEmpty) return '$title ($company)';
          return title;
        }
      }
    }

    if (educations != null && educations.isNotEmpty) {
      for (var edu in educations) {
        final degree = (edu['degree'] ?? '').toString().trim();
        if (degree.isNotEmpty && degree.toLowerCase() != 'diplôme') {
          return degree;
        }
      }
    }

    if (skills != null && skills.isNotEmpty) {
      const genericTags = {
        'emploi',
        'stage',
        'bac+2',
        'bac+3',
        'bac+4',
        'bac+5',
        'bac',
        'btp & industrie',
        'commerce & management',
        'logistique & transport',
        'secteur',
        'polyvalent',
        'tout secteur',
        'btp',
        'bâtiment',
        'informatique',
      };
      final cleanSkills = skills
          .map(
            (s) => s
                .replaceAll('[', '')
                .replaceAll(']', '')
                .replaceAll('"', '')
                .replaceAll("'", '')
                .trim(),
          )
          .where((s) => s.isNotEmpty && !genericTags.contains(s.toLowerCase()))
          .toList();
      if (cleanSkills.isNotEmpty) {
        return cleanSkills.take(2).join(' • ');
      }
    }
    return 'Profil Professionnel';
  }

  void _openFullScreenCv([Uint8List? pdfData]) {
    final effectiveExp =
        (widget.experiences != null && widget.experiences!.isNotEmpty)
        ? widget.experiences
        : _autoExperiences;
    final effectiveEdu =
        (widget.educations != null && widget.educations!.isNotEmpty)
        ? widget.educations
        : _autoEducations;
    final effectiveBio =
        (widget.biography != null && widget.biography!.trim().isNotEmpty)
        ? widget.biography
        : _autoBiography;
    final effectiveSkills = (_autoSkills != null && _autoSkills!.isNotEmpty)
        ? _autoSkills!
        : widget.skills;

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.4),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenCvViewer(
            candidateId: widget.candidateId,
            pdfData: pdfData,
            rawExtractedText: _rawExtractedText,
            candidateName: widget.fullName,
            skills: effectiveSkills,
            biography: effectiveBio,
            sexe: widget.sexe,
            experiences: effectiveExp,
            educations: effectiveEdu,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
          );
          final fadeAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );

          return ScaleTransition(
            scale: scaleAnimation,
            child: FadeTransition(opacity: fadeAnimation, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heroTag = 'candidate_card_${widget.fullName}_${widget.cvUrl ?? ''}';
    final effectiveExp = widget.experiences ?? _autoExperiences;
    final effectiveEdu = widget.educations ?? _autoEducations;
    final effectiveSkills = (_autoSkills != null && _autoSkills!.isNotEmpty)
        ? _autoSkills!
        : widget.skills;

    return Hero(
      tag: heroTag,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {
            if (_pdfFuture != null) {
              _pdfFuture!
                  .then((bytes) {
                    if (mounted) _openFullScreenCv(bytes);
                  })
                  .catchError((_) {
                    if (mounted) _openFullScreenCv(null);
                  });
            } else {
              _openFullScreenCv(null);
            }
          },
          child: Card(
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.r),
              side: const BorderSide(color: Color(0xFF94A3B8), width: 1.5),
            ),
            clipBehavior: Clip.hardEdge,
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: Stack(
                children: [
                  // ─── SCROLLABLE FICHE & PARCOURS DANS LE STYLE DOCUMENT MODERNE ───
                  Positioned.fill(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // 1. En-tête document (Avatar à gauche + Bouton [🔍 Voir CV] sombre à droite + Nom & Titre)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 12.h),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    CircleAvatar(
                                      radius: 22.r,
                                      backgroundColor: const Color(0xFFFFF7ED),
                                      child: Icon(
                                        widget.sexe == 'Femme'
                                            ? Icons.woman
                                            : Icons.man,
                                        color: const Color(0xFFF97316),
                                        size: 26.r,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        if (_pdfFuture != null) {
                                          _pdfFuture!
                                              .then((bytes) {
                                                if (mounted)
                                                  _openFullScreenCv(bytes);
                                              })
                                              .catchError((_) {
                                                if (mounted)
                                                  _openFullScreenCv(null);
                                              });
                                        } else {
                                          _openFullScreenCv(null);
                                        }
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 14.w,
                                          vertical: 7.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF334155),
                                          borderRadius: BorderRadius.circular(
                                            20.r,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.15,
                                              ),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.search_rounded,
                                              size: 15.r,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 5.w),
                                            Text(
                                              'Voir CV',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12.5.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12.h),
                                Text(
                                  widget.fullName.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF781E2E),
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  candidateJobTitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF475569),
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 12.h),
                                const Divider(
                                  color: Color(0xFFCBD5E1),
                                  height: 1,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 2. Présentation & Résumé
                        if ((widget.biography != null &&
                                widget.biography!.trim().isNotEmpty) ||
                            (_autoBiography != null &&
                                _autoBiography!.trim().isNotEmpty)) ...[
                          SliverPadding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            sliver: SliverPersistentHeader(
                              pinned: true,
                              delegate: _StickySectionHeaderDelegate(
                                title: 'Présentation & Résumé',
                                icon: Icons.description_rounded,
                                color: const Color(0xFF781E2E),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 14.h),
                            sliver: SliverToBoxAdapter(
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(14.r),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  (widget.biography != null &&
                                          widget.biography!.trim().isNotEmpty)
                                      ? widget.biography!
                                      : _autoBiography!,
                                  style: TextStyle(
                                    fontSize: 13.5.sp,
                                    color: const Color(0xFF334155),
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],

                        // 3. Compétences Clés (PLACÉ AVANT EXPÉRIENCES PROFESSIONNELLES)
                        if (effectiveSkills.isNotEmpty) ...[
                          SliverPadding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            sliver: SliverPersistentHeader(
                              pinned: true,
                              delegate: _StickySectionHeaderDelegate(
                                title: 'Compétences Clés',
                                icon: Icons.bolt_rounded,
                                color: const Color(0xFF781E2E),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 14.h),
                            sliver: SliverToBoxAdapter(
                              child: Wrap(
                                spacing: 6.w,
                                runSpacing: 6.h,
                                children: () {
                                  final List<String> parsedSkills = [];
                                  for (var s in effectiveSkills) {
                                    final parts = s.split(RegExp(r'[,;\n]'));
                                    for (var p in parts) {
                                      final clean = p
                                          .replaceAll('[', '')
                                          .replaceAll(']', '')
                                          .replaceAll('"', '')
                                          .replaceAll("'", '')
                                          .trim();
                                      if (clean.isNotEmpty)
                                        parsedSkills.add(clean);
                                    }
                                  }
                                  return parsedSkills.map((skill) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 5.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFFCD34D),
                                        ),
                                      ),
                                      child: Text(
                                        skill,
                                        style: TextStyle(
                                          color: const Color(0xFFB45309),
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  }).toList();
                                }(),
                              ),
                            ),
                          ),
                        ],

                        // 4. Expériences Professionnelles
                        if (effectiveExp != null &&
                            effectiveExp.isNotEmpty) ...[
                          SliverPadding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            sliver: SliverPersistentHeader(
                              pinned: true,
                              delegate: _StickySectionHeaderDelegate(
                                title: 'Expériences Professionnelles',
                                icon: Icons.work_history_rounded,
                                color: const Color(0xFF781E2E),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 14.h),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final exp = effectiveExp[index];
                                var rawJob =
                                    (exp['jobTitle'] ??
                                            exp['job_title'] ??
                                            'Poste')
                                        .toString();
                                if (rawJob.trim().toLowerCase() == 'membre') {
                                  rawJob = candidateJobTitle;
                                }
                                final company = (exp['company'] ?? '')
                                    .toString();
                                final startDate =
                                    (exp['startDate'] ??
                                            exp['start_date'] ??
                                            '')
                                        .toString();
                                final endDate =
                                    (exp['endDate'] ?? exp['end_date'] ?? '')
                                        .toString();
                                final rawBullets =
                                    exp['bulletPoints'] ??
                                    exp['bullet_points'] ??
                                    [];
                                final List<String> bullets = rawBullets is List
                                    ? List<String>.from(rawBullets)
                                    : [];

                                String dateString = '';
                                if (startDate.isNotEmpty &&
                                    endDate.isNotEmpty) {
                                  final lowerEnd = endDate.toLowerCase().trim();
                                  if (lowerEnd.contains('présent') ||
                                      lowerEnd.contains('present') ||
                                      lowerEnd.contains('actuel')) {
                                    dateString = startDate;
                                  } else {
                                    dateString = '$startDate - $endDate';
                                  }
                                } else if (startDate.isNotEmpty) {
                                  dateString = startDate;
                                }

                                return Container(
                                  width: double.infinity,
                                  margin: EdgeInsets.only(bottom: 10.h),
                                  padding: EdgeInsets.all(14.r),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              rawJob,
                                              style: TextStyle(
                                                fontSize: 14.5.sp,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          if (dateString.isNotEmpty)
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 8.w,
                                                vertical: 3.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius:
                                                    BorderRadius.circular(6.r),
                                              ),
                                              child: Text(
                                                dateString,
                                                style: TextStyle(
                                                  fontSize: 11.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(
                                                    0xFF1D4ED8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (company.isNotEmpty) ...[
                                        SizedBox(height: 2.h),
                                        Text(
                                          company,
                                          style: TextStyle(
                                            fontSize: 12.5.sp,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                      if (bullets.isNotEmpty) ...[
                                        SizedBox(height: 8.h),
                                        ...bullets
                                            .take(3)
                                            .map(
                                              (b) => Padding(
                                                padding: EdgeInsets.only(
                                                  bottom: 3.h,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '• ',
                                                      style: TextStyle(
                                                        color: const Color(
                                                          0xFF2563EB,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13.sp,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        b,
                                                        style: TextStyle(
                                                          fontSize: 12.5.sp,
                                                          color: const Color(
                                                            0xFF334155,
                                                          ),
                                                          height: 1.35,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                      ],
                                    ],
                                  ),
                                );
                              }, childCount: effectiveExp.length),
                            ),
                          ),
                        ],

                        // 5. Formations & Diplômes
                        if (effectiveEdu != null &&
                            effectiveEdu.isNotEmpty) ...[
                          SliverPadding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            sliver: SliverPersistentHeader(
                              pinned: true,
                              delegate: _StickySectionHeaderDelegate(
                                title: 'Formations & Diplômes',
                                icon: Icons.school_rounded,
                                color: const Color(0xFF781E2E),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              16.w,
                              6.h,
                              16.w,
                              110.h,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final edu = effectiveEdu[index];
                                final degree = (edu['degree'] ?? 'Diplôme')
                                    .toString();
                                final school = (edu['school'] ?? '').toString();
                                final year =
                                    (edu['year'] ?? edu['endDate'] ?? '')
                                        .toString();

                                return Container(
                                  width: double.infinity,
                                  margin: EdgeInsets.only(bottom: 10.h),
                                  padding: EdgeInsets.all(14.r),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              degree,
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            if (school.isNotEmpty)
                                              Text(
                                                school,
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  color: const Color(
                                                    0xFF64748B,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (year.isNotEmpty)
                                        Text(
                                          year,
                                          style: TextStyle(
                                            fontSize: 11.5.sp,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF0284C7),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }, childCount: effectiveEdu.length),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 2. SLEEK DARK OVERLAY FOOTER (Matching exact screenshot!)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: true,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(16.w, 36.h, 16.w, 16.h),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.0),
                              Colors.black.withValues(alpha: 0.75),
                              Colors.black.withValues(alpha: 0.95),
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(24.r),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.fullName.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                CircleAvatar(
                                  radius: 20.r,
                                  backgroundColor: const Color(0xFFF97316),
                                  child: Icon(
                                    Icons.description_rounded,
                                    color: Colors.white,
                                    size: 20.r,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Wrap(
                              spacing: 8.w,
                              runSpacing: 6.h,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                    vertical: 6.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    candidateJobTitle,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                    vertical: 6.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Emploi',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18.r),
        SizedBox(width: 6.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 14.5.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildNoCvBackground({
    String message = 'Aucun CV fourni par ce candidat.',
    bool isError = false,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.description_outlined,
              color: isError ? Colors.redAccent : const Color(0xFFCBD5E1),
              size: 64.r,
            ),
            SizedBox(height: 16.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── Safe PDF Preview that catches rastering errors ───
class _SafePdfPreview extends StatefulWidget {
  final Uint8List pdfData;

  const _SafePdfPreview({required this.pdfData});

  @override
  State<_SafePdfPreview> createState() => _SafePdfPreviewState();
}

class _SafePdfPreviewState extends State<_SafePdfPreview> {
  bool _hasError = false;

  bool _isValidPdf(Uint8List bytes) {
    if (bytes.length < 50) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46; // %PDF
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || !_isValidPdf(widget.pdfData)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              color: const Color(0xFFCBD5E1),
              size: 64.r,
            ),
            SizedBox(height: 16.h),
            Text(
              'Ce CV ne peut pas être affiché',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Guard against zero or extremely small constraints during swiping transitions
        final double renderWidth = constraints.maxWidth > 100
            ? constraints.maxWidth
            : 300.w;
        return PdfPreview(
          build: (format) async => widget.pdfData,
          canChangeOrientation: false,
          canChangePageFormat: false,
          useActions: false,
          allowPrinting: false,
          allowSharing: false,
          maxPageWidth: renderWidth,
          pdfPreviewPageDecoration: const BoxDecoration(color: Colors.white),
          onError: (context, error) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _hasError = true);
            });
            return Center(
              child: Text(
                'Aperçu du CV indisponible',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// ─── Full-Screen CV Viewer with PDF & AI Synthesis ───
class FullScreenCvViewer extends StatefulWidget {
  final String? candidateId;
  final Uint8List? pdfData;
  final String? rawExtractedText;
  final String candidateName;
  final List<String> skills;
  final String? biography;
  final String? sexe;
  final List<Map<String, dynamic>>? experiences;
  final List<Map<String, dynamic>>? educations;

  const FullScreenCvViewer({
    super.key,
    this.candidateId,
    this.pdfData,
    this.rawExtractedText,
    required this.candidateName,
    required this.skills,
    this.biography,
    this.sexe,
    this.experiences,
    this.educations,
  });

  @override
  State<FullScreenCvViewer> createState() => _FullScreenCvViewerState();
}

class _FullScreenCvViewerState extends State<FullScreenCvViewer> {
  String? _rawText;
  List<Map<String, dynamic>>? _experiences;
  List<Map<String, dynamic>>? _educations;
  String? _biography;
  List<String>? _skills;

  bool get _hasValidPdf =>
      widget.pdfData != null &&
      widget.pdfData!.length >= 50 &&
      widget.pdfData![0] == 0x25 &&
      widget.pdfData![1] == 0x50;

  String get candidateJobTitle {
    // 1. Chercher un titre de poste significatif dans le parcours
    if (_experiences != null && _experiences!.isNotEmpty) {
      for (var exp in _experiences!) {
        final title = (exp['jobTitle'] ?? exp['job_title'] ?? '')
            .toString()
            .trim();
        final lower = title.toLowerCase();
        if (title.isNotEmpty &&
            !lower.contains('membre') &&
            !lower.contains('stagiaire') &&
            !lower.contains('bénévol') &&
            title != 'Poste') {
          return title;
        }
      }
    }

    if (_experiences != null && _experiences!.isNotEmpty) {
      for (var exp in _experiences!) {
        final title = (exp['jobTitle'] ?? exp['job_title'] ?? '')
            .toString()
            .trim();
        final company = (exp['company'] ?? '').toString().trim();
        if (title.isNotEmpty && title.toLowerCase() != 'poste') {
          if (company.isNotEmpty) {
            return '$title ($company)';
          }
          return title;
        }
      }
    }

    if (_educations != null && _educations!.isNotEmpty) {
      for (var edu in _educations!) {
        final degree = (edu['degree'] ?? '').toString().trim();
        if (degree.isNotEmpty && degree.toLowerCase() != 'diplôme') {
          return degree;
        }
      }
    }

    if (_skills != null && _skills!.isNotEmpty) {
      const genericTags = {
        'emploi',
        'stage',
        'bac+2',
        'bac+3',
        'bac+4',
        'bac+5',
        'bac',
        'btp & industrie',
        'commerce & management',
        'logistique & transport',
        'secteur',
        'polyvalent',
        'tout secteur',
        'btp',
        'bâtiment',
        'informatique',
      };
      final cleanSkills = _skills!
          .map(
            (s) => s
                .replaceAll('[', '')
                .replaceAll(']', '')
                .replaceAll('"', '')
                .replaceAll("'", '')
                .trim(),
          )
          .where((s) => s.isNotEmpty && !genericTags.contains(s.toLowerCase()))
          .toList();
      if (cleanSkills.isNotEmpty) {
        return cleanSkills.take(2).join(' • ');
      }
    }
    return 'Profil Professionnel';
  }

  @override
  void initState() {
    super.initState();
    _experiences = widget.experiences;
    _educations = widget.educations;
    _biography = widget.biography;
    _skills = widget.skills;
    _rawText = widget.rawExtractedText;

    if (widget.candidateId != null && widget.candidateId!.isNotEmpty) {
      _loadProfileFromSupabase(widget.candidateId!);
    }

    if (widget.pdfData != null) {
      try {
        final extracted = CvAiImportService.extractTextFromPdf(widget.pdfData!);
        final cleaned = CvAiImportService.cleanAndFormatRawText(extracted);
        if (cleaned.isNotEmpty) {
          _rawText = cleaned;
        }
      } catch (e) {
        debugPrint('Safe PDF text extraction catch: $e');
      }
    }
  }

  Future<void> _loadProfileFromSupabase(String candidateId) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('full_name, biography, skills, sexe, raw_cv_text')
          .eq('id', candidateId)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          if (_biography == null || _biography!.isEmpty) {
            _biography = data['biography'] as String?;
          }
          if (_skills == null || _skills!.isEmpty) {
            final raw = data['skills'];
            if (raw is List) {
              _skills = List<String>.from(raw);
            }
          }
          if (_experiences == null || _experiences!.isEmpty) {
            final raw = data['experiences'];
            if (raw is List) {
              _experiences = List<Map<String, dynamic>>.from(raw);
            }
          }
          if (_educations == null || _educations!.isEmpty) {
            final raw = data['educations'];
            if (raw is List) {
              _educations = List<Map<String, dynamic>>.from(raw);
            }
          }
          if (_rawText == null || _rawText!.isEmpty) {
            _rawText = data['raw_cv_text'] as String?;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading full candidate profile in viewer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return HeroMode(
      enabled: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(
            'Fiche & Parcours — ${widget.candidateName}',
            style: TextStyle(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 17.sp,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 1,
        ),
        body: _buildStructuredCvView(context),
      ),
    );
  }

  void _showPdfModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Document PDF Original',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: PdfPreview(
                  build: (format) async => widget.pdfData!,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  useActions: false,
                  allowPrinting: false,
                  allowSharing: false,
                  pdfPreviewPageDecoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStructuredCvView(BuildContext context) {
    final currentSkills = _skills ?? widget.skills;

    OrganizedCvData? organizedData;
    if (_rawText != null && _rawText!.trim().isNotEmpty) {
      organizedData = CvAiImportService.organizeExtractedText(_rawText!);
    }

    final List<String> extractedSkills = [];
    for (var raw in currentSkills) {
      final cleaned = raw
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .replaceAll("'", '')
          .trim();
      if (cleaned.contains(',')) {
        extractedSkills.addAll(cleaned.split(',').map((s) => s.trim()));
      } else if (cleaned.contains('\n')) {
        extractedSkills.addAll(cleaned.split('\n').map((s) => s.trim()));
      } else if (cleaned.isNotEmpty) {
        extractedSkills.add(cleaned);
      }
    }

    const genericTags = {
      'emploi',
      'stage',
      'bac+2',
      'bac+3',
      'bac+4',
      'bac+5',
      'bac',
      'btp & industrie',
      'commerce & management',
      'logistique & transport',
      'secteur',
      'polyvalent',
      'tout secteur',
      'btp',
      'bâtiment',
    };

    final cleanSkills = extractedSkills
        .where(
          (s) =>
              s.trim().isNotEmpty &&
              !genericTags.contains(s.trim().toLowerCase()),
        )
        .toSet()
        .toList();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20.r, 20.r, 20.r, 12.r),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32.r,
                    backgroundColor: const Color(
                      0xFFF97316,
                    ).withValues(alpha: 0.15),
                    child: Icon(
                      widget.sexe == 'Femme' ? Icons.woman : Icons.man,
                      color: const Color(0xFFF97316),
                      size: 36.r,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.candidateName,
                                style: TextStyle(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Icon(
                              Icons.verified_rounded,
                              size: 18.r,
                              color: const Color(0xFF0284C7),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          candidateJobTitle,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2563EB),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_biography != null && _biography!.trim().isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20.r),
            sliver: SliverPersistentHeader(
              pinned: true,
              delegate: _StickySectionHeaderDelegate(
                title: 'Présentation & Résumé',
                icon: Icons.description_rounded,
                color: const Color(0xFFF97316),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20.r, 8.r, 20.r, 20.r),
            sliver: SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: const Color(0xFFF97316).withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _biography!,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF334155),
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],

        if (cleanSkills.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20.r),
            sliver: SliverPersistentHeader(
              pinned: true,
              delegate: _StickySectionHeaderDelegate(
                title: 'Compétences Clés',
                icon: Icons.psychology_rounded,
                color: const Color(0xFFD97706),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20.r, 8.r, 20.r, 20.r),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: cleanSkills.map((skill) {
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      skill,
                      style: TextStyle(
                        color: const Color(0xFFB45309),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],

        if (_experiences != null && _experiences!.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20.r),
            sliver: SliverPersistentHeader(
              pinned: true,
              delegate: _StickySectionHeaderDelegate(
                title: 'Expériences Professionnelles',
                icon: Icons.work_history_rounded,
                color: const Color(0xFF1E3A8A),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20.r, 8.r, 20.r, 20.r),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final exp = _experiences![index];
                var jobTitle = (exp['jobTitle'] ?? exp['job_title'] ?? 'Poste')
                    .toString();
                if (jobTitle.trim().toLowerCase() == 'membre') {
                  jobTitle = candidateJobTitle;
                }
                final company = (exp['company'] ?? '').toString();
                final startDate = (exp['startDate'] ?? '').toString().trim();
                final endDate = (exp['endDate'] ?? '').toString().trim();
                final rawPeriod = (exp['period'] ?? '').toString().trim();

                String period = '';
                final isEndPresent =
                    endDate.isEmpty ||
                    endDate.toLowerCase().contains('présent') ||
                    endDate.toLowerCase().contains('actuel') ||
                    endDate.toLowerCase().contains('aujourd');

                if (startDate.isNotEmpty) {
                  if (endDate.isNotEmpty && !isEndPresent) {
                    period = '$startDate - $endDate';
                  } else {
                    period = startDate;
                  }
                } else if (rawPeriod.isNotEmpty) {
                  period = rawPeriod
                      .replaceAll(' - Présent', '')
                      .replaceAll('- Présent', '')
                      .replaceAll(' - Aujourd\'hui', '')
                      .replaceAll('- Aujourd\'hui', '')
                      .replaceAll('Présent', '')
                      .trim();
                }

                final desc = (exp['description'] ?? '').toString();

                return Container(
                  margin: EdgeInsets.only(bottom: 12.h),
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              jobTitle,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (period.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 3.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                period,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (company.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          company,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                      if (desc.isNotEmpty) ...[
                        SizedBox(height: 8.h),
                        Text(
                          desc,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: const Color(0xFF475569),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }, childCount: _experiences!.length),
            ),
          ),
        ],

        if (_educations != null && _educations!.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20.r),
            sliver: SliverPersistentHeader(
              pinned: true,
              delegate: _StickySectionHeaderDelegate(
                title: 'Formations & Diplômes',
                icon: Icons.school_rounded,
                color: const Color(0xFF059669),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20.r, 8.r, 20.r, 20.r),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final edu = _educations![index];
                final degree = (edu['degree'] ?? 'Diplôme').toString();
                final institution = (edu['institution'] ?? '').toString();
                final startDate = (edu['startDate'] ?? '').toString().trim();
                final endDate = (edu['endDate'] ?? '').toString().trim();
                final rawYear = (edu['year'] ?? edu['period'] ?? '')
                    .toString()
                    .trim();

                String period = '';
                final isEndPresent =
                    endDate.isEmpty ||
                    endDate.toLowerCase().contains('présent') ||
                    endDate.toLowerCase().contains('actuel') ||
                    endDate.toLowerCase().contains('aujourd');

                if (startDate.isNotEmpty) {
                  if (endDate.isNotEmpty && !isEndPresent) {
                    period = '$startDate - $endDate';
                  } else {
                    period = startDate;
                  }
                } else if (endDate.isNotEmpty && !isEndPresent) {
                  period = endDate;
                } else if (rawYear.isNotEmpty) {
                  period = rawYear
                      .replaceAll(' - Présent', '')
                      .replaceAll('- Présent', '')
                      .replaceAll('Présent', '')
                      .trim();
                }

                final desc = (edu['description'] ?? '').toString();

                return Container(
                  margin: EdgeInsets.only(bottom: 12.h),
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              degree,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (period.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 3.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                period,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF059669),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (institution.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          institution,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ],
                      if (desc.isNotEmpty) ...[
                        SizedBox(height: 8.h),
                        Text(
                          desc,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: const Color(0xFF475569),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }, childCount: _educations!.length),
            ),
          ),
        ],

        if ((_experiences == null || _experiences!.isEmpty) &&
            (_educations == null || _educations!.isEmpty)) ...[
          if (organizedData != null && organizedData.sections.isNotEmpty) ...[
            SliverPadding(
              padding: EdgeInsets.all(20.r),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final entry = organizedData!.sections.entries.elementAt(
                    index,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        entry.key,
                        Icons.folder_special_rounded,
                        const Color(0xFF0284C7),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: entry.value
                              .map((line) => _buildFormattedCvLine(line))
                              .toList(),
                        ),
                      ),
                      SizedBox(height: 20.h),
                    ],
                  );
                }, childCount: organizedData.sections.length),
              ),
            ),
          ] else if (_rawText != null && _rawText!.trim().isNotEmpty) ...[
            SliverPadding(
              padding: EdgeInsets.all(20.r),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      'Contenu du CV',
                      Icons.article_rounded,
                      const Color(0xFF0284C7),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SelectableText(
                        _rawText!,
                        style: TextStyle(
                          fontSize: 13.5.sp,
                          color: const Color(0xFF1E293B),
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
        SliverToBoxAdapter(child: SizedBox(height: 30.h)),
      ],
    );
  }

  Widget _buildFormattedCvLine(String rawLine) {
    String cleanLine = rawLine.trim();
    if (cleanLine.isEmpty) return const SizedBox.shrink();

    // Ignorer les puces incomplètes sans texte comme "2025 -"
    if (cleanLine.endsWith('-') ||
        cleanLine.endsWith('–') ||
        cleanLine.endsWith('—')) {
      cleanLine = cleanLine.substring(0, cleanLine.length - 1).trim();
      if (cleanLine.isEmpty) return const SizedBox.shrink();
    }

    // Détection de puces ou coches (✓, •, -, *)
    final isCheck = cleanLine.startsWith('✓') || cleanLine.startsWith('✔');
    final isBullet =
        cleanLine.startsWith('•') ||
        cleanLine.startsWith('-') ||
        cleanLine.startsWith('*');

    if (isCheck || isBullet) {
      cleanLine = cleanLine.substring(1).trim();
    }
    if (cleanLine.isEmpty) return const SizedBox.shrink();

    // Détection de toute plage de dates ou mois (ex: 2023 - 2025 :, Octobre à Décembre 2021 :, Depuis Janvier 2022 :)
    final dateMatch = RegExp(
      r'^((?:\d{4}\s*[-–—]\s*\d{4}|\b\d{4}\b|Depuis\s+[A-Za-zÀ-ÿ0-9\s]+|[A-Za-zÀ-ÿ]+\s+à\s+[A-Za-zÀ-ÿ0-9\s]+))\s*:\s*',
      caseSensitive: false,
    ).firstMatch(cleanLine);

    if (dateMatch != null) {
      final dateText = dateMatch.group(1)?.trim() ?? '';
      final bodyText = cleanLine.substring(dateMatch.end).trim();
      if (bodyText.isEmpty && dateText.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dateText.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12.r,
                      color: const Color(0xFF2563EB),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      dateText,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: const Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (bodyText.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                bodyText,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Lignes Clé : Valeur (ex: Email : ... ou Situation Matrimoniale : ...)
    final colonIndex = cleanLine.indexOf(' : ');
    if (colonIndex > 0 && colonIndex < 40) {
      final keyText = cleanLine.substring(0, colonIndex).trim();
      final valText = cleanLine.substring(colonIndex + 3).trim();

      return Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$keyText : ',
                style: TextStyle(
                  fontSize: 13.5.sp,
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              TextSpan(
                text: valText,
                style: TextStyle(
                  fontSize: 13.5.sp,
                  color: const Color(0xFF334155),
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Ligne standard avec puce ou coche
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCheck) ...[
            Icon(
              Icons.check_circle_rounded,
              size: 16.r,
              color: const Color(0xFF10B981),
            ),
            SizedBox(width: 8.w),
          ] else if (isBullet) ...[
            Container(
              margin: EdgeInsets.only(top: 6.h),
              width: 6.r,
              height: 6.r,
              decoration: const BoxDecoration(
                color: Color(0xFF0284C7),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 10.w),
          ],
          Expanded(
            child: Text(
              cleanLine,
              style: TextStyle(
                fontSize: 13.5.sp,
                color: const Color(0xFF1E293B),
                height: 1.5,
                fontWeight: isCheck ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    final cleanTitle = title
        .replaceAll('📁', '')
        .replaceAll('📄', '')
        .replaceAll('📝', '')
        .replaceAll('💼', '')
        .replaceAll('⚡', '')
        .replaceAll('🎓', '')
        .replaceAll('📂', '')
        .trim();

    return Row(
      children: [
        Icon(icon, color: color, size: 20.r),
        SizedBox(width: 8.w),
        Text(
          cleanTitle,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

/// Delegate d'en-tête épinglé collant (Sticky Header)
class _StickySectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final IconData icon;
  final Color color;

  _StickySectionHeaderDelegate({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final cleanTitle = title
        .replaceAll('📁', '')
        .replaceAll('📄', '')
        .replaceAll('📝', '')
        .replaceAll('💼', '')
        .replaceAll('⚡', '')
        .replaceAll('🎓', '')
        .replaceAll('📂', '')
        .trim();

    return Container(
      color: const Color(0xFFF8FAFC),
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20.r),
            SizedBox(width: 8.w),
            Text(
              cleanTitle,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  double get maxExtent => 52.h;

  @override
  double get minExtent => 52.h;

  @override
  bool shouldRebuild(covariant _StickySectionHeaderDelegate oldDelegate) {
    return oldDelegate.title != title ||
        oldDelegate.icon != icon ||
        oldDelegate.color != color;
  }
}
