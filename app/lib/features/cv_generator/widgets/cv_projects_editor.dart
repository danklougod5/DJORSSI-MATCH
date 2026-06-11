import 'package:flutter/material.dart';
import '../models/cv_model.dart';
import 'cv_rich_text_editor.dart';

class CvProjectsEditor extends StatefulWidget {
  final List<CvProject> initialData;
  final ValueChanged<List<CvProject>> onSaved;

  const CvProjectsEditor({
    Key? key,
    required this.initialData,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<CvProjectsEditor> createState() => _CvProjectsEditorState();
}

class _CvProjectsEditorState extends State<CvProjectsEditor> {
  late List<CvProject> _projects;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _projects = List.from(widget.initialData);
  }

  void _notifyChange() {
    widget.onSaved(_projects);
  }

  void _addProject() {
    setState(() {
      _projects.add(CvProject.empty());
      _expandedIndex = _projects.length - 1;
    });
    _notifyChange();
  }

  void _removeProject(int index) {
    setState(() {
      _projects.removeAt(index);
      if (_expandedIndex == index) {
        _expandedIndex = null;
      } else if (_expandedIndex != null && _expandedIndex! > index) {
        _expandedIndex = _expandedIndex! - 1;
      }
    });
    _notifyChange();
  }

  void _updateProject(int index, CvProject proj) {
    setState(() {
      _projects[index] = proj;
    });
    _notifyChange();
  }

  Widget _buildProjectCard(int index, CvProject proj) {
    final isExpanded = _expandedIndex == index;

    return Card(
      key: ValueKey('proj_$index'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isExpanded ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isExpanded ? const Color(0xFFF97316) : Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Header
          ListTile(
            contentPadding: const EdgeInsets.only(left: 8, right: 8),
            leading: ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.drag_indicator, color: Colors.grey),
              ),
            ),
            title: Text(
              proj.name.isEmpty ? 'Nouveau projet réalisé' : proj.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: proj.isVisible ? Colors.black : Colors.grey,
                decoration: proj.isVisible ? null : TextDecoration.lineThrough,
              ),
            ),
            subtitle: proj.role.isNotEmpty
                ? Text(
                    proj.role,
                    style: TextStyle(color: proj.isVisible ? Colors.grey.shade700 : Colors.grey),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    proj.isVisible ? Icons.visibility : Icons.visibility_off,
                    color: proj.isVisible ? Colors.black54 : Colors.grey,
                  ),
                  tooltip: proj.isVisible ? 'Masquer sur le CV' : 'Afficher sur le CV',
                  onPressed: () {
                    _updateProject(index, proj.copyWith(isVisible: !proj.isVisible));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Supprimer',
                  onPressed: () => _removeProject(index),
                ),
                IconButton(
                  icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() {
                      _expandedIndex = isExpanded ? null : index;
                    });
                  },
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? null : index;
              });
            },
          ),
          // Expanded Body
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          initialValue: proj.name,
                          decoration: const InputDecoration(
                            labelText: "Nom du projet",
                            hintText: "Ex: Portfolio CV Mobile",
                            helperText: "Saisissez le titre ou nom officiel de la réalisation.",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) => _updateProject(index, proj.copyWith(name: val)),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: proj.role,
                                decoration: const InputDecoration(
                                  labelText: "Votre rôle",
                                  hintText: "Ex: Créateur & Lead Dev",
                                  helperText: "Ex: Concepteur, Développeur frontend, etc.",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) => _updateProject(index, proj.copyWith(role: val)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                initialValue: proj.date,
                                decoration: const InputDecoration(
                                  labelText: "Date de réalisation",
                                  hintText: "Ex: 2024 ou 2023 - 2024",
                                  helperText: "Format recommandé: AAAA ou AAAA - AAAA.",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) => _updateProject(index, proj.copyWith(date: val)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Détails et réalisations du projet",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Conseil: Décrivez vos réalisations ligne par ligne en commençant chaque ligne par la puce '•' pour assurer une mise en page parfaite sur le CV.",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        CvRichTextEditor(
                          initialData: proj.description,
                          labelText: 'Description du projet',
                          hintText: '• Conception et développement de l\'application de bout en bout...\n• Intégration de Stripe pour la gestion des abonnements...\n• Publication de l\'application sur l\'App Store et Google Play...',
                          minHeight: 150,
                          onSaved: (val) => _updateProject(index, proj.copyWith(description: val)),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _projects.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Aucun projet réalisé ajouté pour le moment.\nCliquez sur le bouton ci-dessous pour ajouter un projet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, height: 1.4),
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  itemCount: _projects.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _projects.removeAt(oldIndex);
                      _projects.insert(newIndex, item);

                      // Fix expanded index
                      if (_expandedIndex == oldIndex) {
                        _expandedIndex = newIndex;
                      } else if (_expandedIndex != null) {
                        if (_expandedIndex! > oldIndex && _expandedIndex! <= newIndex) {
                          _expandedIndex = _expandedIndex! - 1;
                        } else if (_expandedIndex! < oldIndex && _expandedIndex! >= newIndex) {
                          _expandedIndex = _expandedIndex! + 1;
                        }
                      }
                    });
                    _notifyChange();
                  },
                  itemBuilder: (context, index) {
                    return _buildProjectCard(index, _projects[index]);
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addProject,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Ajouter un projet réalisé'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF222222),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
