import 'package:flutter/material.dart';
import 'local_db.dart';
class HomePage extends StatelessWidget {

  final List<Map<String, dynamic>> friends = [
    {'name': 'Alice', 'profilePic': 'assets/alice.jpg', 'upcomingEvents': 1},
    {'name': 'Bob', 'profilePic': 'assets/bob.jpg', 'upcomingEvents': 0},
    // Add more friends as needed
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hedieaty - Friends List'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search Friends',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // Implement search functionality
              },
            ),
          ),
          // Friends List
          Expanded(
            child: ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: AssetImage(friends[index]['profilePic']),
                    ),
                    title: Text(friends[index]['name']),
                    subtitle: Text(friends[index]['upcomingEvents'] > 0
                        ? 'Upcoming Events: ${friends[index]['upcomingEvents']}'
                        : 'No Upcoming Events'),
                    onTap: () {
                      // Navigate to friend's gift lists
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to create event or gift list page
        },
        child: Icon(Icons.add),
        tooltip: 'Create Your Own Event/List',
      ),
    );
  }
}
