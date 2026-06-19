import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../routing/app_router.dart';

class AnnouncementService {
  AnnouncementService._();
  static final AnnouncementService instance = AnnouncementService._();

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  bool _checkingAnnouncements = false;

  void initialize() {
    debugPrint('*** [ANNOUNCEMENT SERVICE] Initializing global announcement listener ***');
    // 1. Check for active announcements immediately on startup
    checkAndShowAnnouncement();

    // 2. Subscribe to real-time changes
    _channel = _supabase
        .channel('public:app_announcements')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_announcements',
          callback: (payload) {
            debugPrint('*** [REALTIME ANNOUNCEMENT SERVICE] Event: ${payload.eventType} ***');
            checkAndShowAnnouncement();
          },
        );
    _channel?.subscribe();
  }

  void dispose() {
    debugPrint('*** [ANNOUNCEMENT SERVICE] Disposing global announcement listener ***');
    _channel?.unsubscribe();
    _channel = null;
  }

  Future<void> checkAndShowAnnouncement() async {
    if (_checkingAnnouncements) return;
    _checkingAnnouncements = true;

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _checkingAnnouncements = false;
        return;
      }

      final response = await _supabase
          .from('app_announcements')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        _checkingAnnouncements = false;
        return;
      }

      final announcementId = response['id'].toString();
      final title = response['title'].toString();
      final message = response['message'].toString();
      final type = response['type'].toString(); // 'discount', 'update', 'info'
      final ctaLabel = response['cta_label']?.toString();
      final ctaUrl = response['cta_url']?.toString();

      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final prefKey = 'announcement_shows_${announcementId}_$todayStr';
      final currentShows = prefs.getInt(prefKey) ?? 0;

      if (currentShows < 2) {
        final context = AppRouter.navigatorKey.currentContext;
        if (context == null || !context.mounted) {
          debugPrint('*** [ANNOUNCEMENT SERVICE] Context not available or not mounted ***');
          _checkingAnnouncements = false;
          return;
        }

        // Increment count immediately to avoid double displays
        await prefs.setInt(prefKey, currentShows + 1);

        if (context.mounted) {
          _showAnnouncementDialog(
            context: context,
            id: announcementId,
            title: title,
            message: message,
            type: type,
            ctaLabel: ctaLabel,
            ctaUrl: ctaUrl,
          );
        }
      } else {
        debugPrint('*** [ANNOUNCEMENT SERVICE] Announcement $announcementId has already been shown $currentShows times today. ***');
      }
    } catch (e) {
      debugPrint('Erreur global check announcements: $e');
    } finally {
      _checkingAnnouncements = false;
    }
  }

  void _showAnnouncementDialog({
    required BuildContext context,
    required String id,
    required String title,
    required String message,
    required String type,
    String? ctaLabel,
    String? ctaUrl,
  }) {
    Color headerStartColor;
    Color headerEndColor;
    IconData headerIcon;
    Color ctaStartColor;
    Color ctaEndColor;

    if (type == 'discount') {
      headerStartColor = const Color(0xFFF59E0B); // Amber
      headerEndColor = const Color(0xFFE11D48); // Rose
      headerIcon = Icons.stars_rounded;
      ctaStartColor = const Color(0xFFF59E0B);
      ctaEndColor = const Color(0xFFE11D48);
    } else if (type == 'update') {
      headerStartColor = const Color(0xFF7C3AED); // Violet
      headerEndColor = const Color(0xFF2563EB); // Blue
      headerIcon = Icons.rocket_launch_rounded;
      ctaStartColor = const Color(0xFF7C3AED);
      ctaEndColor = const Color(0xFF2563EB);
    } else {
      headerStartColor = const Color(0xFF475569); // Slate
      headerEndColor = const Color(0xFF1E293B); // Dark Slate
      headerIcon = Icons.campaign_rounded;
      ctaStartColor = const Color(0xFF475569);
      ctaEndColor = const Color(0xFF1E293B);
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(
                parent: ModalRoute.of(context)!.animation!,
                curve: Curves.easeOutBack,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28.r),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with Gradient
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 20.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [headerStartColor, headerEndColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12.r),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              headerIcon,
                              color: Colors.white,
                              size: 40.r,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Body Content
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 24.w),
                      child: Column(
                        children: [
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFF334155), // Slate-700
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 24.h),
                          
                          // CTA Button
                          if (ctaLabel != null && ctaLabel.isNotEmpty) ...[
                            InkWell(
                              onTap: () async {
                                Navigator.pop(context);
                                if (ctaUrl != null && ctaUrl.isNotEmpty) {
                                  if (ctaUrl == '/premium') {
                                    context.push('/premium');
                                  } else if (ctaUrl.startsWith('http')) {
                                    final uri = Uri.parse(ctaUrl);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  } else {
                                    context.push(ctaUrl);
                                  }
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: 14.h),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16.r),
                                  gradient: LinearGradient(
                                    colors: [ctaStartColor, ctaEndColor],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: ctaStartColor.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    ctaLabel.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 12.h),
                          ],
                          
                          // Cancel/Close Button
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                  side: BorderSide(
                                    color: const Color(0xFFE2E8F0), // Slate-200
                                    width: 1.5.w,
                                  ),
                                ),
                              ),
                              child: Text(
                                'FERMER',
                                style: TextStyle(
                                  color: const Color(0xFF64748B), // Slate-500
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
