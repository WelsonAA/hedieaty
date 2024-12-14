import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class local_db {
  static Database? mydb;
  static const int Version = 1;
  Future<Database?> getInstance() async {
    if (mydb==null){
      mydb = await initiate_db();
    }
    return mydb;
  }
  initiate_db() async {
    String db_destination = await getDatabasesPath();
    String db_path = join(db_destination, 'local_db.db');
    Database db = await openDatabase(
      db_path,
      version: Version,
      onCreate: (db, version) {
        db.execute('''
        CREATE TABLE Accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,  -- Integer ID with auto-increment
          name TEXT NOT NULL,                    -- User's full name
          email TEXT NOT NULL UNIQUE             -- User's email (should be unique)
        );
      '''); // Removed trailing comma

        db.execute('''
        CREATE TABLE Events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,  -- Integer event ID with auto-increment
          name TEXT NOT NULL,                    -- Event name (e.g., birthday, wedding, etc.)
          date TEXT NOT NULL,                    -- Event date (could be in ISO format or Unix timestamp)
          location TEXT,                         -- Event location
          description TEXT,                      -- Description of the event
          userId INTEGER,                        -- Foreign key reference to the user who created the event
          FOREIGN KEY (userId) REFERENCES Accounts(id) -- Link to Accounts table
        );
      '''); // Removed trailing comma

        db.execute('''
        CREATE TABLE Gifts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,  -- Integer gift ID with auto-increment
          name TEXT NOT NULL,                    -- Name of the gift
          description TEXT,                      -- Description of the gift
          category TEXT,                         -- Category of the gift (e.g., electronics, books)
          price REAL,                            -- Price of the gift
          status TEXT NOT NULL CHECK(status IN ('available', 'pledged', 'purchased')),  -- ENUM-like status
          eventId INTEGER,                       -- Foreign key reference to the event associated with the gift
          pledgerId INTEGER,                     -- Foreign key reference to the user who pledged the gift
          image TEXT,
          FOREIGN KEY (eventId) REFERENCES Events(id),  -- Link to Events table
          FOREIGN KEY (pledgerId) REFERENCES Accounts(id) -- Link to Accounts table
        );
      '''); // Removed trailing comma

        db.execute('''
        CREATE TABLE User_Friends (
          userId INTEGER,                        -- User's ID
          friendId INTEGER,                      -- Friend's ID
          PRIMARY KEY (userId, friendId),        -- Composite primary key (user-friend relationship)
          FOREIGN KEY (userId) REFERENCES Accounts(id),  -- Reference to Accounts table
          FOREIGN KEY (friendId) REFERENCES Accounts(id) -- Reference to Accounts table
        );
      '''); // Removed trailing comma

        print("Database has been created");
        },
    );
    return db;
  }
  writing(sql) async{
    Database? variable = await getInstance();
    var response = variable!.rawInsert(sql);
    return response;
  }
  reading(sql) async{
    Database? variable = await getInstance();
    var response = variable!.rawQuery(sql);
    return response;
  }
  updating(sql) async{
    Database? variable = await getInstance();
    var response = variable!.rawUpdate(sql);
    return response;
  }
  deleting(sql) async{
    Database? variable = await getInstance();
    var response = variable!.rawDelete(sql);
    return response;
  }
  checking(sql) async{
    String db_destination = await getDatabasesPath();
    String db_path = join(db_destination, 'local_db.db');
    await databaseExists(db_path) ? print("it exists") : print("hardluck");
  }
  resetting() async {
    String db_destination = await getDatabasesPath();
    String db_path = join(db_destination, 'local_db.db');
    await deleteDatabase(db_path); // Deletes the existing database
    print("Database reset. Reinitializing...");
    await initiate_db();
  }

}