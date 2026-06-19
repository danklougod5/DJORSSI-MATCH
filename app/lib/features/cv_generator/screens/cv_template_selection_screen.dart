import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../models/cv_model.dart';
import '../utils/cv_pdf_generator.dart';
import '../utils/templates/cv_template_base.dart';
import '../services/cv_storage_service.dart';

class CvTemplateSelectionScreen extends StatefulWidget {
  final CvModel? existingCv;
  final bool isEditingStyle;

  const CvTemplateSelectionScreen({
    Key? key,
    this.existingCv,
    this.isEditingStyle = false,
  }) : super(key: key);

  @override
  State<CvTemplateSelectionScreen> createState() => _CvTemplateSelectionScreenState();
}

class _CvTemplateSelectionScreenState extends State<CvTemplateSelectionScreen> {
  late String _selectedTemplateId;
  late String _selectedPrimaryColor;
  late String _selectedSecondaryColor;
  bool _isSaving = false;

  final List<Map<String, String>> _primaryPresets = [
    {'name': 'Bleu Nuit', 'hex': '#1E3A8A'},
    {'name': 'Bleu Moderne', 'hex': '#2563EB'},
    {'name': 'Émeraude', 'hex': '#065F46'},
    {'name': 'Vert Forêt', 'hex': '#15803D'},
    {'name': 'Violet Créatif', 'hex': '#6D28D9'},
    {'name': 'Indigo', 'hex': '#4338CA'},
    {'name': 'Bordeaux', 'hex': '#7F1D1D'},
    {'name': 'Rouge', 'hex': '#B91C1C'},
    {'name': 'Orange Épicé', 'hex': '#C2410C'},
    {'name': 'Chocolat', 'hex': '#78350F'},
    {'name': 'Gris Ardoise', 'hex': '#334155'},
    {'name': 'Noir Classique', 'hex': '#111827'},
    {'name': 'Bleu Sarcelle', 'hex': '#0F766E'},
    {'name': 'Vert Sauge', 'hex': '#4D7C0F'},
    {'name': 'Prune', 'hex': '#86198F'},
    {'name': 'Terracotta', 'hex': '#9A3412'},
    {'name': 'Corail', 'hex': '#BE123C'},
    {'name': 'Rose Poudré', 'hex': '#A21CAF'},
    {'name': 'Moutarde', 'hex': '#B45309'},
    {'name': 'Sapin', 'hex': '#064E3B'},
    {'name': 'Bleu Acier', 'hex': '#0369A1'},
    {'name': 'Aubergine', 'hex': '#4C1D95'},
    {'name': 'Havane', 'hex': '#854D0E'},
    {'name': 'Charbon', 'hex': '#1F2937'},
  ];

  final List<Map<String, String>> _secondaryPresets = [
    {'name': 'Gris Neutre', 'hex': '#4B5563'},
    {'name': 'Gris Moyen', 'hex': '#6B7280'},
    {'name': 'Gris Ardoise', 'hex': '#475569'},
    {'name': 'Bleu Gris', 'hex': '#64748B'},
    {'name': 'Bleu Clair', 'hex': '#3B82F6'},
    {'name': 'Vert Menthe', 'hex': '#10B981'},
    {'name': 'Bronze', 'hex': '#B45309'},
    {'name': 'Charbon', 'hex': '#1F2937'},
    {'name': 'Sable', 'hex': '#78350F'},
    {'name': 'Kaki', 'hex': '#3F6212'},
    {'name': 'Vert Olive', 'hex': '#3F4F3F'},
    {'name': 'Café', 'hex': '#543D2B'},
    {'name': 'Lavande', 'hex': '#5B21B6'},
    {'name': 'Taupe', 'hex': '#78716C'},
    {'name': 'Gris Perle', 'hex': '#9CA3AF'},
    {'name': 'Rose Ancien', 'hex': '#9D174D'},
  ];

  Color _parseColor(String hex) {
    return Color(int.parse(hex.replaceFirst('#', '0xff')));
  }

