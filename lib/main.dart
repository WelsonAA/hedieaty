import 'package:flutter/material.dart';
import 'home_page.dart'; // Import the HomePage

void main() {
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
      home: HomePage(), // Set HomePage as the initial route
      debugShowCheckedModeBanner: false, // Remove debug banner
    );
  }
}
