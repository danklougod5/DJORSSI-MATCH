import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
  final String? applicationLink;
  final bool requiresCoverLetter;
  final String? coverLetterInstructions;

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
    this.applicationLink,
    this.requiresCoverLetter = false,
    this.coverLetterInstructions,
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

    return RepaintBoundary(
      child: Card(
      elevation: 4,
      clipBehavior: Clip.hardEdge,
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
            padding: EdgeInsets.all(20.0.r),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top badges row
                if (deadline != null)
                  Container(
                    margin: EdgeInsets.only(bottom: 8.h),
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

                if (requiresCoverLetter)
                  Container(
                    margin: EdgeInsets.only(bottom: 8.h),
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                      ),
                      borderRadius: BorderRadius.circular(8.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_document, size: 14.r, color: Colors.white),
                        SizedBox(width: 6.w),
                        Text(
                          'Lettre requise',
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
                        const SizedBox(height: 70), // Spacer for top-left icons padding (Match badge)
                        Text(
                          title,
                          textScaler: const TextScaler.linear(1.0),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          company,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 16.sp,
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
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: [
                            if (contractType != null && contractType != "Non spécifié")
                              _buildDetailBadge(
                                Icons.description_outlined,
                                contractType!,
                                color: Colors.orange.shade300,
                              ),
                            if (experience != null && experience!.isNotEmpty)
                              _buildDetailBadge(
                                Icons.history, 
                                experience!
                              ),
                            _buildDetailBadge(
                              Icons.school, 
                              requiredLevel ?? "Niveau non spécifié"
                            ),
                            if (contactEmail != null && contactEmail!.isNotEmpty)
                              _buildDetailBadge(Icons.email_outlined, contactEmail!),
                            
                            if (whatsappNumber != null && whatsappNumber!.isNotEmpty)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366),
                                  borderRadius: BorderRadius.circular(10.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FaIcon(FontAwesomeIcons.whatsapp, size: 16.r, color: Colors.white),
                                    SizedBox(width: 6.w),
                                    Flexible(
                                      child: Text(
                                        _formatPhoneNumbers(whatsappNumber!),
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            if (applicationLink != null && applicationLink!.isNotEmpty)
                              _buildDetailBadge(
                                Icons.link, 
                                "Candidature via lien externe",
                                color: Colors.blue.shade300,
                              ),
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
                                    fontWeight: FontWeight.bold,
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

                        SizedBox(height: 16.h),
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
      ),
    );
  }

  String _formatPhoneNumbers(String raw) {
    if (raw.isEmpty) return raw;
    // On extrait tous les blocs de chiffres (au moins 8 chiffres)
    final Iterable<Match> matches = RegExp(r'\d{8,}').allMatches(raw.replaceAll(' ', ''));
    if (matches.isEmpty) return raw;
    
    return matches.map((m) => m.group(0)).join(' / ');
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
                fontSize: 11.sp,
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
          fontSize: 11.sp,
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
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
