import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/cv_model.dart';

class OrganizedCvData {
  final String fullCleanText;
  final Map<String, List<String>> sections;
  final String? email;
  final String? phone;

  OrganizedCvData({
    required this.fullCleanText,
    required this.sections,
    this.email,
    this.phone,
  });
}

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

  /// Formate et nettoie le texte brut extrait du PDF pour ré-assembler les mots et séparer proprement chaque expérience et diplôme
  static String cleanAndFormatRawText(String rawText) {
    if (rawText.isEmpty) return '';

    // 1. Normaliser les fins de ligne, espaces et corriger les artefacts OCR
    String text = cleanOcrArtifacts(rawText)
        .replaceAll(RegExp(r'\r\n|\r'), '\n')
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    // 2. Normaliser la ponctuation et libellés clés
    text = text
        .replaceAll(RegExp(r'\s+:\s*'), ' : ')
        .replaceAll(RegExp(r'\s+-\s+'), ' - ')
        .replaceAll(RegExp(r'Ce\s*l\s*:'), 'Cel :')
        .replaceAll(RegExp(r'E\s*mail\s*:'), 'Email :');

    // 3. Insérer un saut de ligne devant les dates, puces, libellés de champs et grands titres de rubriques
    final datePattern = r'(?:\d{4}\s*[-–—]\s*\d{4}|\b\d{4}\b|Depuis\s+[A-Za-zÀ-ÿ]+\s+\d{4}|[A-Za-zÀ-ÿ]+\s+à\s+[A-Za-zÀ-ÿ]+\s+\d{4})\s*:';
    final labelPattern = r'(?:[A-ZÀ-Ÿ][a-zA-ZÀ-ÿ\s]{2,30}\s*:)';
    final symbolPattern = r'(?:[✓✔•\*\-])';
    final headerPattern = r'(?:PROFILES?|EXPÉRIENCES?|PROFESSIONNELLES?|FORMATIONS?|DIPLÔMES?|COMPÉTENCES?|LANGUES?|ATOUTS?|CONTACTS?|CENTRES?\s*D.INTÉRÊTS?|LOISIRS?)';

    final breakRegex = RegExp(
      '($symbolPattern|$datePattern|$labelPattern|$headerPattern)',
      caseSensitive: false,
    );

    text = text.replaceAllMapped(breakRegex, (match) {
      return '\n${match.group(0)}';
    });

    // 4. Découper en lignes nettoyées
    final rawLines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (rawLines.isEmpty) return '';

    // 5. Deuxième passe : Fusionner les fragments d'en-têtes consécutifs (ex: EXPÉRIENCES + PROFESSIONNELLES)
    final List<String> cleanLines = [];
    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];
      if (cleanLines.isNotEmpty) {
        final prev = cleanLines.last;
        if (prev.toUpperCase() == 'EXPÉRIENCES' && line.toUpperCase() == 'PROFESSIONNELLES') {
          cleanLines[cleanLines.length - 1] = 'EXPÉRIENCES PROFESSIONNELLES';
          continue;
        }
        if (prev.toUpperCase() == 'FORMATIONS' && line.toUpperCase() == 'ACADÉMIQUES') {
          cleanLines[cleanLines.length - 1] = 'FORMATIONS ACADÉMIQUES';
          continue;
        }
        if (prev.toUpperCase() == 'ATOUTS' && line.toUpperCase().startsWith('PERSONNELS')) {
          cleanLines[cleanLines.length - 1] = 'ATOUTS PERSONNELS';
          continue;
        }
      }
      cleanLines.add(line);
    }

    return cleanLines.join('\n');
  }

  /// Ordonne et découpe le texte extrait d'un PDF en sections lisibles sans aucun appel IA
  static OrganizedCvData organizeExtractedText(String rawText) {
    final clean = cleanAndFormatRawText(rawText);
    if (clean.isEmpty) {
      return OrganizedCvData(fullCleanText: '', sections: {});
    }

    // Extraction email
    final emailMatch = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}').firstMatch(clean);
    final email = emailMatch?.group(0);

    // Extraction numéro téléphone
    final phoneMatch = RegExp(r'(\+?\d{1,3}[\s.-]?)?\(?\d{2,4}\)?[\s.-]?\d{2,4}[\s.-]?\d{2,4}').firstMatch(clean);
    final phone = phoneMatch?.group(0);

    final headerRegexes = <String, RegExp>{
      '📝 Profil & Informations': RegExp(r'^(profil|[àa]\s*propos|pr[ée]sentation|r[ée]sum[ée]|summary|about|objective|objectif)\b', caseSensitive: false),
      '💼 Expériences Professionnelles': RegExp(r'^(exp[ée]riences?|parcours|emplois?|work\s*experience|experience|exp[ée]rience\s*professionnelle|professionnelles?)\b', caseSensitive: false),
      '🎓 Formations & Diplômes': RegExp(r'^(formations?|[ée]ducation|dipl[ôo]mes?|[ée]tudes?|education|qualifications?|acad[ée]miques?)\b', caseSensitive: false),
      '⚡ Compétences & Savoir-Faire': RegExp(r'^(comp[ée]tences?|skills?|savoir[- ]faire|aptitudes?|technologies?)\b', caseSensitive: false),
      '🎯 Atouts & Qualités': RegExp(r'^(atouts?|qualit[ée]s?|atouts\s*personnels?)\b', caseSensitive: false),
      '🌐 Langues': RegExp(r'^(langues?|languages?)\b', caseSensitive: false),
      '🎨 Centres d\'intérêt & Loisirs': RegExp(r'^(centres?\s*d.int[ée]r[êe]ts?|loisirs?|hobbies|divers|interests?)\b', caseSensitive: false),
      '📞 Coordonnées & Contact': RegExp(r'^(contacts?|coordonn[ée]es?)\b', caseSensitive: false),
    };

    final lines = clean.split('\n');
    final Map<String, List<String>> sections = {};
    String currentSection = '📄 Synthèse du CV';

    sections[currentSection] = [];

    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      String? matchedHeader;
      if (trimmedLine.length < 60) {
        for (var entry in headerRegexes.entries) {
          if (entry.value.hasMatch(trimmedLine)) {
            matchedHeader = entry.key;
            break;
          }
        }
      }

      if (matchedHeader != null) {
        currentSection = matchedHeader;
        if (!sections.containsKey(currentSection)) {
          sections[currentSection] = [];
        }
      } else {
        sections[currentSection]!.add(trimmedLine);
      }
    }

    sections.removeWhere((key, value) => value.isEmpty);

    return OrganizedCvData(
      fullCleanText: clean,
      sections: sections,
      email: email,
      phone: phone,
    );
  }

  /// Nettoie les artefacts de caractères OCR corrompus (ex: NUationUale, AdministrUation, MUaîtrise)
  static String cleanOcrArtifacts(String text) {
    return text
        .replaceAll('HUaute', 'Haute')
        .replaceAll('HUau', 'Hau')
        .replaceAll('Uau', 'au')
        .replaceAll('d u es', 'des')
        .replaceAll('d es', 'des')
        .replaceAll('NUat', 'Nat')
        .replaceAll('MUaî', 'Maî')
        .replaceAll('AdministrUat', 'Administrat')
        .replaceAll('UUniv', 'Univ')
        .replaceAll('FUac', 'Fac')
        .replaceAll('KoumUas', 'Koumas')
        .replaceAll('MUar', 'Mar')
        .replaceAll('enfUan', 'enfan')
        .replaceAll('FinUan', 'Finan')
        .replaceAll('postUal', 'postal')
        .replaceAll('bsUanogo', 'bsanogo')
        .replaceAll('sUanogo', 'sanogo')
        .replaceAll('UBUa', 'Boua')
        .replaceAll('KUat', 'Kat')
        .replaceAll('GénérUal', 'Général')
        .replaceAll('Servic es', 'Services')
        .replaceAll('ComptUab', 'Comptab')
        .replaceAll('UBA', 'BA')
        .replaceAll('UBAC', 'BAC')
        .replaceAll(RegExp(r'(?<=[a-zÀ-ÿ])U(?=[a-zÀ-ÿ])'), '')
        .replaceAll(RegExp(r'(?<=[A-ZÀ-Ÿ])U(?=[a-zÀ-ÿ])'), '');
  }

  /// Transforme le texte brut d'un CV en un CvModel proprement structuré (Parser Intelligent Local)
  static CvModel parseCvLocally(String rawText) {
    final cleanText = cleanOcrArtifacts(cleanAndFormatRawText(rawText));

    final List<CvExperience> experiences = [];
    final List<CvEducation> educations = [];
    final List<String> skills = [];
    final List<String> summaryLines = [];

    final lines = cleanText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    String currentSection = 'summary';

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final upper = line.toUpperCase();

      if (upper.contains('FORMATION') || upper.contains('CURSUS') || upper.contains('DIPLÔME') || upper.contains('ETUDES')) {
        currentSection = 'education';
        continue;
      } else if (upper.contains('EXPÉRIENCE') || upper.contains('EXPERIENCE') || upper.contains('PARCOURS PROF') || upper.contains('EMPLOI')) {
        currentSection = 'experience';
        continue;
      } else if (upper.contains('COMPÉTENCE') || upper.contains('SKILL') || upper.contains('SAVOIR-FAIRE')) {
        currentSection = 'skill';
        continue;
      }

      if (currentSection == 'summary') {
        if (!upper.contains('CURRICULUM') && !upper.contains('RESUME') && !upper.contains('ETAT CIVIL')) {
          summaryLines.add(line);
        }
      } else if (currentSection == 'education') {
        final isDegreeHeader = RegExp(r'(Diplôme|Licence|Master|BTS|BAC|Baccalauréat|Maîtrise|Cycle|Doctorat|Ingénieur|DEUG|DUT)', caseSensitive: false).hasMatch(line);
        final yearMatch = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(line);
        final yearStr = yearMatch?.group(0) ?? '';

        if (isDegreeHeader || yearStr.isNotEmpty) {
          String institution = '';
          if (i + 1 < lines.length) {
            final nextLine = lines[i + 1];
            if (RegExp(r'(Ecole|Université|Lycée|Institut|Faculté|Center|Collège)', caseSensitive: false).hasMatch(nextLine)) {
              institution = nextLine;
            }
          }

          educations.add(CvEducation(
            degree: line,
            institution: institution,
            location: '',
            startDate: '',
            endDate: yearStr,
            description: '',
          ));
        }
      } else if (currentSection == 'experience') {
        final yearMatch = RegExp(r'(Depuis\s+[A-Za-zÀ-ÿ]+\s+\d{4}|\b(19\d{2}|20\d{2})\b)').firstMatch(line);
        final yearStr = yearMatch?.group(0) ?? '';

        if (yearStr.isNotEmpty || RegExp(r'(Membre|Directeur|Chef|Administrateur|Manager|Consultant|Analyste|Commercial|Agent|Gestionnaire|Responsable|President|Président|Trésorier|Fondé)', caseSensitive: false).hasMatch(line)) {
          experiences.add(CvExperience(
            jobTitle: line,
            company: '',
            location: '',
            startDate: yearStr,
            endDate: yearStr.startsWith('Depuis') ? 'Présent' : '',
            description: '',
          ));
        }
      } else if (currentSection == 'skill') {
        skills.add(line);
      }
    }

    return CvModel(
      title: 'CV Structuré',
      personalInfo: CvPersonalInfo(
        fullName: summaryLines.isNotEmpty ? summaryLines.first : 'Candidat',
        jobTitle: summaryLines.length > 1 ? summaryLines[1] : '',
        summary: summaryLines.take(4).join(' '),
        contactFields: [],
      ),
      skills: skills.join('\n'),
      experiences: experiences.take(8).toList(),
      educations: educations.take(6).toList(),
    );
  }

  /// Analyse le texte brut du CV avec Mistral AI (via l'Edge Function Supabase) et retourne un CvModel pré-rempli
  static Future<CvModel> analyzeWithMistral(String rawText) async {
    final cleaned = cleanOcrArtifacts(rawText);
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase.functions.invoke(
        'cv-ai-assist',
        body: {
          'action': 'parse_cv',
          'rawText': cleaned,
        },
      ).timeout(const Duration(seconds: 25));

      if (response.status == 200 && response.data != null && response.data['success'] == true && response.data['data'] != null) {
        final Map<String, dynamic> cvJson = response.data['data'];
        return _jsonToCvModel(cvJson);
      }
    } catch (e) {
      debugPrint('Mistral AI assist exception, fallback to local parser: $e');
    }

    return parseCvLocally(cleaned);
  }

  /// Adapte un CV existant par rapport à une offre d'emploi avec l'IA
  static Future<CvModel> adaptCv({
    required CvModel sourceCv,
    required String jobTitle,
    required String jobCompany,
    required String jobDescription,
  }) async {
    final supabase = Supabase.instance.client;

    final response = await supabase.functions.invoke(
      'cv-ai-assist',
      body: {
        'action': 'adapt_cv',
        'cvData': sourceCv.toJson(),
        'jobTitle': jobTitle,
        'jobCompany': jobCompany,
        'jobDescription': jobDescription,
      },
    );

    if (response.status != 200) {
      throw Exception('Erreur lors de l\'adaptation par l\'IA (${response.status}): ${response.data}');
    }

    final data = response.data;
    if (data == null || data['success'] != true || data['data'] == null) {
      throw Exception('Données d\'adaptation incorrectes reçues du serveur.');
    }

    final Map<String, dynamic> cvJson = data['data'];

    // Convert to CvModel, preserving the template/colors of the source CV
    return _jsonToCvModel(cvJson).copyWith(
      templateId: sourceCv.templateId,
      primaryColor: sourceCv.primaryColor,
      secondaryColor: sourceCv.secondaryColor,
    );
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

    // Helper to check if a string is empty or contains only dashes/spaces
    bool isPlaceholder(String val) {
      final clean = val.replaceAll(RegExp(r'^[-—–\s]+$'), '');
      return clean.isEmpty;
    }

    // Experiences
    final List<CvExperience> experiences = [];
    if (json['experiences'] != null && json['experiences'] is List) {
      for (final exp in json['experiences']) {
        final jobTitle = (exp['jobTitle'] ?? '').toString().trim();
        final company = (exp['company'] ?? '').toString().trim();
        final description = (exp['description'] ?? '').toString().trim();
        final location = (exp['location'] ?? '').toString().trim();
        final startDate = (exp['startDate'] ?? '').toString().trim();
        final endDate = (exp['endDate'] ?? '').toString().trim();

        // Skip completely empty or placeholder experiences
        if (isPlaceholder(jobTitle) && isPlaceholder(company) && isPlaceholder(description)) {
          continue;
        }

        final isPresent = endDate.toLowerCase() == 'présent' || 
                          endDate.toLowerCase() == 'present' || 
                          endDate.toLowerCase() == 'actuel';
        experiences.add(CvExperience(
          jobTitle: jobTitle,
          company: company,
          location: location,
          startDate: startDate,
          endDate: endDate,
          description: description,
          isVisible: true,
          isPresent: isPresent,
        ));
      }
    }

    // Educations
    final List<CvEducation> educations = [];
    if (json['educations'] != null && json['educations'] is List) {
      for (final edu in json['educations']) {
        final degree = (edu['degree'] ?? '').toString().trim();
        final institution = (edu['institution'] ?? '').toString().trim();
        final description = (edu['description'] ?? '').toString().trim();
        final location = (edu['location'] ?? '').toString().trim();
        final startDate = (edu['startDate'] ?? '').toString().trim();
        final endDate = (edu['endDate'] ?? '').toString().trim();

        // Skip completely empty, placeholder or dummy educations
        if (isPlaceholder(degree) && isPlaceholder(institution) && isPlaceholder(description)) {
          continue;
        }
        // Also skip if it doesn't have a valid degree or institution name (e.g. just a dash duplicate)
        if (isPlaceholder(degree) && isPlaceholder(institution)) {
          continue;
        }

        final isPresent = endDate.toLowerCase() == 'présent' || 
                          endDate.toLowerCase() == 'present' || 
                          endDate.toLowerCase() == 'actuel';
        educations.add(CvEducation(
          degree: degree,
          institution: institution,
          location: location,
          startDate: startDate,
          endDate: endDate,
          description: description,
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
        final role = (proj['role'] ?? '').toString().trim();
        final description = (proj['description'] ?? '').toString().trim();
        final date = (proj['date'] ?? '').toString().trim();

        if (isPlaceholder(name) && isPlaceholder(description)) {
          continue;
        }

        projects.add(CvProject(
          name: name,
          role: role,
          date: date,
          description: description,
        ));
      }
    }

    // Activities
    final List<String> activities = [];
    if (json['activities'] != null && json['activities'] is List) {
      for (final act in json['activities']) {
        final actStr = act.toString().trim();
        if (actStr.isNotEmpty && !isPlaceholder(actStr)) {
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
