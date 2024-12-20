import 'package:flutter/material.dart';
import '../local_db.dart';

class EditGiftPage extends StatefulWidget {
  final int giftId; // SQLite Gift ID

  EditGiftPage({required this.giftId});

  @override
  _EditGiftPageState createState() => _EditGiftPageState();
}

class _EditGiftPageState extends State<EditGiftPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGiftDetails();
  }

  Future<void> _loadGiftDetails() async {
    try {
      final db = await local_db().getInstance();
      List<Map<String, dynamic>> result = await db!.query(
        'Gifts',
        where: 'id = ?',
        whereArgs: [widget.giftId],
      );

      if (result.isNotEmpty) {
        final gift = result.first;

        setState(() {
          _nameController.text = gift['name'] ?? '';
          _descriptionController.text = gift['description'] ?? '';
          _categoryController.text = gift['category'] ?? '';
          _priceController.text = gift['price']?.toString() ?? '';
          isLoading = false;
        });
      } else {
        throw Exception("Gift not found in the local database.");
      }
    } catch (e) {
      print("Error loading gift details: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load gift details. Please try again.')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateGift() async {
    if (_formKey.currentState!.validate()) {
      try {
        final db = await local_db().getInstance();
        await db!.update(
          'Gifts',
          {
            'name': _nameController.text,
            'description': _descriptionController.text,
            'category': _categoryController.text,
            'price': double.tryParse(_priceController.text) ?? 0.0,
          },
          where: 'id = ?',
          whereArgs: [widget.giftId],
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gift updated successfully!')),
        );

        Navigator.pop(context, true); // Indicate successful update
      } catch (e) {
        print("Error updating gift: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update gift. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Gift'),
      ),
      body: isLoading
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
                onPressed: _updateGift,
                child: Text('Update Gift'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
