import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:djossimatch/core/services/profile_notifier.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:djossimatch/core/services/cv_quota_service.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/cv_model.dart';
import '../utils/cv_pdf_generator.dart';
import '../utils/templates/cv_template_base.dart';

class CvPreviewScreen extends StatefulWidget {
  final CvModel cv;
  final bool allowEdit;

  const CvPreviewScreen({
    Key? key,
    required this.cv,
    this.allowEdit = false,
  }) : super(key: key);

  @override
  State<CvPreviewScreen> createState() => _CvPreviewScreenState();
}

class _CvPreviewScreenState extends State<CvPreviewScreen> {
  late CvModel _currentCv;
  bool _isUploading = false;
  bool _isPremium = false;

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

  bool get _canEdit => widget.allowEdit || _isPremium;

  @override
  void initState() {
    super.initState();
    _currentCv = widget.cv;
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    final premium = await CvQuotaService.isPremium();
    if (mounted) {
      setState(() {
        _isPremium = premium;
      });
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xff')));
    } catch (_) {
      return const Color(0xFF1E3A8A); // Fallback color
    }
  }

  bool _isPrimaryPreset(String hex) {
    return _primaryPresets.any((p) => p['hex']!.toLowerCase() == hex.toLowerCase());
  }

  bool _isSecondaryPreset(String hex) {
    return _secondaryPresets.any((s) => s['hex']!.toLowerCase() == hex.toLowerCase());
  }

