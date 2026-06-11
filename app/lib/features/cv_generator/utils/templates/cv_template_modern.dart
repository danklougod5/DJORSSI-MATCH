import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/cv_model.dart';
import 'cv_template_base.dart';

class CvTemplateModern extends CvTemplateBase {
  CvTemplateModern() : super(id: 'modern', name: 'Moderne');

  @override
  @override
  Future<Uint8List> generatePdf(CvModel cv) async {
    final pdf = pw.Document();
    
    final primaryColor = hexToPdfColor(cv.primaryColor);
    final secondaryColor = hexToPdfColor(cv.secondaryColor);
    const textColor = PdfColor.fromInt(0xFF1F2937); // Dark grey for body text
    final avatarImage = await getAvatarImage(cv);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context context) {
          return [
            // Colored Header (touching the edges)
            pw.Container(
              color: primaryColor,
              padding: const pw.EdgeInsets.all(32),
              child: _buildHeader(cv.personalInfo, secondaryColor, avatarImage),
            ),
            
            pw.SizedBox(height: 32),
            
            // Body sections, each padded individually so they can break across pages
            if (cv.personalInfo.summary.isNotEmpty) ...[
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                child: _buildSectionTitle('Profil', primaryColor),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                child: pw.Text(sanitizeText(cv.personalInfo.summary), style: const pw.TextStyle(color: textColor, height: 1.5)),
              ),
              pw.SizedBox(height: 20),
            ],

            if (cv.skills.isNotEmpty) ...[
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                child: _buildSectionTitle('Compétences', primaryColor),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                child: buildBulletText(cv.skills, textColor, primaryColor, fontSize: 10, height: 1.4),
              ),
              pw.SizedBox(height: 20),
            ],

            if (cv.experiences.isNotEmpty) ...[
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                child: _buildSectionTitle('Expériences Professionnelles', primaryColor),
              ),
              ...cv.experiences.where((e) => e.isVisible).map((e) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                child: _buildExperienceItem(e, primaryColor, secondaryColor),
              )),
              pw.SizedBox(height: 8),
            ],

            if (cv.projects.isNotEmpty && cv.projects.any((p) => p.isVisible)) ...[
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                child: _buildSectionTitle('Projets Réalisés', primaryColor),
              ),
              ...cv.projects.where((p) => p.isVisible).map((p) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                child: _buildProjectItem(p, primaryColor, secondaryColor),
              )),
              pw.SizedBox(height: 8),
            ],

            if (cv.educations.isNotEmpty && cv.educations.any((e) => e.isVisible)) ...[
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                child: _buildSectionTitle('Formations et Diplômes', primaryColor),
              ),
              ...cv.educations.where((e) => e.isVisible).map((ed) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                child: _buildEducationItem(ed, primaryColor, secondaryColor),
              )),
              pw.SizedBox(height: 8),
            ],

            if (cv.activities.isNotEmpty) ...[
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                child: _buildSectionTitle('Activités et Loisirs', primaryColor),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                child: buildBulletList(cv.activities, textColor, primaryColor, fontSize: 10),
              ),
            ],
            
            pw.SizedBox(height: 32),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(CvPersonalInfo info, PdfColor secondaryColor, pw.ImageProvider? avatarImage) {
    final visibleContacts = info.contactFields.where((f) => f.isVisible && f.value.isNotEmpty).toList();

    pw.Widget buildContactInfo() {
      if (visibleContacts.isEmpty) return pw.SizedBox();
      
      return pw.Wrap(
        spacing: 16,
        runSpacing: 8,
        children: visibleContacts.map((c) => pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(sanitizeText(c.value), style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
          ]
        )).toList(),
      );
    }

    pw.Widget buildTextPart() {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            sanitizeText(info.fullName).toUpperCase(),
            style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          ),
          if (info.jobTitle.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              sanitizeText(info.jobTitle),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.normal, color: PdfColors.white),
            ),
          ],
          pw.SizedBox(height: 12),
          buildContactInfo(),
        ],
      );
    }

    pw.Widget buildAvatar() {
      return buildAvatarWidget(info, avatarImage, size: 80, fallbackBg: PdfColors.white);
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(child: buildTextPart()),
        if (info.showAvatar) ...[
          pw.SizedBox(width: 20),
          buildAvatar(),
        ],
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          sanitizeText(title).toUpperCase(),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: 30,
          height: 3,
          color: color,
        ),
        pw.SizedBox(height: 12),
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
                  text: sanitizeText(exp.jobTitle),
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
                  text: sanitizeText(proj.date),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primary, fontSize: 11),
                ),
                pw.TextSpan(
                  text: ' : ${sanitizeText(proj.name)}${proj.role.isNotEmpty ? ' (${sanitizeText(proj.role)})' : ''}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF374151), fontSize: 11),
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
                        text: sanitizeText(edu.degree),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primary, fontSize: 11),
                      ),
                      pw.TextSpan(
                        text: formatEducationHeader(edu),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF374151), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              pw.Text('${sanitizeText(edu.startDate)} - ${sanitizeText(edu.endDate)}', style: pw.TextStyle(color: secondary, fontSize: 10)),
            ],
          ),
          if (edu.location.isNotEmpty)
            pw.Text(sanitizeText(edu.location), style: pw.TextStyle(color: secondary, fontSize: 10)),
          if (edu.description.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            buildBulletText(edu.description, secondary, primary, fontSize: 9, height: 1.3),
          ],
        ],
      ),
    );
  }
}
