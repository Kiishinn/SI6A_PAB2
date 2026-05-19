import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _baseUrl = 'https://notes-rest-api-ecru.vercel.app';
  static const String _topicName = 'notes';

  // VAPID key from Firebase Console > Project Settings > Cloud Messaging > Web Push certificates
  // TODO: Replace with your actual VAPID key from Firebase Console
  static const String _vapidKey = 'BI8gT1WcJ7NiCKe_C_GCzSGMwmceZ_h-irQ5h_AJCMRtgOtD9FWDqMy7HqFB2LiZnPIkJI8mdop9VTbdmu0tY34';

  /// Initialize FCM and Local Notifications
  Future<void> initialize() async {
    try {
      // 1. Request Permissions with timeout
      NotificationSettings? settings;
      try {
        settings = await _messaging
            .requestPermission(
              alert: true,
              badge: true,
              sound: true,
            )
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('FCM permission request timed out or failed: $e');
      }

      if (settings != null && settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted permission');
      } else {
        debugPrint('User declined, timed out, or has not accepted permission');
      }

      // 2. Initialize Local Notifications for Foreground (Mobile Only)
      if (!kIsWeb) {
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');

        const InitializationSettings initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: DarwinInitializationSettings(),
        );

        // Use dynamic to bypass strict compile-time checks on Web
        final dynamic localNotifications = _localNotificationsPlugin;

        await localNotifications.initialize(
          settings: initializationSettings,
          onDidReceiveNotificationResponse: (details) {
            debugPrint('Notification clicked: ${details.payload}');
          },
        );

        // 3. Create Android Notification Channel
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'This channel is used for important notifications.',
          importance: Importance.max,
        );

        await localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);

        // 4. Handle Foreground Messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Got a message in the foreground!');
          debugPrint('Message data: ${message.data}');

          RemoteNotification? notification = message.notification;
          
          if (notification != null) {
            debugPrint('Message also contained a notification: ${notification.title}');
            
            localNotifications.show(
              id: notification.hashCode,
              title: notification.title,
              body: notification.body,
              notificationDetails: NotificationDetails(
                android: AndroidNotificationDetails(
                  channel.id,
                  channel.name,
                  channelDescription: channel.description,
                  icon: '@mipmap/ic_launcher', // Use fixed icon for reliability
                  importance: Importance.max,
                  priority: Priority.high,
                ),
              ),
              payload: jsonEncode(message.data),
            );
          } else if (message.data.isNotEmpty) {
            // Handle data-only messages if they contain title/body
            final title = message.data['title'] ?? 'Catatan Baru';
            final body = message.data['body'] ?? 'Cek aplikasi Anda';
            
            localNotifications.show(
              id: message.hashCode,
              title: title,
              body: body,
              notificationDetails: NotificationDetails(
                android: AndroidNotificationDetails(
                  channel.id,
                  channel.name,
                  channelDescription: channel.description,
                  icon: '@mipmap/ic_launcher',
                  importance: Importance.max,
                  priority: Priority.high,
                ),
              ),
              payload: jsonEncode(message.data),
            );
          }
        });
      } else {
        // On Web, foreground messages are handled by the browser
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Foreground message on web: ${message.notification?.title}');
        });
      }

      // 5. Subscribe to topics (Mobile Only)
      if (!kIsWeb) {
        await _messaging.subscribeToTopic(_topicName).timeout(
          const Duration(seconds: 10),
          onTimeout: () => debugPrint('Subscription to topic $_topicName timed out'),
        );
        await _messaging.subscribeToTopic('berita').timeout(
          const Duration(seconds: 10),
          onTimeout: () => debugPrint('Subscription to topic berita timed out'),
        );
        debugPrint('Subscribed to topics: $_topicName and berita');
      }

      // 6. Get and print token for debugging (with timeout)
      String? token;
      try {
        if (kIsWeb) {
          token = await _messaging.getToken(vapidKey: _vapidKey).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              debugPrint('FCM Token request timed out');
              return null;
            },
          );
        } else {
          token = await _messaging.getToken().timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              debugPrint('FCM Token request timed out');
              return null;
            },
          );
        }
      } catch (e) {
        debugPrint('Error getting FCM token: $e');
      }
      if (token != null) {
        debugPrint('FCM Token: $token');
      }
    } catch (e) {
      debugPrint('Error during FcmService initialization: $e');
    }
  }

  /// Send notification via REST API when a note is added
  Future<void> sendNoteNotification({
    required String title,
    required String description,
  }) async {
    try {
      final now = DateTime.now();
      final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final response = await http.post(
        Uri.parse('$_baseUrl/send-to-topic'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topic': _topicName,
          'title': 'Catatan Baru: $title',
          'body': description,
          'data': {
            'senderName': 'User Notes',
            'senderPhoto': 'https://firebase.google.com/static/images/brand-guidelines/logo-vertical.png',
            'created_at': formattedDate,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'type': 'new_note',
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('Notification sent successfully');
      } else {
        debugPrint('Failed to send notification: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// Subscribe to a specific topic (Mobile Only)
  Future<bool> subscribeToTopic(String topic) async {
    if (kIsWeb) {
      debugPrint('Topic subscription is not supported on Web');
      return false;
    }
    try {
      await _messaging.subscribeToTopic(topic).timeout(
        const Duration(seconds: 10),
        onTimeout: () => debugPrint('Subscription to topic $topic timed out'),
      );
      debugPrint('Subscribed to topic: $topic');
      return true;
    } catch (e) {
      debugPrint('Error subscribing to topic $topic: $e');
      return false;
    }
  }

  /// Unsubscribe from a specific topic (Mobile Only)
  Future<bool> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) {
      debugPrint('Topic unsubscription is not supported on Web');
      return false;
    }
    try {
      await _messaging.unsubscribeFromTopic(topic).timeout(
        const Duration(seconds: 10),
        onTimeout: () => debugPrint('Unsubscription from topic $topic timed out'),
      );
      debugPrint('Unsubscribed from topic: $topic');
      return true;
    } catch (e) {
      debugPrint('Error unsubscribing from topic $topic: $e');
      return false;
    }
  }

  /// Subscribe token to topic via REST API
  Future<bool> subscribeTokenToTopic(String topic) async {
    try {
      String? token;
      if (kIsWeb) {
        token = await _messaging.getToken(vapidKey: _vapidKey);
      } else {
        token = await _messaging.getToken();
      }

      if (token == null) {
        debugPrint('Cannot subscribe: FCM token is null');
        return false;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/subscribe-to-topic'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tokens': [token],
          'topic': topic,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('Token subscribed to topic $topic via API');
        return true;
      } else {
        debugPrint('Failed to subscribe token to topic: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error subscribing token to topic: $e');
      return false;
    }
  }
}