import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/cv_model.dart';
import 'cv_template_base.dart';

class CvTemplateCreative extends CvTemplateBase {
  CvTemplateCreative() : super(id: 'creative', name: 'Créatif');

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
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Creative Header with borders
            _buildHeader(cv.personalInfo, primary, secondary, avatarImage),
            pw.SizedBox(height: 24),
            
            if (cv.personalInfo.summary.isNotEmpty) ...[
              _buildSectionTitle('À Propos', primary),
              pw.Text(cv.personalInfo.summary, style: const pw.TextStyle(color: textColor, height: 1.5, fontSize: 10)),
              pw.SizedBox(height: 20),
            ],

            if (cv.skills.isNotEmpty) ...[
              _buildSectionTitle('Compétences', primary),
              buildBulletText(cv.skills, textColor, primary, fontSize: 10, height: 1.4, splitByDelimiterIfNoNewline: true),
              pw.SizedBox(height: 20),
            ],

            if (cv.experiences.isNotEmpty && cv.experiences.any((e) => e.isVisible)) ...[
              _buildSectionTitle('Parcours Pro', primary),
              ...cv.experiences.where((e) => e.isVisible).map((e) => _buildExperienceItem(e, primary, secondary)),
              pw.SizedBox(height: 20),
            ],

            if (cv.projects.isNotEmpty && cv.projects.any((p) => p.isVisible)) ...[
              _buildSectionTitle('Projets Marquants', primary),
              ...cv.projects.where((p) => p.isVisible).map((p) => _buildProjectItem(p, primary, secondary)),
              pw.SizedBox(height: 20),
            ],

            if (cv.educations.isNotEmpty && cv.educations.any((e) => e.isVisible)) ...[
              _buildSectionTitle('Formations', primary),
              ...cv.educations.where((e) => e.isVisible).map((ed) => _buildEducationItem(ed, primary, secondary)),
              pw.SizedBox(height: 20),
            ],

            if (cv.activities.isNotEmpty) ...[
              _buildSectionTitle('Loisirs & Centres d\'intérêt', primary),
              pw.Wrap(
                spacing: 8,
                runSpacing: 4,
                children: cv.activities.map((a) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(a, style: const pw.TextStyle(color: textColor, fontSize: 9)),
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

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: primary, width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      padding: const pw.EdgeInsets.all(20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  info.fullName,
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primary),
                ),
                if (info.jobTitle.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    info.jobTitle,
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: secondary),
                  ),
                ],
                pw.SizedBox(height: 12),
                pw.Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: visibleContacts.map((c) => pw.Text(c.value, style: pw.TextStyle(color: secondary, fontSize: 9))).toList(),
                ),
              ],
            ),
          ),
          if (info.showAvatar) ...[
            pw.SizedBox(width: 16),
            buildAvatarWidget(info, avatarImage, size: 70),
          ]
        ],
      ),
    );
  }

  pw.Widget _buildSectionTitle(String title, PdfColor primary) {
    return pw.Container(
      width: double.infinity,
      color: primary,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 0.5),
      ),
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
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primary, fontSize: 11),
                ),
                pw.TextSpan(
                  text: formatExperienceHeader(exp),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF374151), fontSize: 11),
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
