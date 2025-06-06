// lib/database/database_helper.dart

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_model.dart';
import 'event_database_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'vinyl_store.db');
    
    return await openDatabase(
      path,
      version: 3, // Increased version for event tables
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    print('Creating database tables...');
    
    // Create users table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_login_at TEXT,
        profile_photo TEXT
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_username ON users(username)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_email ON users(email)');

    // Create event tables
    await EventDatabaseHelper.createEventTables(db);

    print('Database created successfully with user and event tables');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from version $oldVersion to $newVersion');
    
    if (oldVersion < 2) {
      // Add profile_photo column if upgrading from version 1
      try {
        await db.execute('ALTER TABLE users ADD COLUMN profile_photo TEXT');
        print('Added profile_photo column to users table');
      } catch (e) {
        print('Profile photo column might already exist: $e');
      }
    }
    
    if (oldVersion < 3) {
      // Add event tables if upgrading from version 2
      try {
        await EventDatabaseHelper.createEventTables(db);
        print('Added event tables');
      } catch (e) {
        print('Event tables might already exist: $e');
      }
    }
    
    print('Database upgraded from version $oldVersion to $newVersion');
  }

  // Insert a new user
  Future<int> insertUser(User user) async {
    try {
      print('DatabaseHelper: Attempting to insert user: ${user.username}');
      final db = await database;
      print('DatabaseHelper: Database instance obtained');
      
      final result = await db.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      
      print('DatabaseHelper: User inserted successfully with ID: $result');
      return result;
    } catch (e) {
      print('DatabaseHelper: Error inserting user: $e');
      print('DatabaseHelper: User data being inserted: ${user.toMap()}');
      rethrow;
    }
  }

  // Get user by username
  Future<User?> getUserByUsername(String username) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return User.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Error getting user by username: $e');
      return null;
    }
  }

  // Get user by email
  Future<User?> getUserByEmail(String email) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [email],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return User.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Error getting user by email: $e');
      return null;
    }
  }

  // Get user by ID
  Future<User?> getUserById(int id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return User.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  // Update user's last login time
  Future<int> updateLastLogin(int userId) async {
    try {
      final db = await database;
      return await db.update(
        'users',
        {'last_login_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      print('Error updating last login: $e');
      return 0;
    }
  }

  // Update user information
  Future<int> updateUser(User user) async {
    try {
      final db = await database;
      return await db.update(
        'users',
        user.toMap(),
        where: 'id = ?',
        whereArgs: [user.id],
      );
    } catch (e) {
      print('Error updating user: $e');
      return 0;
    }
  }

  // Update user profile photo
  Future<int> updateUserProfilePhoto(int userId, String? profilePhotoPath) async {
    try {
      final db = await database;
      return await db.update(
        'users',
        {'profile_photo': profilePhotoPath},
        where: 'id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      print('Error updating user profile photo: $e');
      return 0;
    }
  }

  // Delete user
  Future<int> deleteUser(int userId) async {
    try {
      final db = await database;
      return await db.delete(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      print('Error deleting user: $e');
      return 0;
    }
  }

  // Get all users (for admin purposes)
  Future<List<User>> getAllUsers() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('users');
      return List.generate(maps.length, (i) => User.fromMap(maps[i]));
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  // Check if username exists
  Future<bool> usernameExists(String username) async {
    try {
      final user = await getUserByUsername(username);
      return user != null;
    } catch (e) {
      print('Error checking if username exists: $e');
      return false;
    }
  }

  // Check if email exists
  Future<bool> emailExists(String email) async {
    try {
      final user = await getUserByEmail(email);
      return user != null;
    } catch (e) {
      print('Error checking if email exists: $e');
      return false;
    }
  }

  // Get user count
  Future<int> getUserCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM users');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('Error getting user count: $e');
      return 0;
    }
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Delete database (for testing purposes)
  Future<void> deleteDatabase() async {
    try {
      String path = join(await getDatabasesPath(), 'vinyl_store.db');
      await databaseFactory.deleteDatabase(path);
      _database = null;
      print('Database deleted successfully');
    } catch (e) {
      print('Error deleting database: $e');
      rethrow;
    }
  }
}