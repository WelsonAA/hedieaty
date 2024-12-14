import '../local_db.dart';

class Account {
  int? id;
  String name;
  String email;

  Account({
    this.id,
    required this.name,
    required this.email,
  });

  // Convert an Account object into a map for inserting into the database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
    };
  }

  // Convert a map into an Account object
  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      name: map['name'],
      email: map['email'],
    );
  }

  // Insert an account into the local database
  Future<int> save() async {
    final db = await local_db().getInstance();
    if (id == null) {
      // Insert a new account
      return await db!.insert('Accounts', toMap());
    } else {
      // Update an existing account
      return await db!.update(
        'Accounts',
        toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // Fetch an account by email from the local database
  static Future<Account?> getByEmail(String email) async {
    final db = await local_db().getInstance();
    var result = await db!.query(
      'Accounts',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (result.isNotEmpty) {
      return Account.fromMap(result.first);
    }
    return null;
  }
}
