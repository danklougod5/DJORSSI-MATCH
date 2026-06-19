import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/cv_model.dart';
import 'cv_template_base.dart';

class CvTemplateElegant extends CvTemplateBase {
  CvTemplateElegant() : super(id: 'elegant', name: 'Élégant');

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
            // Elegant Header
            _buildHeader(cv.personalInfo, primary, secondary, avatarImage),
            pw.SizedBox(height: 20),
            
            if (cv.personalInfo.summary.isNotEmpty) ...[
              _buildSectionTitle('Profil Professionnel', primary),
              pw.Text(cv.personalInfo.summary, style: const pw.TextStyle(color: textColor, height: 1.5, fontSize: 10)),
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
              _buildSectionTitle('Projets Clés', primary),
              ...cv.projects.where((p) => p.isVisible).map((p) => _buildProjectItem(p, primary, secondary)),
              pw.SizedBox(height: 16),
            ],

            if (cv.educations.isNotEmpty && cv.educations.any((e) => e.isVisible)) ...[
              _buildSectionTitle('Cursus Académique', primary),
              ...cv.educations.where((e) => e.isVisible).map((ed) => _buildEducationItem(ed, primary, secondary)),
              pw.SizedBox(height: 16),
            ],

            if (cv.activities.isNotEmpty) ...[
              _buildSectionTitle('Activités & Intérêts', primary),
              pw.Wrap(
                spacing: 12,
                runSpacing: 6,
                children: cv.activities.map((a) => pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: 3.5,
                      height: 3.5,
                      decoration: pw.BoxDecoration(
                        color: primary,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.75)),
                      ),
                      margin: const pw.EdgeInsets.only(right: 4),
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

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (info.showAvatar) ...[
          buildAvatarWidget(info, avatarImage, size: 70),
          pw.SizedBox(height: 10),
        ],
        pw.Text(
          info.fullName.toUpperCase(),
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primary, letterSpacing: 1.5),
        ),
        if (info.jobTitle.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            info.jobTitle,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal, color: secondary, fontStyle: pw.FontStyle.italic),
          ),
        ],
        pw.SizedBox(height: 10),
        pw.Wrap(
          spacing: 12,
          runSpacing: 4,
          alignment: pw.WrapAlignment.center,
          children: visibleContacts.map((c) => pw.Text(c.value, style: pw.TextStyle(color: secondary, fontSize: 9))).toList(),
        ),
        pw.SizedBox(height: 8),
        // Double line divider
        pw.Container(height: 1, color: primary),
        pw.SizedBox(height: 2),
        pw.Container(height: 1, color: primary),
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title, PdfColor primary) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 12),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primary),
        ),
        pw.SizedBox(height: 4),
        pw.Container(height: 1, color: PdfColors.grey300),
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
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: exp.jobTitle,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primary, fontSize: 10),
                ),
                pw.TextSpan(
                  text: formatExperienceHeader(exp),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF374151), fontSize: 10),
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
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF374151), fontSize: 10),
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
              pw.Expanded(
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: edu.degree,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primary, fontSize: 10),
                      ),
                      pw.TextSpan(
                        text: formatEducationHeader(edu),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF374151), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text('${edu.startDate} - ${edu.endDate}', style: pw.TextStyle(color: secondary, fontSize: 9)),
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
    );
  }
}
