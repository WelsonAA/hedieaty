import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'my_pledged_gifts_page.dart';
import 'user_profile_edit_page.dart';

class UserProfilePage extends StatefulWidget {
  final String firebaseUserUid;

  UserProfilePage({required this.firebaseUserUid});

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  //late Future<DocumentSnapshot> _userFuture;
  bool _notificationsEnabled = true; // Default value
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  @override
  void initState() {
    super.initState();
    _initializeUserPreferences();
    _fetchUserPreferences();
  }


  Future<void> _initializeUserPreferences() async {
    try {
      DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(widget.firebaseUserUid).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (userData['notificationsEnabled'] == null) {
          // Add the field with a default value
          await FirebaseFirestore.instance.collection('users').doc(widget.firebaseUserUid).update({
            'notificationsEnabled': true, // Default value
          });
        }
      }
    } catch (e) {
      print("Error initializing user preferences: $e");
    }
  }



  void _fetchUserInfo() {
    setState(() {
      //_userFuture = FirebaseFirestore.instance.collection('users').doc(widget.firebaseUserUid).get();
    });
  }
  Future<void> _fetchUserPreferences() async {
    try {
      DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(widget.firebaseUserUid).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _notificationsEnabled = userData['notificationsEnabled'] ?? true; // Default to true if field is missing
        });
      }
    } catch (e) {
      print("Error fetching user preferences: $e");
    }
  }



  Future<void> _toggleNotifications(bool enable) async {
    try {
      if (enable) {
        // Request notification permissions
        NotificationSettings settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          print('User granted permission');

          // Retrieve and save device token
          String? token = await _messaging.getToken();
          print("Device Token: $token");
          await FirebaseFirestore.instance.collection('users').doc(widget.firebaseUserUid).update({
            'deviceToken': token,
            'notificationsEnabled': true,
          });

          setState(() {
            _notificationsEnabled = true;
          });
        } else {
          print('User denied notification permissions');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Notification permissions are required to enable notifications.')),
          );
        }
      } else {
        // Remove device token and disable notifications
        await FirebaseFirestore.instance.collection('users').doc(widget.firebaseUserUid).update({
          'deviceToken': FieldValue.delete(),
          'notificationsEnabled': false,
        });

        setState(() {
          _notificationsEnabled = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(enable ? 'Notifications Enabled' : 'Notifications Disabled')),
      );
    } catch (e) {
      print("Error toggling notifications: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update notification settings.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Information
            Text(
              'Profile Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(widget.firebaseUserUid).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Text("Unable to fetch profile information.");
                }
                final userData = snapshot.data!.data() as Map<String, dynamic>;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: ${userData['name']}'),
                    Text('Email: ${userData['email']}'),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfileEditPage(
                              firebaseUserUid: widget.firebaseUserUid,
                              initialName: userData['name'],
                              initialEmail: userData['email'],
                            ),
                          ),
                        ).then((_) {
                          // Refresh user info after returning from the edit page
                          //_fetchUserInfo();
                          _fetchUserPreferences();
                        });
                      },
                      icon: Icon(Icons.edit),
                      label: Text('Edit Profile'),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 20),

            // Notification Settings
            Text(
              'Notification Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: Text('Receive Notifications'),
              value: _notificationsEnabled,
              onChanged: (value) {
                _toggleNotifications(value);
              },
            ),
            SizedBox(height: 20),

            // User's Created Events and Associated Gifts
            Text(
              'My Created Events and Gifts',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('events')
                    .where('userId', isEqualTo: widget.firebaseUserUid)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Text('No events found.');
                  }
                  final events = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final eventData = event.data() as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          title: Text(eventData['name']),
                          subtitle: Text('Date: ${eventData['date']}'),
                          onTap: () {
                            // Navigate to gifts associated with this event
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 20),

            // Button to navigate to My Pledged Gifts Page
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MyPledgedGiftsPage(), // Navigate to MyPledgedGiftsPage
                    ),
                  );
                },
                icon: Icon(Icons.card_giftcard),
                label: Text('View My Pledged Gifts'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
