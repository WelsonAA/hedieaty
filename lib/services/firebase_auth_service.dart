import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../local_db.dart';
import 'account.dart';  // Account model for local database
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up a new user
  Future<void> signUp(String email, String password, String name) async {
    try {
      // Sign up with Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Add user data to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
      });

      // Sync with Firestore to local SQLite
      //await syncAccountWithFirestore(userCredential.user!.uid);

      // Create an Account object for local SQLite
      //Account account = Account(
      //  id: null,  // Local ID will be generated in SQLite
      //  name: name,
      //  email: email,
      //);

      // Save account to local SQLite
      //await account.save();

      //return account;
    } catch (e) {
      print("Error signing up: $e");

    }
  }

  // Log in an existing user
  Future<Account?> logIn(String email, String password) async {
    try {
      // Log in with Firebase Authentication
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Sync with Firestore to local SQLite
      await syncAccountWithFirestore(userCredential.user!.uid);

      // Retrieve user data from Firestore
      DocumentSnapshot snapshot = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      var userData = snapshot.data() as Map<String, dynamic>;

      // Create an Account object for local SQLite
      Account account = Account(
        id: null,  // ID will be set when saved to local SQLite
        name: userData['name'],
        email: userData['email'],
      );

      // Save account to local SQLite
      await account.save();

      return account;
    } catch (e) {
      print("Error logging in: $e");
      return null;
    }
  }

  // Sign out the current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get the current Firebase user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Sync Account Data from Firestore to local SQLite
  Future<void> syncAccountWithFirestore(String uid) async {
    try {
      // Fetch user data from Firestore
      DocumentSnapshot snapshot = await _firestore.collection('users').doc(uid).get();
      var data = snapshot.data() as Map<String, dynamic>;

      // Create an Account object for local SQLite
      Account account = Account(
        id: null,  // ID will be set in SQLite after insertion
        name: data['name'],
        email: data['email'],
      );

      // Save the account data to local SQLite
      await account.save();
      print("User synced with local database");
    } catch (e) {
      print("Error syncing account with Firestore: $e");
    }
  }
}
