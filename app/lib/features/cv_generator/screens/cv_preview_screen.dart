import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:djossimatch/core/services/profile_notifier.dart';
import 'package:file_picker/file_picker.dart';
import 'package:djossimatch/core/services/cv_quota_service.dart';
import '../models/cv_model.dart';
import '../utils/cv_pdf_generator.dart';

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
              child: PdfPreview(
                key: ValueKey('${_currentCv.templateId}_${_currentCv.primaryColor}_${_currentCv.secondaryColor}_${_currentCv.personalInfo.profileImageUrl}_${_currentCv.personalInfo.showAvatar}'),
                build: (format) => CvPdfGenerator.generateCvPdf(_currentCv),
                canChangeOrientation: false,
                canChangePageFormat: false,
                useActions: true,
                allowPrinting: false,
                allowSharing: false,
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
              children: _primaryPresets.map((preset) {
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
              }).toList(),
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
              children: _secondaryPresets.map((preset) {
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
              }).toList(),
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
                  ClipRRect(
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
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _uploadPhoto,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Changer', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF97316),
                      side: const BorderSide(color: Color(0xFFF97316)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: _removePhoto,
                    tooltip: 'Supprimer la photo',
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
                    onPressed: _isUploadingPhoto ? null : _uploadPhoto,
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

  bool _isUploadingPhoto = false;

  Future<void> _uploadPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;

      setState(() => _isUploadingPhoto = true);

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final bytes = result.files.first.bytes!;
      final extension = result.files.first.extension ?? 'png';
      final fileName = '${user.id}_avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = 'avatars/$fileName';

      await supabase.storage.from('cv_files').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          contentType: 'image/$extension',
          upsert: true,
        ),
      );

      final String publicUrl = supabase.storage.from('cv_files').getPublicUrl(filePath);

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
