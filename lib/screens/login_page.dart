import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../local_db.dart';
import 'signup_page.dart';
import 'home_page.dart';
class LoginPage extends StatefulWidget {
  final Key? key; // Add this line

  LoginPage({this.key}) : super(key: key); // Pass the key to the superclass

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkUserLogin();
  }

  // Check if the user is already logged in
  Future<void> _checkUserLogin() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Ensure this navigation is wrapped in a post-frame callback
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      });
    }
  }

  // Handle login
  Future<void> _login() async {
    try {
      // Step 1: Authenticate the user
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      String userId = userCredential.user!.uid;

      // Step 2: Fetch account data from Firestore
      DocumentSnapshot accountSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!accountSnapshot.exists) {
        throw Exception("User data not found in Firestore.");
      }

      // Extract account data
      var accountData = accountSnapshot.data() as Map<String, dynamic>;
      String name = accountData['name'];
      String email = accountData['email'];

      // Insert the account into the local database
      await local_db().writing('''
      INSERT INTO Accounts (name, email)
      VALUES ('$name', '$email');
    ''');

      // Step 3: Fetch related data (friends, events, gifts) and insert into local database
      await _syncRelatedData(userId);

      // Step 4: Navigate to the home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } catch (e) {
      // Handle login errors
      String errorMessage = 'An error occurred. Please try again later.';
      if (e is FirebaseAuthException) {
        if (e.code == 'user-not-found') {
          errorMessage = 'No user found for that email.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Incorrect password provided.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Invalid email format.';
        }
      }

      // Show error message
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Login Failed'),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }
  Future<void> _syncRelatedData(String userId) async {
    try {
      final db = await local_db().getInstance();

      // Fetch and insert friends
      QuerySnapshot friendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('friends')
          .get();

      for (var doc in friendsSnapshot.docs) {
        var friendData = doc.data() as Map<String, dynamic>;
        String friendId = doc.id;

        await db?.insert('User_Friends', {
          'userId': userId,
          'friendId': friendId,
        });
      }

      // Fetch and insert events
      QuerySnapshot eventsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('events')
          .get();

      for (var doc in eventsSnapshot.docs) {
        var eventData = doc.data() as Map<String, dynamic>;
        await db?.insert('Events', {
          'id': null,
          'name': eventData['name'],
          'date': eventData['date'],
          'location': eventData['location'],
          'description': eventData['description'],
          'userId': userId,
        });

        // Fetch and insert gifts for this event
        QuerySnapshot giftsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('events')
            .doc(doc.id)
            .collection('gifts')
            .get();

        for (var giftDoc in giftsSnapshot.docs) {
          var giftData = giftDoc.data() as Map<String, dynamic>;
          await db?.insert('Gifts', {
            'id': null,
            'name': giftData['name'],
            'description': giftData['description'],
            'category': giftData['category'],
            'price': giftData['price'],
            'status': giftData['status'],
            'eventId': doc.id,
            'pledgerId': giftData['pledgerId'],
            'image': giftData['image'],
          });
        }
      }
    } catch (e) {
      print("Error syncing related data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login Screen'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: Key('LoginPage_EmailField'), // Key for email field
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              key: Key('LoginPage_PasswordField'), // Key for password field
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              key: Key('LoginPage_LoginButton'), // Key for login button
              onPressed: _login,
              child: Text('Login'),
            ),
            SizedBox(height: 20),
            TextButton(
              key: Key('LoginPage_SignUpButton'), // Key for signup button
              onPressed: () {
                // Navigate to signup screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpPage(key: Key('SignUpPage'))),
                );
              },
              child: Text('Don\'t have an account? Sign up'),
            ),
          ],
        ),
      ),
    );
  }

}
