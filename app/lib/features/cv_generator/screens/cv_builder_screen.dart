import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/cv_model.dart';
import '../services/cv_storage_service.dart';
import '../widgets/cv_basic_info_editor.dart';
import '../widgets/cv_skills_editor.dart';
import '../widgets/cv_experiences_editor.dart';
import '../widgets/cv_education_editor.dart';
import '../widgets/cv_activities_editor.dart';
import '../widgets/cv_projects_editor.dart';
import 'cv_template_selection_screen.dart';

class CvBuilderScreen extends StatefulWidget {
  final CvModel? initialCv;

  const CvBuilderScreen({Key? key, this.initialCv}) : super(key: key);

  @override
  State<CvBuilderScreen> createState() => _CvBuilderScreenState();
}

class _CvBuilderScreenState extends State<CvBuilderScreen> {
  late CvModel _cvModel;
  bool _isSaving = false;
  bool _hasSaved = false;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _cvModel = widget.initialCv ?? CvModel.empty();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  void _autoSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      setState(() => _isSaving = true);
      try {
        final saved = await CvStorageService.saveCv(_cvModel);
        if (!mounted) return;
        setState(() {
          _cvModel = saved;
          _isSaving = false;
          _hasSaved = true;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _isSaving = false);
      }
    });
  }

  void _openEditor(BuildContext context, String title, Widget editor) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(title),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 1,
            actions: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined),
                tooltip: 'Aperçu temporaire',
                onPressed: () {
                  context.push('/cv_preview?allow_edit=true', extra: _cvModel);
                },
              ),
            ],
          ),
          body: editor,
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      setState(() {});
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E293B), // slate-800
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: const Duration(seconds: 6),
          content: Builder(
            builder: (innerContext) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Color(0xFF22C55E), size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$title mis à jour !',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(innerContext).hideCurrentSnackBar();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade400,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: const Text(
                          'PLUS TARD',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final cvModelToUse = _cvModel;
                          ScaffoldMessenger.of(innerContext).hideCurrentSnackBar();
                          if (innerContext.mounted) {
                            innerContext.push('/cv_preview?allow_edit=true', extra: cvModelToUse);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'VOIR L\'APERÇU',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      );
    });
  }

  String _getTemplateName(String id) {
    switch (id) {
      case 'classic': return 'Classique';
      case 'modern': return 'Moderne';
      case 'minimalist': return 'Minimaliste';
      case 'left_right': return 'Gauche-Droite';
      case 'timeline': return 'Chronologique';
      case 'creative': return 'Créatif';
      case 'elegant': return 'Élégant';
      default: return 'Classique';
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(int.parse(_cvModel.primaryColor.replaceFirst('#', '0xff')));
    final secondaryColor = Color(int.parse(_cvModel.secondaryColor.replaceFirst('#', '0xff')));

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_cvModel);
        return false;
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_cvModel),
        ),
        title: GestureDetector(
          onTap: _renameCvDialog,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _cvModel.displayTitle,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 14, color: Colors.grey),
                  ],
                ),
                if (_isSaving)
                  const Text('Sauvegarde...', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w400))
                else if (_hasSaved)
                  const Text('Sauvegardé ✓', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w400))
                else
                  const Text('Modifier les sections', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w400)),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.drive_file_rename_outline),
            tooltip: 'Renommer le CV',
            onPressed: _renameCvDialog,
          ),
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'Aperçu du CV',
            onPressed: () async {
              final result = await context.push<CvModel>('/cv_preview?allow_edit=true', extra: _cvModel);
              if (result != null) {
                setState(() {
                  _cvModel = result;
                });
                _autoSave();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Selected style card
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.palette_outlined, color: primaryColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Modèle : ${_getTemplateName(_cvModel.templateId)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Couleurs : ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: secondaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CvTemplateSelectionScreen(
                            existingCv: _cvModel,
                            isEditingStyle: true,
                          ),
                        ),
                      ).then((result) {
                        if (result is CvModel) {
                          setState(() {
                            _cvModel = result;
                          });
                          _autoSave();
                        }
                      });
                    },
                    icon: const Icon(Icons.edit, size: 16, color: Color(0xFFF97316)),
                    label: const Text('Style', style: TextStyle(color: Color(0xFFF97316))),
                  ),
                ],
              ),
            ),
          ),
          
          const Text(
            'Complétez les sections ci-dessous. Vous pouvez prévisualiser à tout moment via l\'icône en haut à droite.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          
          _buildSectionTile(
            context,
            icon: Icons.person_outline,
            title: '1. Informations de base',
            subtitle: _cvModel.personalInfo.fullName.isNotEmpty
                ? _cvModel.personalInfo.fullName
                : 'Nom, contacts, résumé...',
            onTap: () => _openEditor(
              context,
              'Informations de base',
              CvBasicInfoEditor(
                initialData: _cvModel.personalInfo,
                onSaved: (info) {
                  setState(() {
                    _cvModel = _cvModel.copyWith(personalInfo: info);
                  });
                  _autoSave();
                },
              ),
            ),
          ),
          _buildSectionTile(
            context,
            icon: Icons.bolt,
            title: '2. Compétences professionnelles',
            subtitle: _cvModel.skills.isNotEmpty ? 'Compétences ajoutées' : 'Langages, outils, frameworks...',
            onTap: () => _openEditor(
              context,
              'Compétences professionnelles',
              CvSkillsEditor(
                initialData: _cvModel.skills,
                candidateSummary: _cvModel.personalInfo.summary,
                onSaved: (skillsText) {
                  setState(() {
                    _cvModel = _cvModel.copyWith(skills: skillsText);
                  });
                  _autoSave();
                },
              ),
            ),
          ),
          _buildSectionTile(
            context,
            icon: Icons.work_outline,
            title: '3. Expérience professionnelle',
            subtitle: '${_cvModel.experiences.length} expérience(s) ajoutée(s)',
            onTap: () => _openEditor(
              context,
              'Expérience professionnelle',
              CvExperiencesEditor(
                initialData: _cvModel.experiences,
                onSaved: (exps) {
                  setState(() {
                    _cvModel = _cvModel.copyWith(experiences: exps);
                  });
                  _autoSave();
                },
              ),
            ),
          ),
          _buildSectionTile(
            context,
            icon: Icons.school_outlined,
            title: '4. Formation et diplômes',
            subtitle: '${_cvModel.educations.length} formation(s) ajoutée(s)',
            onTap: () => _openEditor(
              context,
              'Formation et diplômes',
              CvEducationEditor(
                initialData: _cvModel.educations,
                onSaved: (edus) {
                  setState(() {
                    _cvModel = _cvModel.copyWith(educations: edus);
                  });
                  _autoSave();
                },
              ),
            ),
          ),
          _buildSectionTile(
            context,
            icon: Icons.folder_outlined,
            title: '5. Projets réalisés',
            subtitle: '${_cvModel.projects.length} projet(s) ajouté(s)',
            onTap: () => _openEditor(
              context,
              'Projets réalisés',
              CvProjectsEditor(
                initialData: _cvModel.projects,
                onSaved: (projs) {
                  setState(() {
                    _cvModel = _cvModel.copyWith(projects: projs);
                  });
                  _autoSave();
                },
              ),
            ),
          ),
          _buildSectionTile(
            context,
            icon: Icons.sports_soccer,
            title: '6. Activités et loisirs',
            subtitle: '${_cvModel.activities.length} activité(s) ajoutée(s)',
            onTap: () => _openEditor(
              context,
              'Activités et loisirs',
              CvActivitiesEditor(
                initialData: _cvModel.activities,
                onSaved: (activities) {
                  setState(() {
                    _cvModel = _cvModel.copyWith(activities: activities);
                  });
                  _autoSave();
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () {
              context.push('/cv_preview?allow_edit=true', extra: _cvModel);
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Voir le résultat final'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildSectionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF97316).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFFF97316)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Future<void> _renameCvDialog() async {
    final textController = TextEditingController(text: _cvModel.displayTitle);
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer le CV'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nom du CV',
              hintText: 'Entrez le nouveau nom...',
              isDense: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Le nom ne peut pas être vide';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Renommer', style: TextStyle(color: Color(0xFFF97316))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final newTitle = textController.text.trim();
      if (newTitle == _cvModel.displayTitle) return;

      setState(() {
        _cvModel = _cvModel.copyWith(title: newTitle);
      });
      _autoSave();
    }
  }
}
