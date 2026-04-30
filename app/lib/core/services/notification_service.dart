import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

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

      await _localNotifications.initialize(initializationSettings);

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
            );
          }
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error initializing notifications: $e');
    }
  }

  static Future<void> updateToken() async {
    if (kDebugMode) print('NotificationService: Updating token...');
    String? token;
    try {
      if (Platform.isIOS) {
        token = await _firebaseMessaging.getAPNSToken();
      } else {
        token = await _firebaseMessaging.getToken();
      }

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
