import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/cv_model.dart';
import 'cv_template_base.dart';

class CvTemplateExecutive extends CvTemplateBase {
  CvTemplateExecutive() : super(id: 'executive', name: 'Exécutif');

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
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        build: (pw.Context context) {
          return [
            // Executive Header
            _buildHeader(cv.personalInfo, primary, secondary, avatarImage),
            pw.SizedBox(height: 20),
            
            if (cv.personalInfo.summary.isNotEmpty) ...[
              _buildSectionTitle('Profil Professionnel', primary),
              pw.Text(
                cv.personalInfo.summary,
                style: const pw.TextStyle(color: textColor, height: 1.5, fontSize: 10),
              ),
              pw.SizedBox(height: 16),
            ],

            if (cv.skills.isNotEmpty) ...[
              _buildSectionTitle('Compétences', primary),
              buildBulletText(cv.skills, textColor, primary, fontSize: 10, height: 1.4, splitByDelimiterIfNoNewline: true),
              pw.SizedBox(height: 16),
            ],

            if (cv.experiences.isNotEmpty && cv.experiences.any((e) => e.isVisible)) ...[
              _buildSectionTitle('Expériences Professionnelles', primary),
              ...cv.experiences.where((e) => e.isVisible).map((e) => _buildExperienceItem(e, primary, secondary)),
              pw.SizedBox(height: 16),
            ],

            if (cv.projects.isNotEmpty && cv.projects.any((p) => p.isVisible)) ...[
              _buildSectionTitle('Projets Récents', primary),
              ...cv.projects.where((p) => p.isVisible).map((p) => _buildProjectItem(p, primary, secondary)),
              pw.SizedBox(height: 16),
            ],

            if (cv.educations.isNotEmpty && cv.educations.any((e) => e.isVisible)) ...[
              _buildSectionTitle('Formation', primary),
              ...cv.educations.where((e) => e.isVisible).map((ed) => _buildEducationItem(ed, primary, secondary)),
              pw.SizedBox(height: 16),
            ],

            if (cv.activities.isNotEmpty) ...[
              _buildSectionTitle('Activités & Centres d\'intérêt', primary),
              pw.Wrap(
                spacing: 12,
                runSpacing: 6,
                children: cv.activities.map((a) => pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: 4,
                      height: 4,
                      decoration: const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFF374151),
                        shape: pw.BoxShape.circle,
                      ),
                      margin: const pw.EdgeInsets.only(right: 6),
                    ),
                    pw.Text(a, style: const pw.TextStyle(color: textColor, fontSize: 10)),
                  ],
                )).toList(),
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
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left column: Name and Title
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                info.fullName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: primary,
                  letterSpacing: 1.0,
                ),
              ),
              if (info.jobTitle.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  info.jobTitle,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: secondary,
                  ),
                ),
              ],
              pw.SizedBox(height: 12),
              // Horizontal line under name
              pw.Container(height: 1.5, color: PdfColor(secondary.red, secondary.green, secondary.blue, 0.3), width: 120),
            ],
          ),
        ),
        
        // Right column: Contact details & Avatar
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (visibleContacts.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(right: 16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: visibleContacts.map((c) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Text(
                      c.value,
                      style: const pw.TextStyle(color: PdfColor.fromInt(0xFF4B5563), fontSize: 8.5),
                    ),
                  )).toList(),
                ),
              ),
            if (info.showAvatar)
              buildAvatarWidget(info, avatarImage, size: 65, fallbackBg: PdfColor(secondary.red, secondary.green, secondary.blue, 0.2)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title, PdfColor primary) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Vertical bar
            pw.Container(
              width: 3.5,
              height: 14,
              decoration: pw.BoxDecoration(
                color: primary,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: primary,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Container(height: 0.5, color: PdfColors.grey300),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildExperienceItem(CvExperience exp, PdfColor primary, PdfColor secondary) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Job title & Company
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      exp.jobTitle,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primary, fontSize: 10),
                    ),
                    if (exp.company.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          exp.company,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF374151), fontSize: 9.5),
                        ),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              // Dates & Location
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    '${exp.startDate} - ${exp.endDate}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF374151), fontSize: 9),
                  ),
                  if (exp.location.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(
                        exp.location,
                        style: pw.TextStyle(color: secondary, fontSize: 8.5, fontStyle: pw.FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (exp.description.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            buildBulletText(exp.description, const PdfColor.fromInt(0xFF374151), primary, fontSize: 9, height: 1.3),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildEducationItem(CvEducation edu, PdfColor primary, PdfColor secondary) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Degree & School
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      edu.degree,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primary, fontSize: 10),
                    ),
                    if (edu.institution.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          edu.institution,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF374151), fontSize: 9.5),
                        ),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              // Dates & Location
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    '${edu.startDate} - ${edu.endDate}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF374151), fontSize: 9),
                  ),
                  if (edu.location.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(
                        edu.location,
                        style: pw.TextStyle(color: secondary, fontSize: 8.5, fontStyle: pw.FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (edu.description.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            buildBulletText(edu.description, const PdfColor.fromInt(0xFF374151), primary, fontSize: 9, height: 1.3),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildProjectItem(CvProject proj, PdfColor primary, PdfColor secondary) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Project name & Role
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      proj.name,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primary, fontSize: 10),
                    ),
                    if (proj.role.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          proj.role,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.normal, color: const PdfColor.fromInt(0xFF374151), fontSize: 9.5, fontStyle: pw.FontStyle.italic),
                        ),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              // Dates
              if (proj.date.isNotEmpty)
                pw.Text(
                  proj.date,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF374151), fontSize: 9),
                ),
            ],
          ),
          if (proj.description.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            buildBulletText(proj.description, const PdfColor.fromInt(0xFF374151), primary, fontSize: 9, height: 1.3),
          ],
        ],
      ),
    );
  }
}
