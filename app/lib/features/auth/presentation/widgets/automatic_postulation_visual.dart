import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AutomaticPostulationVisual extends StatefulWidget {
  const AutomaticPostulationVisual({super.key});

  @override
  State<AutomaticPostulationVisual> createState() => _AutomaticPostulationVisualState();
}

class _AutomaticPostulationVisualState extends State<AutomaticPostulationVisual>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Card animations
  late Animation<double> _cardTranslateX;
  late Animation<double> _cardRotation;
  late Animation<double> _cardOpacity;

  // Icon animations
  late Animation<double> _pop1Scale;
  late Animation<double> _pop1Opacity;
  late Animation<double> _pop2Scale;
  late Animation<double> _pop2Opacity;
  late Animation<double> _pop3Scale;
  late Animation<double> _pop3Opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Swipe Card Animation (Matches CSS animate-swipe-card)
    _cardTranslateX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: -60.0, end: 0.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 80.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(80.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _cardRotation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: -10.0 * math.pi / 180, end: 6.0 * math.pi / 180),
        weight: 15,
      ),
      TweenSequenceItem(tween: ConstantTween(6.0 * math.pi / 180), weight: 55),
      TweenSequenceItem(
        tween: Tween(begin: 6.0 * math.pi / 180, end: 25.0 * math.pi / 180),
        weight: 15,
      ),
      TweenSequenceItem(tween: ConstantTween(25.0 * math.pi / 180), weight: 15),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _cardOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 15),
    ]).animate(_controller);

    // Pop Icons (Matches CSS popIcon)
    _pop1Scale = _createPopScaleTween(0.0);
    _pop1Opacity = _createPopOpacityTween(0.0);

    _pop2Scale = _createPopScaleTween(0.1);
    _pop2Opacity = _createPopOpacityTween(0.1);

    _pop3Scale = _createPopScaleTween(0.2);
    _pop3Opacity = _createPopOpacityTween(0.2);
  }

  Animation<double> _createPopScaleTween(double delay) {
    return TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.5), weight: (delay * 100).toInt() + 10),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.1), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 10),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 20),
    ]).animate(_controller);
  }

  Animation<double> _createPopOpacityTween(double delay) {
    return TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: (delay * 100).toInt() + 10),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 20),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280.w,
      height: 280.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Decorative Background Circles
          Container(
            width: 280.w,
            height: 280.w,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5722).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 220.w,
            height: 220.w,
            decoration: BoxDecoration(
              color: const Color(0xFF1B6D24).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),

          // Animated CV Card
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _cardOpacity.value,
                child: Transform.translate(
                  offset: Offset(_cardTranslateX.value.w, 0),
                  child: Transform.rotate(
                    angle: _cardRotation.value,
                    child: _buildCVCard(),
                  ),
                ),
              );
            },
          ),

          // Floating Icons
          _buildFloatingIcon(
            icon: Icons.description,
            color: const Color(0xFFB02F00),
            top: 40.h,
            right: 20.w,
            scale: _pop1Scale,
            opacity: _pop1Opacity,
          ),
          _buildFloatingIcon(
            icon: Icons.mail,
            color: const Color(0xFF1B6D24),
            bottom: 60.h,
            right: 10.w,
            scale: _pop2Scale,
            opacity: _pop2Opacity,
          ),
          _buildFloatingIcon(
            icon: Icons.local_fire_department,
            color: const Color(0xFFFF5722),
            top: 20.h,
            left: 20.w,
            isFire: true,
            scale: _pop3Scale,
            opacity: _pop3Opacity,
          ),
        ],
      ),
    );
  }

  Widget _buildCVCard() {
    return Container(
      width: 140.w,
      height: 180.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB02F00).withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(10, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E2E5)),
      ),
      child: Column(
        children: [
          // African Pattern Header
          Container(
            height: 60.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFB02F00),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
            ),
            child: CustomPaint(
              painter: AfricanPatternPainter(),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 8.h,
                  width: 80.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E8EA),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  height: 6.h,
                  width: 50.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEF0),
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Container(
                      height: 16.h,
                      width: 40.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFA0F399).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Container(
                      height: 16.h,
                      width: 40.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFA0F399).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingIcon({
    required IconData icon,
    required Color color,
    double? top,
    double? bottom,
    double? left,
    double? right,
    bool isFire = false,
    required Animation<double> scale,
    required Animation<double> opacity,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: opacity.value,
            child: Transform.scale(
              scale: scale.value,
              child: Container(
                padding: EdgeInsets.all(isFire ? 8.r : 12.r),
                decoration: BoxDecoration(
                  color: isFire ? color : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: isFire ? null : Border.all(color: const Color(0xFFE4BEB4).withOpacity(0.5)),
                ),
                child: Icon(
                  icon,
                  color: isFire ? Colors.white : color,
                  size: isFire ? 24.r : 32.r,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AfricanPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 2;

    const spacing = 15.0;
    for (double i = -size.height; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
