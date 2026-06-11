import 'package:flutter/material.dart';
import '../models/cv_model.dart';
import 'cv_rich_text_editor.dart';

class CvExperiencesEditor extends StatefulWidget {
  final List<CvExperience> initialData;
  final ValueChanged<List<CvExperience>> onSaved;

  const CvExperiencesEditor({
    Key? key,
    required this.initialData,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<CvExperiencesEditor> createState() => _CvExperiencesEditorState();
}

class _CvExperiencesEditorState extends State<CvExperiencesEditor> {
  late List<CvExperience> _experiences;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _experiences = List.from(widget.initialData);
  }

  void _notifyChange() {
    widget.onSaved(_experiences);
  }

  void _addExperience() {
    setState(() {
      _experiences.add(CvExperience.empty());
      _expandedIndex = _experiences.length - 1;
    });
    _notifyChange();
  }

  void _removeExperience(int index) {
    setState(() {
      _experiences.removeAt(index);
      if (_expandedIndex == index) {
        _expandedIndex = null;
      } else if (_expandedIndex != null && _expandedIndex! > index) {
        _expandedIndex = _expandedIndex! - 1;
      }
    });
    _notifyChange();
  }

  void _updateExperience(int index, CvExperience exp) {
    setState(() {
      _experiences[index] = exp;
    });
    _notifyChange();
  }

  Widget _buildExperienceCard(int index, CvExperience exp) {
    final isExpanded = _expandedIndex == index;

    return Card(
      key: ValueKey('exp_$index'),
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
              exp.company.isEmpty ? 'Nouvelle entreprise' : exp.company,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: exp.isVisible ? Colors.black : Colors.grey,
                decoration: exp.isVisible ? null : TextDecoration.lineThrough,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    exp.isVisible ? Icons.visibility : Icons.visibility_off,
                    color: exp.isVisible ? Colors.black54 : Colors.grey,
                  ),
                  tooltip: exp.isVisible ? 'Masquer sur le CV' : 'Afficher sur le CV',
                  onPressed: () {
                    _updateExperience(index, exp.copyWith(isVisible: !exp.isVisible));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Supprimer',
                  onPressed: () => _removeExperience(index),
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
                                initialValue: exp.company,
                                decoration: const InputDecoration(
                                  labelText: "Nom de l'entreprise",
                                  hintText: "Ex: Djorssi Corp",
                                  helperText: "L'entreprise d'embauche.",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) => _updateExperience(index, exp.copyWith(company: val)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                initialValue: exp.jobTitle,
                                decoration: const InputDecoration(
                                  labelText: "Poste",
                                  hintText: "Ex: Développeur Flutter Senior",
                                  helperText: "Votre intitulé de poste exact.",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) => _updateExperience(index, exp.copyWith(jobTitle: val)),
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
                                initialValue: exp.startDate,
                                decoration: const InputDecoration(
                                  labelText: "Date de début",
                                  hintText: "Ex: 2023",
                                  helperText: "Année ou mois/année de début.",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) => _updateExperience(index, exp.copyWith(startDate: val)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                initialValue: exp.isPresent ? 'Présent' : exp.endDate,
                                decoration: const InputDecoration(
                                  labelText: "Date de fin",
                                  hintText: "Ex: 2024",
                                  helperText: "Année de fin ou 'Présent'.",
                                  border: OutlineInputBorder(),
                                ),
                                enabled: !exp.isPresent,
                                onChanged: (val) => _updateExperience(index, exp.copyWith(endDate: val)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text("Poste actuel (À ce jour)"),
                            Switch(
                              value: exp.isPresent,
                              activeColor: const Color(0xFFF97316),
                              onChanged: (val) {
                                _updateExperience(index, exp.copyWith(isPresent: val, endDate: val ? 'Présent' : ''));
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: exp.location,
                          decoration: const InputDecoration(
                            labelText: "Lieu",
                            hintText: "Ex: Abidjan, Côte d'Ivoire",
                            helperText: "Format recommandé: Ville, Pays (facultatif).",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) => _updateExperience(index, exp.copyWith(location: val)),
                        ),
                        const SizedBox(height: 24),
                        const Text("Responsabilités du poste", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text(
                          "Conseil: Décrivez vos tâches et résultats ligne par ligne en démarrant par la puce '•' pour obtenir une liste à puces professionnelle sur le CV.",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        CvRichTextEditor(
                          initialData: exp.description,
                          labelText: 'Responsabilités du poste (Expérience)',
                          hintText: '• Responsable du développement de l\'application Djorssi Match...\n• Optimisation du temps de chargement des listes de 40%...\n• Mentorat de développeurs juniors et revue de code...',
                          minHeight: 150,
                          onSaved: (val) => _updateExperience(index, exp.copyWith(description: val)),
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
          child: _experiences.isEmpty
              ? const Center(
                  child: Text(
                    'Aucune expérience ajoutée.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ReorderableListView.builder(
                  itemCount: _experiences.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _experiences.removeAt(oldIndex);
                      _experiences.insert(newIndex, item);
                      
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
                    return _buildExperienceCard(index, _experiences[index]);
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addExperience,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Ajouter une expérience professionnelle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF222222), // Dark as requested
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
