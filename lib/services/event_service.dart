// lib/services/event_service.dart

import '../models/event_model.dart';
import '../database/event_database_helper.dart';

class EventService {
  static final EventService _instance = EventService._internal();
  factory EventService() => _instance;
  EventService._internal();

  final EventDatabaseHelper _eventDatabaseHelper = EventDatabaseHelper();

  // Supported timezones with their display names and UTC offsets
  static const Map<String, String> _timezoneDisplayNames = {
    'WIB': 'WIB (UTC+7)',
    'WITA': 'WITA (UTC+8)',
    'WIT': 'WIT (UTC+9)',
    'London': 'London Time (UTC+0/+1)',
  };

  // Timezone UTC offsets in hours
  static const Map<String, int> _timezoneOffsets = {
    'WIB': 7,
    'WITA': 8,
    'WIT': 9,
    'London': 0, // Simplified - doesn't account for DST
  };

  // Get available timezones for UI
  static List<String> getAvailableTimezones() {
    return _timezoneDisplayNames.keys.toList();
  }

  static String getTimezoneDisplayName(String timezone) {
    return _timezoneDisplayNames[timezone] ?? timezone;
  }

  // Format event datetime for display
  String formatEventDateTime(Event event) {
    try {
      // Convert UTC time to the event's original timezone
      final convertedDateTime = _convertToTimezone(event.eventDateTime, event.timezone);
      return _formatDateTime(convertedDateTime, event.timezone);
    } catch (e) {
      return 'Invalid date/time';
    }
  }

  // Format event datetime for display in a different timezone
  String formatEventDateTimeInTimezone(Event event, String displayTimezone) {
    try {
      // Convert UTC time to the display timezone
      final convertedDateTime = _convertToTimezone(event.eventDateTime, displayTimezone);
      return _formatDateTime(convertedDateTime, displayTimezone);
    } catch (e) {
      return 'Invalid date/time';
    }
  }

  // Convert UTC DateTime to specified timezone
  DateTime _convertToTimezone(DateTime utcDateTime, String timezone) {
    final offset = _timezoneOffsets[timezone] ?? 0;
    return utcDateTime.add(Duration(hours: offset));
  }

  String _formatDateTime(DateTime dateTime, String timezone) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final day = dateTime.day;
    final month = months[dateTime.month - 1];
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final timezoneDisplay = _timezoneDisplayNames[timezone]?.split(' ')[0] ?? timezone;
    
