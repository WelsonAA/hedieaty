import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hedieaty/screens/login_page.dart';
import 'package:hedieaty/local_db.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/home_page.dart';
import 'screens/start_page.dart';
import '/services/firebase_options.dart';
// Import the necessary package for web SQLite support
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background message received: ${message.notification?.title}");
}



void _listenForTokenRefresh() {
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    print("Token refreshed: $newToken");

    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({'deviceToken': newToken});
      print("Updated token in Firestore");
    }
  });
}
void _saveTokenToFirestore(String token) async {
  User? currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser != null) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

    await userRef.update({
      'deviceToken': token,
    });
    print("Device token saved to Firestore: $token");
  }
}

// Initialize local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();
void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  await local_db().resetting(); // Reset the database
  await local_db().getInstance();

  // Run the Flutter app
  runApp(HedieatyApp());
}

class HedieatyApp extends StatefulWidget {
  @override
  _HedieatyAppState createState() => _HedieatyAppState();
}

class _HedieatyAppState extends State<HedieatyApp> {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _initializeFirebaseMessaging();
  }

  void _initializeFirebaseMessaging() async {
    // Request permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else {
      print('User denied notification permissions');
    }

    // Retrieve and save device token
    String? token = await _messaging.getToken();
    print("Device Token: $token");
    _saveTokenToFirestore(token!);

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground message received: ${message.notification?.title}");
      _showNotification(
        title: message.notification?.title ?? "Notification",
        body: message.notification?.body ?? "You have a new message.",
      );
    });

    // Listen for background messages when app is opened
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification opened: ${message.notification?.title}");
    });
  }


  void _showNotification({required String title, required String body}) {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'high_importance_channel', // Channel ID
      'High Importance Notifications', // Channel name
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      title,
      body,
      platformChannelSpecifics,
    );
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: Key('MaterialApp_Main'), // Key for the MaterialApp
      title: 'Hedieaty',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/start',
      routes: {
        '/start': (context) => StartPage(key: Key('StartPage')), // Key for StartPage
        '/home': (context) => HomePage(key: Key('HomePage')),   // Key for HomePage
        '/login': (context) => LoginPage(key: Key('LoginPage')), // Key for LoginPage
      },
      debugShowCheckedModeBanner: true,
    );
  }

}
