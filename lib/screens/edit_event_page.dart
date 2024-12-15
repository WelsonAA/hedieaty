import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../local_db.dart';

class EditEventPage extends StatefulWidget {
  final Map<String, dynamic> event; // The event to be edited
  final String? firebaseEventId; // Firestore event ID (if applicable)
  final int? localEventId; // SQLite event ID (if applicable)

  EditEventPage({
    required this.event,
    this.firebaseEventId,
    this.localEventId,
  });

  @override
  _EditEventPageState createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dateController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.event['name']);
    _dateController = TextEditingController(text: widget.event['date']);
    _locationController =
        TextEditingController(text: widget.event['location']);
    _descriptionController =
        TextEditingController(text: widget.event['description']);
  }

  Future<void> _updateEvent() async {
    if (_formKey.currentState!.validate()) {
      try {
        final updatedEvent = {
          'name': _nameController.text,
          'date': _dateController.text,
          'location': _locationController.text,
          'description': _descriptionController.text,
        };

        // Update in SQLite
        if (widget.localEventId != null) {
          final db = await local_db().getInstance();
          await db!.update(
            'Events',
            updatedEvent,
            where: 'id = ?',
            whereArgs: [widget.localEventId],
          );
        }

        // Update in Firestore
        if (widget.firebaseEventId != null) {
          await FirebaseFirestore.instance
              .collection('events')
              .doc(widget.firebaseEventId)
              .update(updatedEvent);
        }

        Navigator.pop(context, true); // Notify parent page
      } catch (e) {
        print("Error updating event: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update event. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Event'),
      ),
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
              ),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(labelText: 'Event Location'),
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Event Description'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateEvent,
                child: Text('Update Event'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
