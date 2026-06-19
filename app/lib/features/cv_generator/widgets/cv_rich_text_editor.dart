import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cv_ai_loading_dialog.dart';
import 'cv_speech_dictation_sheet.dart';

class CvRichTextEditor extends StatefulWidget {
  final String initialData;
  final ValueChanged<String> onSaved;
  final String hintText;
  final double minHeight;
  final String? labelText;

  const CvRichTextEditor({
    Key? key,
    required this.initialData,
    required this.onSaved,
    this.hintText = '',
    this.minHeight = 200,
    this.labelText,
  }) : super(key: key);

  @override
  State<CvRichTextEditor> createState() => _CvRichTextEditorState();
}

class _CvRichTextEditorState extends State<CvRichTextEditor> {
  late TextEditingController _controller;
  String _previousText = '';
  TextSelection _previousSelection = const TextSelection.collapsed(offset: 0);
  bool _isHandlingTextChange = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialData);
    _previousText = _controller.text;
    _previousSelection = _controller.selection;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_isHandlingTextChange) return;

    final currentText = _controller.text;
    final currentSelection = _controller.selection;

    // Detect if user typed a newline character '\n'
    if (currentText.length > _previousText.length && 
        currentSelection.isCollapsed && 
        _previousSelection.isValid && 
        _previousSelection.isCollapsed) {
      final int diffStart = _previousSelection.start;
      final int newCursor = currentSelection.start;
      
      if (diffStart >= 0 && newCursor >= 0 && newCursor <= currentText.length && diffStart <= newCursor) {
        if (currentText.substring(diffStart, newCursor) == '\n') {
          // A newline was inserted. Let's find the line that just ended.
          final textBeforeNewline = currentText.substring(0, diffStart);
          final lines = textBeforeNewline.split('\n');
          if (lines.isNotEmpty) {
            final lastLine = lines.last;
            
            // Check if the last line starts with a bullet point
            final match = RegExp(r'^(\s*•\s*)').firstMatch(lastLine);
            if (match != null) {
              final prefix = match.group(0)!;
              
              // If the bullet line is empty (contains only the bullet prefix or only space/bullet)
              final isPrefixOnly = lastLine == prefix || lastLine.trim() == '•';
              
              _isHandlingTextChange = true;
              if (isPrefixOnly) {
                // Remove the bullet and empty line prefix (stop bulleting)
                final bulletStartIndex = textBeforeNewline.lastIndexOf(lastLine);
                final newText = currentText.replaceRange(bulletStartIndex, newCursor, '');
                _controller.text = newText;
                _controller.selection = TextSelection.collapsed(offset: bulletStartIndex);
                widget.onSaved(newText);
              } else {
                // Auto-generate the next bullet point
                final newText = currentText.replaceRange(newCursor, newCursor, prefix);
                _controller.text = newText;
                _controller.selection = TextSelection.collapsed(offset: newCursor + prefix.length);
                widget.onSaved(newText);
              }
              _isHandlingTextChange = false;
            }
          }
        }
      }
    }

    _previousText = _controller.text;
    _previousSelection = _controller.selection;
  }

  void _startVoiceDictation() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CvSpeechDictationSheet(),
    );

    if (result != null && result.isNotEmpty) {
      final text = _controller.text;
      final selection = _controller.selection;
      
      int start = selection.start;
      int end = selection.end;
      
      if (start < 0 || end < 0) {
        start = text.length;
        end = text.length;
      }
      
      String prefix = "";
      if (start > 0 && !text.substring(start - 1, start).contains(RegExp(r'\s'))) {
        prefix = " ";
      }
      
      final replacement = '$prefix$result';
      final newText = text.replaceRange(start, end, replacement);
      
      setState(() {
        _controller.text = newText;
        _controller.selection = TextSelection.collapsed(offset: start + replacement.length);
      });
      widget.onSaved(newText);
    }
  }

  void _insertText(String prefix, [String suffix = '']) {
    final text = _controller.text;
    final selection = _controller.selection;
    
    int start = selection.start;
    int end = selection.end;
    
    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    final selectedText = text.substring(start, end);
    final replacement = '$prefix$selectedText$suffix';
    
    final newText = text.replaceRange(start, end, replacement);
    _controller.text = newText;
    
    // Set selection
    _controller.selection = TextSelection(
      baseOffset: start + prefix.length,
      extentOffset: start + prefix.length + selectedText.length,
    );
    widget.onSaved(newText);
  }

  void _insertNumberedList() {
    final text = _controller.text;
    final lines = text.split('\n');
    int count = 1;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (RegExp(r'^\d+\. ').hasMatch(lines[i])) {
        count = int.parse(lines[i].split('.').first) + 1;
        break;
      }
    }
    _insertText('$count. ');
  }

  Future<void> _simulateAIPolish() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez saisir du texte avant d'utiliser l'amélioration par IA."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CvAiLoadingDialog(
        title: "Optimisation de votre texte par l'IA",
        steps: [
          "Analyse de la structure du texte...",
          "Correction grammaticale et orthographe...",
          "Amélioration des verbes d'action...",
          "Formatage professionnel...",
        ],
      ),
    );

    try {
      String systemContent = 'Tu es un expert en recrutement et en rédaction de CV. Ton rôle est de reformuler, polir, corriger l\'orthographe et améliorer le texte de l\'utilisateur pour le rendre plus professionnel, percutant et adapté à un CV. ';
      
      if (widget.labelText != null) {
        systemContent += 'Le champ concerné est : "${widget.labelText}". ';
        if (widget.labelText!.toLowerCase().contains('compétence')) {
          systemContent += 'Propose une liste plate de compétences individuelles et précises, sans les regrouper par catégories, sans utiliser de deux-points (:) ou de parenthèses. Chaque compétence doit être courte, claire et être sur sa propre ligne précédée d\'une puce (•). Ne crée pas de sous-éléments. Corrige l\'orthographe des technologies ou termes techniques. ';
        } else if (widget.labelText!.toLowerCase().contains('expérience') || widget.labelText!.toLowerCase().contains('responsabilité')) {
          systemContent += 'Formate le contenu sous forme de liste à puces (•). Chaque puce doit impérativement commencer par un verbe d\'action fort (ex: "Concevoir", "Gérer", "Optimiser") ou un nom d\'action (ex: "Conception de...", "Gestion de...", "Optimisation de..."). Évite les tournures personnelles comme "Je" ou "Nous". Rend les phrases concises, percutantes et valorise les résultats et réalisations concrètes. ';
        } else if (widget.labelText!.toLowerCase().contains('projet')) {
          systemContent += 'Présente le projet sous forme de liste à puces (•) en décrivant l\'objectif global, ton rôle/responsabilités, les technologies utilisées, et les résultats ou bénéfices obtenus. ';
        } else if (widget.labelText!.toLowerCase().contains('formation') || widget.labelText!.toLowerCase().contains('mention')) {
          systemContent += 'Rends la description de la formation académique, précise et soignée. Formate sous forme de puces (•) si plusieurs éléments (options, cours clés, distinctions) sont mentionnés. ';
        }
      }
      
      systemContent += 'Conserve la même langue (Français). IMPORTANT : Si le texte original ou suggéré contient des puces (symboles •), conserve-les impérativement. Retourne UNIQUEMENT le texte corrigé et poli final, sans aucun commentaire ou texte d\'accompagnement.';

      final supabase = Supabase.instance.client;

      final response = await supabase.functions.invoke(
        'cv-ai-assist',
        body: {
          'action': 'polish_text',
          'text': text,
          'systemContent': systemContent,
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
          _controller.text = polishedText;
          _controller.selection = TextSelection.collapsed(offset: polishedText.length);
        });
        widget.onSaved(polishedText);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Texte amélioré avec succès par l'IA !"),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 0,
            children: [
              IconButton(
                icon: const Icon(Icons.format_bold, size: 20),
                tooltip: 'Gras',
                onPressed: () => _insertText('**', '**'),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
              IconButton(
                icon: const Icon(Icons.format_italic, size: 20),
                tooltip: 'Italique',
                onPressed: () => _insertText('_', '_'),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
              IconButton(
                icon: const Icon(Icons.format_underlined, size: 20),
                tooltip: 'Souligné',
                onPressed: () => _insertText('__', '__'),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
              IconButton(
                icon: const Icon(Icons.format_strikethrough, size: 20),
                tooltip: 'Barré',
                onPressed: () => _insertText('~~', '~~'),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
              Container(width: 1, height: 24, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 4)),
              IconButton(
                icon: const Icon(Icons.format_list_bulleted, size: 20),
                tooltip: 'Liste à puces',
                onPressed: () => _insertText('• '),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
              IconButton(
                icon: const Icon(Icons.format_list_numbered, size: 20),
                tooltip: 'Liste numérotée',
                onPressed: _insertNumberedList,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
              Container(width: 1, height: 24, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 4)),
              IconButton(
                icon: const Icon(Icons.link, size: 20),
                tooltip: 'Lien',
                onPressed: () => _insertText('[', '](url)'),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
              IconButton(
                icon: const Icon(Icons.mic, size: 20, color: Color(0xFF3B82F6)),
                tooltip: 'Dictée vocale',
                onPressed: _startVoiceDictation,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
              Container(width: 1, height: 24, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 4)),
              TextButton.icon(
                onPressed: _simulateAIPolish,
                icon: const Icon(Icons.auto_awesome, color: Color(0xFFF97316), size: 16),
                label: const Text("Améliorer par l'IA", style: TextStyle(color: Color(0xFFF97316), fontSize: 13)),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
        ),
        // Editor
        Container(
          constraints: BoxConstraints(minHeight: widget.minHeight),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(color: Colors.grey.shade300),
              right: BorderSide(color: Colors.grey.shade300),
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
          ),
          child: TextField(
            controller: _controller,
            maxLines: null,
            minLines: 5,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: widget.onSaved,
          ),
        ),
      ],
    );
  }
}
