import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendGiftListPage extends StatefulWidget {
  final String friendId;

  FriendGiftListPage({required this.friendId});

  @override
  _FriendGiftListPageState createState() => _FriendGiftListPageState();
}

class _FriendGiftListPageState extends State<FriendGiftListPage> {
  List<Map<String, dynamic>> giftLists = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGiftLists();
  }

  Future<void> _fetchGiftLists() async {
    try {
      QuerySnapshot giftsSnap = await FirebaseFirestore.instance
          .collection('gifts')
          .where('userId', isEqualTo: widget.friendId)
          .get();

      setState(() {
        giftLists = giftsSnap.docs.map((doc) {
          return {
            'name': doc['name'],
            'description': doc['description'],
            'category': doc['category'],
            'status': doc['status'],
          };
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching gift lists: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gift Lists"),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : giftLists.isEmpty
          ? Center(child: Text("No gifts found."))
          : ListView.builder(
        itemCount: giftLists.length,
        itemBuilder: (context, index) {
          final gift = giftLists[index];
          return Card(
            child: ListTile(
              title: Text(gift['name']),
              subtitle: Text(gift['description']),
              trailing: Text(gift['status']),
              onTap: () {
                // Logic to pledge gifts
              },
            ),
          );
        },
      ),
    );
  }
}
