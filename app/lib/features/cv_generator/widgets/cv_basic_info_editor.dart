import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cv_model.dart';
import 'cv_ai_loading_dialog.dart';

class CvBasicInfoEditor extends StatefulWidget {
  final CvPersonalInfo initialData;
  final ValueChanged<CvPersonalInfo> onSaved;

  const CvBasicInfoEditor({
    Key? key,
    required this.initialData,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<CvBasicInfoEditor> createState() => _CvBasicInfoEditorState();
}

class _CvBasicInfoEditorState extends State<CvBasicInfoEditor> {
  late CvPersonalInfo _info;
  String _summaryKeySource = 'initial';

  @override
  void initState() {
    super.initState();
    _info = widget.initialData;
  }

  void _update(CvPersonalInfo newInfo) {
    setState(() => _info = newInfo);
    widget.onSaved(_info);
  }

  Widget _buildLayoutSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mise en page', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          children: [
            _LayoutOption(
              icon: Icons.format_align_left,
              isSelected: _info.layout == 'left',
              onTap: () => _update(_info.copyWith(layout: 'left')),
            ),
            const SizedBox(width: 12),
            _LayoutOption(
              icon: Icons.format_align_center,
              isSelected: _info.layout == 'center',
              onTap: () => _update(_info.copyWith(layout: 'center')),
            ),
            const SizedBox(width: 12),
            _LayoutOption(
              icon: Icons.splitscreen, // Using splitscreen as a proxy for split layout
              isSelected: _info.layout == 'split',
              onTap: () => _update(_info.copyWith(layout: 'split')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_outlined, color: Colors.grey),
          const SizedBox(width: 8),
          const Text('Avatar', style: TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          IconButton(
            icon: Icon(
              _info.showAvatar ? Icons.visibility : Icons.visibility_off,
              color: _info.showAvatar ? Colors.black54 : Colors.grey,
            ),
            onPressed: () => _update(_info.copyWith(showAvatar: !_info.showAvatar)),
          ),
        ],
      ),
    );
  }

  Future<void> _polishSummaryWithMistral(BuildContext context) async {
    final text = _info.summary.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez saisir un résumé avant d'utiliser l'amélioration par IA."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CvAiLoadingDialog(
        title: "Amélioration intelligente de votre résumé",
        steps: [
          "Analyse du résumé actuel...",
          "Optimisation des mots-clés...",
          "Correction de l'orthographe...",
          "Application des améliorations...",
        ],
      ),
    );

    try {
      final supabase = Supabase.instance.client;

      final response = await supabase.functions.invoke(
        'cv-ai-assist',
        body: {
          'action': 'polish_text',
          'text': text,
          'systemContent': 'Tu es un expert en recrutement et en rédaction de CV. Ton rôle est de reformuler, polir et améliorer le profil/résumé professionnel de l\'utilisateur pour le rendre plus percutant, professionnel et vendeur. Garde le résumé au format paragraphe. Conserve la même langue (Français). Retourne UNIQUEMENT le texte corrigé et poli final, sans aucun commentaire ou texte d\'accompagnement.',
        },
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (response.status == 200) {
        final data = response.data;
        if (data == null || data['success'] != true || data['polishedText'] == null) {
          throw Exception('Données incorrectes reçues du serveur.');
        }

        final String polishedText = data['polishedText'].toString().trim();
        
        setState(() {
          _info = _info.copyWith(summary: polishedText);
          _summaryKeySource = DateTime.now().millisecondsSinceEpoch.toString();
        });
        widget.onSaved(_info);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Résumé amélioré par l'IA !"),
            backgroundColor: Colors.green,
          ),
        );
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

  Widget _buildStaticFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Champs de base', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        _StaticFieldRow(
          label: 'Nom',
          value: _info.fullName,
          hintText: 'Ex: Jean Dupont',
          helperText: 'Saisissez votre nom complet pour l\'en-tête du CV.',
          onChanged: (val) => _update(_info.copyWith(fullName: val)),
        ),
        const SizedBox(height: 16),
        _StaticFieldRow(
          label: 'Position',
          value: _info.jobTitle,
          hintText: 'Ex: Développeur Mobile Flutter',
          helperText: 'Le poste recherché ou votre titre professionnel.',
          onChanged: (val) => _update(_info.copyWith(jobTitle: val)),
        ),
        const SizedBox(height: 16),
        _StaticFieldRow(
          key: ValueKey(_summaryKeySource),
          label: 'Résumé',
          value: _info.summary,
          hintText: 'Ex: Développeur passionné avec plus de 5 ans d\'expérience dans la création d\'applications mobiles performantes...',
          helperText: 'Présentez-vous brièvement en 2 ou 3 phrases synthétisant vos compétences clés.',
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          onChanged: (val) => _update(_info.copyWith(summary: val)),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _polishSummaryWithMistral(context),
            icon: const Icon(Icons.auto_awesome, color: Color(0xFFF97316), size: 16),
            label: const Text("Améliorer par l'IA", style: TextStyle(color: Color(0xFFF97316), fontSize: 13)),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicFields() {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = _info.contactFields.removeAt(oldIndex);
          _info.contactFields.insert(newIndex, item);
        });
        _update(_info);
      },
      children: [
        for (int i = 0; i < _info.contactFields.length; i++)
          _DynamicFieldRow(
            key: ValueKey(_info.contactFields[i].id),
            index: i,
            field: _info.contactFields[i],
            onChanged: (val) {
              final newFields = List<CvContactField>.from(_info.contactFields);
              newFields[i] = newFields[i].copyWith(value: val);
              _update(_info.copyWith(contactFields: newFields));
            },
            onToggleVisibility: () {
              final newFields = List<CvContactField>.from(_info.contactFields);
              newFields[i] = newFields[i].copyWith(isVisible: !newFields[i].isVisible);
              _update(_info.copyWith(contactFields: newFields));
            },
            onDelete: () {
              final newFields = List<CvContactField>.from(_info.contactFields);
              newFields.removeAt(i);
              _update(_info.copyWith(contactFields: newFields));
            },
          ),
      ],
    );
  }

  void _addContactField() {
    final newFields = List<CvContactField>.from(_info.contactFields);
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    newFields.add(CvContactField(
      id: newId,
      iconName: 'info',
      label: 'Nouveau champ',
      value: '',
    ));
    _update(_info.copyWith(contactFields: newFields));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLayoutSelector(),
          const SizedBox(height: 24),
          _buildAvatarSection(),
          const SizedBox(height: 24),
          _buildStaticFields(),
          const SizedBox(height: 24),
          const Text('Champs dynamiques', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _buildDynamicFields(),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: _addContactField,
              icon: const Icon(Icons.add, color: Color(0xFFF97316)),
              label: const Text('Ajouter un champ', style: TextStyle(color: Color(0xFFF97316))),
            ),
          ),
        ],
      ),
    );
  }
}

