// lib/database/event_database_helper.dart

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../models/event_model.dart';
import 'database_helper.dart';

class EventDatabaseHelper {
  static final EventDatabaseHelper _instance = EventDatabaseHelper._internal();
  factory EventDatabaseHelper() => _instance;
  EventDatabaseHelper._internal();

  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Get database instance
  Future<Database> get database async {
    return await _databaseHelper.database;
  }

  // Create event tables
  static Future<void> createEventTables(Database db) async {
    print('Creating event tables...');
    
    // Events table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        event_type TEXT NOT NULL,
        event_date_time TEXT NOT NULL,
        timezone TEXT NOT NULL,
        location TEXT,
        created_by INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        image_url TEXT,
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    // Event subscriptions table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS event_subscriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        notification_enabled INTEGER NOT NULL DEFAULT 0,
        subscribed_at TEXT NOT NULL,
        FOREIGN KEY (event_id) REFERENCES events (id),
        FOREIGN KEY (user_id) REFERENCES users (id),
        UNIQUE(event_id, user_id)
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_events_date ON events(event_date_time)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_events_creator ON events(created_by)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_subscriptions_user ON event_subscriptions(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_subscriptions_event ON event_subscriptions(event_id)');

    print('Event tables created successfully');
  }

  // Insert a new event
  Future<int> insertEvent(Event event) async {
    try {
      final db = await database;
      return await db.insert(
        'events',
        event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } catch (e) {
      print('Error inserting event: $e');
      rethrow;
    }
  }

  // Get all events (ordered by date)
  Future<List<Event>> getAllEvents({int? userId}) async {
    try {
      final db = await database;
      String query;
      List<dynamic> arguments = [];

      if (userId != null) {
        // Include subscription info for the user
        query = '''
          SELECT e.*, 
                 s.notification_enabled,
                 CASE WHEN s.user_id IS NOT NULL THEN 1 ELSE 0 END as is_subscribed
          FROM events e
          LEFT JOIN event_subscriptions s ON e.id = s.event_id AND s.user_id = ?
          ORDER BY e.event_date_time ASC
        ''';
        arguments = [userId];
      } else {
        query = 'SELECT * FROM events ORDER BY event_date_time ASC';
      }

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, arguments);
      return List.generate(maps.length, (i) => Event.fromMap(maps[i]));
    } catch (e) {
      print('Error getting all events: $e');
      return [];
    }
  }

  // Get upcoming events
  Future<List<Event>> getUpcomingEvents({int? userId, int limit = 10}) async {
    try {
      final db = await database;
      final now = DateTime.now().toUtc().toIso8601String();
      String query;
      List<dynamic> arguments;

      if (userId != null) {
        query = '''
          SELECT e.*, 
                 s.notification_enabled,
                 CASE WHEN s.user_id IS NOT NULL THEN 1 ELSE 0 END as is_subscribed
          FROM events e
          LEFT JOIN event_subscriptions s ON e.id = s.event_id AND s.user_id = ?
          WHERE e.event_date_time >= ?
          ORDER BY e.event_date_time ASC
          LIMIT ?
        ''';
        arguments = [userId, now, limit];
      } else {
        query = '''
          SELECT * FROM events 
          WHERE event_date_time >= ? 
          ORDER BY event_date_time ASC 
          LIMIT ?
        ''';
        arguments = [now, limit];
      }

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, arguments);
      return List.generate(maps.length, (i) => Event.fromMap(maps[i]));
    } catch (e) {
      print('Error getting upcoming events: $e');
      return [];
    }
  }

