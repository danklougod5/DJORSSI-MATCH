import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:djossimatch/core/routing/app_router.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      // 1. Demander la permission (essentiel sur iOS)
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 2. Configurer les notifications locales pour le premier plan
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _handleNotificationRoute(payload);
          }
        },
      );

      // 3. Créer le canal Android pour les notifications à haute importance
      if (Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'high_importance_channel',
          'Notifications Importantes',
          description: 'Ce canal est utilisé pour les notifications importantes.',
          importance: Importance.max,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) print('User granted permission');
        
        await updateToken();

        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          _saveTokenToSupabase(newToken);
        });

        // 4. Gérer les messages quand l'app est au premier plan
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          RemoteNotification? notification = message.notification;
          AndroidNotification? android = message.notification?.android;
          final jobId = message.data['job_id'];

          if (notification != null && !kIsWeb) {
            _localNotifications.show(
              notification.hashCode,
              notification.title,
              notification.body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  'high_importance_channel',
                  'Notifications Importantes',
                  channelDescription: 'Ce canal est utilisé pour les notifications importantes.',
                  icon: android?.smallIcon ?? '@mipmap/ic_launcher',
                  importance: Importance.max,
                  priority: Priority.high,
                ),
                iOS: const DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
              payload: jobId,
            );
          }
        });

        // 5. Gérer les messages quand l'utilisateur clique sur la notification (App en arrière-plan)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          final jobId = message.data['job_id'];
          if (jobId != null) {
            _handleNotificationRoute(jobId);
          }
        });

        // 6. Gérer les messages quand l'app est fermée et s'ouvre via la notification
        _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
          if (message != null) {
            final jobId = message.data['job_id'];
            if (jobId != null) {
              Future.delayed(const Duration(milliseconds: 800), () {
                _handleNotificationRoute(jobId);
              });
            }
          }
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error initializing notifications: $e');
    }
  }

  static void _handleNotificationRoute(String jobId) {
    if (kDebugMode) print('NotificationService: Navigating to job $jobId');
    try {
      AppRouter.router.go('/?tab=swipe&job_id=$jobId');
    } catch (e) {
      if (kDebugMode) print('NotificationService: Error navigating: $e');
    }
  }


  static Future<void> updateToken() async {
    if (kDebugMode) print('NotificationService: Updating token...');
    String? token;
    try {
      if (Platform.isIOS) {
        // Wait for APNS token to be available
        String? apnsToken;
        int retries = 0;
        while (apnsToken == null && retries < 10) {
          apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken == null) {
            await Future.delayed(const Duration(seconds: 1));
            retries++;
            if (kDebugMode) print('NotificationService: Waiting for APNS token... (retry $retries)');
          }
        }
        if (apnsToken == null) {
          if (kDebugMode) print('NotificationService: Failed to get APNS token after 10 attempts');
          return;
        } else {
          if (kDebugMode) print('NotificationService: APNS token found: $apnsToken');
        }
      }

      token = await _firebaseMessaging.getToken();

      if (token != null) {
        if (kDebugMode) print('NotificationService: Token found: $token');
        await _saveTokenToSupabase(token);
      }
    } catch (e) {
      if (kDebugMode) print('NotificationService: Error getting token: $e');
    }
  }

  static Future<void> _saveTokenToSupabase(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', user.id);
      } catch (e) {
        if (kDebugMode) print('Error saving token to Supabase: $e');
      }
    }
  }
}
