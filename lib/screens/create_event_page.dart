import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../local_db.dart';
import 'package:intl/intl.dart'; // For formatting dates

class CreateEventPage extends StatefulWidget {
  final int userId; // Pass the current user ID for local DB association
  final String firebaseUserId; // Pass the Firebase User ID for Firestore association

  CreateEventPage({required this.userId, required this.firebaseUserId});

  @override
  _CreateEventPageState createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Save the event to both local DB and Firestore
  Future<void> _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      String name = _nameController.text;
      String date = _dateController.text;
      String location = _locationController.text;
      String description = _descriptionController.text;

      // Save to Local SQLite Database
      final db = await local_db().getInstance();
      int localEventId = await db!.insert('Events', {
        'name': name,
        'date': date,
        'location': location,
        'description': description,
        'userId': widget.userId,
      });

      // Save to Firestore
      CollectionReference eventsCollection =
      FirebaseFirestore.instance.collection('events');
      await eventsCollection.add({
        'name': name,
        'date': date,
        'location': location,
        'description': description,
        'userId': widget.firebaseUserId,
        'localEventId': localEventId, // Optional: Track local DB ID in Firestore
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Show Success and Navigate Back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event Created Successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Event')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Event Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an event name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _dateController,
                decoration: InputDecoration(labelText: 'Event Date'),
                readOnly: true,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _dateController.text =
                          DateFormat('yyyy-MM-dd').format(pickedDate);
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a date';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(labelText: 'Event Location'),
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Event Description'),
                maxLines: 3,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveEvent,
                child: Text('Save Event'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
