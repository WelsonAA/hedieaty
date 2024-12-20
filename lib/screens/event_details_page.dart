import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../local_db.dart';
import 'add_gifts_page.dart';
import 'edit_gift_page.dart';

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
  List<Map<String, dynamic>> publicGifts = [];
  List<Map<String, dynamic>> privateGifts = [];
  bool isLoading = true;
  String selectedSortOption = 'Name Ascending'; // Default sorting option

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

      setState(() {
        publicGifts = firestoreGifts;
        privateGifts = localGifts
            .where((gift) => !firestoreGifts.any((fg) => fg['name'] == gift['name']))
            .toList();
        isLoading = false;
      });

      _sortGifts(); // Apply initial sorting
    } catch (e) {
      print("Error fetching gifts: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _sortGifts() {
    setState(() {
      if (selectedSortOption == 'Name Ascending') {
        _sortBy(publicGifts, 'name', true);
        _sortBy(privateGifts, 'name', true);
      } else if (selectedSortOption == 'Name Descending') {
        _sortBy(publicGifts, 'name', false);
        _sortBy(privateGifts, 'name', false);
      } else if (selectedSortOption == 'Category Ascending') {
        _sortBy(publicGifts, 'category', true);
        _sortBy(privateGifts, 'category', true);
      } else if (selectedSortOption == 'Category Descending') {
        _sortBy(publicGifts, 'category', false);
        _sortBy(privateGifts, 'category', false);
      } else if (selectedSortOption == 'Status Ascending') {
        _sortBy(publicGifts, 'status', true);
        _sortBy(privateGifts, 'status', true);
      } else if (selectedSortOption == 'Status Descending') {
        _sortBy(publicGifts, 'status', false);
        _sortBy(privateGifts, 'status', false);
      }
    });
  }

  void _sortBy(List<Map<String, dynamic>> gifts, String key, bool ascending) {
    gifts.sort((a, b) {
      final valueA = a[key]?.toString().toLowerCase() ?? '';
      final valueB = b[key]?.toString().toLowerCase() ?? '';
      return ascending ? valueA.compareTo(valueB) : valueB.compareTo(valueA);
    });
  }

  Future<void> _navigateToAddGift() async {
    bool? addedGift = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddGiftsPage(
          eventId: widget.localEventId,
        ),
      ),
    );

    if (addedGift == true) {
      _fetchGifts();
    }
  }

  Future<void> _publishGift(Map<String, dynamic> gift) async {
    try {
      if (widget.firebaseEventId != null) {
        await FirebaseFirestore.instance.collection('gifts').add({
          'name': gift['name'],
          'description': gift['description'],
          'category': gift['category'],
          'price': gift['price'],
          'status': 'available',
          'eventId': widget.firebaseEventId,
        });

        setState(() {
          privateGifts.removeWhere((g) => g['id'] == gift['id']);
          publicGifts.add({
            ...gift,
            'source': 'Firestore',
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gift published successfully!')),
        );
      }
    } catch (e) {
      print("Error publishing gift: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to publish gift. Please try again.')),
      );
    }
  }

  Future<void> _editGift(Map<String, dynamic> gift) async {
    bool? updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditGiftPage(
          giftId: gift['id'],
        ),
      ),
    );

    if (updated == true) {
      _fetchGifts();
    }
  }

  Future<void> _deleteGift(Map<String, dynamic> gift) async {
    try {
      final db = await local_db().getInstance();
      await db!.delete(
        'Gifts',
        where: 'id = ?',
        whereArgs: [gift['id']],
      );

      setState(() {
        privateGifts.removeWhere((g) => g['id'] == gift['id']);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gift deleted successfully!')),
      );
    } catch (e) {
      print("Error deleting gift: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete gift. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event['name']),
        actions: [
          DropdownButton<String>(
            value: selectedSortOption,
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  selectedSortOption = newValue;
                  _sortGifts(); // Apply sorting
                });
              }
            },
            items: [
              'Name Ascending',
              'Name Descending',
              'Category Ascending',
              'Category Descending',
              'Status Ascending',
              'Status Descending',
            ].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildGiftSection('Public Gifts', publicGifts, false),
                _buildGiftSection('Private Gifts', privateGifts, true),
              ],
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

  Widget _buildGiftSection(
      String title, List<Map<String, dynamic>> gifts, bool isPrivate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        if (gifts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('No gifts found.'),
          )
        else
          ...gifts.map((gift) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
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
                trailing: isPrivate
                    ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => _editGift(gift),
                    ),
                    IconButton(
                      icon: Icon(Icons.publish),
                      onPressed: () => _publishGift(gift),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteGift(gift),
                    ),
                  ],
                )
                    : Text(
                  gift['status'],
                  style: TextStyle(
                    color: gift['status'] == 'available'
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }
}
