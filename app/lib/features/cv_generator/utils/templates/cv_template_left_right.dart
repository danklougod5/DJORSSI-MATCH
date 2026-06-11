import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/cv_model.dart';
import 'cv_template_base.dart';

class CvTemplateLeftRight extends CvTemplateBase {
  CvTemplateLeftRight() : super(id: 'left_right', name: 'Gauche-Droite');

  @override
  @override
  Future<Uint8List> generatePdf(CvModel cv) async {
    final pdf = pw.Document();
    
    final primary = hexToPdfColor(cv.primaryColor);
    final secondary = hexToPdfColor(cv.secondaryColor);
    const textColor = PdfColor.fromInt(0xFF1F2937);
    final avatarImage = await getAvatarImage(cv);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          buildBackground: (pw.Context context) {
            // Draw a clean vertical divider on each page.
            // Left margin is 24, left column width is 170.
            // Boundary is at x = 24 + 170 = 194.
            // We draw the line at x = 194.
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Stack(
                children: [
                  pw.Positioned(
                    left: 194,
                    top: 24,
                    bottom: 24,
                    child: pw.Container(
                      width: 1,
                      color: PdfColors.grey300,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        build: (pw.Context context) {
          return [
            pw.Partitions(
              children: [
                // Left Column (Sidebar)
                pw.Partition(
                  width: 170,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 16),
                        child: _buildHeaderLeft(cv.personalInfo, primary, secondary, avatarImage),
                      ),
                      
                      if (cv.skills.isNotEmpty) ...[
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(right: 16, top: 20),
                          child: _buildSectionTitle('Compétences', primary),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(right: 16),
                          child: buildBulletText(cv.skills, textColor, primary, fontSize: 10, height: 1.4),
                        ),
                      ],

                      if (cv.activities.isNotEmpty) ...[
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(right: 16, top: 20),
                          child: _buildSectionTitle('Loisirs', primary),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(right: 16),
                          child: buildBulletList(cv.activities, textColor, primary, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Right Column (Main content)
                pw.Partition(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (cv.personalInfo.summary.isNotEmpty) ...[
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 16),
                          child: _buildSectionTitle('Profil Professionnel', primary),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 16, bottom: 20),
                          child: pw.Text(sanitizeText(cv.personalInfo.summary), style: pw.TextStyle(fontSize: 10, color: textColor, height: 1.4)),
                        ),
                      ],

                      if (cv.experiences.isNotEmpty) ...[
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 16),
                          child: _buildSectionTitle('Expérience Professionnelle', primary),
                        ),
                        ...cv.experiences.where((e) => e.isVisible).map((e) => pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 16),
                          child: _buildExperienceItem(e, primary, secondary),
                        )),
                        pw.SizedBox(height: 8),
                      ],

                      if (cv.projects.isNotEmpty && cv.projects.any((p) => p.isVisible)) ...[
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 16, top: 12),
                          child: _buildSectionTitle('Projets', primary),
                        ),
                        ...cv.projects.where((p) => p.isVisible).map((p) => pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 16),
                          child: _buildProjectItem(p, primary, secondary),
                        )),
                        pw.SizedBox(height: 8),
                      ],

                      if (cv.educations.isNotEmpty && cv.educations.any((e) => e.isVisible)) ...[
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 16, top: 12),
                          child: _buildSectionTitle('Formation', primary),
                        ),
                        ...cv.educations.where((e) => e.isVisible).map((ed) => pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 16),
                          child: _buildEducationItem(ed, primary, secondary),
                        )),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeaderLeft(CvPersonalInfo info, PdfColor primary, PdfColor secondary, pw.ImageProvider? avatarImage) {
    final visibleContacts = info.contactFields.where((f) => f.isVisible && f.value.isNotEmpty).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (info.showAvatar) ...[
          buildAvatarWidget(info, avatarImage, size: 70),
          pw.SizedBox(height: 12),
        ],
        pw.Text(
          sanitizeText(info.fullName),
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: primary),
        ),
        if (info.jobTitle.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            sanitizeText(info.jobTitle),
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: secondary),
          ),
        ],
        pw.SizedBox(height: 16),
        ...visibleContacts.map((c) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(sanitizeText(c.label).toUpperCase(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: secondary)),
              pw.SizedBox(height: 2),
              pw.Text(sanitizeText(c.value), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
            ],
          ),
        )),
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          sanitizeText(title).toUpperCase(),
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color, letterSpacing: 0.5),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: 20,
          height: 2,
          color: color,
        ),
        pw.SizedBox(height: 10),
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
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primary, fontSize: 10),
                ),
                pw.TextSpan(
                  text: ' : ${sanitizeText(proj.name)}${proj.role.isNotEmpty ? ' (${sanitizeText(proj.role)})' : ''}',
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
                        text: sanitizeText(edu.degree),
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
              pw.Text('${sanitizeText(edu.startDate)} - ${sanitizeText(edu.endDate)}', style: pw.TextStyle(color: secondary, fontSize: 9)),
            ],
          ),
          if (edu.location.isNotEmpty)
            pw.Text(sanitizeText(edu.location), style: pw.TextStyle(color: secondary, fontSize: 9)),
          if (edu.description.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            buildBulletText(edu.description, secondary, primary, fontSize: 9, height: 1.3),
          ],
        ],
      ),
    );
  }
}