  void _showCustomColorPicker(bool isPrimary) {
    final controller = TextEditingController(
      text: isPrimary ? _currentCv.primaryColor : _currentCv.secondaryColor,
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
                          _currentCv = _currentCv.copyWith(primaryColor: hex);
                        } else {
                          _currentCv = _currentCv.copyWith(secondaryColor: hex);
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

  IconData _getTemplateIcon(String id) {
    switch (id) {
      case 'classic':
        return Icons.article_outlined;
      case 'modern':
        return Icons.dashboard_outlined;
      case 'minimalist':
        return Icons.notes_outlined;
      case 'left_right':
        return Icons.view_sidebar_outlined;
      case 'timeline':
        return Icons.linear_scale_outlined;
      case 'creative':
        return Icons.brush_outlined;
      case 'elegant':
        return Icons.auto_awesome_outlined;
      case 'executive':
        return Icons.business_center_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  Future<void> _printCv() async {
    try {
      final pdfBytes = await CvPdfGenerator.generateCvPdf(_currentCv);
      await Printing.layoutPdf(
        onLayout: (format) => pdfBytes,
        name: 'CV_${_currentCv.personalInfo.fullName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'impression : $e')),
        );
      }
    }
  }

  Future<void> _shareCv() async {
    try {
      final pdfBytes = await CvPdfGenerator.generateCvPdf(_currentCv);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'CV_${_currentCv.personalInfo.fullName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du partage : $e')),
        );
      }
    }
  }

  Future<void> _downloadCv() async {
    try {
      final pdfBytes = await CvPdfGenerator.generateCvPdf(_currentCv);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'CV_${_currentCv.personalInfo.fullName.replaceAll(' ', '_')}.pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Téléchargement du CV lancé avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du téléchargement : $e')),
        );
      }
    }
  }

  Future<void> _setAsProfileCv() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Définir comme CV du profil ?'),
        content: const Text(
          'Ce CV généré va remplacer le CV actuel de votre profil. '
          'Les recruteurs verront ce nouveau CV lorsque vous postulerez aux offres.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF97316)),
            child: const Text('Remplacer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utilisateur non connecté')),
      );
      return;
    }

    setState(() => _isUploading = true);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFFF97316)),
            SizedBox(width: 16),
            Expanded(child: Text("Mise à jour du CV de votre profil...")),
          ],
        ),
      ),
    );

    try {
      final pdfBytes = await CvPdfGenerator.generateCvPdf(_currentCv);
      final fileName = '${user.id}_cv.pdf';
      final filePath = 'cvs/$fileName';

      await supabase.storage
          .from('cv_files')
          .uploadBinary(
            filePath,
            pdfBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final String publicUrl = supabase.storage
          .from('cv_files')
          .getPublicUrl(filePath);

      await supabase
          .from('profiles')
          .update({'cv_url': publicUrl})
          .eq('id', user.id);

      ProfileNotifier.notifyProfileUpdated();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Votre profil a été mis à jour avec ce CV !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_canEdit ? _currentCv : null);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: _canEdit ? _renameCvDialog : null,
            child: MouseRegion(
              cursor: _canEdit ? SystemMouseCursors.click : MouseCursor.defer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _currentCv.displayTitle,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_canEdit) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 14, color: Colors.grey),
                      ],
                    ],
                  ),
                  const Text('Aperçu du CV', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop(_canEdit ? _currentCv : null);
            },
          ),
          actions: [
            if (_canEdit)
              IconButton(
                icon: const Icon(Icons.drive_file_rename_outline),
                tooltip: 'Renommer le CV',
                onPressed: _renameCvDialog,
              ),
            IconButton(
              icon: const Icon(Icons.cloud_upload_outlined),
              tooltip: 'Définir comme CV du profil',
              onPressed: _isUploading ? null : _setAsProfileCv,
            ),
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: 'Imprimer',
              onPressed: _printCv,
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Télécharger',
              onPressed: _downloadCv,
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Partager',
              onPressed: _shareCv,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 1.0,
                maxScale: 4.0,
                child: PdfPreview(
                  key: ValueKey('${_currentCv.templateId}_${_currentCv.primaryColor}_${_currentCv.secondaryColor}_${_currentCv.personalInfo.profileImageUrl}_${_currentCv.personalInfo.showAvatar}'),
                  build: (format) => CvPdfGenerator.generateCvPdf(_currentCv),
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  useActions: true,
                  allowPrinting: false,
                  allowSharing: false,
                  onError: (context, error) {
                    return const Center(
                      child: Text('Aperçu du CV indisponible'),
                    );
                  },
                ),
              ),
            ),
            if (_canEdit)
              _buildTemplateSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateSelector() {
    final templates = CvPdfGenerator.availableTemplates;
    final primaryThemeColor = _parseColor(_currentCv.primaryColor);

    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 24, left: 8, right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Choisir un modèle
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Choisir un modèle',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: templates.map((template) {
                final isSelected = _currentCv.templateId == template.id;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentCv = _currentCv.copyWith(templateId: template.id);
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryThemeColor.withOpacity(0.08) : Colors.grey.shade50,
                      border: Border.all(
                        color: isSelected ? primaryThemeColor : Colors.grey.shade200,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _getTemplateIcon(template.id),
                          color: isSelected ? primaryThemeColor : Colors.grey.shade500,
                          size: 26,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          template.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? primaryThemeColor : Colors.grey.shade700,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Couleur principale
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Couleur principale (Titres)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._primaryPresets.map((preset) {
                  final hexColor = preset['hex']!;
                  final isSelected = _currentCv.primaryColor == hexColor;
                  final color = _parseColor(hexColor);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentCv = _currentCv.copyWith(primaryColor: hexColor);
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.grey.shade300,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => _showCustomColorPicker(true),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: !_isPrimaryPreset(_currentCv.primaryColor) ? Colors.black : Colors.grey.shade300,
                        width: !_isPrimaryPreset(_currentCv.primaryColor) ? 3 : 1,
                      ),
                    ),
                    child: !_isPrimaryPreset(_currentCv.primaryColor)
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: _parseColor(_currentCv.primaryColor),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const Icon(Icons.check, color: Colors.white, size: 12),
                            ],
                          )
                        : const Icon(Icons.colorize, color: Colors.grey, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 3: Couleur secondaire
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Couleur secondaire (Détails)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._secondaryPresets.map((preset) {
                  final hexColor = preset['hex']!;
                  final isSelected = _currentCv.secondaryColor == hexColor;
                  final color = _parseColor(hexColor);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentCv = _currentCv.copyWith(secondaryColor: hexColor);
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.grey.shade300,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => _showCustomColorPicker(false),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: !_isSecondaryPreset(_currentCv.secondaryColor) ? Colors.black : Colors.grey.shade300,
                        width: !_isSecondaryPreset(_currentCv.secondaryColor) ? 3 : 1,
                      ),
                    ),
                    child: !_isSecondaryPreset(_currentCv.secondaryColor)
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: _parseColor(_currentCv.secondaryColor),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const Icon(Icons.check, color: Colors.white, size: 12),
                            ],
                          )
                        : const Icon(Icons.colorize, color: Colors.grey, size: 16),
                  ),
                ),
              ],
            ),
          ),
          
          // Section 4: Photo de profil
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                const Text(
                  'Photo de profil',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Text('Afficher', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 4),
                Switch.adaptive(
                  value: _currentCv.personalInfo.showAvatar,
                  activeColor: const Color(0xFFF97316),
                  onChanged: (val) {
                    setState(() {
                      _currentCv = _currentCv.copyWith(
                        personalInfo: _currentCv.personalInfo.copyWith(showAvatar: val),
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                if (_currentCv.personalInfo.profileImageUrl != null && _currentCv.personalInfo.profileImageUrl!.isNotEmpty) ...[
                  GestureDetector(
                    onTap: _showPhotoOptionsBottomSheet,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.network(
                        _currentCv.personalInfo.profileImageUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.person, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _showPhotoOptionsBottomSheet,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Modifier', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF97316),
                      side: const BorderSide(color: Color(0xFFF97316)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ] else ...[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Icon(Icons.person_outline, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isUploadingPhoto ? null : _showPhotoOptionsBottomSheet,
                    icon: _isUploadingPhoto
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.upload_file_rounded, size: 16),
                    label: const Text('Ajouter une photo', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _renameCvDialog() async {
    final textController = TextEditingController(text: _currentCv.displayTitle);
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
      if (newTitle == _currentCv.displayTitle) return;

      setState(() {
        _currentCv = _currentCv.copyWith(title: newTitle);
      });
    }
  }

  Future<Uint8List?> _showCropDialog(Uint8List imageBytes) async {
    return await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final cropController = CropController();
        bool isCropping = false;
        
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                title: const Text('Recadrer la photo'),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  if (!isCropping)
                    TextButton(
                      onPressed: () {
                        setStateDialog(() => isCropping = true);
                        cropController.crop();
                      },
                      child: const Text(
                        'Valider',
                        style: TextStyle(
                          color: Color(0xFFF97316),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFF97316),
                        ),
                      ),
                    ),
                ],
              ),
              body: Column(
                children: [
                  Expanded(
                    child: Crop(
                      image: imageBytes,
                      controller: cropController,
                      onCropped: (cropped) {
                        Navigator.pop(context, cropped);
                      },
                      aspectRatio: 1.0,
                      withCircleUi: true,
                      interactive: true,
                      fixCropRect: false,
                      cornerDotBuilder: (size, edgeAlignment) => Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: const Color(0xFFF97316), width: 2.5),
                        ),
                      ),
                      maskColor: Colors.black.withOpacity(0.8),
                      baseColor: Colors.black,
                    ),
                  ),
                  Container(
                    color: Colors.black,
                    padding: const EdgeInsets.only(bottom: 32.0, top: 16.0, left: 16.0, right: 16.0),
                    child: const Text(
                      'Pincez pour zoomer et déplacez pour ajuster la photo',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool _isUploadingPhoto = false;

  Future<void> _showPhotoOptionsBottomSheet() async {
    final hasPhoto = _currentCv.personalInfo.profileImageUrl != null &&
        _currentCv.personalInfo.profileImageUrl!.isNotEmpty;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  'Modifier la photo de profil',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Colors.black87),
                title: const Text('Prendre une photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Colors.black87),
                title: const Text('Choisir depuis la galerie'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadPhoto(ImageSource.gallery);
                },
              ),
              if (hasPhoto) ...[
                ListTile(
                  leading: const Icon(Icons.crop_outlined, color: Colors.black87),
                  title: const Text('Recadrer la photo actuelle'),
                  onTap: () {
                    Navigator.pop(context);
                    _recropCurrentPhoto();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Supprimer la photo', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _removePhoto();
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      
      // Dialogue de recadrage
      final croppedBytes = await _showCropDialog(bytes);
      if (croppedBytes == null) return; // L'utilisateur a annulé

      await _uploadPhotoBytes(croppedBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _recropCurrentPhoto() async {
    final imageUrl = _currentCv.personalInfo.profileImageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return;

    setState(() => _isUploadingPhoto = true);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Téléchargement de la photo actuelle...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        
        setState(() => _isUploadingPhoto = false);

        // Dialogue de recadrage
        final croppedBytes = await _showCropDialog(bytes);
        if (croppedBytes == null) return; // Annulé

        await _uploadPhotoBytes(croppedBytes);
      } else {
        throw Exception('Code statut: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isUploadingPhoto = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec du téléchargement de la photo : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadPhotoBytes(Uint8List croppedBytes) async {
    setState(() => _isUploadingPhoto = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      Uint8List bytes = croppedBytes;
      var extension = 'png'; // L'image recadrée par crop_your_image est toujours en PNG/JPEG.
      
      // Valider que le format de l'image est compatible avec le moteur PDF
      pw.MemoryImage? memoryImage;
      try {
        memoryImage = pw.MemoryImage(bytes);
      } catch (e) {
        debugPrint('[CV Avatar Upload] Format potentiellement incompatible avec pw.MemoryImage: $e. Tentative de conversion native...');
        try {
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          final uiImage = frame.image;
          final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            bytes = byteData.buffer.asUint8List();
            memoryImage = pw.MemoryImage(bytes);
            extension = 'png'; // L'image a été convertie avec succès en PNG standard
            debugPrint('[CV Avatar Upload] Conversion native réussie en PNG !');
          } else {
            throw Exception('Échec de la sérialisation de l\'image convertie.');
          }
        } catch (convError) {
          debugPrint('[CV Avatar Upload] Échec de la conversion native : $convError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Format d\'image non supporté par le moteur PDF (veuillez utiliser une image PNG ou JPG standard).'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() => _isUploadingPhoto = false);
          return;
        }
      }
      
      // Normaliser l'extension pour des types MIME corrects
      if (extension == 'heic' || extension == 'heif') {
        extension = 'jpg';
      }
      
      // Déterminer le content-type correct
      String contentType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'png':
          contentType = 'image/png';
          break;
        case 'webp':
          contentType = 'image/webp';
          break;
        default:
          contentType = 'image/png';
          extension = 'png';
      }
      
      final fileName = '${user.id}_avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = 'avatars/$fileName';

      debugPrint('[CV Avatar Upload] Extension: $extension, ContentType: $contentType, Taille: ${bytes.length} octets');

      await supabase.storage.from('cv_files').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          contentType: contentType,
          upsert: true,
        ),
      );

      final String publicUrl = supabase.storage.from('cv_files').getPublicUrl(filePath);
      debugPrint('[CV Avatar Upload] URL publique générée: $publicUrl');

      // Pré-remplir le cache mémoire pour éviter un re-téléchargement réseau
      CvTemplateBase.avatarCache[publicUrl] = memoryImage;

      setState(() {
        _currentCv = _currentCv.copyWith(
          personalInfo: _currentCv.personalInfo.copyWith(
            profileImageUrl: publicUrl,
            showAvatar: true,
          ),
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo téléchargée avec succès !'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'upload de la photo : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _currentCv = _currentCv.copyWith(
        personalInfo: _currentCv.personalInfo.copyWith(
          profileImageUrl: '',
          showAvatar: false,
        ),
      );
    });
  }
}
