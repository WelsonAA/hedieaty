import '../local_db.dart';

class User {
  int? id;
  String name;
  String email;
  String passwordHashed;  // Not recommended to store passwords, consider storing only necessary info

  User({
    this.id,
    required this.name,
    required this.email,
    required this.passwordHashed,
  });

  // Convert a User object into a map for inserting into the database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'passwordHashed': passwordHashed,
    };
  }

  // Convert a map into a User object
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      passwordHashed: map['passwordHashed'],
    );
  }

  // Insert a user into the database
  Future<int> save() async {
    final db = await local_db().getInstance();
    if (id == null) {
      // Insert a new user
      return await db!.insert('Users', toMap());
    } else {
      // Update an existing user
      return await db!.update(
        'Users',
        toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // Fetch a user by email
  static Future<User?> getByEmail(String email) async {
    final db = await local_db().getInstance();
    var result = await db!.query(
      'Users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (result.isNotEmpty) {
      return User.fromMap(result.first);
    }
    return null;
  }
}
