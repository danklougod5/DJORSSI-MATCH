import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:async';
import '../services/cv_ai_import_service.dart';
import '../models/cv_model.dart';

class CvLandingScreen extends StatefulWidget {
  final bool autoImport;
  final Uint8List? pdfBytes;
  
  const CvLandingScreen({
    Key? key,
    this.autoImport = false,
    this.pdfBytes,
  }) : super(key: key);

  @override
  State<CvLandingScreen> createState() => _CvLandingScreenState();
}

class _CvLandingScreenState extends State<CvLandingScreen> with TickerProviderStateMixin {
  bool _isProcessing = false;
  double _progress = 0.0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<String> _importSteps = [
    "Lecture et préparation du fichier PDF",
    "Extraction du texte brut du document",
    "Analyse de vos informations de contact",
    "Extraction de vos expériences professionnelles",
    "Classification des compétences & études",
    "Génération finale du modèle de CV",
  ];
  int _currentImportStep = 0;
  Timer? _importTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.pdfBytes != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAiImport(prePickedBytes: widget.pdfBytes);
      });
    } else if (widget.autoImport) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAiImport();
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _importTimer?.cancel();
    super.dispose();
  }

  void _startImportTimer() {
    _importTimer?.cancel();
    _importTimer = Timer.periodic(const Duration(milliseconds: 1600), (timer) {
      if (!mounted) return;
      setState(() {
        if (_currentImportStep < _importSteps.length - 2) {
          _currentImportStep++;
          _progress = 0.2 + (_currentImportStep * 0.13);
        } else {
          _importTimer?.cancel();
        }
      });
    });
  }

  Future<void> _handleAiImport({Uint8List? prePickedBytes}) async {
    final Uint8List bytes;
    if (prePickedBytes != null) {
      bytes = prePickedBytes;
    } else {
      // Step 1: Pick PDF file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
      bytes = result.files.first.bytes!;
    }

    setState(() {
      _isProcessing = true;
      _currentImportStep = 0;
      _progress = 0.05;
    });

    try {
      // Step 2: Extract text from PDF
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() {
        _currentImportStep = 1;
        _progress = 0.2;
      });

      final String rawText = CvAiImportService.extractTextFromPdf(bytes);

      if (rawText.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _progress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'extraire le texte de ce PDF. Le fichier est peut-être un scan/image. Essayez un PDF avec du texte sélectionnable.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 6),
          ),
        );
        return;
      }

      // Step 3: Analyze with AI
      _startImportTimer();

      final CvModel cvModel = await CvAiImportService.analyzeWithMistral(rawText);

      _importTimer?.cancel();

      setState(() {
        _currentImportStep = _importSteps.length - 1;
        _progress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _progress = 0.0;
      });

      // Navigate to template selection with pre-filled CvModel
      context.push('/cv_template_select', extra: cvModel);

    } catch (e) {
      _importTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _progress = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'analyse : ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Générateur de CV'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: _isProcessing ? _buildProcessingView() : _buildChoiceView(),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF97316),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF97316).withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Analyse intelligente en cours',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Extraction et structuration automatique de vos données...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF97316)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_importSteps.length, (index) {
                  final stepText = _importSteps[index];
                  final isDone = index < _currentImportStep;
                  final isActive = index == _currentImportStep;

                  Color iconColor;
                  IconData iconData;
                  TextStyle textStyle;

                  if (isDone) {
                    iconColor = Colors.green;
                    iconData = Icons.check_circle_rounded;
                    textStyle = TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    );
                  } else if (isActive) {
                    iconColor = const Color(0xFFF97316);
                    iconData = Icons.radio_button_checked_rounded;
                    textStyle = const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    );
                  } else {
                    iconColor = Colors.grey.shade300;
                    iconData = Icons.radio_button_off_rounded;
                    textStyle = TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            iconData,
                            color: iconColor,
                            size: 18,
                            key: ValueKey('$index-$isDone-$isActive'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: textStyle,
                            child: Text(stepText),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        // Header
        const Text(
          'Comment souhaitez-vous\ncréer votre CV ?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choisissez votre méthode de création',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 28),

        // ===== CARD 1: Import with AI =====
        _buildImportCard(),

        const SizedBox(height: 20),

        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OU',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                  letterSpacing: 1,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
          ],
        ),

        const SizedBox(height: 20),

        // ===== CARD 2: Manual creation =====
        _buildManualCard(),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildImportCard() {
    const Color accentColor = Color(0xFFF97316);

    return GestureDetector(
      onTap: _handleAiImport,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Importer mon CV',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'IA',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Uploadez votre CV existant (PDF)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'L\'intelligence artificielle analyse votre CV, extrait les informations et les reformate dans un template professionnel.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem('Upload de votre CV en PDF', accentColor),
                  _buildFeatureItem('Extraction automatique par IA', accentColor),
                  _buildFeatureItem('Pré-remplissage instantané', accentColor),
                  _buildFeatureItem('Choix du template & couleurs', accentColor),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handleAiImport,
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text('Importer un PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
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
  }

  Widget _buildManualCard() {
    const Color accentColor = Color(0xFF16A34A); // Green

    return GestureDetector(
      onTap: () => context.push('/cv_template_select'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Créer manuellement',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Remplissez vos informations pas à pas',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Créez votre CV de zéro en remplissant chaque section à votre rythme. Idéal si vous n\'avez pas encore de CV existant.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem('Formulaire guidé étape par étape', accentColor),
                  _buildFeatureItem('Aide IA pour polir votre texte', accentColor),
                  _buildFeatureItem('7 templates professionnels', accentColor),
                  _buildFeatureItem('Personnalisation des couleurs', accentColor),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/cv_template_select'),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Commencer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
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
  }

  Widget _buildFeatureItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
