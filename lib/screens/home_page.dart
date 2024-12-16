import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hedieaty/services/firebase_auth_service.dart';
import 'start_page.dart'; // Import the StartPage
import '../local_db.dart';
import 'create_event_page.dart';
import 'user_events_page.dart';
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = "Loading..."; // Default value while fetching data
  String searchEmail = ''; // Store the email entered for searching
  List<Map<String, dynamic>> friends = []; // List to store friends
  bool isLoading = true;
  bool isSearching = false; // Flag for searching state
  Map<String, dynamic>? searchResult; // Store search result for user to add

  @override
  void initState() {
    super.initState();
    _fetchUserName(); // Fetch the logged-in user's name
    _fetchFriends(); // Fetch friends from Firestore
  }

  // Fetch the logged-in user's name from Firestore
  Future<void> _fetchUserName() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Fetch user data from Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            userName = userDoc['name']; // Update the user's name
          });
        }
      } else {
        setState(() {
          userName = "No User Logged In";
        });
      }
    } catch (e) {
      print("Error fetching user name: $e");
      setState(() {
        userName = "Error Loading User";
      });
    }
  }
// Fetch friends list from Firestore
  Future<void> _fetchFriends() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          List friendsList = userDoc['friends'] ?? [];
          setState(() {
            friends = friendsList.map((friend) => {'name': friend['name'], 'email': friend['email']}).toList();
            isLoading = false; // Stop the loading indicator
          });
        }
      }
    } catch (e) {
      print("Error fetching friends: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // Search for a user by email
  Future<void> _searchUserByEmail() async {
    setState(() {
      isSearching = true;
      searchResult = null;
    });

    try {
      // Query Firestore for a user by email
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: searchEmail)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          searchResult = querySnapshot.docs.first.data() as Map<String, dynamic>;
        });
      } else {
        setState(() {
          searchResult = null;
        });
      }
    } catch (e) {
      print("Error searching for user: $e");
      setState(() {
        searchResult = null;
      });
    } finally {
      setState(() {
        isSearching = false;
      });
    }
  }

  // Add friend logic
  Future<void> _addFriend() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && searchResult != null) {
        // Update the current user's friends list
        DocumentReference currentUserDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid);

        // Add the found user to the current user's friends list
        await currentUserDocRef.update({
          'friends': FieldValue.arrayUnion([{
            'id': searchResult!['id'],
            'name': searchResult!['name'],
            'email': searchResult!['email']
          }])
        });

        // Update the found user's friends list
        DocumentReference friendDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(searchResult!['id']);

        await friendDocRef.update({
          'friends': FieldValue.arrayUnion([{
            'id': currentUser.uid,
            'name': userName,
            'email': currentUser.email
          }])
        });

        // Refresh the friends list
        _fetchFriends();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Friend added successfully!'),
        ));
      }
    } catch (e) {
      print("Error adding friend: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error adding friend, please try again.'),
      ));
    }
  }

  // Handle sign-out
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut(); // Sign out from Firebase
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => StartPage()),
        // Navigate to StartPage
            (route) => false, // Remove all previous routes
      );
    } catch (e) {
      print("Error signing out: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error signing out. Please try again."),
      ));
    }
  }

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> filteredFriends = [];


  void _filterFriends(String query) {
    setState(() {
      filteredFriends = friends
          .where((friend) =>
          friend['name'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hedieaty - Friends List'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
          IconButton(
            icon: Icon(Icons.event),
            tooltip: 'View My Events',
            onPressed: () async {
              Map<String, dynamic>? identifiers = await getUserIdentifiers();
              if (identifiers != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserEventsPage(
                      userId: identifiers['loggedInUserId'], // SQLite User ID
                      firebaseUserUid: identifiers['firebaseUserUid'], // Firebase UID
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Unable to fetch user details. Please try again.')),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.add),
            tooltip: 'Add Friend',
            onPressed: () {
              _showAddFriendDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchEmail = value;
                });
              },
              decoration: InputDecoration(
                labelText: 'Enter email to search for friend',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _searchUserByEmail,
                ),
              ),
            ),
          ),
          // Display search result or loading indicator
          isSearching
              ? CircularProgressIndicator()
              : searchResult != null
              ? Column(
            children: [
              Text('Found: ${searchResult!['name']}'),
              Text('Email: ${searchResult!['email']}'),
              ElevatedButton(
                onPressed: _addFriend,
                child: Text('Add Friend'),
              ),
            ],
          )
              : Text('No user found with that email.'),

          // Friends List
    // Display current friends
    Expanded(
      child: ListView.builder(
        itemCount: friends.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(friends[index]['name']),
            subtitle: Text(friends[index]['email']),
          );
        },
      ),
      ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          Map<String, dynamic>? identifiers = await getUserIdentifiers();
          if (identifiers != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    CreateEventPage(
                      userId: identifiers['loggedInUserId'], // SQLite User ID
                      firebaseUserId: identifiers['firebaseUserUid'], // Firebase UID
                    ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(
                  'Unable to fetch user details. Please try again.')),
            );
          }
        },
        label: Text('Create Event/List'),
        icon: Icon(Icons.create),

      ),



    );
  }

  Future<Map<String, dynamic>?> getUserIdentifiers() async {
    User? firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser != null) {
      String firebaseUserUid = firebaseUser.uid;
      String? email = firebaseUser.email;

      if (email != null) {
        int? loggedInUserId = await getLoggedInUserId(email);

        if (loggedInUserId != null) {
          return {
            'firebaseUserUid': firebaseUserUid,
            'loggedInUserId': loggedInUserId,
          };
        }
      }
    }
    return null; // Return null if user identifiers are not available
  }


  Future<int?> getLoggedInUserId(String email) async {
    final db = await local_db().getInstance();
    List<Map<String, dynamic>> result = await db!.query(
      'Accounts',
      columns: ['id'], // Fetch only the ID
      where: 'email = ?',
      whereArgs: [email],
    );

    if (result.isNotEmpty) {
      return result.first['id'];
    }
    return null; // User not found
  }


// Navigate to friend's gift lists
  void _navigateToGiftLists(Map<String, dynamic> friend) {
    // Replace with your GiftListPage navigation logic
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text("${friend['name']}'s Gift Lists")),
          body: Center(child: Text('Gift list for ${friend['name']}')),
        ),
      ),
    );
  }

  // Navigate to Create Event or Gift List Page
  void _navigateToCreateEventOrGiftList() {
    // Replace with your CreateEventPage or CreateGiftListPage navigation logic
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text("Create Event or Gift List")),
          body: Center(child: Text('Event/List Creation Page')),
        ),
      ),
    );
  }

  // Show Add Friend Dialog
  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController friendNameController = TextEditingController();
        TextEditingController friendPhoneController = TextEditingController();
        return AlertDialog(
          title: Text('Add Friend'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: friendNameController,
                decoration: InputDecoration(labelText: 'Friend\'s Name'),
              ),
              TextField(
                controller: friendPhoneController,
                decoration: InputDecoration(labelText: 'Phone Number'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  friends.add({
                    'name': friendNameController.text,
                    'profilePic': 'assets/default.jpg',
                    'upcomingEvents': 0,
                  });
                });
                Navigator.of(context).pop();
              },
              child: Text('Add Friend'),
            ),
          ],
        );
      },
    );
  }
}