import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DjossiSwipeCard extends StatelessWidget {
  final String title;
  final String company;
  final String salary;
  final String? requiredLevel;
  final String? experience;
  final String? contactEmail;
  final String? whatsappNumber;
  final String? specialty;
  final String? contractType;
  final String? description;
  final bool isVerified;
  final List<String> tags;
  final String? deadline;
  final String location;

  const DjossiSwipeCard({
    super.key,
    required this.title,
    required this.company,
    required this.salary,
    required this.location,
    this.requiredLevel,
    this.experience,
    this.contactEmail,
    this.whatsappNumber,
    this.specialty,
    this.contractType,
    this.description,
    this.isVerified = false,
    this.tags = const [],
    this.deadline,
  });

  @override
  Widget build(BuildContext context) {
    // List of premium colors for the background
    final List<Color> backgroundColors = [
      const Color(0xFFF97316), // Orange
      const Color(0xFFEA580C), // Orange Foncé
      const Color(0xFFF59E0B), // Ambre
      const Color(0xFFD97706), // Ambre Foncé
      const Color(0xFFFB923C), // Orange Clair
      const Color(0xFFFACC15), // Jaune/Or
      const Color(0xFFE11D48), // Rose/Rouge (pour contraste mais proche orange)
      const Color(0xFFF43F5E), // Rose (pour contraste)
      const Color(0xFFC2410C), // Brique
    ];

    // Pick a color based on the title hash (consistent random)
    final Color bgColor = backgroundColors[title.hashCode % backgroundColors.length];

    return Card(
      elevation: 12,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      child: Stack(
        children: [
          // Background Color with Gradient
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  bgColor,
                  bgColor.withOpacity(0.8),
                  Colors.black.withOpacity(0.4),
                ],
              ),
            ),
          ),
          
          // Subtle Pattern or Overlay
          Positioned(
            top: -50.w,
            right: -50.w,
            child: Icon(
              Icons.work_outline,
              size: 250.r,
              color: Colors.white.withOpacity(0.05),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(24.0.r),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (deadline != null)
                  Container(
                    margin: EdgeInsets.only(bottom: 12.h),
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 14.r, color: Colors.white),
                        SizedBox(width: 6.w),
                        Text(
                          'Expire le: $deadline',
                          style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                
                if (isVerified) const SizedBox.shrink(),
                
                // Main content column wrapped in a Scrollable to avoid overflows
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start, // Changed to start for scrollable content
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 100), // Spacer for top-left icons padding
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28.sp,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          company,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (specialty != null && specialty != "Non spécifié")
                          Padding(
                            padding: EdgeInsets.only(top: 4.h),
                            child: Text(
                              specialty!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14.sp,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        
                        SizedBox(height: 20.h),
                        
                        // Job Details Badges
                        Wrap(
                          spacing: 10.w,
                          runSpacing: 10.h,
                          children: [
                            if (contractType != null && contractType != "Non spécifié")
                              _buildDetailBadge(
                                Icons.description_outlined,
                                contractType!,
                                color: Colors.orange.shade300,
                              ),
                            _buildDetailBadge(
                              Icons.history, 
                              experience ?? "Expérience non spécifiée"
                            ),
                            _buildDetailBadge(
                              Icons.school, 
                              requiredLevel ?? "Niveau non spécifié"
                            ),
                            if (contactEmail != null && contactEmail!.isNotEmpty)
                              _buildDetailBadge(Icons.email_outlined, contactEmail!),
                            if (whatsappNumber != null && whatsappNumber!.isNotEmpty)
                              _buildDetailBadge(Icons.message_outlined, whatsappNumber!, color: Colors.green.shade300),
                          ],
                        ),
                        
                        if (description != null && description!.isNotEmpty) ...[
                          SizedBox(height: 20.h),
                          Container(
                            padding: EdgeInsets.all(16.r),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 14.r, color: Colors.white70),
                                    SizedBox(width: 8.w),
                                    Text(
                                      "RÉSUMÉ DU POSTE",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  description!,
                                  // Removed maxLines and overflow for scrollable content
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13.sp,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        SizedBox(height: 16.h),

                        if (tags.isNotEmpty) ...[
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: tags.map((tag) => _buildSimpleTag(tag)).toList(), // Removed .take(4)
                          ),
                          SizedBox(height: 20.h),
                        ],
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 16.h),

                // Bottom row with salary and location, changed to Wrap for responsiveness
                Wrap(
                  spacing: 12.w,
                  runSpacing: 8.h,
                  children: [
                    _buildInfoTag(Icons.payments_outlined, salary),
                    _buildInfoTag(Icons.location_on_outlined, location),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailBadge(IconData icon, String text, {Color? color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: (color ?? Colors.white).withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.r, color: color ?? Colors.white),
          SizedBox(width: 6.w),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleTag(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(100.r),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoTag(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Optimization for Wrap
        children: [
          Icon(icon, size: 16.r, color: Colors.white),
          SizedBox(width: 6.w),
          Flexible( // Use Flexible instead of Expanded inside Wrap/min rows
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
