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

  @override
  void initState() {
    super.initState();
    _fetchUserName(); // Fetch the logged-in user's name
    filteredFriends = friends; // Initially, show all friends
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

  final List<Map<String, dynamic>> friends = [
    {'name': 'Alice', 'profilePic': 'assets/alice.jpg', 'upcomingEvents': 1},
    {'name': 'Bob', 'profilePic': 'assets/bob.jpg', 'upcomingEvents': 0},
    // Add more friends as needed
  ];
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
  void _viewFriendRequests() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    QuerySnapshot requestsSnapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    List<QueryDocumentSnapshot> requests = requestsSnapshot.docs;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Friend Requests'),
          content: requests.isEmpty
              ? Text('No friend requests.')
              : Column(
            mainAxisSize: MainAxisSize.min,
            children: requests.map((request) {
              String senderId = request['senderId'];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(senderId)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();

                  String senderName = snapshot.data!['name'];

                  return ListTile(
                    title: Text(senderName),
                    subtitle: Text('Wants to be your friend'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.check, color: Colors.green),
                          onPressed: () => _respondToFriendRequest(
                              request.id, 'accepted', senderId),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () => _respondToFriendRequest(
                              request.id, 'rejected', senderId),
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _respondToFriendRequest(
      String requestId, String response, String senderId) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw "User not logged in.";

      // Update the friend request in Firestore
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(requestId)
          .update({'status': response});

      if (response == 'accepted') {
        // Add each other as friends in Firestore
        await FirebaseFirestore.instance.collection('friends').add({
          'user1': currentUser.uid,
          'user2': senderId,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Friend request accepted.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Friend request rejected.")),
        );
      }

      Navigator.of(context).pop(); // Close the dialog
    } catch (e) {
      print("Error responding to friend request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to respond to request.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hedieaty - Friends List'),
        actions: [IconButton(
          icon: Icon(Icons.notifications),
          tooltip: 'Friend Requests',
          onPressed: _viewFriendRequests,
        ),
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
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Friends',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.search),
              ),
              onChanged: _filterFriends,
            ),
          ),
          // Friends List
          Expanded(
            child: ListView.builder(
              itemCount: filteredFriends.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(
                      vertical: 5, horizontal: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                      AssetImage(filteredFriends[index]['profilePic']),
                    ),
                    title: Text(filteredFriends[index]['name']),
                    subtitle: Text(filteredFriends[index]['upcomingEvents'] > 0
                        ? 'Upcoming Events: ${filteredFriends[index]['upcomingEvents']}'
                        : 'No Upcoming Events'),
                    trailing: filteredFriends[index]['upcomingEvents'] > 0
                        ? CircleAvatar(
                      backgroundColor: Colors.red,
                      child: Text(
                        '${filteredFriends[index]['upcomingEvents']}',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                        : null,
                    onTap: () {
                      _navigateToGiftLists(filteredFriends[index]);
                    },
                  ),
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
        TextEditingController friendEmailController = TextEditingController();
        return AlertDialog(
          title: Text('Send Friend Request'),
          content: TextField(
            controller: friendEmailController,
            decoration: InputDecoration(labelText: 'Friend\'s Email'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String friendEmail = friendEmailController.text.trim();
                await _sendFriendRequest(friendEmail);
                Navigator.of(context).pop();
              },
              child: Text('Send Request'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendFriendRequest(String friendEmail) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw "User not logged in.";

      // Find the receiver's UID based on their email
      QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: friendEmail)
          .get();

      if (userSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User with this email not found.")),
        );
        return;
      }

      String receiverUid = userSnapshot.docs.first.id;

      // Add the friend request to the notifications collection
      await FirebaseFirestore.instance.collection('notifications').add({
        'senderId': currentUser.uid,
        'receiverId': receiverUid,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Friend request sent.")),
      );
    } catch (e) {
      print("Error sending friend request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send friend request.")),
      );
    }
  }

}