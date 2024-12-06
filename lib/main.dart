import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'home_page.dart';
import 'start_page.dart';

// Import the necessary package for web SQLite support
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void main() {
  // Initialize the database factory for web
  databaseFactory = databaseFactoryFfiWeb;

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
      home: StartPage(), // Set HomePage as the initial route
      debugShowCheckedModeBanner: false, // Remove debug banner
    );
  }
}
