import 'package:flutter/material.dart';
import '../local_db.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserEventsPage extends StatefulWidget {
  final int userId; // Local SQLite user ID
  final String firebaseUserUid; // Firebase UID

  UserEventsPage({required this.userId, required this.firebaseUserUid});

  @override
  _UserEventsPageState createState() => _UserEventsPageState();
}

class _UserEventsPageState extends State<UserEventsPage> {
  List<Map<String, dynamic>> userEvents = [];
  bool isLoading = true; // Loading indicator

  @override
  void initState() {
    super.initState();
    _fetchUserEvents();
  }

  Future<void> _fetchUserEvents() async {
    try {
      // Fetch events from SQLite
      final db = await local_db().getInstance();
      List<Map<String, dynamic>> localEvents = await db!.query(
        'Events',
        where: 'userId = ?',
        whereArgs: [widget.userId],
      );

      // Fetch events from Firestore
      QuerySnapshot firestoreEvents = await FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: widget.firebaseUserUid)
          .get();

      List<Map<String, dynamic>> firestoreEventsList = firestoreEvents.docs.map((doc) {
        return {
          'id': doc.id, // Firestore document ID
          'name': doc['name'],
          'date': doc['date'],
          'location': doc['location'],
          'description': doc['description'],
          'source': 'Firestore', // Indicate the source
        };
      }).toList();

      // Combine events from both sources
      setState(() {
        userEvents = [
          ...localEvents.map((event) => {
            ...event,
            'source': 'SQLite', // Indicate the source
          }),
          ...firestoreEventsList,
        ];
        isLoading = false; // Disable loading indicator
      });
    } catch (e) {
      print("Error fetching events: $e");
      setState(() {
        isLoading = false; // Disable loading indicator on error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Events'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // Show loader while fetching data
          : userEvents.isEmpty
          ? Center(child: Text('No events found.'))
          : ListView.builder(
        itemCount: userEvents.length,
        itemBuilder: (context, index) {
          final event = userEvents[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
            child: ListTile(
              title: Text(event['name']),
              subtitle: Text('Date: ${event['date']}'),
              trailing: Text(
                event['source'],
                style: TextStyle(
                  color: event['source'] == 'SQLite' ? Colors.blue : Colors.green,
                  fontSize: 12,
                ),
              ), // Show source (SQLite or Firestore)
              onTap: () {
                _navigateToEventDetails(event);
              },
            ),
          );
        },
      ),
    );
  }

  void _navigateToEventDetails(Map<String, dynamic> event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(event['name'])),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Event Name: ${event['name']}', style: TextStyle(fontSize: 18)),
                SizedBox(height: 10),
                Text('Date: ${event['date']}', style: TextStyle(fontSize: 16)),
                SizedBox(height: 10),
                Text('Location: ${event['location'] ?? 'No location provided'}',
                    style: TextStyle(fontSize: 16)),
                SizedBox(height: 10),
                Text('Description: ${event['description'] ?? 'No description provided'}',
                    style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
