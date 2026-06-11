import 'dart:async';
import 'package:flutter/material.dart';

class CvAiLoadingDialog extends StatefulWidget {
  final String title;
  final List<String> steps;

  const CvAiLoadingDialog({
    Key? key,
    required this.title,
    required this.steps,
  }) : super(key: key);

  @override
  State<CvAiLoadingDialog> createState() => _CvAiLoadingDialogState();
}

class _CvAiLoadingDialogState extends State<CvAiLoadingDialog>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startTimer();
  }

  void _startTimer() {
    // Transition through steps every 1.5 seconds.
    final duration = const Duration(milliseconds: 1500);
    _timer = Timer.periodic(duration, (timer) {
      if (!mounted) return;
      if (_currentStep < widget.steps.length - 1) {
        setState(() {
          _currentStep++;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFF97316); // Djorssi-Match primary orange

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing Magic Icon
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: primaryColor,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / widget.steps.length,
              backgroundColor: Colors.grey.shade100,
              valueColor: const AlwaysStoppedAnimation<Color>(primaryColor),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 20),
          // Animated checklist steps
          Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.steps.length, (index) {
              final stepText = widget.steps[index];
              final isDone = index < _currentStep;
              final isActive = index == _currentStep;

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
                iconColor = primaryColor;
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
        ],
      ),
    );
  }
}