class _LayoutOption extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _LayoutOption({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF97316).withOpacity(0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFFF97316) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: isSelected ? const Color(0xFFF97316) : Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _StaticFieldRow extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final String? helperText;
  final int? maxLines;
  final TextInputType? keyboardType;

  const _StaticFieldRow({
    Key? key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hintText,
    this.helperText,
    this.maxLines = 1,
    this.keyboardType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ),
        Expanded(
          child: TextFormField(
            initialValue: value,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              isDense: true,
              hintText: hintText,
              helperText: helperText,
              helperMaxLines: 2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _DynamicFieldRow extends StatelessWidget {
  final int index;
  final CvContactField field;
  final ValueChanged<String> onChanged;
  final VoidCallback onToggleVisibility;
  final VoidCallback onDelete;

  const _DynamicFieldRow({
    Key? key,
    required this.index,
    required this.field,
    required this.onChanged,
    required this.onToggleVisibility,
    required this.onDelete,
  }) : super(key: key);

  IconData _getIconForName(String name) {
    switch (name) {
      case 'email':
        return Icons.email_outlined;
      case 'phone':
        return Icons.phone_outlined;
      case 'location':
        return Icons.location_on_outlined;
      case 'date':
        return Icons.calendar_today_outlined;
      case 'link':
        return Icons.link;
      default:
        return Icons.info_outline;
    }
  }

  String _getPlaceholderForId(String id) {
    switch (id) {
      case 'email':
        return 'Ex: jean.dupont@email.com';
      case 'phone':
        return 'Ex: +225 07 00 00 00 00';
      case 'location':
        return 'Ex: Abidjan, Côte d\'Ivoire';
      default:
        if (id.contains('link') || field.label.toLowerCase().contains('link') || field.label.toLowerCase().contains('linkedin')) {
          return 'Ex: linkedin.com/in/jeandupont';
        }
        return field.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.drag_indicator, color: Colors.grey),
            ),
          ),
          Icon(_getIconForName(field.iconName), size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: field.value,
              decoration: InputDecoration(
                hintText: _getPlaceholderForId(field.id),
                labelText: field.label,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onChanged: onChanged,
            ),
          ),
          IconButton(
            icon: Icon(
              field.isVisible ? Icons.visibility : Icons.visibility_off,
              color: field.isVisible ? Colors.black54 : Colors.grey,
            ),
            onPressed: onToggleVisibility,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
