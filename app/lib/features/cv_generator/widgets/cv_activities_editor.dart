import 'package:flutter/material.dart';

class CvActivitiesEditor extends StatefulWidget {
  final List<String> initialData;
  final ValueChanged<List<String>> onSaved;

  const CvActivitiesEditor({
    Key? key,
    required this.initialData,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<CvActivitiesEditor> createState() => _CvActivitiesEditorState();
}

class _CvActivitiesEditorState extends State<CvActivitiesEditor> {
  late List<String> _activities;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _activities = List.from(widget.initialData);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addActivity() {
    final activity = _controller.text.trim();
    if (activity.isNotEmpty && !_activities.contains(activity)) {
      setState(() {
        _activities.add(activity);
        _controller.clear();
      });
      widget.onSaved(_activities);
    }
  }

  void _removeActivity(String activity) {
    setState(() {
      _activities.remove(activity);
    });
    widget.onSaved(_activities);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activités et loisirs',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Conseil : Indiquez des centres d\'intérêt pertinents (sports, bénévolat, projets personnels, lectures professionnelles) pour montrer des aspects complémentaires de votre personnalité.',
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Nouvelle activité / loisir',
                    hintText: 'Ex: Football, Lecture de livres d\'architecture, Bénévolat...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addActivity(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addActivity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Ajouter'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _activities.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune activité ajoutée.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _activities.length,
                    itemBuilder: (context, index) {
                      final activity = _activities[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(activity),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _removeActivity(activity),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
