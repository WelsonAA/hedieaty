import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hedieaty/screens/login_page.dart';
import 'package:hedieaty/local_db.dart';
import 'screens/home_page.dart';
import 'screens/start_page.dart';
import '/services/firebase_options.dart';
// Import the necessary package for web SQLite support
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'local_db.dart';
void main() async{
  // Initialize the database factory for web
  //await local_db().getInstance();
  print("Helloo");
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);  // Initialize Firebase
  await local_db().resetting(); // Reset the database
  await local_db().getInstance();

  // Run the Flutter app
  runApp(HedieatyApp());
}

class HedieatyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hedieaty',
      theme: ThemeData(
        primarySwatch: Colors.purple, // Customize theme as needed
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/start', // Set the initial route to '/start'
      routes:{
        '/start': (context) => StartPage(),
        '/home': (context) => HomePage(),
        '/login': (context) => LoginPage(),
      },
      debugShowCheckedModeBanner: true, // Remove debug banner
    );
  }
}
