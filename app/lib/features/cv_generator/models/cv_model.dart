class CvModel {
  final String? id;
  final String title;
  final CvPersonalInfo personalInfo;
  final String skills;
  final List<CvExperience> experiences;
  final List<CvProject> projects;
  final List<CvEducation> educations;
  final List<String> activities;
  final String templateId;
  final String primaryColor;
  final String secondaryColor;

  CvModel({
    this.id,
    this.title = 'Mon CV',
    required this.personalInfo,
    this.skills = '',
    this.experiences = const [],
    this.projects = const [],
    this.educations = const [],
    this.activities = const [],
    this.templateId = 'classic',
    this.primaryColor = '#1E3A8A',
    this.secondaryColor = '#4B5563',
  });

  factory CvModel.empty() {
    return CvModel(
      personalInfo: CvPersonalInfo.empty(),
      skills: '',
      experiences: [],
      projects: [],
      educations: [],
      activities: [],
      templateId: 'classic',
      primaryColor: '#1E3A8A',
      secondaryColor: '#4B5563',
    );
  }

  factory CvModel.mock() {
    return CvModel(
      personalInfo: CvPersonalInfo(
        fullName: 'Koffi Kouadio',
        jobTitle: 'Développeur Mobile Flutter',
        summary: 'Développeur passionné avec plus de 5 ans d\'expérience dans la création d\'applications mobiles performantes et intuitives. Spécialisé en Flutter et architecture propre.',
        showAvatar: true,
        layout: 'left',
        contactFields: [
          CvContactField(id: 'email', iconName: 'email', label: 'Email', value: 'koffi.kouadio@email.com'),
          CvContactField(id: 'phone', iconName: 'phone', label: 'Téléphone', value: '+225 07 00 00 00 00'),
          CvContactField(id: 'location', iconName: 'location', label: 'Adresse', value: 'Abidjan, Côte d\'Ivoire'),
          CvContactField(id: 'link', iconName: 'link', label: 'LinkedIn', value: 'linkedin.com/in/koffikouadio'),
        ],
      ),
      skills: '• Flutter & Dart\n• React Native & JavaScript\n• Native iOS (Swift) & Android (Kotlin)\n• State Management (Bloc, Riverpod, Provider)\n• Clean Architecture & SOLID Principles\n• CI/CD (GitHub Actions, Fastlane)\n• Firebase, Supabase & REST APIs\n• Méthodes Agiles (Scrum/Kanban)',
      experiences: [
        CvExperience(
          jobTitle: 'Développeur Flutter Senior',
          company: 'Djorssi Corp',
          location: 'Abidjan',
          startDate: '2023',
          endDate: 'Présent',
          description: '• Architecture et développement de l\'application Djorssi Match.\n• Optimisation du temps de rendu des listes complexes de 40%.\n• Mise en place de tests unitaires et d\'intégration (couverture de 85%).\n• Lead technique d\'une équipe de 3 développeurs juniors.',
          isVisible: true,
          isPresent: true,
        ),
        CvExperience(
          jobTitle: 'Développeur Mobile Full-Stack',
          company: 'Tech Solutions',
          location: 'Paris, France',
          startDate: '2021',
          endDate: '2023',
          description: '• Conception d\'applications hybrides sous Flutter et React Native.\n• Intégration de solutions de paiement et d\'achats in-app (Stripe, In-App Purchase).\n• Maintenance corrective et évolutive des applications en production.',
          isVisible: true,
          isPresent: false,
        ),
      ],
      projects: [
        CvProject(
          name: 'Portfolio CV Mobile',
          role: 'Créateur & Lead Dev',
          date: '2024',
          description: 'Application mobile permettant de créer et d\'exporter son CV sous divers formats PDF personnalisés.',
        ),
      ],
      educations: [
        CvEducation(
          degree: 'Master en Informatique et Systèmes d\'Information',
          institution: 'Université Virtuelle de Côte d\'Ivoire',
          location: 'Abidjan',
          startDate: '2019',
          endDate: '2021',
          description: 'Spécialisation en Génie Logiciel et Développement Mobile.',
          isVisible: true,
          isPresent: false,
        ),
        CvEducation(
          degree: 'Licence en Sciences Informatiques',
          institution: 'Université Félix Houphouët-Boigny',
          location: 'Abidjan',
          startDate: '2016',
          endDate: '2019',
          description: 'Bases solides en algorithmique, structures de données, base de données et programmation système.',
          isVisible: true,
          isPresent: false,
        ),
      ],
      activities: [
        'Football (Pratique régulière en club)',
        'Lecture (Livres d\'architecture logicielle)',
        'Bénévolat (Mentorat de développeurs)',
      ],
      templateId: 'classic',
      primaryColor: '#1E3A8A',
      secondaryColor: '#4B5563',
    );
  }

  /// Auto-generate a title from the user's name if no title is set
  String get displayTitle {
    if (title.isNotEmpty && title != 'Mon CV') return title;
    if (personalInfo.fullName.isNotEmpty) {
      return 'CV - ${personalInfo.fullName}';
    }
    return 'Mon CV';
  }

  /// Whether this is an AI-adapted CV
  bool get isAdapted => title.contains(' - Adapté pour ') || title.contains('Adapté pour');

  Map<String, dynamic> toJson() {
    return {
      'personalInfo': personalInfo.toJson(),
      'skills': skills,
      'experiences': experiences.map((e) => e.toJson()).toList(),
      'projects': projects.map((p) => p.toJson()).toList(),
      'educations': educations.map((e) => e.toJson()).toList(),
      'activities': activities,
    };
  }

  factory CvModel.fromJson(Map<String, dynamic> json, {
    String? id,
    String? title,
    String? templateId,
    String? primaryColor,
    String? secondaryColor,
  }) {
    return CvModel(
      id: id,
      title: title ?? 'Mon CV',
      personalInfo: json['personalInfo'] != null
          ? CvPersonalInfo.fromJson(json['personalInfo'] as Map<String, dynamic>)
          : CvPersonalInfo.empty(),
      skills: (json['skills'] ?? '').toString(),
      experiences: json['experiences'] != null
          ? (json['experiences'] as List).map((e) => CvExperience.fromJson(e as Map<String, dynamic>)).toList()
          : [],
      projects: json['projects'] != null
          ? (json['projects'] as List).map((p) => CvProject.fromJson(p as Map<String, dynamic>)).toList()
          : [],
      educations: json['educations'] != null
          ? (json['educations'] as List).map((e) => CvEducation.fromJson(e as Map<String, dynamic>)).toList()
          : [],
      activities: json['activities'] != null
          ? (json['activities'] as List).map((a) => a.toString()).toList()
          : [],
      templateId: templateId ?? 'classic',
      primaryColor: primaryColor ?? '#1E3A8A',
      secondaryColor: secondaryColor ?? '#4B5563',
    );
  }

  CvModel copyWith({
    String? id,
    String? title,
    CvPersonalInfo? personalInfo,
    String? skills,
    List<CvExperience>? experiences,
    List<CvProject>? projects,
    List<CvEducation>? educations,
    List<String>? activities,
    String? templateId,
    String? primaryColor,
    String? secondaryColor,
  }) {
    return CvModel(
      id: id ?? this.id,
      title: title ?? this.title,
      personalInfo: personalInfo ?? this.personalInfo,
      skills: skills ?? this.skills,
      experiences: experiences ?? this.experiences,
      projects: projects ?? this.projects,
      educations: educations ?? this.educations,
      activities: activities ?? this.activities,
      templateId: templateId ?? this.templateId,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
    );
  }
}

