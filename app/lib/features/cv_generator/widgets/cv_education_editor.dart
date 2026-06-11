import 'package:flutter/material.dart';
import '../models/cv_model.dart';
import 'cv_rich_text_editor.dart';

class CvEducationEditor extends StatefulWidget {
  final List<CvEducation> initialData;
  final ValueChanged<List<CvEducation>> onSaved;

  const CvEducationEditor({
    Key? key,
    required this.initialData,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<CvEducationEditor> createState() => _CvEducationEditorState();
}

class _CvEducationEditorState extends State<CvEducationEditor> {
  late List<CvEducation> _educations;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _educations = List.from(widget.initialData);
  }

  void _notifyChange() {
    widget.onSaved(_educations);
  }

  void _addEducation() {
    setState(() {
      _educations.add(CvEducation.empty());
      _expandedIndex = _educations.length - 1;
    });
    _notifyChange();
  }

  void _removeEducation(int index) {
    setState(() {
      _educations.removeAt(index);
      if (_expandedIndex == index) {
        _expandedIndex = null;
      } else if (_expandedIndex != null && _expandedIndex! > index) {
        _expandedIndex = _expandedIndex! - 1;
      }
    });
    _notifyChange();
  }

  void _updateEducation(int index, CvEducation edu) {
    setState(() {
      _educations[index] = edu;
    });
    _notifyChange();
  }

  Widget _buildEducationCard(int index, CvEducation edu) {
    final isExpanded = _expandedIndex == index;

    return Card(
      key: ValueKey('edu_$index'),
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
              edu.institution.isEmpty ? 'Nouvelle école/université' : edu.institution,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: edu.isVisible ? Colors.black : Colors.grey,
                decoration: edu.isVisible ? null : TextDecoration.lineThrough,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    edu.isVisible ? Icons.visibility : Icons.visibility_off,
                    color: edu.isVisible ? Colors.black54 : Colors.grey,
                  ),
                  tooltip: edu.isVisible ? 'Masquer sur le CV' : 'Afficher sur le CV',
                  onPressed: () {
                    _updateEducation(index, edu.copyWith(isVisible: !edu.isVisible));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Supprimer',
                  onPressed: () => _removeEducation(index),
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: edu.institution,
                                decoration: const InputDecoration(
                                  labelText: "Nom de l'école/université",
                                  hintText: "Ex: Université Félix Houphouët-Boigny",
                                  helperText: "L'établissement d'enseignement.",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) => _updateEducation(index, edu.copyWith(institution: val)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                initialValue: edu.degree,
                                decoration: const InputDecoration(
                                  labelText: "Diplôme/Filière",
                                  hintText: "Ex: Master en Informatique",
                                  helperText: "L'intitulé du diplôme ou domaine.",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) => _updateEducation(index, edu.copyWith(degree: val)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: edu.startDate,
                                decoration: const InputDecoration(
                                  labelText: "Date de début",
                                  hintText: "Ex: 2019",
                                  helperText: "Année d'entrée (ex: 2019).",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) => _updateEducation(index, edu.copyWith(startDate: val)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                initialValue: edu.isPresent ? 'Présent' : edu.endDate,
                                decoration: const InputDecoration(
                                  labelText: "Date de fin",
                                  hintText: "Ex: 2021",
                                  helperText: "Année de fin ou 'Présent'.",
                                  border: OutlineInputBorder(),
                                ),
                                enabled: !edu.isPresent,
                                onChanged: (val) => _updateEducation(index, edu.copyWith(endDate: val)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text("Cursus en cours (À ce jour)"),
                            Switch(
                              value: edu.isPresent,
                              activeColor: const Color(0xFFF97316),
                              onChanged: (val) {
                                _updateEducation(index, edu.copyWith(isPresent: val, endDate: val ? 'Présent' : ''));
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: edu.location,
                          decoration: const InputDecoration(
                            labelText: "Lieu",
                            hintText: "Ex: Abidjan, Côte d'Ivoire",
                            helperText: "Format recommandé: Ville, Pays (facultatif).",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) => _updateEducation(index, edu.copyWith(location: val)),
                        ),
                        const SizedBox(height: 24),
                        const Text("Description / Mentions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text(
                          "Conseil: Décrivez vos distinctions, projets académiques ou mentions ligne par ligne en commençant chaque ligne par la puce '•'.",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        CvRichTextEditor(
                          initialData: edu.description,
                          labelText: 'Description / Mentions (Formation)',
                          hintText: '• Mention très bien...\n• Spécialisation en Génie Logiciel et Développement Mobile...\n• Projet de fin d\'études sur les architectures cloud...',
                          minHeight: 120,
                          onSaved: (val) => _updateEducation(index, edu.copyWith(description: val)),
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
          child: _educations.isEmpty
              ? const Center(
                  child: Text(
                    'Aucune formation ajoutée.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ReorderableListView.builder(
                  itemCount: _educations.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _educations.removeAt(oldIndex);
                      _educations.insert(newIndex, item);
                      
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
                    return _buildEducationCard(index, _educations[index]);
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addEducation,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Ajouter une formation'),
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
