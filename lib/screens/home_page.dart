import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'user_profile_page.dart';
import 'package:hedieaty/services/firebase_auth_service.dart';
import 'my_pledged_gifts_page.dart';
import 'start_page.dart'; // Import the StartPage
import '../local_db.dart';
import 'create_event_page.dart';
import 'user_events_page.dart';
import 'friend_gift_list_page.dart';
class HomePage extends StatefulWidget {
  final Key? key; // Add this line

  HomePage({this.key}) : super(key: key); // Pass the key to the superclass
  @override
  _HomePageState createState() => _HomePageState();
}
void _removeTokenFromFirestore() async {
  String? token = await FirebaseMessaging.instance.getToken();
  User? currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser != null && token != null) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .update({
      'deviceTokens': FieldValue.arrayRemove([token])
    });
    print("Token removed from Firestore");
  }
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
    _syncUserData(); // Sync user data from Firestore to local DB
    _fetchUserName(); // Fetch the logged-in user's name
    _fetchFriends(); // Fetch friends from Firestore
  }
  Future<void> _syncUserData() async {
    try {
      final db = await local_db().getInstance();
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        print("No user logged in.");
        return;
      }

      // Fetch user information from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        print("User document not found in Firestore.");
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;

      // Insert or update user in local DB
      await db!.insert(
        'Accounts',
        {
          'name': userData['name'] ?? 'Unknown User',
          'email': currentUser.email ?? 'Unknown Email',
        },
        conflictAlgorithm: ConflictAlgorithm.replace, // Handle duplicates
      );

      // Get local user ID
      final List<Map<String, dynamic>> localUsers = await db.query(
        'Accounts',
        where: 'email = ?',
        whereArgs: [currentUser.email],
      );

      if (localUsers.isEmpty) {
        print("Failed to find the user in the local database.");
        return;
      }

      final localUserId = localUsers.first['id'];

      // Fetch events from Firestore
      QuerySnapshot eventDocs = await FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      for (var eventDoc in eventDocs.docs) {
        final eventData = eventDoc.data() as Map<String, dynamic>;

        await db.insert(
          'Events',
          {
            'name': eventData['name'] ?? 'Unknown Event',
            'date': eventData['date'] ?? '1970-01-01T00:00:00Z',
            'location': eventData['location'] ?? '',
            'description': eventData['description'] ?? '',
            'userId': localUserId,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Fetch gifts from Firestore
      QuerySnapshot giftDocs = await FirebaseFirestore.instance
          .collection('gifts')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      for (var giftDoc in giftDocs.docs) {
        final giftData = giftDoc.data() as Map<String, dynamic>;

        await db.insert(
          'Gifts',
          {
            'name': giftData['name'] ?? 'Unknown Gift',
            'description': giftData['description'] ?? '',
            'category': giftData['category'] ?? '',
            'price': giftData['price'] ?? 0.0,
            'status': giftData['status'] ?? 'available',
            'eventId': giftData['eventId'] ?? null,
            'pledgerId': giftData['pledgerId'] ?? null,
            'image': giftData['image'] ?? '',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      print("User data synced successfully.");
    } catch (e) {
      print("Error syncing user data: $e");
    }
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
  Future<void> _fetchFriends() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Fetch the current user's document
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          List<dynamic> friendsList = userDoc['friends'] ?? [];
          List<Map<String, dynamic>> enrichedFriends = [];

          // Loop through each friend to get their events count
          for (var friend in friendsList) {
            String friendId = friend['id'] ?? '';

            // Fetch the number of events associated with the friend
            int eventCount = await _getUpcomingEventsCount(friendId);

            enrichedFriends.add({
              'id': friendId,
              'name': friend['name'] ?? 'Unknown',
              'email': friend['email'] ?? 'Unknown',
              'upcomingEvents': eventCount, // Set actual count
            });
          }

          setState(() {
            friends = enrichedFriends;
            isLoading = false;
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

// Helper function to get the count of upcoming events for a friend
  Future<int> _getUpcomingEventsCount(String friendId) async {
    try {
      // Query Firestore to get events created by this friend
      QuerySnapshot eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: friendId) // Check userId of events
          .get();

      return eventsSnapshot.docs.length; // Return the number of events
    } catch (e) {
      print("Error fetching event count for friend $friendId: $e");
      return 0; // Return 0 in case of error
    }
  }




  // Search for a user by email
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
          // Include the document ID in the search result
          final doc = querySnapshot.docs.first;
          searchResult = {
            'id': doc.id, // Firestore document ID
            ...doc.data() as Map<String, dynamic>, // Include other fields
          };
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
            'id': searchResult!['id'], // Use the correct ID
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
      _removeTokenFromFirestore();
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
  void _navigateToFriendGiftLists(Map<String, dynamic> friend) {
    final friendId = friend['id'] ?? ''; // Default to an empty string

    if (friendId.isEmpty) {
      // Show a warning if friendId is missing
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load gift list. Friend ID is missing.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendGiftListPage(friendId: friendId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        key: Key('HomePage_AppBar'), // Key for AppBar
        title: Text('Home Page'),
        actions: [
          IconButton(
            key: Key('HomePage_SignOutButton'), // Key for Sign Out button
            icon: Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
          IconButton(
            key: Key('HomePage_ViewEventsButton'), // Key for View Events button
            icon: Icon(Icons.event),
            tooltip: 'View My Events',
            onPressed: () async {
              Map<String, dynamic>? identifiers = await getUserIdentifiers();
              if (identifiers != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserEventsPage(
                      key: Key('UserEventsPage'), // Key for UserEventsPage
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
            key: Key('HomePage_MyPledgedGiftsButton'), // Key for My Pledged Gifts button
            icon: Icon(Icons.card_giftcard),
            tooltip: 'My Pledged Gifts',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyPledgedGiftsPage(
                    key: Key('MyPledgedGiftsPage'), // Key for MyPledgedGiftsPage
                  ),
                ),
              );
            },
          ),
          IconButton(
            key: Key('HomePage_UserProfileButton'), // Key for User Profile button
            icon: Icon(Icons.person),
            tooltip: 'User Profile',
            onPressed: () async {
              Map<String, dynamic>? identifiers = await getUserIdentifiers();
              if (identifiers != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfilePage(
                      key: Key('UserProfilePage'), // Key for UserProfilePage
                      firebaseUserUid: identifiers['firebaseUserUid'], // Correct parameter name
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
        ],
      ),
      body: Column(
        key: Key('HomePage_Body'), // Key for the body column
        children: [
          // Search Bar
          Padding(
            key: Key('HomePage_SearchBarPadding'), // Key for Search Bar Padding
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              key: Key('HomePage_SearchBar'), // Key for Search Bar
              onChanged: (value) {
                setState(() {
                  searchEmail = value;
                });
              },
              decoration: InputDecoration(
                labelText: 'Enter email to search for friend',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  key: Key('HomePage_SearchButton'), // Key for Search Button
                  icon: Icon(Icons.search),
                  onPressed: _searchUserByEmail,
                ),
              ),
            ),
          ),
          // Display search result or loading indicator
          isSearching
              ? CircularProgressIndicator(
            key: Key('HomePage_SearchLoadingIndicator'), // Key for Loading Indicator
          )
              : searchResult != null
              ? Column(
            key: Key('HomePage_SearchResultColumn'), // Key for Search Result Column
            children: [
              Text(
                key: Key('HomePage_SearchResultName'), // Key for Search Result Name
                'Found: ${searchResult!['name']}',
              ),
              Text(
                key: Key('HomePage_SearchResultEmail'), // Key for Search Result Email
                'Email: ${searchResult!['email']}',
              ),
              ElevatedButton(
                key: Key('HomePage_AddFriendButton'), // Key for Add Friend Button
                onPressed: _addFriend,
                child: Text('Add Friend'),
              ),
            ],
          )
              : Text(
            key: Key('HomePage_NoUserFoundText'), // Key for No User Found Text
            'No user found with that email.',
          ),
          // Friends List
          Expanded(
            key: Key('HomePage_FriendsListExpanded'), // Key for Friends List Expanded
            child: ListView.builder(
              key: Key('HomePage_FriendsList'), // Key for Friends List
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                return Card(
                  key: Key('HomePage_FriendCard_$index'), // Key for each Friend Card
                  child: ListTile(
                    key: Key('HomePage_FriendTile_$index'), // Key for each Friend Tile
                    leading: CircleAvatar(
                      key: Key('HomePage_FriendAvatar_$index'), // Key for Friend Avatar
                      child: Text(friend['name'][0]),
                    ),
                    title: Text(
                      key: Key('HomePage_FriendName_$index'), // Key for Friend Name
                      friend['name'],
                    ),
                    subtitle: Text(
                      key: Key('HomePage_FriendUpcomingEvents_$index'), // Key for Friend Upcoming Events
                      friend['upcomingEvents'] > 0
                          ? 'Upcoming Events: ${friend['upcomingEvents']}'
                          : 'No Upcoming Events',
                    ),
                    onTap: () {
                      _navigateToFriendGiftLists(friend);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: Key('HomePage_CreateEventButton'), // Key for Create Event Button
        onPressed: () async {
          Map<String, dynamic>? identifiers = await getUserIdentifiers();
          if (identifiers != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreateEventPage(
                  key: Key('CreateEventPage'), // Key for CreateEventPage
                  userId: identifiers['loggedInUserId'], // SQLite User ID
                  firebaseUserId: identifiers['firebaseUserUid'], // Firebase UID
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Unable to fetch user details. Please try again.')),
            );
          }
        },
        label: Text('Create Event'),
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


}