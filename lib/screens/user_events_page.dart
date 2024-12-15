import 'package:flutter/material.dart';
import '../local_db.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_gifts_page.dart';
import 'event_details_page.dart';
import 'edit_event_page.dart';

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

  Future<void> _editEvent(Map<String, dynamic> event) async {
    final int? localEventId = event['source'] == 'SQLite' ? event['id'] as int : null;
    final String? firebaseEventId =
    event['source'] == 'Firestore' ? event['id'] as String : null;

    bool? updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditEventPage(
          localEventId: localEventId,
          firebaseEventId: firebaseEventId,
          event: event,
        ),
      ),
    );

    if (updated == true) {
      _fetchUserEvents(); // Refresh the events list
    }
  }

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    final confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Event'),
          content: Text('Are you sure you want to delete this event?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // Delete from SQLite
        if (event['source'] == 'SQLite') {
          final db = await local_db().getInstance();
          await db!.delete(
            'Events',
            where: 'id = ?',
            whereArgs: [event['id']],
          );
        }

        // Delete from Firestore
        if (event['source'] == 'Firestore') {
          await FirebaseFirestore.instance
              .collection('events')
              .doc(event['id'])
              .delete();
        }

        _fetchUserEvents(); // Refresh the events list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Event deleted successfully.')),
        );
      } catch (e) {
        print("Error deleting event: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete event. Please try again.')),
        );
      }
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
            margin: const EdgeInsets.symmetric(
                vertical: 5, horizontal: 10),
            child: ListTile(
              title: Text(event['name']),
              subtitle: Text('Date: ${event['date']}'),
              trailing: PopupMenuButton<String>(
                onSelected: (String choice) {
                  if (choice == 'Edit') {
                    _editEvent(event);
                  } else if (choice == 'Delete') {
                    _deleteEvent(event);
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    PopupMenuItem<String>(
                      value: 'Edit',
                      child: Text('Edit'),
                    ),
                    PopupMenuItem<String>(
                      value: 'Delete',
                      child: Text('Delete'),
                    ),
                  ];
                },
              ),
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
    final int? localEventId =
    event['source'] == 'SQLite' ? event['id'] as int : null;
    final String? firebaseEventId =
    event['source'] == 'Firestore' ? event['id'] as String : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsPage(
          event: event,
          localEventId: localEventId,
          firebaseEventId: firebaseEventId,
        ),
      ),
    );
  }
}
