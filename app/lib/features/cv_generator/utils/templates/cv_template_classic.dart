import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/cv_model.dart';
import 'cv_template_base.dart';

class CvTemplateClassic extends CvTemplateBase {
  CvTemplateClassic() : super(id: 'classic', name: 'Classique');

  @override
  Future<Uint8List> generatePdf(CvModel cv) async {
    final pdf = pw.Document();
    
    final primary = hexToPdfColor(cv.primaryColor);
    final secondary = hexToPdfColor(cv.secondaryColor);
    final avatarImage = await getAvatarImage(cv);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(cv.personalInfo, primary, secondary, avatarImage),
            pw.SizedBox(height: 20),
            
            if (cv.personalInfo.summary.isNotEmpty) ...[
              _buildSectionTitle('Profil / Résumé', primary, secondary),
              pw.Text(cv.personalInfo.summary),
              pw.SizedBox(height: 15),
            ],

            if (cv.skills.isNotEmpty) ...[
              _buildSectionTitle('Compétences', primary, secondary),
              buildBulletText(cv.skills, const PdfColor.fromInt(0xFF1F2937), primary, fontSize: 10, height: 1.4),
              pw.SizedBox(height: 15),
            ],

            if (cv.experiences.isNotEmpty) ...[
              _buildSectionTitle('Expériences Professionnelles', primary, secondary),
              ...cv.experiences.where((e) => e.isVisible).map((e) => _buildExperienceItem(e, primary, secondary)),
              pw.SizedBox(height: 15),
            ],

            if (cv.projects.isNotEmpty && cv.projects.any((p) => p.isVisible)) ...[
              _buildSectionTitle('Projets Réalisés', primary, secondary),
              ...cv.projects.where((p) => p.isVisible).map((p) => _buildProjectItem(p, primary, secondary)),
              pw.SizedBox(height: 15),
            ],

            if (cv.educations.isNotEmpty && cv.educations.any((e) => e.isVisible)) ...[
              _buildSectionTitle('Formations et Diplômes', primary, secondary),
              ...cv.educations.where((e) => e.isVisible).map((ed) => _buildEducationItem(ed, primary, secondary)),
              pw.SizedBox(height: 15),
            ],

            if (cv.activities.isNotEmpty) ...[
              _buildSectionTitle('Activités et Loisirs', primary, secondary),
              buildBulletList(cv.activities, const PdfColor.fromInt(0xFF374151), primary, fontSize: 10),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(CvPersonalInfo info, PdfColor primary, PdfColor secondary, pw.ImageProvider? avatarImage) {
    final visibleContacts = info.contactFields.where((f) => f.isVisible && f.value.isNotEmpty).toList();

    pw.Widget buildContactInfo() {
      if (visibleContacts.isEmpty) return pw.SizedBox();
      
      if (info.layout == 'center') {
        return pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            for (int i = 0; i < visibleContacts.length; i++) ...[
              if (i > 0) pw.Text(' | ', style: pw.TextStyle(color: secondary)),
              pw.Text(visibleContacts[i].value, style: pw.TextStyle(color: secondary)),
            ]
          ],
        );
      } else {
        return pw.Wrap(
          spacing: 12,
          runSpacing: 4,
          children: visibleContacts.map((c) => pw.Text(c.value, style: pw.TextStyle(color: secondary))).toList(),
        );
      }
    }

    pw.Widget buildContactInfoSplit() {
      if (visibleContacts.isEmpty) return pw.SizedBox();
      
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: visibleContacts.map((c) => pw.Text(c.value, style: pw.TextStyle(color: secondary, fontSize: 10))).toList(),
      );
    }

    pw.Widget buildAvatar() {
      return buildAvatarWidget(info, avatarImage, size: 60);
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
                  buildAvatar(),
                  pw.SizedBox(width: 16),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        info.fullName.toUpperCase(),
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primary),
                      ),
                      if (info.jobTitle.isNotEmpty)
                        pw.Text(
                          info.jobTitle,
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: secondary),
                        ),
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
      final align = info.layout == 'center' ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start;
      
      pw.Widget buildTextPart() {
        return pw.Column(
          crossAxisAlignment: align,
          children: [
            pw.Text(
              info.fullName.toUpperCase(),
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primary),
            ),
            if (info.jobTitle.isNotEmpty)
              pw.Text(
                info.jobTitle,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: secondary),
              ),
            pw.SizedBox(height: 8),
            buildContactInfo(),
          ],
        );
      }

      content = pw.Column(
        crossAxisAlignment: align,
        children: [
          if (info.showAvatar) ...[
            buildAvatar(),
            pw.SizedBox(height: 12),
          ],
          buildTextPart(),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        content,
        pw.SizedBox(height: 8),
        pw.Divider(color: secondary),
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title, PdfColor primary, PdfColor secondary) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primary),
        ),
        pw.Divider(color: secondary, thickness: 1),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildExperienceItem(CvExperience exp, PdfColor primary, PdfColor secondary) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
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
      padding: const pw.EdgeInsets.only(bottom: 10),
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
      padding: const pw.EdgeInsets.only(bottom: 10),
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
