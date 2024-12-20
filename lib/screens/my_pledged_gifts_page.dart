import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../local_db.dart';
import '../notifications_manager.dart';

class MyPledgedGiftsPage extends StatefulWidget {
  @override
  _MyPledgedGiftsPageState createState() => _MyPledgedGiftsPageState();
}

class _MyPledgedGiftsPageState extends State<MyPledgedGiftsPage> {
  List<Map<String, dynamic>> pledgedGifts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPledgedGifts();
  }

  Future<void> _fetchPledgedGifts() async {
    try {
      final db = await local_db().getInstance();
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) return;

      // Fetch gifts pledged by the current user from Firestore
      QuerySnapshot giftsSnap = await FirebaseFirestore.instance
          .collection('gifts')
          .where('pledgerId', isEqualTo: currentUser.uid)
          .get();

      // Fetch gifts pledged by the current user from SQLite
      List<Map<String, dynamic>> localGifts = await db!.query(
        'Gifts',
        where: 'pledgerId = ?',
        whereArgs: [currentUser.uid],
      );

      List<Map<String, dynamic>> enrichedGifts = [];

      for (var doc in giftsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        String eventDate = 'Unknown Date';

        // Fetch the event date from Firestore
        if (data.containsKey('eventId')) {
          String? eventId = data['eventId'];
          if (eventId != null) {
            DocumentSnapshot eventDoc = await FirebaseFirestore.instance
                .collection('events')
                .doc(eventId)
                .get();

            if (eventDoc.exists && eventDoc['date'] != null) {
              eventDate = eventDoc['date'];
            }
          }
        }

        enrichedGifts.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Gift',
          'description': data['description'] ?? '',
          'eventDate': eventDate,
          'friendId': data['userId'],
          'status': data['status'] ?? 'available',
          'source': 'Firestore',
        });
      }

      for (var localGift in localGifts) {
        enrichedGifts.add({
          'id': localGift['id'],
          'name': localGift['name'],
          'description': localGift['description'],
          'eventDate': localGift['eventDate'] ?? 'Unknown Date',
          'friendId': localGift['userId'],
          'status': localGift['status'],
          'source': 'SQLite',
        });
      }

      setState(() {
        pledgedGifts = enrichedGifts;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching pledged gifts: $e");
      setState(() {
        isLoading = false;
      });
    }
  }


  Future<void> _unpledgeGift(String giftId, String source, String friendId, String giftName) async {
    try {
      final db = await local_db().getInstance();
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) return;

      // Update Firestore
      if (source == 'Firestore') {
        await FirebaseFirestore.instance.collection('gifts').doc(giftId).update({
          'status': 'available',
          'pledgerId': null,
        });
      }

      // Update SQLite
      await db!.update(
        'Gifts',
        {
          'status': 'available',
          'pledgerId': null,
        },
        where: 'id = ?',
        whereArgs: [giftId],
      );

      // Send notification to the friend
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(friendId).get();
      if (userDoc.exists && userDoc['deviceToken'] != null) {
        String deviceToken = userDoc['deviceToken'];
        await FCMService.sendNotification(
          token: deviceToken,
          title: "Gift unpledged",
          body: "${currentUser.displayName ?? 'A friend'} unpledged the gift: $giftName",
          data: {"giftId": giftId, "action": "unpledged"},
        );
      }

      // Remove the gift from the list and update the UI
      setState(() {
        pledgedGifts.removeWhere((gift) => gift['id'] == giftId);
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gift unpledged successfully!")));
    } catch (e) {
      print("Error unpledging gift: $e");
    }
  }


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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Pledged Gifts"),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : pledgedGifts.isEmpty
          ? Center(child: Text("No pledged gifts found."))
          : ListView.builder(
        itemCount: pledgedGifts.length,
        itemBuilder: (context, index) {
          final gift = pledgedGifts[index];
          DateTime? eventDate;
          if (gift['eventDate'] != 'Unknown Date') {
            try {
              eventDate = DateTime.parse(gift['eventDate']);
            } catch (e) {
              print("Error parsing date: $e");
            }
          }

          final canUnpledge = gift['status'] == 'pledged' &&
              eventDate != null &&
              DateTime.now().isBefore(eventDate);

          return Card(
            color: _getGiftColor(gift['status']),
            child: ListTile(
              title: Text(gift['name']),
              subtitle: Text("Event Date: ${gift['eventDate']}"),
              trailing: canUnpledge
                  ? ElevatedButton(
                onPressed: () => _unpledgeGift(
                  gift['id'],
                  gift['source'],
                  gift['friendId'],
                  gift['name'],
                ),
                child: Text("Unpledge"),
              )
                  : Text(
                gift['status'] == 'purchased'
                    ? "Purchased"
                    : "Event Passed",
                style: TextStyle(color: Colors.red),
              ),
            ),
          );
        },

    ),
    );
  }
}
