import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../local_db.dart';
import '../notifications_manager.dart';

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
      final db = await local_db().getInstance();

      QuerySnapshot giftsSnap = await FirebaseFirestore.instance
          .collection('gifts')
          .where('userId', isEqualTo: widget.friendId)
          .get();

      List<Map<String, dynamic>> localGifts = await db!.query(
        'Gifts',
        where: 'eventId = ?',
        whereArgs: [widget.friendId],
      );

      setState(() {
        giftLists = giftsSnap.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown Gift',
            'description': data['description'] ?? '',
            'category': data['category'] ?? '',
            'status': data['status'] ?? 'available',
            'pledgerId': data['pledgerId'] ?? null,
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

  Future<void> _updateGiftStatus(String giftId, String source, String newStatus) async {
    try {
      final db = await local_db().getInstance();
      User? currentUser = FirebaseAuth.instance.currentUser;

      // Fetch the gift details
      String? ownerId;
      String? giftName;
      if (source == 'Firestore') {
        DocumentSnapshot giftDoc = await FirebaseFirestore.instance.collection('gifts').doc(giftId).get();
        ownerId = giftDoc['userId'];
        giftName = giftDoc['name'];
      } else {
        List<Map<String, dynamic>> giftData = await db!.query(
          'Gifts',
          where: 'id = ?',
          whereArgs: [giftId],
        );
        if (giftData.isNotEmpty) {
          ownerId = giftData.first['userId'];
          giftName = giftData.first['name'];
        }
      }

      if (ownerId == null || currentUser == null)
        return;

      // Update Firestore
      if (source == 'Firestore') {
        await FirebaseFirestore.instance.collection('gifts').doc(giftId).update({
          'status': newStatus,
          'pledgerId': newStatus == 'available' ? null : currentUser.uid,
        });
      }

      // Update SQLite
      await db!.update(
        'Gifts',
        {
          'status': newStatus,
          'pledgerId': newStatus == 'available' ? null : currentUser.uid,
        },
        where: 'id = ?',
        whereArgs: [giftId],
      );

      // Fetch owner's device token
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
      if (userDoc.exists && userDoc['deviceToken'] != null) {
        String deviceToken = userDoc['deviceToken'];

        // Prepare notification details
        String action = newStatus == 'pledged'
            ? 'pledged'
            : newStatus == 'purchased'
            ? 'purchased'
            : 'unpledged';

        String notificationTitle = "Your gift was $action";
        String notificationBody = "${currentUser.displayName ?? 'A friend'} has $action your gift: $giftName";

        // Send the notification using FCMService
        await FCMService.sendNotification(
          token: deviceToken,
          title: notificationTitle,
          body: notificationBody,
          data: {"giftId": giftId, "action": action},
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newStatus == 'purchased' ? 'Gift marked as purchased!' : 'Gift updated successfully!')),
      );

      _fetchGiftLists();
    } catch (e) {
      print("Error updating gift status: $e");
    }
  }


  Future<void> _sendNotificationToUser(String userId, {required String title, required String body}) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc['deviceToken'] != null) {
        String deviceToken = userDoc['deviceToken'];

        final payload = {
          "to": deviceToken,
          "notification": {
            "title": title,
            "body": body,
          },
          "data": {
            "action": "gift_update",
            "userId": userId,
          },
        };

        final response = await http.post(
          Uri.parse('https://fcm.googleapis.com/fcm/send'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'key=YOUR_SERVER_KEY',
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200) {
          print("Notification sent successfully: $title - $body");
        } else {
          print("Error sending notification: ${response.body}");
        }
      }
    } catch (e) {
      print("Error sending notification: $e");
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
