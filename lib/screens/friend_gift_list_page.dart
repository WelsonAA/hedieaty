import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../local_db.dart';

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

  // Fetch gifts for the selected friend
  Future<void> _fetchGiftLists() async {
    try {
      final db = await local_db().getInstance();

      // Fetch gifts from Firestore
      QuerySnapshot giftsSnap = await FirebaseFirestore.instance
          .collection('gifts')
          .where('userId', isEqualTo: widget.friendId)
          .get();

      // Fetch gifts from local SQLite
      List<Map<String, dynamic>> localGifts = await db!.query(
        'Gifts',
        where: 'eventId = ?',
        whereArgs: [widget.friendId],
      );

      // Combine results
      setState(() {
        giftLists = giftsSnap.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown Gift',
            'description': data['description'] ?? '',
            'category': data['category'] ?? '',
            'status': data['status'] ?? 'available',
            'pledgerId': data['pledgerId'] ?? null, // Check for pledgerId
            'source': 'Firestore',
          };
        }).toList();

        for (var localGift in localGifts) {
          giftLists.add({
            'id': localGift['id'],
            'name': localGift['name'],
            'description': localGift['description'],
            'category': localGift['category'],
            'status': localGift['status'],
            'pledgerId': localGift['pledgerId'],
            'source': 'SQLite',
          });
        }

        isLoading = false;
      });
    } catch (e) {
      print("Error fetching gift lists: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // Report purchased
  Future<void> _reportPurchased(String giftId, String source) async {
    await _updateGiftStatus(giftId, source, 'purchased');
  }

  // Unpledge a gift
  Future<void> _unpledgeGift(String giftId, String source) async {
    await _updateGiftStatus(giftId, source, 'available');
  }

  // Update gift status in both Firestore and SQLite
  Future<void> _updateGiftStatus(String giftId, String source, String newStatus) async {
    try {
      final db = await local_db().getInstance();

      // Update Firestore
      if (source == 'Firestore') {
        await FirebaseFirestore.instance.collection('gifts').doc(giftId).update({
          'status': newStatus,
          'pledgerId': newStatus == 'available' ? null : FirebaseAuth.instance.currentUser!.uid,
        });
      }

      // Update SQLite
      await db!.update(
        'Gifts',
        {
          'status': newStatus,
          'pledgerId': newStatus == 'available' ? null : FirebaseAuth.instance.currentUser!.uid,
        },
        where: 'id = ?',
        whereArgs: [giftId],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newStatus == 'purchased' ? 'Gift marked as purchased!' : 'Gift unpledged!')),
      );

      _fetchGiftLists();
    } catch (e) {
      print("Error updating gift status: $e");
    }
  }

  // Determine color based on gift status
  Color _getGiftColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'pledged':
        return Colors.orange;
      case 'purchased':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Determine status label
  String _getStatusLabel(String status, String? pledgerId) {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (status == 'pledged') {
      return pledgerId == currentUser?.uid
          ? 'Pledged by You'
          : 'Pledged by Another';
    } else if (status == 'purchased') {
      return pledgerId == currentUser?.uid
          ? 'Purchased by You'
          : 'Purchased by Another';
    }
    return 'Available';
  }

  // Check if the current user pledged the gift
  bool _isPledgedByCurrentUser(String? pledgerId) {
    User? currentUser = FirebaseAuth.instance.currentUser;
    return pledgerId == currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Friend's Gift Lists"),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : giftLists.isEmpty
          ? Center(child: Text("No gifts found."))
          : ListView.builder(
        itemCount: giftLists.length,
        itemBuilder: (context, index) {
          final gift = giftLists[index];
          final isPledgedByUser = _isPledgedByCurrentUser(gift['pledgerId']);
          return Card(
            color: _getGiftColor(gift['status']),
            child: ListTile(
              title: Text(gift['name']),
              subtitle: Text(
                "${gift['description']}\n${_getStatusLabel(gift['status'], gift['pledgerId'])}",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              trailing: gift['status'] == 'available'
                  ? ElevatedButton(
                onPressed: () => _updateGiftStatus(gift['id'], gift['source'], 'pledged'),
                child: Text('Pledge'),
              )
                  : gift['status'] == 'pledged' && isPledgedByUser
                  ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => _reportPurchased(gift['id'], gift['source']),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: Text('Report Purchased'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _unpledgeGift(gift['id'], gift['source']),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: Text('Unpledge'),
                  ),
                ],
              )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
