import 'package:flutter/material.dart';
import 'login_page.dart';
import 'signup_page.dart';
import '../local_db.dart';
class StartPage extends StatelessWidget {
  final Key? key; // Add this line

  StartPage({this.key}) : super(key: key); // Pass the key to the superclass
  @override
  Widget build(BuildContext context) {
    local_db().getInstance();
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome to Hedieaty'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App logo or title
            Icon(
              Icons.abc,
              size: 100,
              color: Colors.blue,
            ),
            SizedBox(height: 30),

            // Login button
            ElevatedButton(key: Key('LoginButton'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
              child: Text('Login'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15),
                textStyle: TextStyle(fontSize: 18),
                backgroundColor: Colors.blue,
              ),
            ),
            SizedBox(height: 20),

            // Sign Up button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpPage()),
                );
              },
              child: Text('Sign Up'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15),
                textStyle: TextStyle(fontSize: 18),
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