    return '$day $month $year, $hour:$minute $timezoneDisplay';
  }

  // Get relative time string (e.g., "in 2 days", "3 hours ago")
  String getRelativeTimeString(Event event, {String? displayTimezone}) {
    try {
      final now = DateTime.now().toUtc();
      final eventTime = event.eventDateTime;
      final difference = eventTime.difference(now);
      
      if (difference.isNegative) {
        // Past event
        final absDiff = difference.abs();
        if (absDiff.inDays > 0) {
          return '${absDiff.inDays} day${absDiff.inDays > 1 ? 's' : ''} ago';
        } else if (absDiff.inHours > 0) {
          return '${absDiff.inHours} hour${absDiff.inHours > 1 ? 's' : ''} ago';
        } else if (absDiff.inMinutes > 0) {
          return '${absDiff.inMinutes} minute${absDiff.inMinutes > 1 ? 's' : ''} ago';
        } else {
          return 'Just now';
        }
      } else {
        // Future event
        if (difference.inDays > 0) {
          return 'in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
        } else if (difference.inHours > 0) {
          return 'in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
        } else if (difference.inMinutes > 0) {
          return 'in ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
        } else {
          return 'Starting now';
        }
      }
    } catch (e) {
      return 'Unknown time';
    }
  }

  // Check if event is happening soon (within 1 hour)
  bool isEventSoon(Event event) {
    final now = DateTime.now().toUtc();
    final timeDiff = event.eventDateTime.difference(now);
    return timeDiff.inMinutes > 0 && timeDiff.inMinutes <= 60;
  }

  // Check if event is happening today
  bool isEventToday(Event event, {String? timezone}) {
    try {
      final targetTimezone = timezone ?? event.timezone;
      final eventDateTime = _convertToTimezone(event.eventDateTime, targetTimezone);
      final todayInTimezone = _convertToTimezone(DateTime.now().toUtc(), targetTimezone);
      
      return eventDateTime.year == todayInTimezone.year &&
             eventDateTime.month == todayInTimezone.month &&
             eventDateTime.day == todayInTimezone.day;
    } catch (e) {
      // Fallback to simple comparison
      final eventDate = event.eventDateTime;
      final today = DateTime.now().toUtc();
      
      return eventDate.year == today.year &&
             eventDate.month == today.month &&
             eventDate.day == today.day;
    }
  }

  // Check if event is past
  bool isEventPast(Event event) {
    final now = DateTime.now().toUtc();
    return event.eventDateTime.isBefore(now);
  }

  // Create new event
  Future<EventResult> createEvent({
    required String title,
    String? description,
    required EventType eventType,
    required DateTime localDateTime,
    required String timezone,
    String? location,
    required int createdBy,
    String? imageUrl,
  }) async {
    try {
      // Validate input
      if (title.trim().isEmpty) {
        return EventResult.failure('Event title cannot be empty');
      }

      if (localDateTime.isBefore(DateTime.now())) {
        return EventResult.failure('Event date/time cannot be in the past');
      }

      final event = Event(
        title: title.trim(),
        description: description?.trim(),
        eventType: eventType,
        eventDateTime: localDateTime.toUtc(), // Store as UTC
        timezone: timezone,
        location: location?.trim(),
        createdBy: createdBy,
        createdAt: DateTime.now(),
        imageUrl: imageUrl,
      );

      final eventId = await _eventDatabaseHelper.insertEvent(event);
      
      if (eventId > 0) {
        final createdEvent = event.copyWith(id: eventId);
        return EventResult.success('Event created successfully', createdEvent);
      } else {
        return EventResult.failure('Failed to create event');
      }
    } catch (e) {
      print('Error creating event: $e');
      return EventResult.failure('An error occurred while creating the event');
    }
  }

  // Get all events
  Future<List<Event>> getAllEvents({int? userId}) async {
    return await _eventDatabaseHelper.getAllEvents(userId: userId);
  }

  // Get upcoming events
  Future<List<Event>> getUpcomingEvents({int? userId, int limit = 10}) async {
    return await _eventDatabaseHelper.getUpcomingEvents(userId: userId, limit: limit);
  }

  // Get events by type
  Future<List<Event>> getEventsByType(EventType eventType, {int? userId}) async {
    return await _eventDatabaseHelper.getEventsByType(eventType, userId: userId);
  }

  // Get event by ID
  Future<Event?> getEventById(int eventId, {int? userId}) async {
    return await _eventDatabaseHelper.getEventById(eventId, userId: userId);
  }

  // Subscribe to event
  Future<EventResult> subscribeToEvent(int eventId, int userId, {bool enableNotifications = false}) async {
    try {
      final result = await _eventDatabaseHelper.subscribeToEvent(
        eventId, 
        userId, 
        enableNotifications: enableNotifications
      );
      
      if (result > 0) {
        return EventResult.success('Successfully subscribed to event');
      } else {
        return EventResult.failure('Failed to subscribe to event');
      }
    } catch (e) {
      print('Error subscribing to event: $e');
      return EventResult.failure('An error occurred while subscribing');
    }
  }

  // Unsubscribe from event
  Future<EventResult> unsubscribeFromEvent(int eventId, int userId) async {
    try {
      final result = await _eventDatabaseHelper.unsubscribeFromEvent(eventId, userId);
      
      if (result > 0) {
        return EventResult.success('Successfully unsubscribed from event');
      } else {
        return EventResult.failure('Failed to unsubscribe from event');
      }
    } catch (e) {
      print('Error unsubscribing from event: $e');
      return EventResult.failure('An error occurred while unsubscribing');
    }
  }

  // Toggle notification for subscribed event
  Future<EventResult> toggleNotification(int eventId, int userId, bool enable) async {
    try {
      final result = await _eventDatabaseHelper.updateNotificationSetting(eventId, userId, enable);
      
      if (result > 0) {
        final message = enable ? 'Notifications enabled' : 'Notifications disabled';
        return EventResult.success(message);
      } else {
        return EventResult.failure('Failed to update notification setting');
      }
    } catch (e) {
      print('Error toggling notification: $e');
      return EventResult.failure('An error occurred while updating notification');
    }
  }

  // Get user's subscribed events
  Future<List<Event>> getUserSubscribedEvents(int userId) async {
    return await _eventDatabaseHelper.getUserSubscribedEvents(userId);
  }

  // Search events
  Future<List<Event>> searchEvents(String query, {int? userId}) async {
    return await _eventDatabaseHelper.searchEvents(query, userId: userId);
  }

  // Delete event (only by creator)
  Future<EventResult> deleteEvent(int eventId, int userId) async {
    try {
      // Check if user is the creator
      final event = await _eventDatabaseHelper.getEventById(eventId);
      if (event == null) {
        return EventResult.failure('Event not found');
      }

      if (event.createdBy != userId) {
        return EventResult.failure('You can only delete events you created');
      }

      final result = await _eventDatabaseHelper.deleteEvent(eventId);
      
      if (result > 0) {
        return EventResult.success('Event deleted successfully');
      } else {
        return EventResult.failure('Failed to delete event');
      }
    } catch (e) {
      print('Error deleting event: $e');
      return EventResult.failure('An error occurred while deleting the event');
    }
  }

  // Get events for today (with proper timezone handling)
  Future<List<Event>> getTodaysEvents(String userTimezone, {int? userId}) async {
    final events = await getAllEvents(userId: userId);
    final todayInTimezone = _convertToTimezone(DateTime.now().toUtc(), userTimezone);
    
    return events.where((event) {
      final eventInTimezone = _convertToTimezone(event.eventDateTime, userTimezone);
      return eventInTimezone.year == todayInTimezone.year &&
             eventInTimezone.month == todayInTimezone.month &&
             eventInTimezone.day == todayInTimezone.day;
    }).toList();
  }

  // Get events for this week (with proper timezone handling)
  Future<List<Event>> getThisWeeksEvents(String userTimezone, {int? userId}) async {
    final events = await getAllEvents(userId: userId);
    final nowInTimezone = _convertToTimezone(DateTime.now().toUtc(), userTimezone);
    final startOfWeek = nowInTimezone.subtract(Duration(days: nowInTimezone.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    
    return events.where((event) {
      final eventInTimezone = _convertToTimezone(event.eventDateTime, userTimezone);
      return eventInTimezone.isAfter(startOfWeek) && 
             eventInTimezone.isBefore(endOfWeek);
    }).toList();
  }

  // Get events by creator
  Future<List<Event>> getEventsByCreator(int userId) async {
    return await _eventDatabaseHelper.getEventsByCreator(userId);
  }

  // Get event subscription info
  Future<EventSubscription?> getEventSubscription(int eventId, int userId) async {
    return await _eventDatabaseHelper.getEventSubscription(eventId, userId);
  }

  // Get events with notifications enabled
  Future<List<Event>> getEventsWithNotificationsEnabled(int userId) async {
    return await _eventDatabaseHelper.getEventsWithNotificationsEnabled(userId);
  }

  // Get upcoming events with notifications
  Future<List<Event>> getUpcomingEventsWithNotifications(int userId) async {
    return await _eventDatabaseHelper.getUpcomingEventsWithNotifications(userId);
  }

  // Get event count
  Future<int> getEventCount() async {
    return await _eventDatabaseHelper.getEventCount();
  }

  // Utility methods for time calculations
  Duration getTimeUntilEvent(Event event) {
    final now = DateTime.now().toUtc();
    return event.eventDateTime.difference(now);
  }

  // Check if event is within specified duration
  bool isEventWithinDuration(Event event, Duration duration) {
    final timeUntil = getTimeUntilEvent(event);
    return timeUntil.inMilliseconds > 0 && timeUntil <= duration;
  }

  // Format duration until event
  String formatDurationUntilEvent(Event event) {
    final duration = getTimeUntilEvent(event);
    
    if (duration.isNegative) {
      return 'Event has passed';
    }
    
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''} remaining';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''} remaining';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''} remaining';
    } else {
      return 'Starting now!';
    }
  }

  // Get timezone offset for display
  String getTimezoneOffset(String timezone) {
    final offset = _timezoneOffsets[timezone] ?? 0;
    final sign = offset >= 0 ? '+' : '';
    return 'UTC$sign$offset';
  }

  // Get timezone offset in hours
  static int getTimezoneOffsetHours(String timezone) {
    return _timezoneOffsets[timezone] ?? 0;
  }
}

// Event result class
class EventResult {
  final bool success;
  final String message;
  final Event? event;

  EventResult._({
    required this.success,
    required this.message,
    this.event,
  });

  factory EventResult.success(String message, [Event? event]) {
    return EventResult._(
      success: true,
      message: message,
      event: event,
    );
  }

  factory EventResult.failure(String message) {
    return EventResult._(
      success: false,
      message: message,
    );
  }
}