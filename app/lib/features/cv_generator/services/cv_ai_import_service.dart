import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/cv_model.dart';

class CvAiImportService {
  /// Extrait le texte brut d'un fichier PDF
  static String extractTextFromPdf(Uint8List bytes) {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final StringBuffer textBuffer = StringBuffer();

    for (int i = 0; i < document.pages.count; i++) {
      final String pageText = PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
      textBuffer.writeln(pageText);
    }

    return textBuffer.toString().trim();
  }

  /// Analyse le texte brut du CV avec Mistral AI (via l'Edge Function Supabase) et retourne un CvModel pré-rempli
  static Future<CvModel> analyzeWithMistral(String rawText) async {
    final supabase = Supabase.instance.client;

    final response = await supabase.functions.invoke(
      'cv-ai-assist',
      body: {
        'action': 'parse_cv',
        'rawText': rawText,
      },
    );

    if (response.status != 200) {
      throw Exception('Erreur lors de l\'analyse par l\'IA (${response.status}): ${response.data}');
    }

    final data = response.data;
    if (data == null || data['success'] != true || data['data'] == null) {
      throw Exception('Données d\'analyse incorrectes reçues du serveur.');
    }

    final Map<String, dynamic> cvJson = data['data'];

    return _jsonToCvModel(cvJson);
  }

  /// Convertit le JSON structuré en CvModel
  static CvModel _jsonToCvModel(Map<String, dynamic> json) {
    // Contact fields
    final List<CvContactField> contactFields = [];
    
    final email = (json['email'] ?? '').toString().trim();
    if (email.isNotEmpty) {
      contactFields.add(CvContactField(id: 'email', iconName: 'email', label: 'Email', value: email));
    } else {
      contactFields.add(CvContactField(id: 'email', iconName: 'email', label: 'Email', value: ''));
    }

    final phone = (json['phone'] ?? '').toString().trim();
    if (phone.isNotEmpty) {
      contactFields.add(CvContactField(id: 'phone', iconName: 'phone', label: 'Téléphone', value: phone));
    } else {
      contactFields.add(CvContactField(id: 'phone', iconName: 'phone', label: 'Téléphone', value: ''));
    }

    final location = (json['location'] ?? '').toString().trim();
    if (location.isNotEmpty) {
      contactFields.add(CvContactField(id: 'location', iconName: 'location', label: 'Adresse', value: location));
    } else {
      contactFields.add(CvContactField(id: 'location', iconName: 'location', label: 'Adresse', value: ''));
    }

    final linkedin = (json['linkedin'] ?? '').toString().trim();
    if (linkedin.isNotEmpty) {
      contactFields.add(CvContactField(id: 'link', iconName: 'link', label: 'LinkedIn', value: linkedin));
    }

    // Personal info
    final personalInfo = CvPersonalInfo(
      fullName: (json['fullName'] ?? '').toString().trim(),
      jobTitle: (json['jobTitle'] ?? '').toString().trim(),
      summary: (json['summary'] ?? '').toString().trim(),
      contactFields: contactFields,
    );

    // Skills
    final skills = (json['skills'] ?? '').toString().trim();

    // Experiences
    final List<CvExperience> experiences = [];
    if (json['experiences'] != null && json['experiences'] is List) {
      for (final exp in json['experiences']) {
        final endDate = (exp['endDate'] ?? '').toString().trim();
        final isPresent = endDate.toLowerCase() == 'présent' || 
                          endDate.toLowerCase() == 'present' || 
                          endDate.toLowerCase() == 'actuel';
        experiences.add(CvExperience(
          jobTitle: (exp['jobTitle'] ?? '').toString().trim(),
          company: (exp['company'] ?? '').toString().trim(),
          location: (exp['location'] ?? '').toString().trim(),
          startDate: (exp['startDate'] ?? '').toString().trim(),
          endDate: endDate,
          description: (exp['description'] ?? '').toString().trim(),
          isVisible: true,
          isPresent: isPresent,
        ));
      }
    }

    // Educations
    final List<CvEducation> educations = [];
    if (json['educations'] != null && json['educations'] is List) {
      for (final edu in json['educations']) {
        final endDate = (edu['endDate'] ?? '').toString().trim();
        final isPresent = endDate.toLowerCase() == 'présent' || 
                          endDate.toLowerCase() == 'present' || 
                          endDate.toLowerCase() == 'actuel';
        educations.add(CvEducation(
          degree: (edu['degree'] ?? '').toString().trim(),
          institution: (edu['institution'] ?? '').toString().trim(),
          location: (edu['location'] ?? '').toString().trim(),
          startDate: (edu['startDate'] ?? '').toString().trim(),
          endDate: endDate,
          description: (edu['description'] ?? '').toString().trim(),
          isVisible: true,
          isPresent: isPresent,
        ));
      }
    }

    // Projects
    final List<CvProject> projects = [];
    if (json['projects'] != null && json['projects'] is List) {
      for (final proj in json['projects']) {
        final name = (proj['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          projects.add(CvProject(
            name: name,
            role: (proj['role'] ?? '').toString().trim(),
            date: (proj['date'] ?? '').toString().trim(),
            description: (proj['description'] ?? '').toString().trim(),
          ));
        }
      }
    }

    // Activities
    final List<String> activities = [];
    if (json['activities'] != null && json['activities'] is List) {
      for (final act in json['activities']) {
        final actStr = act.toString().trim();
        if (actStr.isNotEmpty) {
          activities.add(actStr);
        }
      }
    }

    return CvModel(
      personalInfo: personalInfo,
      skills: skills,
      experiences: experiences,
      projects: projects,
      educations: educations,
      activities: activities,
    );
  }
}
