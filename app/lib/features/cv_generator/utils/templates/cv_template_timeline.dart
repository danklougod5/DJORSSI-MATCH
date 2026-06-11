import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/cv_model.dart';
import 'cv_template_base.dart';

class CvTemplateTimeline extends CvTemplateBase {
  CvTemplateTimeline() : super(id: 'timeline', name: 'Chronologique');

  @override
  Future<Uint8List> generatePdf(CvModel cv) async {
    final pdf = pw.Document();
    
    final primary = hexToPdfColor(cv.primaryColor);
    final secondary = hexToPdfColor(cv.secondaryColor);
    const textColor = PdfColor.fromInt(0xFF1F2937);
    final avatarImage = await getAvatarImage(cv);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return [
            // Timeline Header
            _buildHeader(cv.personalInfo, primary, secondary, avatarImage),
            pw.SizedBox(height: 24),
            
            if (cv.personalInfo.summary.isNotEmpty) ...[
              _buildSectionTitle('Profil / Résumé', primary),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 12),
                child: pw.Text(
                  cv.personalInfo.summary,
                  style: const pw.TextStyle(color: textColor, fontSize: 10, height: 1.4),
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            if (cv.skills.isNotEmpty) ...[
              _buildSectionTitle('Compétences', primary),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 12),
                child: buildBulletText(cv.skills, textColor, primary, fontSize: 10, height: 1.4),
              ),
              pw.SizedBox(height: 20),
            ],

            if (cv.experiences.isNotEmpty) ...[
              _buildSectionTitle('Parcours Professionnel', primary),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: () {
                    final visibleExps = cv.experiences.where((e) => e.isVisible).toList();
                    return List.generate(visibleExps.length, (index) {
                      final e = visibleExps[index];
                      return _buildTimelineExperience(
                        e,
                        primary,
                        textColor,
                        secondary,
                        isFirst: index == 0,
                        isLast: index == visibleExps.length - 1,
                      );
                    });
                  }(),
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            if (cv.projects.isNotEmpty && cv.projects.any((p) => p.isVisible)) ...[
              _buildSectionTitle('Projets Réalisés', primary),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 12),
                child: pw.Column(
                  children: cv.projects.where((p) => p.isVisible).map((p) => _buildProjectItem(p, primary, secondary)).toList(),
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            if (cv.educations.isNotEmpty && cv.educations.any((e) => e.isVisible)) ...[
              _buildSectionTitle('Formations', primary),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: () {
                    final visibleEdus = cv.educations.where((e) => e.isVisible).toList();
                    return List.generate(visibleEdus.length, (index) {
                      final ed = visibleEdus[index];
                      return _buildTimelineEducation(
                        ed,
                        primary,
                        textColor,
                        secondary,
                        isFirst: index == 0,
                        isLast: index == visibleEdus.length - 1,
                      );
                    });
                  }(),
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            if (cv.activities.isNotEmpty) ...[
              _buildSectionTitle('Activités & Loisirs', primary),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 12),
                child: buildBulletList(cv.activities, textColor, primary, fontSize: 10),
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(CvPersonalInfo info, PdfColor primary, PdfColor secondary, pw.ImageProvider? avatarImage) {
    final visibleContacts = info.contactFields.where((f) => f.isVisible && f.value.isNotEmpty).toList();

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Swiss Style accent vertical bar
              pw.Container(
                width: 4,
                height: info.jobTitle.isNotEmpty ? 42 : 28,
                decoration: pw.BoxDecoration(
                  color: primary,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      info.fullName.toUpperCase(),
                      style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: primary),
                    ),
                    if (info.jobTitle.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        info.jobTitle.toUpperCase(),
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: secondary, letterSpacing: 1),
                      ),
                    ],
                    pw.SizedBox(height: 12),
                    pw.Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: visibleContacts.map((c) => pw.Text(c.value, style: pw.TextStyle(color: secondary, fontSize: 10))).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (info.showAvatar) ...[
          pw.SizedBox(width: 16),
          buildAvatarWidget(info, avatarImage, size: 70),
        ]
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title, PdfColor primary) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 5,
              height: 14,
              decoration: pw.BoxDecoration(
                color: primary,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A), letterSpacing: 0.5),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 1, color: PdfColors.grey200),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _buildTimelineExperience(
    CvExperience exp,
    PdfColor primary,
    PdfColor textColor,
    PdfColor secondary, {
    required bool isFirst,
    required bool isLast,
  }) {
    return pw.Stack(
      children: [
        // Ligne verticale segmentée
        if (!(isFirst && isLast))
          pw.Positioned(
            top: isFirst ? 7.5 : 0,
            bottom: isLast ? null : 0,
            left: 3.25,
            child: pw.Container(
              width: 1.5,
              height: isLast ? 7.5 : null,
              color: PdfColor(primary.red, primary.green, primary.blue, 0.3),
            ),
          ),
        // Point de frise (rond)
        pw.Positioned(
          left: 0,
          top: 3.5,
          child: pw.Container(
            width: 8,
            height: 8,
            decoration: pw.BoxDecoration(
              color: primary,
              shape: pw.BoxShape.circle,
            ),
          ),
        ),
        // Contenu
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 20, bottom: 16),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: exp.jobTitle,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primary, fontSize: 11),
                    ),
                    pw.TextSpan(
                      text: formatExperienceHeader(exp),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF374151), fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (exp.description.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                buildBulletText(exp.description, secondary, primary, fontSize: 9, height: 1.3),
              ],
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTimelineEducation(
    CvEducation edu,
    PdfColor primary,
    PdfColor textColor,
    PdfColor secondary, {
    required bool isFirst,
    required bool isLast,
  }) {
    return pw.Stack(
      children: [
        // Ligne verticale segmentée
        if (!(isFirst && isLast))
          pw.Positioned(
            top: isFirst ? 7.5 : 0,
            bottom: isLast ? null : 0,
            left: 3.25,
            child: pw.Container(
              width: 1.5,
              height: isLast ? 7.5 : null,
              color: PdfColor(primary.red, primary.green, primary.blue, 0.3),
            ),
          ),
        // Point de frise (rond)
        pw.Positioned(
          left: 0,
          top: 3.5,
          child: pw.Container(
            width: 8,
            height: 8,
            decoration: pw.BoxDecoration(
              color: primary,
              shape: pw.BoxShape.circle,
            ),
          ),
        ),
        // Contenu
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 20, bottom: 16),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: edu.degree,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primary, fontSize: 11),
                          ),
                          pw.TextSpan(
                            text: formatEducationHeader(edu),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF374151), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.Text(
                    '${edu.startDate} - ${edu.endDate}',
                    style: pw.TextStyle(color: secondary, fontWeight: pw.FontWeight.bold, fontSize: 9),
                  ),
                ],
              ),
              if (edu.location.isNotEmpty)
                pw.Text(edu.location, style: pw.TextStyle(color: secondary, fontSize: 9)),
              if (edu.description.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                buildBulletText(edu.description, secondary, primary, fontSize: 9, height: 1.3),
              ],
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildProjectItem(CvProject proj, PdfColor primary, PdfColor secondary) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: proj.date,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primary, fontSize: 10),
                ),
                pw.TextSpan(
                  text: ' : ${proj.name}${proj.role.isNotEmpty ? ' (${proj.role})' : ''}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF374151), fontSize: 10),
                ),
              ],
            ),
          ),
          if (proj.description.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            buildBulletText(proj.description, secondary, primary, fontSize: 9, height: 1.3),
          ],
        ],
      ),
    );
  }
}
