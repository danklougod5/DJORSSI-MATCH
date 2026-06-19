import 'dart:typed_data';
import '../models/cv_model.dart';
import 'templates/cv_template_base.dart';
import 'templates/cv_template_classic.dart';
import 'templates/cv_template_modern.dart';
import 'templates/cv_template_minimalist.dart';
import 'templates/cv_template_left_right.dart';
import 'templates/cv_template_timeline.dart';
import 'templates/cv_template_creative.dart';
import 'templates/cv_template_elegant.dart';
import 'templates/cv_template_executive.dart';

class CvPdfGenerator {
  static final Map<String, CvTemplateBase> _templates = {
    'classic': CvTemplateClassic(),
    'modern': CvTemplateModern(),
    'minimalist': CvTemplateMinimalist(),
    'left_right': CvTemplateLeftRight(),
    'timeline': CvTemplateTimeline(),
    'creative': CvTemplateCreative(),
    'elegant': CvTemplateElegant(),
    'executive': CvTemplateExecutive(),
  };

  static List<CvTemplateBase> get availableTemplates => _templates.values.toList();

  static Future<Uint8List> generateCvPdf(CvModel cv) async {
    final sanitizedCv = _sanitizeCv(cv);
    final template = _templates[sanitizedCv.templateId] ?? _templates['classic']!;
    return await template.generatePdf(sanitizedCv);
  }

  static CvModel _sanitizeCv(CvModel cv) {
    String clean(String val) {
      return val
          .replaceAll('’', "'")
          .replaceAll('‘', "'")
          .replaceAll('`', "'")
          .replaceAll('“', '"')
          .replaceAll('”', '"')
          .replaceAll('«', '"')
          .replaceAll('»', '"')
          .replaceAll('œ', 'oe')
          .replaceAll('Œ', 'OE')
          .replaceAll('–', '-')
          .replaceAll('—', '-')
          .replaceAll('•', '-')
          .replaceAll('●', '-')
          .replaceAll('▪', '-')
          .replaceAll('■', '-')
          .replaceAll('\u00a0', ' ')
          .replaceAll('\uFFFD', '');
    }

    final cleanPersonalInfo = cv.personalInfo.copyWith(
      fullName: clean(cv.personalInfo.fullName),
      jobTitle: clean(cv.personalInfo.jobTitle),
      summary: clean(cv.personalInfo.summary),
      contactFields: cv.personalInfo.contactFields.map((f) => f.copyWith(
        value: clean(f.value),
      )).toList(),
    );

    final cleanExperiences = cv.experiences.map((e) => e.copyWith(
      jobTitle: clean(e.jobTitle),
      company: clean(e.company),
      location: clean(e.location),
      description: clean(e.description),
    )).toList();

    final cleanEducations = cv.educations.map((e) => e.copyWith(
      degree: clean(e.degree),
      institution: clean(e.institution),
      location: clean(e.location),
      description: clean(e.description),
    )).toList();

    final cleanProjects = cv.projects.map((p) => p.copyWith(
      name: clean(p.name),
      role: clean(p.role),
      description: clean(p.description),
    )).toList();

    final cleanActivities = cv.activities.map((a) => clean(a)).toList();

    return cv.copyWith(
      personalInfo: cleanPersonalInfo,
      skills: clean(cv.skills),
      experiences: cleanExperiences,
      educations: cleanEducations,
      projects: cleanProjects,
      activities: cleanActivities,
    );
  }
}