  bool _isPrimaryPreset(String hex) {
    return _primaryPresets.any((p) => p['hex']!.toLowerCase() == hex.toLowerCase());
  }

  bool _isSecondaryPreset(String hex) {
    return _secondaryPresets.any((s) => s['hex']!.toLowerCase() == hex.toLowerCase());
  }

  void _showCustomColorPicker(bool isPrimary) {
    final controller = TextEditingController(
      text: isPrimary ? _selectedPrimaryColor : _selectedSecondaryColor,
    );
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String currentVal = controller.text.trim();
            if (!currentVal.startsWith('#')) {
              currentVal = '#$currentVal';
            }
            Color? previewColor;
            try {
              previewColor = _parseColor(currentVal);
            } catch (_) {
              previewColor = null;
            }

            return AlertDialog(
              title: Text(isPrimary ? 'Couleur principale' : 'Couleur secondaire'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Entrez un code hexadécimal (ex: #FF5733) :'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: '#CCCCCC',
                        prefixIcon: previewColor != null
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: previewColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey),
                                  ),
                                ),
                              )
                            : const Icon(Icons.colorize),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setDialogState(() {});
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez entrer une couleur';
                        }
                        final clean = value.trim();
                        final regex = RegExp(r'^#?[0-9a-fA-F]{6}$');
                        if (!regex.hasMatch(clean)) {
                          return 'Format invalide (ex: #FF5733)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Palette rapide :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        '#FF0000', '#FF7F00', '#FFFF00', '#00FF00', '#0000FF',
                        '#4B0082', '#8B00FF', '#FF1493', '#00FFFF', '#FF00FF',
                        '#00FA9A', '#FFD700', '#FF4500', '#7FFF00', '#00CED1',
                      ].map((hex) => GestureDetector(
                        onTap: () {
                          controller.text = hex;
                          setDialogState(() {});
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _parseColor(hex),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() == true) {
                      String hex = controller.text.trim();
                      if (!hex.startsWith('#')) {
                        hex = '#$hex';
                      }
                      setState(() {
                        if (isPrimary) {
                          _selectedPrimaryColor = hex;
                        } else {
                          _selectedSecondaryColor = hex;
                        }
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Appliquer', style: TextStyle(color: Color(0xFFF97316))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  CvModel _getPreviewCv(String templateId) {
    final baseCv = widget.existingCv != null && widget.existingCv!.personalInfo.fullName.isNotEmpty
        ? widget.existingCv!
        : CvModel.mock();
    return baseCv.copyWith(
      templateId: templateId,
      primaryColor: _selectedPrimaryColor,
      secondaryColor: _selectedSecondaryColor,
    );
  }

  void _showTemplatePreviewDialog(BuildContext context, CvTemplateBase template) {
    showDialog(
      context: context,
      builder: (context) {
        final previewCv = _getPreviewCv(template.id);
        
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.8,
            width: double.infinity,
            child: Column(
              children: [
                AppBar(
                  title: Text('Modèle : ${template.name}'),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 1,
                  automaticallyImplyLeading: false,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Expanded(
                  child: PdfPreview(
                    build: (format) => CvPdfGenerator.generateCvPdf(previewCv),
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    allowPrinting: false,
                    allowSharing: false,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedTemplateId = template.id;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Sélectionner ce modèle'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTemplateThumbnail(String id, Color primary, Color secondary) {
    final lineGrey = Colors.grey.shade300;
    final accent = primary;

    Widget line([double width = 40, Color? col]) => Container(
          margin: const EdgeInsets.only(bottom: 3),
          height: 3,
          width: width,
          decoration: BoxDecoration(
            color: col ?? lineGrey,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );

    switch (id) {
      case 'classic':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: line(30, accent)),
            const SizedBox(height: 2),
            Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [line(15), const SizedBox(width: 2), line(15)])),
            const Divider(height: 6, thickness: 0.5),
            line(25, accent),
            Row(children: [line(12), const Spacer(), line(15, secondary)]),
            line(50),
            line(45),
            const SizedBox(height: 4),
            line(25, accent),
            Row(children: [line(15), const Spacer(), line(10, secondary)]),
            line(50),
          ],
        );
      case 'modern':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 14,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Container(width: 20, height: 3, color: Colors.white),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line(30, secondary),
                  const SizedBox(height: 2),
                  line(50),
                  line(45),
                  const SizedBox(height: 4),
                  line(25, accent),
                  line(50),
                ],
              ),
            ),
          ],
        );
      case 'minimalist':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 4),
            line(35, accent),
            line(20, secondary),
            const SizedBox(height: 6),
            line(40),
            line(35),
            const SizedBox(height: 6),
            line(25, accent),
            line(45),
          ],
        );
      case 'left_right':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column
            Container(
              width: 22,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.08),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: accent.withOpacity(0.3), shape: BoxShape.circle)),
                  const SizedBox(height: 4),
                  line(12, accent),
                  line(14),
                  line(14),
                  const SizedBox(height: 6),
                  line(12, accent),
                  line(14),
                ],
              ),
            ),
            const VerticalDivider(width: 2, thickness: 0.5),
            // Right column
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    line(30, accent),
                    line(50),
                    line(45),
                    const SizedBox(height: 6),
                    line(25, accent),
                    line(48),
                  ],
                ),
              ),
            ),
          ],
        );
      case 'timeline':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Container(width: 4, height: 4, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                  Container(width: 1, height: 12, color: accent),
                  Container(width: 4, height: 4, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                  Container(width: 1, height: 12, color: accent),
                  Container(width: 4, height: 4, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    line(20, accent),
                    line(40),
                    const SizedBox(height: 4),
                    line(25, accent),
                    line(42),
                    const SizedBox(height: 4),
                    line(15, accent),
                    line(30),
                  ],
                ),
              ),
            ),
          ],
        );
      case 'creative':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accent, secondary]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line(35, accent),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    color: accent.withOpacity(0.1),
                    child: line(20, accent),
                  ),
                  const SizedBox(height: 2),
                  line(50),
                  line(45),
                ],
              ),
            ),
          ],
        );
      case 'elegant':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                border: Border.symmetric(horizontal: BorderSide(color: accent, width: 0.5)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Center(child: line(30, accent)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: line(25, secondary)),
                  const SizedBox(height: 4),
                  line(20, accent),
                  line(50),
                  line(45),
                ],
              ),
            ),
          ],
        );
      case 'executive':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      line(25, accent),
                      const SizedBox(height: 2),
                      line(15, secondary),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    line(12),
                    line(12),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(width: 2, height: 6, color: accent),
                const SizedBox(width: 4),
                line(20, accent),
              ],
            ),
            const Divider(height: 4, thickness: 0.5),
            Row(
              children: [
                Expanded(child: line(30)),
                const SizedBox(width: 8),
                line(12),
              ],
            ),
            line(45),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(width: 2, height: 6, color: accent),
                const SizedBox(width: 4),
                line(20, accent),
              ],
            ),
            const Divider(height: 4, thickness: 0.5),
            Row(
              children: [
                Expanded(child: line(30)),
                const SizedBox(width: 8),
                line(12),
              ],
            ),
          ],
        );
      default:
        return Container();
    }
  }

  @override
  void initState() {
    super.initState();
    final cv = widget.existingCv ?? CvModel.empty();
    _selectedTemplateId = cv.templateId;
    _selectedPrimaryColor = cv.primaryColor;
    _selectedSecondaryColor = cv.secondaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final templates = CvPdfGenerator.availableTemplates;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Design de votre CV'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: widget.existingCv != null 
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Sélectionnez un modèle',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          // Grid of templates
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              final isSelected = _selectedTemplateId == template.id;
              final primary = _parseColor(_selectedPrimaryColor);
              final secondary = _parseColor(_selectedSecondaryColor);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTemplateId = template.id;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: isSelected ? const Color(0xFFF97316) : Colors.grey.shade200,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: const Color(0xFFF97316).withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ] : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Template Thumbnail Representation
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: _buildTemplateThumbnail(template.id, primary, secondary),
                              ),
                              // Preview overlay button at top-right
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.visibility, size: 16),
                                    color: const Color(0xFFF97316),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    tooltip: 'Voir l\'aperçu PDF',
                                    onPressed: () {
                                      _showTemplatePreviewDialog(context, template);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Title and Desc
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              template.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? const Color(0xFFF97316) : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getTemplateDesc(template.id),
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      // Select/View button at the bottom of card
                      Padding(
                        padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8, top: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFF97316) : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isSelected ? 'Sélectionné' : 'Choisir',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Primary color choice
          const Text(
            'Couleur principale (Titres)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ..._primaryPresets.map((preset) {
                  final isSelected = _selectedPrimaryColor == preset['hex'];
                  final color = _parseColor(preset['hex']!);
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPrimaryColor = preset['hex']!;
                      });
                    },
                    child: Tooltip(
                      message: preset['name']!,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => _showCustomColorPicker(true),
                  child: Tooltip(
                    message: 'Personnalisé...',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: !_isPrimaryPreset(_selectedPrimaryColor) ? Colors.black : Colors.grey.shade300,
                          width: !_isPrimaryPreset(_selectedPrimaryColor) ? 3 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: !_isPrimaryPreset(_selectedPrimaryColor)
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: _parseColor(_selectedPrimaryColor),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const Icon(Icons.check, color: Colors.white, size: 16),
                              ],
                            )
                          : const Icon(Icons.colorize, color: Colors.grey, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Secondary color choice
          const Text(
            'Couleur secondaire (Détails & Sous-titres)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ..._secondaryPresets.map((preset) {
                  final isSelected = _selectedSecondaryColor == preset['hex'];
                  final color = _parseColor(preset['hex']!);
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSecondaryColor = preset['hex']!;
                      });
                    },
                    child: Tooltip(
                      message: preset['name']!,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.black : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => _showCustomColorPicker(false),
                  child: Tooltip(
                    message: 'Personnalisé...',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: !_isSecondaryPreset(_selectedSecondaryColor) ? Colors.black : Colors.grey.shade300,
                          width: !_isSecondaryPreset(_selectedSecondaryColor) ? 3 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: !_isSecondaryPreset(_selectedSecondaryColor)
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: _parseColor(_selectedSecondaryColor),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const Icon(Icons.check, color: Colors.white, size: 16),
                              ],
                            )
                          : const Icon(Icons.colorize, color: Colors.grey, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _isSaving
                ? null
                : () async {
                    // Update state model
                    final currentCv = widget.existingCv ?? CvModel.empty();
                    final updatedCv = currentCv.copyWith(
                      templateId: _selectedTemplateId,
                      primaryColor: _selectedPrimaryColor,
                      secondaryColor: _selectedSecondaryColor,
                    );
                    
                    if (widget.isEditingStyle) {
                      // If we came from builder editing styles, pop back with updated model
                      Navigator.of(context).pop(updatedCv);
                    } else {
                      setState(() => _isSaving = true);
                      try {
                        final savedCv = await CvStorageService.saveCv(updatedCv);
                        if (!mounted) return;
                        setState(() => _isSaving = false);
                        if (context.mounted) {
                          context.pushReplacement('/cv_builder', extra: savedCv);
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isSaving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur de création : ${e.toString().replaceAll('Exception: ', '')}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(widget.isEditingStyle ? 'Appliquer les styles' : 'Continuer vers le formulaire'),
          ),
        ),
      ),
    );
  }

  String _getTemplateDesc(String id) {
    switch (id) {
      case 'classic':
        return 'Layout simple et professionnel.';
      case 'modern':
        return 'Bandeau d\'en-tête de couleur.';
      case 'minimalist':
        return 'Style épuré, centré et aéré.';
      case 'left_right':
        return 'Double colonne compacte.';
      case 'timeline':
        return 'Ligne de temps chronologique.';
      case 'creative':
        return 'En-tête stylisé & bannières.';
      case 'elegant':
        return 'Fines bordures, style chic.';
      case 'executive':
        return 'Style executive élégant avec barre verticale.';
      default:
        return '';
    }
  }
}
