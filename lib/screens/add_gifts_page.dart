import 'package:flutter/material.dart';
import '../local_db.dart';

class AddGiftsPage extends StatefulWidget {
  final int? eventId; // SQLite Event ID

  AddGiftsPage({this.eventId});

  @override
  _AddGiftsPageState createState() => _AddGiftsPageState();
}

class _AddGiftsPageState extends State<AddGiftsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();

  bool isSaving = false;

  Future<void> _saveGiftLocally() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        isSaving = true;
      });

      try {
        // Prepare gift data
        final giftData = {
          'name': _nameController.text,
          'description': _descriptionController.text,
          'category': _categoryController.text,
          'price': double.tryParse(_priceController.text) ?? 0.0,
          'status': 'available',
          'eventId': widget.eventId, // SQLite Event ID
          'pledgerId': null, // Initially no pledger
        };

        // Save to SQLite
        if (widget.eventId != null) {
          final db = await local_db().getInstance();
          await db!.insert('Gifts', giftData);
        }

        // Notify the parent page
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gift saved locally!')),
        );
      } catch (e) {
        print("Error saving gift locally: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save gift locally. Please try again.')),
        );
      } finally {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Gift'),
      ),
      body: isSaving
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Gift Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a gift name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
              ),
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(labelText: 'Category'),
              ),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null ||
                      value.isEmpty ||
                      double.tryParse(value) == null) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveGiftLocally,
                child: Text('Save Locally'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
