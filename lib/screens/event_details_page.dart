import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../local_db.dart';
import 'add_gifts_page.dart';

class EventDetailsPage extends StatefulWidget {
  final Map<String, dynamic> event;
  final int? localEventId; // SQLite Event ID
  final String? firebaseEventId; // Firestore Event ID

  EventDetailsPage({
    required this.event,
    this.localEventId,
    this.firebaseEventId,
  });

  @override
  _EventDetailsPageState createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  List<Map<String, dynamic>> gifts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGifts();
  }

  Future<void> _fetchGifts() async {
    try {
      List<Map<String, dynamic>> localGifts = [];
      List<Map<String, dynamic>> firestoreGifts = [];

      // Fetch gifts from SQLite
      if (widget.localEventId != null) {
        final db = await local_db().getInstance();
        localGifts = await db!.query(
          'Gifts',
          where: 'eventId = ?',
          whereArgs: [widget.localEventId],
        );
      }

      // Fetch gifts from Firestore
      if (widget.firebaseEventId != null) {
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('gifts')
            .where('eventId', isEqualTo: widget.firebaseEventId)
            .get();

        firestoreGifts = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'name': doc['name'],
            'description': doc['description'],
            'category': doc['category'],
            'price': doc['price'],
            'status': doc['status'],
            'source': 'Firestore',
          };
        }).toList();
      }

      // Combine gifts from both sources
      setState(() {
        gifts = [
          ...localGifts.map((gift) => {
            ...gift,
            'source': 'SQLite',
          }),
          ...firestoreGifts,
        ];
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching gifts: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _navigateToAddGift() async {
    bool? addedGift = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddGiftsPage(
          eventId: widget.localEventId,
          firebaseEventId: widget.firebaseEventId,
        ),
      ),
    );

    // Refresh the gift list if a gift was added
    if (addedGift == true) {
      _fetchGifts();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event['name']),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: gifts.isEmpty
                ? Center(child: Text('No gifts found for this event.'))
                : ListView.builder(
              itemCount: gifts.length,
              itemBuilder: (context, index) {
                final gift = gifts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      vertical: 5, horizontal: 10),
                  child: ListTile(
                    title: Text(gift['name']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (gift['description'] != null)
                          Text('Description: ${gift['description']}'),
                        if (gift['category'] != null)
                          Text('Category: ${gift['category']}'),
                        if (gift['price'] != null)
                          Text('Price: \$${gift['price']}'),
                      ],
                    ),
                    trailing: Text(
                      gift['status'],
                      style: TextStyle(
                          color: gift['status'] == 'available'
                              ? Colors.green
                              : Colors.red),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _navigateToAddGift,
              child: Text('Add Gift'),
            ),
          ),
        ],
      ),
    );
  }
}