class CvPersonalInfo {
  final String fullName;
  final String jobTitle;
  final String summary;
  final String? profileImageUrl;
  final bool showAvatar;
  final String layout; // 'left', 'center', 'right'
  final List<CvContactField> contactFields;

  CvPersonalInfo({
    required this.fullName,
    required this.jobTitle,
    required this.summary,
    this.profileImageUrl,
    this.showAvatar = true,
    this.layout = 'left',
    this.contactFields = const [],
  });

  factory CvPersonalInfo.empty() {
    return CvPersonalInfo(
      fullName: '',
      jobTitle: '',
      summary: '',
      contactFields: [
        CvContactField(id: 'email', iconName: 'email', label: 'Email', value: ''),
        CvContactField(id: 'phone', iconName: 'phone', label: 'Téléphone', value: ''),
        CvContactField(id: 'location', iconName: 'location', label: 'Adresse', value: ''),
      ],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'jobTitle': jobTitle,
      'summary': summary,
      'profileImageUrl': profileImageUrl,
      'showAvatar': showAvatar,
      'layout': layout,
      'contactFields': contactFields.map((c) => c.toJson()).toList(),
    };
  }

  factory CvPersonalInfo.fromJson(Map<String, dynamic> json) {
    return CvPersonalInfo(
      fullName: (json['fullName'] ?? '').toString(),
      jobTitle: (json['jobTitle'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      profileImageUrl: json['profileImageUrl']?.toString(),
      showAvatar: json['showAvatar'] ?? true,
      layout: (json['layout'] ?? 'left').toString(),
      contactFields: json['contactFields'] != null
          ? (json['contactFields'] as List).map((c) => CvContactField.fromJson(c as Map<String, dynamic>)).toList()
          : [],
    );
  }

  CvPersonalInfo copyWith({
    String? fullName,
    String? jobTitle,
    String? summary,
    String? profileImageUrl,
    bool? showAvatar,
    String? layout,
    List<CvContactField>? contactFields,
  }) {
    return CvPersonalInfo(
      fullName: fullName ?? this.fullName,
      jobTitle: jobTitle ?? this.jobTitle,
      summary: summary ?? this.summary,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      showAvatar: showAvatar ?? this.showAvatar,
      layout: layout ?? this.layout,
      contactFields: contactFields ?? this.contactFields,
    );
  }
}

class CvContactField {
  final String id;
  final String iconName;
  final String label;
  final String value;
  final bool isVisible;

  CvContactField({
    required this.id,
    required this.iconName,
    required this.label,
    required this.value,
    this.isVisible = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'iconName': iconName,
      'label': label,
      'value': value,
      'isVisible': isVisible,
    };
  }

  factory CvContactField.fromJson(Map<String, dynamic> json) {
    return CvContactField(
      id: (json['id'] ?? '').toString(),
      iconName: (json['iconName'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
      isVisible: json['isVisible'] ?? true,
    );
  }

  CvContactField copyWith({
    String? id,
    String? iconName,
    String? label,
    String? value,
    bool? isVisible,
  }) {
    return CvContactField(
      id: id ?? this.id,
      iconName: iconName ?? this.iconName,
      label: label ?? this.label,
      value: value ?? this.value,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

class CvExperience {
  final String jobTitle;
  final String company;
  final String location;
  final String startDate;
  final String endDate;
  final String description;
  final bool isVisible;
  final bool isPresent;

  CvExperience({
    required this.jobTitle,
    required this.company,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.description,
    this.isVisible = true,
    this.isPresent = false,
  });

  factory CvExperience.empty() {
    return CvExperience(
      jobTitle: '',
      company: '',
      location: '',
      startDate: '',
      endDate: '',
      description: '',
      isVisible: true,
      isPresent: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'jobTitle': jobTitle,
      'company': company,
      'location': location,
      'startDate': startDate,
      'endDate': endDate,
      'description': description,
      'isVisible': isVisible,
      'isPresent': isPresent,
    };
  }

  factory CvExperience.fromJson(Map<String, dynamic> json) {
    return CvExperience(
      jobTitle: (json['jobTitle'] ?? '').toString(),
      company: (json['company'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      startDate: (json['startDate'] ?? '').toString(),
      endDate: (json['endDate'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isVisible: json['isVisible'] ?? true,
      isPresent: json['isPresent'] ?? false,
    );
  }

  CvExperience copyWith({
    String? jobTitle,
    String? company,
    String? location,
    String? startDate,
    String? endDate,
    String? description,
    bool? isVisible,
    bool? isPresent,
  }) {
    return CvExperience(
      jobTitle: jobTitle ?? this.jobTitle,
      company: company ?? this.company,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      description: description ?? this.description,
      isVisible: isVisible ?? this.isVisible,
      isPresent: isPresent ?? this.isPresent,
    );
  }
}

class CvProject {
  final String name;
  final String role;
  final String date;
  final String description;
  final bool isVisible;

  CvProject({
    required this.name,
    required this.role,
    required this.date,
    required this.description,
    this.isVisible = true,
  });

  factory CvProject.empty() {
    return CvProject(
      name: '',
      role: '',
      date: '',
      description: '',
      isVisible: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'role': role,
      'date': date,
      'description': description,
      'isVisible': isVisible,
    };
  }

  factory CvProject.fromJson(Map<String, dynamic> json) {
    return CvProject(
      name: (json['name'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isVisible: json['isVisible'] ?? true,
    );
  }

  CvProject copyWith({
    String? name,
    String? role,
    String? date,
    String? description,
    bool? isVisible,
  }) {
    return CvProject(
      name: name ?? this.name,
      role: role ?? this.role,
      date: date ?? this.date,
      description: description ?? this.description,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

class CvEducation {
  final String degree;
  final String institution;
  final String location;
  final String startDate;
  final String endDate;
  final String description;
  final bool isVisible;
  final bool isPresent;

  CvEducation({
    required this.degree,
    required this.institution,
    required this.location,
    required this.startDate,
    required this.endDate,
    this.description = '',
    this.isVisible = true,
    this.isPresent = false,
  });

  factory CvEducation.empty() {
    return CvEducation(
      degree: '',
      institution: '',
      location: '',
      startDate: '',
      endDate: '',
      description: '',
      isVisible: true,
      isPresent: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'degree': degree,
      'institution': institution,
      'location': location,
      'startDate': startDate,
      'endDate': endDate,
      'description': description,
      'isVisible': isVisible,
      'isPresent': isPresent,
    };
  }

  factory CvEducation.fromJson(Map<String, dynamic> json) {
    return CvEducation(
      degree: (json['degree'] ?? '').toString(),
      institution: (json['institution'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      startDate: (json['startDate'] ?? '').toString(),
      endDate: (json['endDate'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isVisible: json['isVisible'] ?? true,
      isPresent: json['isPresent'] ?? false,
    );
  }

  CvEducation copyWith({
    String? degree,
    String? institution,
    String? location,
    String? startDate,
    String? endDate,
    String? description,
    bool? isVisible,
    bool? isPresent,
  }) {
    return CvEducation(
      degree: degree ?? this.degree,
      institution: institution ?? this.institution,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      description: description ?? this.description,
      isVisible: isVisible ?? this.isVisible,
      isPresent: isPresent ?? this.isPresent,
    );
  }
}
