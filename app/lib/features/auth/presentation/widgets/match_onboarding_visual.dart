import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MatchOnboardingVisual extends StatefulWidget {
  const MatchOnboardingVisual({super.key});

  @override
  State<MatchOnboardingVisual> createState() => _MatchOnboardingVisualState();
}

class _MatchOnboardingVisualState extends State<MatchOnboardingVisual>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _pulseController;
  late AnimationController _entranceController;

  late Animation<double> _float1;
  late Animation<double> _float2;
  late Animation<double> _pulseScale;
  late Animation<double> _entranceScale;
  late Animation<double> _entranceOpacity;

  @override
  void initState() {
    super.initState();

    // Floating Animation Controller (4s)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _float1 = Tween<double>(begin: 0.0, end: -12.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Second floating animation (delayed/offset)
    _float2 = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 12.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: 0.0), weight: 50),
    ]).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Pulsing Animation Controller (2s)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Entrance Animation Controller (1s)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _entranceScale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _entranceOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pulseController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entranceOpacity,
      child: ScaleTransition(
        scale: _entranceScale,
        child: Container(
          width: 300.w,
          height: 300.w,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40.r),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 50,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background Gradient
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40.r),
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      const Color(0xFFFF5722).withOpacity(0.05),
                      Colors.transparent,
                      const Color(0xFF217336).withOpacity(0.05),
                    ],
                  ),
                ),
              ),

              // Profile Card (Candidate) - Top Left
              AnimatedBuilder(
                animation: _float1,
                builder: (context, child) {
                  return Positioned(
                    top: 50.h + _float1.value,
                    left: 20.w,
                    child: _buildMiniCard(
                      icon: Icons.person,
                      color: const Color(0xFFFF5722),
                      width: 160.w,
                    ),
                  );
                },
              ),

              // Job Card (Recruiter) - Bottom Right
              AnimatedBuilder(
                animation: _float2,
                builder: (context, child) {
                  return Positioned(
                    bottom: 50.h + _float2.value,
                    right: 20.w,
                    child: _buildMiniCard(
                      icon: Icons.work,
                      color: const Color(0xFF217336),
                      width: 160.w,
                      isReverse: true,
                    ),
                  );
                },
              ),

              // Match Badge
              ScaleTransition(
                scale: _pulseScale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30.r),
                        border: Border.all(color: const Color(0xFFFF5722), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5722).withOpacity(0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite, color: const Color(0xFFFF5722), size: 24.r),
                          SizedBox(width: 8.w),
                          Text(
                            'MATCH !',
                            style: TextStyle(
                              color: const Color(0xFFFF5722),
                              fontWeight: FontWeight.w900,
                              fontSize: 18.sp,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF217336),
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.send, color: Colors.white, size: 12.r),
                          SizedBox(width: 6.w),
                          Text(
                            'POSTULATION ENVOYÉE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10.sp,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Connecting Line (SVG Path approximation)
              CustomPaint(
                size: Size(300.w, 300.w),
                painter: ConnectionPainter(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniCard({
    required IconData icon,
    required Color color,
    required double width,
    bool isReverse = false,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: isReverse ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isReverse) _buildIcon(icon, color),
          if (!isReverse) SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: isReverse ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                height: 8.h,
                width: 60.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              SizedBox(height: 6.h),
              Container(
                height: 6.h,
                width: 40.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(3.r),
                ),
              ),
            ],
          ),
          if (isReverse) SizedBox(width: 12.w),
          if (isReverse) _buildIcon(icon, color),
        ],
      ),
    );
  }

  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      width: 40.w,
      height: 40.w,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20.r),
    );
  }
}

class ConnectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF5722).withOpacity(0.1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.3, size.height * 0.4);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.5,
      size.width * 0.7,
      size.height * 0.6,
    );

    // Draw dashed line
    var dashWidth = 5.0;
    var dashSpace = 3.0;
    double distance = 0.0;
    for (var i = 0; i < 10; i++) {
      // Very simple dashed line approximation for the curve
    }
    
    // For simplicity, just drawing the path as a light solid line or dots
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
