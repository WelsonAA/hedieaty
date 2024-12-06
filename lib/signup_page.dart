import 'package:flutter/material.dart';
import 'user.dart';  // Import the User model
import 'local_db.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _isLoading = false;

  // Method to handle sign-up
  _signUp() async {
    String name = _nameController.text;
    String email = _emailController.text;
    String password = _passwordController.text;
    String confirmPassword = _passwordConfirmController.text;

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Passwords do not match'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Check if the email is already registered
    User? existingUser = await User.getByEmail(email);
    if (existingUser != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Email is already registered'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Hash the password (for demonstration, you should use a hashing library in a real app)
    String hashedPassword = password;

    // Create a new user and save it to the database
    User newUser = User(
      name: name,
      email: email,
      passwordHashed: hashedPassword,
    );
    await newUser.save();

    // Show success message and navigate to login page
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Sign up successful! Please log in.'),
      backgroundColor: Colors.green,
    ));
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign Up'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Name Input
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),

            // Email Input
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),

            // Password Input
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),

            // Confirm Password Input
            TextField(
              controller: _passwordConfirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 30),

            // Sign Up Button
            ElevatedButton(
              onPressed: _isLoading ? null : _signUp,
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Sign Up'),
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
