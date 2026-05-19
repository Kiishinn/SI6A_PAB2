import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'screens/note_list_screen.dart';
import 'services/fcm_service.dart';

/// Top-level background message handler.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background isolate
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('Handling a background message: ${message.messageId}');

  // Check if it's a data-only message
  if (message.notification == null && message.data.isNotEmpty) {
    debugPrint('Data-only message received in background');

    // Show local notification for data-only messages
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    final title = message.data['title'] ?? 'Catatan Baru';
    final body = message.data['body'] ?? 'Cek aplikasi Anda';

    await flutterLocalNotificationsPlugin.show(
    id: message.hashCode,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription:
            'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: jsonEncode(message.data),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize FCM service for foreground handling
  await FcmService().initialize();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: NoteListScreen(),
    );
  }
}
