import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cv_rich_text_editor.dart';
import 'cv_ai_loading_dialog.dart';

class SkillTemplate {
  final String title;
  final IconData icon;
  final String content;

  const SkillTemplate({
    required this.title,
    required this.icon,
    required this.content,
  });
}

class CvSkillsEditor extends StatefulWidget {
  final String initialData;
  final String candidateSummary;
  final ValueChanged<String> onSaved;

  const CvSkillsEditor({
    Key? key,
    required this.initialData,
    this.candidateSummary = '',
    required this.onSaved,
  }) : super(key: key);

  @override
  State<CvSkillsEditor> createState() => _CvSkillsEditorState();
}

class _CvSkillsEditorState extends State<CvSkillsEditor> {
  late String _currentText;
  late String _editorKeySource;

  final List<SkillTemplate> _skillTemplates = const [
    SkillTemplate(
      title: 'Dév. Mobile & Flutter',
      icon: Icons.phone_android,
      content: '• Développement Mobile : Dart, Flutter (State Management: BLoC, Riverpod, Provider)\n'
          '• Intégration de services : Firebase (Auth, Firestore, Cloud Messaging), Supabase, REST APIs\n'
          '• Architecture logicielle : Clean Architecture, SOLID, Design Patterns, MVVM\n'
          '• DevOps & Outils : Git, GitHub Actions, CI/CD, Fastlane, App Store & Google Play Console\n'
          '• Compétences de Test : Tests unitaires, Tests de widgets, Tests d\'intégration',
    ),
    SkillTemplate(
      title: 'Dév. Web Full-Stack',
      icon: Icons.computer,
      content: '• Frontend Web : HTML5, CSS3, JavaScript (ES6+), React.js, Next.js, Tailwind CSS\n'
          '• Backend & API : Node.js, Express, Python, Django, REST APIs, GraphQL\n'
          '• Bases de données : PostgreSQL, MongoDB, MySQL, Redis\n'
          '• DevOps & Cloud : Git, Docker, AWS (S3, EC2), Vercel, Netlify, Pipelines CI/CD\n'
          '• Méthodologies & Qualité : Scrum, Kanban, Clean Code, Jest, Cypress',
    ),
    SkillTemplate(
      title: 'UI/UX Design',
      icon: Icons.brush,
      content: '• Design d\'interface (UI) : Figma, Adobe Creative Suite, Design Systems, Typographie, Théorie des couleurs\n'
          '• Expérience utilisateur (UX) : Recherche utilisateur, Personas, Wireframing, Tests d\'utilisabilité, Cartographie de parcours\n'
          '• Prototypage & Intégration : Prototypes animés interactifs Figma, Auto-layout, Composants réutilisables\n'
          '• Collaboration agile : Handover technique développeurs, Méthode Scrum',
    ),
    SkillTemplate(
      title: 'Chef de Projet / PO',
      icon: Icons.assignment_outlined,
      content: '• Gestion de projet : Méthodes Agiles (Scrum, Kanban), Planification de sprints, Animation de rituels agiles\n'
          '• Outils collaboratifs : Jira, Confluence, Trello, Asana, Notion, Slack\n'
          '• Product Management : Rédaction de User Stories, Priorisation (MoSCoW, RICE), Roadmap produit\n'
          '• Analytics & KPIs : Google Analytics 4, Mixpanel, Hotjar, Suivi des métriques d\'activation & rétention\n'
          '• Facilitation : Communication transversale entre équipes techniques, design et business',
    ),
    SkillTemplate(
      title: 'Marketing & Growth',
      icon: Icons.trending_up,
      content: '• Marketing de contenu & SEO : Rédaction web optimisée, Recherche de mots-clés, Audits SEO\n'
          '• Acquisition Payante (SEA/SMA) : Google Ads, Meta Ads (Facebook/Instagram), LinkedIn Ads\n'
          '• Analytics & Conversion : Google Analytics 4, Google Tag Manager, A/B Testing, Optimisation CRO\n'
          '• CRM & Emailing Automation : HubSpot, Mailchimp, Brevo, Cycles de vie clients, Segmentation\n'
          '• Growth Hacking : Analyse d\'entonnoirs AARRR, Stratégies de parrainage et viralité',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentText = widget.initialData;
    _editorKeySource = 'initial';
  }

  void _importTemplate(String templateContent, {required bool append}) {
    String newText;
    if (append) {
      final separator = _currentText.isEmpty || _currentText.endsWith('\n') ? '' : '\n';
      newText = '$_currentText$separator$templateContent';
    } else {
      newText = templateContent;
    }

    setState(() {
      _currentText = newText;
      _editorKeySource = DateTime.now().millisecondsSinceEpoch.toString();
    });
    widget.onSaved(_currentText);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Modèle de compétences importé !'),
        backgroundColor: Colors.green.shade900,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _generateSkillsFromSummary(BuildContext context) async {
    if (widget.candidateSummary.trim().isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CvAiLoadingDialog(
        title: "Génération de vos compétences par l'IA",
        steps: [
          "Analyse de votre profil...",
          "Identification des compétences clés...",
          "Classification par catégories...",
          "Finalisation du modèle...",
        ],
      ),
    );

    try {
      final supabase = Supabase.instance.client;
      const prompt = "Tu es un expert en recrutement. Analyse le résumé de profil du candidat ci-dessous et propose une liste de compétences professionnelles et techniques clés correspondantes. Organise ces compétences par catégories logiques (ex: Compétences techniques, Outils, Soft Skills) et présente-les sous forme de liste avec des puces (•) pour chaque élément. Retourne UNIQUEMENT la liste finale de compétences structurées, sans introduction, sans conclusion et sans aucun commentaire.";

      final response = await supabase.functions.invoke(
        'cv-ai-assist',
        body: {
          'action': 'polish_text',
          'text': widget.candidateSummary,
          'systemContent': prompt,
        },
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (response.status == 200) {
        final data = response.data;
        if (data == null || data['success'] != true || data['polishedText'] == null) {
          throw Exception('Données incorrectes reçues du serveur.');
        }

        final String generatedText = data['polishedText'].toString().trim();
        
        final aiTemplate = SkillTemplate(
          title: "Recommandations de l'IA",
          icon: Icons.auto_awesome,
          content: generatedText,
        );

        if (mounted) {
          _showImportTemplateDialog(context, aiTemplate);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur de l'API (${response.status}) : ${response.data}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur : $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImportTemplateDialog(BuildContext context, SkillTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Importer le modèle : ${template.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comment souhaitez-vous ajouter les compétences de ce modèle à votre saisie actuelle ?',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Text(
                    template.content,
                    style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _importTemplate(template.content, append: true);
            },
            child: const Text('Ajouter à la fin', style: TextStyle(color: Color(0xFFF97316))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _importTemplate(template.content, append: false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
            ),
            child: const Text('Remplacer tout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vos compétences clés et technologies',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Conseil : Regroupez vos compétences par catégorie (ex: Langages, Frameworks, Bases de données). Utilisez le symbole de puce (•) en début de chaque ligne pour un rendu parfait sur le modèle de CV.',
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          const Text(
            'Modèles de compétences rapides par métier :',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (widget.candidateSummary.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF8B5CF6)),
                      label: const Text("Suggérer avec l'IA (basé sur le résumé)", style: TextStyle(color: Color(0xFF6D28D9), fontWeight: FontWeight.bold)),
                      backgroundColor: const Color(0xFFF5F3FF),
                      side: const BorderSide(color: Color(0xFFDDD6FE)),
                      onPressed: () => _generateSkillsFromSummary(context),
                    ),
                  ),
                ..._skillTemplates.map((template) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(template.icon, size: 16, color: const Color(0xFFF97316)),
                      label: Text(template.title),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey.shade300),
                      onPressed: () => _showImportTemplateDialog(context, template),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
          CvRichTextEditor(
            key: ValueKey(_editorKeySource),
            initialData: _currentText,
            labelText: 'Compétences',
            onSaved: (val) {
              _currentText = val;
              widget.onSaved(val);
            },
            hintText: 'Exemples :\n'
                '• Frameworks & Librairies : Maîtrise de Flutter, React Native, Vue.js et Next.js\n'
                '• Langages de programmation : Dart, TypeScript, JavaScript (ES6+), HTML5, CSS3\n'
                '• Outils DevOps & CI/CD : Git, GitHub Actions, Docker, Fastlane\n'
                '• Bases de données : PostgreSQL, Firebase, Supabase, SQLite\n'
                '• State Management : Riverpod, BLoC, Provider, Redux, Zustand\n'
                '• Soft Skills : Esprit d\'équipe, Autonomie, Rigueur, Agilité',
            minHeight: 300,
          ),
        ],
      ),
    );
  }
}
