import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SwipeOnboardingVisual extends StatefulWidget {
  const SwipeOnboardingVisual({super.key});

  @override
  State<SwipeOnboardingVisual> createState() => _SwipeOnboardingVisualState();
}

class _SwipeOnboardingVisualState extends State<SwipeOnboardingVisual>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Swipe animations
  late Animation<double> _swipeTranslateX;
  late Animation<double> _swipeRotation;

  // Feedback animations (Heart/Cross)
  late Animation<double> _heartOpacity;
  late Animation<double> _heartScale;
  late Animation<double> _crossOpacity;
  late Animation<double> _crossScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Swipe Gesture Animation
    _swipeTranslateX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 60.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 60.0, end: 0.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -60.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -60.0, end: 0.0), weight: 25),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 5),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _swipeRotation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 15.0 * math.pi / 180),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 15.0 * math.pi / 180, end: 0.0),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -15.0 * math.pi / 180),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -15.0 * math.pi / 180, end: 0.0),
        weight: 25,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 5),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Heart Pop (Match) - Syncs with right swipe (around 20%)
    _heartOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 5),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 55),
    ]).animate(_controller);

    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.5), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.5), weight: 5),
      TweenSequenceItem(tween: ConstantTween(1.5), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 0.5), weight: 10),
      TweenSequenceItem(tween: ConstantTween(0.5), weight: 55),
    ]).animate(_controller);

    // Cross Pop (Pass) - Syncs with left swipe (around 70%)
    _crossOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 5),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 5),
    ]).animate(_controller);

    _crossScale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.5), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.5), weight: 5),
      TweenSequenceItem(tween: ConstantTween(1.5), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 0.5), weight: 10),
      TweenSequenceItem(tween: ConstantTween(0.5), weight: 5),
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
      width: 300.w,
      height: 300.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Gradient/Visual
          Container(
            width: 260.w,
            height: 320.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFEC5B13).withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(24.r),
            ),
          ),

          // Animated Card
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_swipeTranslateX.value.w, 0),
                child: Transform.rotate(
                  angle: _swipeRotation.value,
                  child: _buildJobCard(),
                ),
              );
            },
          ),

          // Feedback Icons (Heart)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _heartOpacity.value,
                child: Transform.scale(
                  scale: _heartScale.value,
                  child: Icon(
                    Icons.favorite,
                    color: Colors.green,
                    size: 80.r,
                  ),
                ),
              );
            },
          ),

          // Feedback Icons (Cross)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _crossOpacity.value,
                child: Transform.scale(
                  scale: _crossScale.value,
                  child: Icon(
                    Icons.close,
                    color: Colors.red,
                    size: 80.r,
                  ),
                ),
              );
            },
          ),

          // Hand Gesture (Pulse)
          Positioned(
            bottom: 40.h,
            child: _buildHandGesture(),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard() {
    return Container(
      width: 200.w,
      height: 250.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Image Placeholder
          Container(
            height: 100.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Icon(
              Icons.business,
              color: const Color(0xFFCBD5E1),
              size: 40.r,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12.h,
                  width: 120.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  height: 8.h,
                  width: 80.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Container(
                      height: 24.h,
                      width: 50.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC5B13).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      height: 24.h,
                      width: 50.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC5B13).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
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

  Widget _buildHandGesture() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.2),
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Column(
            children: [
              Icon(
                Icons.touch_app,
                color: const Color(0xFFEC5B13),
                size: 60.r,
              ),
              const SizedBox(height: 8),
              Container(
                width: 100,
                height: 4,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.green],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        );
      },
      onEnd: () {
        // This is just for the hand pulse, the main controller handles the swipe
      },
    );
  }
}