  // Get events by type
  Future<List<Event>> getEventsByType(EventType eventType, {int? userId}) async {
    try {
      final db = await database;
      String query;
      List<dynamic> arguments;

      if (userId != null) {
        query = '''
          SELECT e.*, 
                 s.notification_enabled,
                 CASE WHEN s.user_id IS NOT NULL THEN 1 ELSE 0 END as is_subscribed
          FROM events e
          LEFT JOIN event_subscriptions s ON e.id = s.event_id AND s.user_id = ?
          WHERE e.event_type = ?
          ORDER BY e.event_date_time ASC
        ''';
        arguments = [userId, eventType.name];
      } else {
        query = '''
          SELECT * FROM events 
          WHERE event_type = ? 
          ORDER BY event_date_time ASC
        ''';
        arguments = [eventType.name];
      }

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, arguments);
      return List.generate(maps.length, (i) => Event.fromMap(maps[i]));
    } catch (e) {
      print('Error getting events by type: $e');
      return [];
    }
  }

  // Get events created by a specific user
  Future<List<Event>> getEventsByCreator(int userId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'events',
        where: 'created_by = ?',
        whereArgs: [userId],
        orderBy: 'event_date_time ASC',
      );
      return List.generate(maps.length, (i) => Event.fromMap(maps[i]));
    } catch (e) {
      print('Error getting events by creator: $e');
      return [];
    }
  }

  // Get event by ID
  Future<Event?> getEventById(int eventId, {int? userId}) async {
    try {
      final db = await database;
      String query;
      List<dynamic> arguments;

      if (userId != null) {
        query = '''
          SELECT e.*, 
                 s.notification_enabled,
                 CASE WHEN s.user_id IS NOT NULL THEN 1 ELSE 0 END as is_subscribed
          FROM events e
          LEFT JOIN event_subscriptions s ON e.id = s.event_id AND s.user_id = ?
          WHERE e.id = ?
          LIMIT 1
        ''';
        arguments = [userId, eventId];
      } else {
        query = 'SELECT * FROM events WHERE id = ? LIMIT 1';
        arguments = [eventId];
      }

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, arguments);

      if (maps.isNotEmpty) {
        return Event.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Error getting event by ID: $e');
      return null;
    }
  }

  // Update event
  Future<int> updateEvent(Event event) async {
    try {
      final db = await database;
      return await db.update(
        'events',
        event.toMap(),
        where: 'id = ?',
        whereArgs: [event.id],
      );
    } catch (e) {
      print('Error updating event: $e');
      return 0;
    }
  }

  // Delete event
  Future<int> deleteEvent(int eventId) async {
    try {
      final db = await database;
      
      // First delete all subscriptions for this event
      await db.delete(
        'event_subscriptions',
        where: 'event_id = ?',
        whereArgs: [eventId],
      );
      
      // Then delete the event
      return await db.delete(
        'events',
        where: 'id = ?',
        whereArgs: [eventId],
      );
    } catch (e) {
      print('Error deleting event: $e');
      return 0;
    }
  }

  // Subscribe to event
  Future<int> subscribeToEvent(int eventId, int userId, {bool enableNotifications = false}) async {
    try {
      final db = await database;
      final subscription = EventSubscription(
        eventId: eventId,
        userId: userId,
        notificationEnabled: enableNotifications,
        subscribedAt: DateTime.now(),
      );

      return await db.insert(
        'event_subscriptions',
        subscription.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace, // Replace if already exists
      );
    } catch (e) {
      print('Error subscribing to event: $e');
      return 0;
    }
  }

  // Unsubscribe from event
  Future<int> unsubscribeFromEvent(int eventId, int userId) async {
    try {
      final db = await database;
      return await db.delete(
        'event_subscriptions',
        where: 'event_id = ? AND user_id = ?',
        whereArgs: [eventId, userId],
      );
    } catch (e) {
      print('Error unsubscribing from event: $e');
      return 0;
    }
  }

  // Update notification setting for subscription
  Future<int> updateNotificationSetting(int eventId, int userId, bool enableNotifications) async {
    try {
      final db = await database;
      return await db.update(
        'event_subscriptions',
        {'notification_enabled': enableNotifications ? 1 : 0},
        where: 'event_id = ? AND user_id = ?',
        whereArgs: [eventId, userId],
      );
    } catch (e) {
      print('Error updating notification setting: $e');
      return 0;
    }
  }

  // Get user's subscribed events
  Future<List<Event>> getUserSubscribedEvents(int userId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT e.*, s.notification_enabled, 1 as is_subscribed
        FROM events e
        INNER JOIN event_subscriptions s ON e.id = s.event_id
        WHERE s.user_id = ?
        ORDER BY e.event_date_time ASC
      ''', [userId]);
      
      return List.generate(maps.length, (i) => Event.fromMap(maps[i]));
    } catch (e) {
      print('Error getting user subscribed events: $e');
      return [];
    }
  }

  // Get subscription info
  Future<EventSubscription?> getEventSubscription(int eventId, int userId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'event_subscriptions',
        where: 'event_id = ? AND user_id = ?',
        whereArgs: [eventId, userId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return EventSubscription.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Error getting event subscription: $e');
      return null;
    }
  }

  // Search events
  Future<List<Event>> searchEvents(String query, {int? userId}) async {
    try {
      final db = await database;
      final searchQuery = '%$query%';
      String sql;
      List<dynamic> arguments;

      if (userId != null) {
        sql = '''
          SELECT e.*, 
                 s.notification_enabled,
                 CASE WHEN s.user_id IS NOT NULL THEN 1 ELSE 0 END as is_subscribed
          FROM events e
          LEFT JOIN event_subscriptions s ON e.id = s.event_id AND s.user_id = ?
          WHERE e.title LIKE ? OR e.description LIKE ? OR e.location LIKE ?
          ORDER BY e.event_date_time ASC
        ''';
        arguments = [userId, searchQuery, searchQuery, searchQuery];
      } else {
        sql = '''
          SELECT * FROM events 
          WHERE title LIKE ? OR description LIKE ? OR location LIKE ?
          ORDER BY event_date_time ASC
        ''';
        arguments = [searchQuery, searchQuery, searchQuery];
      }

      final List<Map<String, dynamic>> maps = await db.rawQuery(sql, arguments);
      return List.generate(maps.length, (i) => Event.fromMap(maps[i]));
    } catch (e) {
      print('Error searching events: $e');
      return [];
    }
  }

  // Get event count
  Future<int> getEventCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM events');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('Error getting event count: $e');
      return 0;
    }
  }

  // Get events by date range
  Future<List<Event>> getEventsByDateRange(DateTime startDate, DateTime endDate, {int? userId}) async {
    try {
      final db = await database;
      final startDateStr = startDate.toUtc().toIso8601String();
      final endDateStr = endDate.toUtc().toIso8601String();
      
      String query;
      List<dynamic> arguments;

      if (userId != null) {
        query = '''
          SELECT e.*, 
                 s.notification_enabled,
                 CASE WHEN s.user_id IS NOT NULL THEN 1 ELSE 0 END as is_subscribed
          FROM events e
          LEFT JOIN event_subscriptions s ON e.id = s.event_id AND s.user_id = ?
          WHERE e.event_date_time >= ? AND e.event_date_time <= ?
          ORDER BY e.event_date_time ASC
        ''';
        arguments = [userId, startDateStr, endDateStr];
      } else {
        query = '''
          SELECT * FROM events 
          WHERE event_date_time >= ? AND event_date_time <= ?
          ORDER BY event_date_time ASC
        ''';
        arguments = [startDateStr, endDateStr];
      }

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, arguments);
      return List.generate(maps.length, (i) => Event.fromMap(maps[i]));
    } catch (e) {
      print('Error getting events by date range: $e');
      return [];
    }
  }

  // Get events with notifications enabled for a user (for notification scheduling)
  Future<List<Event>> getEventsWithNotificationsEnabled(int userId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT e.*, s.notification_enabled, 1 as is_subscribed
        FROM events e
        INNER JOIN event_subscriptions s ON e.id = s.event_id
        WHERE s.user_id = ? AND s.notification_enabled = 1
        ORDER BY e.event_date_time ASC
      ''', [userId]);
      
      return List.generate(maps.length, (i) => Event.fromMap(maps[i]));
    } catch (e) {
      print('Error getting events with notifications enabled: $e');
      return [];
    }
  }

  // Get upcoming events with notifications for scheduling
  Future<List<Event>> getUpcomingEventsWithNotifications(int userId) async {
    try {
      final db = await database;
      final now = DateTime.now().toUtc().toIso8601String();
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT e.*, s.notification_enabled, 1 as is_subscribed
        FROM events e
        INNER JOIN event_subscriptions s ON e.id = s.event_id
        WHERE s.user_id = ? AND s.notification_enabled = 1 AND e.event_date_time >= ?
        ORDER BY e.event_date_time ASC
      ''', [userId, now]);
      
      return List.generate(maps.length, (i) => Event.fromMap(maps[i]));
    } catch (e) {
      print('Error getting upcoming events with notifications: $e');
      return [];
    }
  }

  // Get events happening today for a specific timezone
  Future<List<Event>> getEventsToday(String timezone, {int? userId}) async {
    try {
      final db = await database;
      
      // Calculate today's date range in UTC
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final startDateStr = startOfDay.toUtc().toIso8601String();
      final endDateStr = endOfDay.toUtc().toIso8601String();
      
      String query;
      List<dynamic> arguments;

      if (userId != null) {
        query = '''
          SELECT e.*, 
                 s.notification_enabled,
                 CASE WHEN s.user_id IS NOT NULL THEN 1 ELSE 0 END as is_subscribed
          FROM events e
          LEFT JOIN event_subscriptions s ON e.id = s.event_id AND s.user_id = ?
          WHERE e.event_date_time >= ? AND e.event_date_time < ?
          ORDER BY e.event_date_time ASC
        ''';
        arguments = [userId, startDateStr, endDateStr];
      } else {
        query = '''
          SELECT * FROM events 
          WHERE event_date_time >= ? AND event_date_time < ?
          ORDER BY event_date_time ASC
        ''';
        arguments = [startDateStr, endDateStr];
      }

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, arguments);
      return List.generate(maps.length, (i) => Event.fromMap(maps[i]));
    } catch (e) {
      print('Error getting today\'s events: $e');
      return [];
    }
  }

  // Get events happening this week
  Future<List<Event>> getEventsThisWeek({int? userId}) async {
    try {
      final db = await database;
      
      // Calculate this week's date range in UTC
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 7));
      
      final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      final endOfWeekDay = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);
      
      final startDateStr = startOfWeekDay.toUtc().toIso8601String();
      final endDateStr = endOfWeekDay.toUtc().toIso8601String();
      
      String query;
      List<dynamic> arguments;

      if (userId != null) {
        query = '''
          SELECT e.*, 
                 s.notification_enabled,
                 CASE WHEN s.user_id IS NOT NULL THEN 1 ELSE 0 END as is_subscribed
          FROM events e
          LEFT JOIN event_subscriptions s ON e.id = s.event_id AND s.user_id = ?
          WHERE e.event_date_time >= ? AND e.event_date_time < ?
          ORDER BY e.event_date_time ASC
        ''';
        arguments = [userId, startDateStr, endDateStr];
      } else {
        query = '''
          SELECT * FROM events 
          WHERE event_date_time >= ? AND event_date_time < ?
          ORDER BY event_date_time ASC
        ''';
        arguments = [startDateStr, endDateStr];
      }

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, arguments);
      return List.generate(maps.length, (i) => Event.fromMap(maps[i]));
    } catch (e) {
      print('Error getting this week\'s events: $e');
      return [];
    }
  }

  // Get past events
  Future<List<Event>> getPastEvents({int? userId, int limit = 20}) async {
    try {
      final db = await database;
      final now = DateTime.now().toUtc().toIso8601String();
      String query;
      List<dynamic> arguments;

      if (userId != null) {
        query = '''
          SELECT e.*, 
                 s.notification_enabled,
                 CASE WHEN s.user_id IS NOT NULL THEN 1 ELSE 0 END as is_subscribed
          FROM events e
          LEFT JOIN event_subscriptions s ON e.id = s.event_id AND s.user_id = ?
          WHERE e.event_date_time < ?
          ORDER BY e.event_date_time DESC
          LIMIT ?
        ''';
        arguments = [userId, now, limit];
      } else {
        query = '''
          SELECT * FROM events 
          WHERE event_date_time < ? 
          ORDER BY event_date_time DESC 
          LIMIT ?
        ''';
        arguments = [now, limit];
      }

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, arguments);
      return List.generate(maps.length, (i) => Event.fromMap(maps[i]));
    } catch (e) {
      print('Error getting past events: $e');
      return [];
    }
  }

  // Get subscription count for an event
  Future<int> getEventSubscriptionCount(int eventId) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM event_subscriptions WHERE event_id = ?',
        [eventId]
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('Error getting event subscription count: $e');
      return 0;
    }
  }

  // Get all subscriptions for a user
  Future<List<EventSubscription>> getUserSubscriptions(int userId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'event_subscriptions',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'subscribed_at DESC',
      );
      return List.generate(maps.length, (i) => EventSubscription.fromMap(maps[i]));
    } catch (e) {
      print('Error getting user subscriptions: $e');
      return [];
    }
  }

  // Clear old events (cleanup utility)
  Future<int> deleteEventsOlderThan(Duration duration) async {
    try {
      final db = await database;
      final cutoffDate = DateTime.now().subtract(duration).toUtc().toIso8601String();
      
      // First delete related subscriptions
      await db.rawDelete('''
        DELETE FROM event_subscriptions 
        WHERE event_id IN (
          SELECT id FROM events WHERE event_date_time < ?
        )
      ''', [cutoffDate]);
      
      // Then delete the events
      return await db.delete(
        'events',
        where: 'event_date_time < ?',
        whereArgs: [cutoffDate],
      );
    } catch (e) {
      print('Error deleting old events: $e');
      return 0;
    }
  }
}