import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/cv_model.dart';
import 'cv_template_base.dart';

class CvTemplateMinimalist extends CvTemplateBase {
  CvTemplateMinimalist() : super(id: 'minimalist', name: 'Minimaliste');

  @override
  Future<Uint8List> generatePdf(CvModel cv) async {
    final pdf = pw.Document();
    
    final primary = hexToPdfColor(cv.primaryColor);
    final secondary = hexToPdfColor(cv.secondaryColor);
    const textColor = PdfColor.fromInt(0xFF333333);
    final avatarImage = await getAvatarImage(cv);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Center Header
            _buildHeader(cv.personalInfo, primary, secondary, avatarImage),
            pw.SizedBox(height: 30),
            
            // Body
            if (cv.personalInfo.summary.isNotEmpty) ...[
              _buildSectionTitle('Profil', primary),
              pw.Text(cv.personalInfo.summary, style: const pw.TextStyle(color: textColor, height: 1.6, fontSize: 10)),
              pw.SizedBox(height: 24),
            ],

            if (cv.skills.isNotEmpty) ...[
              _buildSectionTitle('Compétences', primary),
              buildBulletText(cv.skills, textColor, primary, fontSize: 10, height: 1.4, splitByDelimiterIfNoNewline: true),
              pw.SizedBox(height: 24),
            ],

            if (cv.experiences.isNotEmpty && cv.experiences.any((e) => e.isVisible)) ...[
              _buildSectionTitle('Expériences Professionnelles', primary),
              ...cv.experiences.where((e) => e.isVisible).map((e) => _buildExperienceItem(e, primary, secondary)),
              pw.SizedBox(height: 24),
            ],

            if (cv.projects.isNotEmpty && cv.projects.any((p) => p.isVisible)) ...[
              _buildSectionTitle('Projets Réalisés', primary),
              ...cv.projects.where((p) => p.isVisible).map((p) => _buildProjectItem(p, primary, secondary)),
              pw.SizedBox(height: 24),
            ],

            if (cv.educations.isNotEmpty && cv.educations.any((e) => e.isVisible)) ...[
              _buildSectionTitle('Formations et Diplômes', primary),
              ...cv.educations.where((e) => e.isVisible).map((ed) => _buildEducationItem(ed, primary, secondary)),
              pw.SizedBox(height: 24),
            ],

            if (cv.activities.isNotEmpty) ...[
              _buildSectionTitle('Activités et Loisirs', primary),
              pw.Wrap(
                spacing: 8,
                runSpacing: 4,
                children: cv.activities.map((a) => pw.Text(a, style: const pw.TextStyle(color: textColor, fontSize: 10))).toList(),
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

    pw.Widget buildContactInfo(pw.WrapAlignment wrapAlign) {
      if (visibleContacts.isEmpty) return pw.SizedBox();
      
      return pw.Wrap(
        alignment: wrapAlign,
        spacing: 12,
        runSpacing: 4,
        children: visibleContacts.map((c) => pw.Text(c.value, style: pw.TextStyle(color: secondary, fontSize: 10))).toList(),
      );
    }

    pw.Widget buildContactInfoSplit() {
      if (visibleContacts.isEmpty) return pw.SizedBox();
      
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: visibleContacts.map((c) => pw.Text(c.value, style: pw.TextStyle(color: secondary, fontSize: 10))).toList(),
      );
    }

    pw.Widget content;
    if (info.layout == 'split') {
      content = pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (info.showAvatar) ...[
                  buildAvatarWidget(info, avatarImage, size: 70),
                  pw.SizedBox(width: 16),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        info.fullName.toUpperCase(),
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.normal, letterSpacing: 2, color: primary),
                      ),
                      if (info.jobTitle.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        pw.Text(
                          info.jobTitle.toUpperCase(),
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: secondary, letterSpacing: 1),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 24),
          buildContactInfoSplit(),
        ],
      );
    } else {
      final align = info.layout == 'left' ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.center;
      final wrapAlign = info.layout == 'left' ? pw.WrapAlignment.start : pw.WrapAlignment.center;
      
      content = pw.Column(
        crossAxisAlignment: align,
        children: [
          if (info.showAvatar) ...[
            buildAvatarWidget(info, avatarImage, size: 70),
            pw.SizedBox(height: 12),
          ],
          pw.Text(
            info.fullName.toUpperCase(),
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.normal, letterSpacing: 2, color: primary),
          ),
          if (info.jobTitle.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              info.jobTitle.toUpperCase(),
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: secondary, letterSpacing: 1),
            ),
          ],
          pw.SizedBox(height: 12),
          buildContactInfo(wrapAlign),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        content,
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title, PdfColor primary) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 1, color: primary),
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _buildExperienceItem(CvExperience exp, PdfColor primary, PdfColor secondary) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: exp.jobTitle.toUpperCase(),
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
      padding: const pw.EdgeInsets.only(bottom: 16),
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
      padding: const pw.EdgeInsets.only(bottom: 16),
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
                        text: edu.degree.toUpperCase(),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primary, fontSize: 10),
                      ),
                      pw.TextSpan(
                        text: formatEducationHeader(edu),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF374151), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              pw.Text('${edu.startDate} - ${edu.endDate}', style: pw.TextStyle(color: secondary, fontSize: 10)),
            ],
          ),
          if (edu.location.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(edu.location, style: pw.TextStyle(color: secondary, fontSize: 9)),
          ],
          if (edu.description.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            buildBulletText(edu.description, secondary, primary, fontSize: 9, height: 1.3),
          ],
        ],
      ),
    );
  }
}
