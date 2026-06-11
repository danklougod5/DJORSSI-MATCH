import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class CvSpeechDictationSheet extends StatefulWidget {
  const CvSpeechDictationSheet({super.key});

  @override
  State<CvSpeechDictationSheet> createState() => _CvSpeechDictationSheetState();
}

class _CvSpeechDictationSheetState extends State<CvSpeechDictationSheet> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  bool _hasPermission = true;
  String _transcribedText = "";
  double _soundLevel = 0.0;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _initSpeechRecognition();
  }

  Future<void> _initSpeechRecognition() async {
    try {
      bool available = await _speech.initialize(
        onError: (val) {
          debugPrint('SpeechToText error: ${val.errorMsg}');
          setState(() {
            _isListening = false;
            if (val.errorMsg.contains('error_permission') || val.errorMsg.contains('permission')) {
              _hasPermission = false;
              _errorMessage = "Permission d'accès au micro refusée.";
            } else {
              _errorMessage = "Erreur : ${val.errorMsg}";
            }
          });
        },
        onStatus: (val) {
          debugPrint('SpeechToText status: $val');
          setState(() {
            _isListening = _speech.isListening;
          });
        },
      );

      if (mounted) {
        setState(() {
          _isInitialized = available;
          _hasPermission = true;
        });

        if (available) {
          _startListening();
        } else {
          setState(() {
            _errorMessage = "La reconnaissance vocale n'est pas disponible sur cet appareil.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _hasPermission = false;
          _errorMessage = "Erreur d'initialisation : $e";
        });
      }
    }
  }

  void _startListening() async {
    if (!_isInitialized) return;

    setState(() {
      _errorMessage = "";
      _transcribedText = "";
    });

    // Retrieve default system locale or fallback to French (fr_FR)
    String localeId = 'fr_FR';
    try {
      final systemLocale = await _speech.systemLocale();
      if (systemLocale != null && systemLocale.localeId.toLowerCase().startsWith('fr')) {
        localeId = systemLocale.localeId;
      }
    } catch (_) {}

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _transcribedText = result.recognizedWords;
        });
      },
      listenFor: const Duration(minutes: 10),
      pauseFor: const Duration(seconds: 10),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        localeId: localeId,
        partialResults: true,
        autoPunctuation: true,
      ),
      onSoundLevelChange: (level) {
        setState(() {
          _soundLevel = level;
        });
      },
    );

    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
      _soundLevel = 0.0;
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFF97316); // Orange theme
    const darkTextColor = Color(0xFF0F172A);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Dictée vocale",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkTextColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Transcribed text display / status area
          Container(
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: _errorMessage.isNotEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        if (!_hasPermission) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              _initSpeechRecognition();
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text("Réessayer"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ]
                      ],
                    )
                  : _transcribedText.isEmpty
                      ? Text(
                          _isListening
                              ? "Parlez maintenant, l'application écoute..."
                              : "Appuyez sur le microphone pour commencer à parler...",
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                          ),
                        )
                      : Text(
                          _transcribedText,
                          style: const TextStyle(
                            color: darkTextColor,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
            ),
          ),
          const SizedBox(height: 24),

          // Voice Wave Animation and Microphone Button
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Wave ripple 2
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: _isListening ? 96 + (_soundLevel.clamp(0.0, 10.0) * 6) : 0,
                  height: _isListening ? 96 + (_soundLevel.clamp(0.0, 10.0) * 6) : 0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: 0.1),
                  ),
                ),
                // Wave ripple 1
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: _isListening ? 76 + (_soundLevel.clamp(0.0, 10.0) * 4) : 0,
                  height: _isListening ? 76 + (_soundLevel.clamp(0.0, 10.0) * 4) : 0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                // Microphone button
                GestureDetector(
                  onTap: () {
                    if (_isListening) {
                      _stopListening();
                    } else {
                      _startListening();
                    }
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? primaryColor : Colors.grey.shade200,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? primaryColor : Colors.black).withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.white : Colors.grey.shade700,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _isListening ? "Écoute en cours..." : "Reconnaissance en pause",
              style: TextStyle(
                color: _isListening ? primaryColor : Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _transcribedText.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _transcribedText = "";
                          });
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(color: _transcribedText.isEmpty ? Colors.grey.shade300 : Colors.redAccent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Réinitialiser"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _transcribedText.trim().isEmpty
                      ? null
                      : () {
                          Navigator.pop(context, _transcribedText.trim());
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade400,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Insérer le texte"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
