// lib/presenters/event_presenter.dart

import '../models/event_model.dart';
import '../services/event_service.dart';
import '../services/notification_service.dart';

// Base view interface
abstract class BaseEventView {
  void showLoading();
  void hideLoading();
  void showError(String message);
  void showSuccess(String message);
}

// Specific view interfaces
abstract class EventListView extends BaseEventView {
  void showEventList(List<Event> events);
  void showEmptyState();
}

abstract class EventDetailView extends BaseEventView {
  void showEventDetails(Event event);
  void updateSubscriptionStatus(bool isSubscribed, bool notificationEnabled);
}

abstract class CreateEventView extends BaseEventView {
  void onEventCreated(Event event);
  void showValidationError(String field, String error);
}

// Main presenter class
class EventPresenter {
  // View references
  EventListView? _listView;
  EventDetailView? _detailView;
  CreateEventView? _createView;

  // Services
  final EventService _eventService = EventService();
  final NotificationService _notificationService = NotificationService();

  // State management
  List<Event> _currentEvents = [];
  Event? _currentEvent;
  String _lastQuery = '';
  EventType? _lastEventType;
  int? _currentUserId;
  String _lastFilterType = 'upcoming'; // upcoming, all, today, subscribed, type

  // Constructor - initialize notification service
  EventPresenter() {
    _initializeNotifications();
  }

  // Initialize notification service
  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();
      print('Notification service initialized in presenter');
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  // Attach views
  void attachListView(EventListView view) => _listView = view;
  void attachDetailView(EventDetailView view) => _detailView = view;
  void attachCreateView(CreateEventView view) => _createView = view;

  // Detach views
  void detachListView() => _listView = null;
  void detachDetailView() => _detailView = null;
  void detachCreateView() => _createView = null;

  // Set current user for context
  void setCurrentUser(int? userId) {
    _currentUserId = userId;
    // Schedule notifications for new user
    if (userId != null) {
      _scheduleUserNotifications();
    }
  }

  // Schedule notifications for current user
  Future<void> _scheduleUserNotifications() async {
    try {
      await _notificationService.scheduleAllUserNotifications();
    } catch (e) {
      print('Error scheduling user notifications: $e');
    }
  }

  // Load all events
  Future<void> loadAllEvents() async {
    _lastFilterType = 'all';
    _lastQuery = '';
    _lastEventType = null;
    _listView?.showLoading();

    try {
      final events = await _eventService.getAllEvents(userId: _currentUserId);
      _currentEvents = events;

      _listView?.hideLoading();

      if (_currentEvents.isEmpty) {
        _listView?.showEmptyState();
      } else {
        _listView?.showEventList(_currentEvents);
      }
    } catch (e) {
      _listView?.hideLoading();
      _listView?.showError(_getErrorMessage(e));
    }
  }

  // Load upcoming events
  Future<void> loadUpcomingEvents({int limit = 50}) async {
    _lastFilterType = 'upcoming';
    _lastQuery = '';
    _lastEventType = null;
    _listView?.showLoading();

    try {
      final events = await _eventService.getUpcomingEvents(
        userId: _currentUserId,
        limit: limit,
      );
      _currentEvents = events;

      _listView?.hideLoading();

      if (_currentEvents.isEmpty) {
        _listView?.showEmptyState();
      } else {
        _listView?.showEventList(_currentEvents);
      }
    } catch (e) {
      _listView?.hideLoading();
      _listView?.showError(_getErrorMessage(e));
    }
  }

  // Load events by type
  Future<void> loadEventsByType(EventType eventType) async {
    _lastEventType = eventType;
    _lastFilterType = 'type';
    _lastQuery = '';
    _listView?.showLoading();

    try {
      final events = await _eventService.getEventsByType(eventType, userId: _currentUserId);
      _currentEvents = events;

      _listView?.hideLoading();

      if (_currentEvents.isEmpty) {
        _listView?.showEmptyState();
      } else {
        _listView?.showEventList(_currentEvents);
      }
    } catch (e) {
      _listView?.hideLoading();
      _listView?.showError(_getErrorMessage(e));
    }
  }

  // Search events
  Future<void> searchEvents(String query) async {
    if (query.trim().isEmpty) {
      await loadUpcomingEvents();
      return;
    }

    _lastQuery = query;
    _lastFilterType = 'search';
    _lastEventType = null;
    _listView?.showLoading();

    try {
      final events = await _eventService.searchEvents(query, userId: _currentUserId);
      _currentEvents = events;

      _listView?.hideLoading();

      if (_currentEvents.isEmpty) {
        _listView?.showEmptyState();
      } else {
        _listView?.showEventList(_currentEvents);
      }
    } catch (e) {
      _listView?.hideLoading();
      _listView?.showError(_getErrorMessage(e));
    }
  }

  // Load event details
  Future<void> loadEventDetails(int eventId) async {
    _detailView?.showLoading();

    try {
      final event = await _eventService.getEventById(eventId, userId: _currentUserId);
      
      if (event != null) {
        _currentEvent = event;
        _detailView?.hideLoading();
        _detailView?.showEventDetails(event);
      } else {
        _detailView?.hideLoading();
        _detailView?.showError('Event not found');
      }
    } catch (e) {
      _detailView?.hideLoading();
      _detailView?.showError(_getErrorMessage(e));
    }
  }

  // Create new event
  Future<void> createEvent({
    required String title,
    String? description,
    required EventType eventType,
    required DateTime localDateTime,
    required String timezone,
    String? location,
    String? imageUrl,
  }) async {
    if (_currentUserId == null) {
      _createView?.showError('User not logged in');
      return;
    }

    // Validate input
    if (title.trim().isEmpty) {
      _createView?.showValidationError('title', 'Event title is required');
      return;
    }

    if (localDateTime.isBefore(DateTime.now())) {
      _createView?.showValidationError('datetime', 'Event date/time cannot be in the past');
      return;
    }

    _createView?.showLoading();

    try {
      final result = await _eventService.createEvent(
        title: title,
        description: description,
        eventType: eventType,
        localDateTime: localDateTime,
        timezone: timezone,
        location: location,
        createdBy: _currentUserId!,
        imageUrl: imageUrl,
      );

      _createView?.hideLoading();

      if (result.success && result.event != null) {
        _createView?.showSuccess(result.message);
        _createView?.onEventCreated(result.event!);
        
        // Schedule notifications for all users who might be interested
        // (This is a simple implementation - in a real app, you might want to 
        // send push notifications to all users or only notify when they subscribe)
        print('Event created: ${result.event!.title}');
      } else {
        _createView?.showError(result.message);
      }
    } catch (e) {
      _createView?.hideLoading();
      _createView?.showError(_getErrorMessage(e));
    }
  }

  // ggggggSubscribe to event with notification handling
  // Subscribe to event with notification handling
  Future<void> subscribeToEvent(int eventId, {bool enableNotifications = false}) async {
    if (_currentUserId == null) {
      _detailView?.showError('User not logged in');
      return;
    }

    try {
      final result = await _eventService.subscribeToEvent(
        eventId,
        _currentUserId!,
        enableNotifications: enableNotifications,
      );

      if (result.success) {
        _detailView?.showSuccess(result.message);
        _detailView?.updateSubscriptionStatus(true, enableNotifications);
        
        // Update current event if it's the same
        if (_currentEvent?.id == eventId) {
          _currentEvent = _currentEvent?.copyWith(
            isSubscribed: true,
            notificationEnabled: enableNotifications,
          );
          
          // Handle notifications with error handling
          if (_currentEvent != null) {
            try {
              await _notificationService.onEventSubscribed(_currentEvent!, enableNotifications);
            } catch (e) {
              print('Error handling event subscription notification: $e');
              // Don't show error to user for notification issues
            }
          }
        }
      } else {
        _detailView?.showError(result.message);
      }
    } catch (e) {
      _detailView?.showError(_getErrorMessage(e));
    }
  }

  // Unsubscribe from event with notification handling
  Future<void> unsubscribeFromEvent(int eventId) async {
    if (_currentUserId == null) {
      _detailView?.showError('User not logged in');
      return;
    }

    try {
      final result = await _eventService.unsubscribeFromEvent(eventId, _currentUserId!);

      if (result.success) {
        _detailView?.showSuccess(result.message);
        _detailView?.updateSubscriptionStatus(false, false);
        
        // Update current event if it's the same
        if (_currentEvent?.id == eventId) {
          _currentEvent = _currentEvent?.copyWith(
            isSubscribed: false,
            notificationEnabled: false,
          );
          
          // Cancel notifications with error handling
          if (_currentEvent != null) {
            try {
              await _notificationService.onEventUnsubscribed(_currentEvent!);
            } catch (e) {
              print('Error handling event unsubscription notification: $e');
              // Don't show error to user for notification issues
            }
          }
        }
      } else {
        _detailView?.showError(result.message);
      }
    } catch (e) {
      _detailView?.showError(_getErrorMessage(e));
    }
  }

  // Toggle notification for subscribed event
  Future<void> toggleNotification(int eventId, bool enable) async {
    if (_currentUserId == null) {
      _detailView?.showError('User not logged in');
      return;
    }

    try {
      final result = await _eventService.toggleNotification(eventId, _currentUserId!, enable);

      if (result.success) {
        _detailView?.showSuccess(result.message);
        _detailView?.updateSubscriptionStatus(true, enable);
        
        // Update current event if it's the same
        if (_currentEvent?.id == eventId) {
          _currentEvent = _currentEvent?.copyWith(notificationEnabled: enable);
          
          // Handle notification scheduling with error handling
          if (_currentEvent != null) {
            try {
              await _notificationService.onNotificationToggled(_currentEvent!, enable);
            } catch (e) {
              print('Error handling notification toggle: $e');
              // Don't show error to user for notification issues
            }
          }
        }
      } else {
        _detailView?.showError(result.message);
      }
    } catch (e) {
      _detailView?.showError(_getErrorMessage(e));
    }
  }
  // Load user's subscribed events
  Future<void> loadUserSubscribedEvents() async {
    if (_currentUserId == null) {
      _listView?.showError('User not logged in');
      return;
    }

    _lastFilterType = 'subscribed';
    _lastQuery = '';
    _lastEventType = null;
    _listView?.showLoading();

    try {
      final events = await _eventService.getUserSubscribedEvents(_currentUserId!);
      _currentEvents = events;

      _listView?.hideLoading();

      if (_currentEvents.isEmpty) {
        _listView?.showEmptyState();
      } else {
        _listView?.showEventList(_currentEvents);
      }
    } catch (e) {
      _listView?.hideLoading();
      _listView?.showError(_getErrorMessage(e));
    }
  }

  // Delete event (only by creator)
  Future<void> deleteEvent(int eventId) async {
    if (_currentUserId == null) {
      _detailView?.showError('User not logged in');
      return;
    }

    try {
      final result = await _eventService.deleteEvent(eventId, _currentUserId!);

      if (result.success) {
        _detailView?.showSuccess(result.message);
        
        // Cancel all notifications for this event
        await _notificationService.cancelEventNotifications(eventId);
        
        // Refresh the current view
        await refresh();
      } else {
        _detailView?.showError(result.message);
      }
    } catch (e) {
      _detailView?.showError(_getErrorMessage(e));
    }
  }

  // Get today's events in user's timezone
  Future<void> loadTodaysEvents(String userTimezone) async {
    _lastFilterType = 'today';
    _lastQuery = '';
    _lastEventType = null;
    _listView?.showLoading();

    try {
      final events = await _eventService.getTodaysEvents(userTimezone, userId: _currentUserId);
      _currentEvents = events;

      _listView?.hideLoading();

      if (_currentEvents.isEmpty) {
        _listView?.showEmptyState();
      } else {
        _listView?.showEventList(_currentEvents);
      }
    } catch (e) {
      _listView?.hideLoading();
      _listView?.showError(_getErrorMessage(e));
    }
  }

  // Get this week's events
  Future<void> loadThisWeeksEvents(String userTimezone) async {
    _lastFilterType = 'week';
    _lastQuery = '';
    _lastEventType = null;
    _listView?.showLoading();

    try {
      final events = await _eventService.getThisWeeksEvents(userTimezone, userId: _currentUserId);
      _currentEvents = events;

      _listView?.hideLoading();

      if (_currentEvents.isEmpty) {
        _listView?.showEmptyState();
      } else {
        _listView?.showEventList(_currentEvents);
      }
    } catch (e) {
      _listView?.hideLoading();
      _listView?.showError(_getErrorMessage(e));
    }
  }

  // Load events by creator
  Future<void> loadEventsByCreator(int creatorId) async {
    _lastFilterType = 'creator';
    _lastQuery = '';
    _lastEventType = null;
    _listView?.showLoading();

    try {
      final events = await _eventService.getEventsByCreator(creatorId);
      _currentEvents = events;

      _listView?.hideLoading();

      if (_currentEvents.isEmpty) {
        _listView?.showEmptyState();
      } else {
        _listView?.showEventList(_currentEvents);
      }
    } catch (e) {
      _listView?.hideLoading();
      _listView?.showError(_getErrorMessage(e));
    }
  }

  // Load events with notifications enabled (for notification management)
  Future<void> loadEventsWithNotifications() async {
    if (_currentUserId == null) {
      _listView?.showError('User not logged in');
      return;
    }

    _lastFilterType = 'notifications';
    _lastQuery = '';
    _lastEventType = null;
    _listView?.showLoading();

    try {
      final events = await _eventService.getEventsWithNotificationsEnabled(_currentUserId!);
      _currentEvents = events;

      _listView?.hideLoading();

      if (_currentEvents.isEmpty) {
        _listView?.showEmptyState();
      } else {
        _listView?.showEventList(_currentEvents);
      }
    } catch (e) {
      _listView?.hideLoading();
      _listView?.showError(_getErrorMessage(e));
    }
  }

  // Refresh current view
  Future<void> refresh() async {
    switch (_lastFilterType) {
      case 'all':
        await loadAllEvents();
        break;
      case 'upcoming':
        await loadUpcomingEvents();
        break;
      case 'today':
        await loadTodaysEvents('WIB'); // Default timezone, should be passed from UI
        break;
      case 'week':
        await loadThisWeeksEvents('WIB'); // Default timezone, should be passed from UI
        break;
      case 'subscribed':
        await loadUserSubscribedEvents();
        break;
      case 'notifications':
        await loadEventsWithNotifications();
        break;
      case 'type':
        if (_lastEventType != null) {
          await loadEventsByType(_lastEventType!);
        } else {
          await loadUpcomingEvents();
        }
        break;
      case 'search':
        if (_lastQuery.isNotEmpty) {
          await searchEvents(_lastQuery);
        } else {
          await loadUpcomingEvents();
        }
        break;
      case 'creator':
        if (_currentUserId != null) {
          await loadEventsByCreator(_currentUserId!);
        } else {
          await loadUpcomingEvents();
        }
        break;
      default:
        await loadUpcomingEvents();
        break;
    }
  }

  // Update event (for editing)
  Future<void> updateEvent(Event event) async {
    if (_currentUserId == null) {
      _detailView?.showError('User not logged in');
      return;
    }

    if (event.createdBy != _currentUserId) {
      _detailView?.showError('You can only edit events you created');
      return;
    }

    try {
      // Note: You'll need to add updateEvent method to EventService
      // For now, this is a placeholder for future implementation
      _detailView?.showSuccess('Event updated successfully');
      _currentEvent = event;
      _detailView?.showEventDetails(event);
    } catch (e) {
      _detailView?.showError(_getErrorMessage(e));
    }
  }

  // Notification management methods
  
  // Test notification (for debugging)
  Future<void> testNotification(Event event) async {
    try {
      await _notificationService.showImmediateNotification(
        title: '🎵 Test Notification',
        body: 'This is a test notification for ${event.title}',
        payload: event.id.toString(),
      );
      _detailView?.showSuccess('Test notification sent!');
    } catch (e) {
      _detailView?.showError('Failed to send test notification: ${_getErrorMessage(e)}');
    }
  }

  // Get notification statistics
  Future<Map<String, int>> getNotificationStats() async {
    try {
      return await _notificationService.getNotificationStats();
    } catch (e) {
      print('Error getting notification stats: $e');
      return {'pending': 0, 'subscribed': 0};
    }
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      return await _notificationService.areNotificationsEnabled();
    } catch (e) {
      print('Error checking notification permissions: $e');
      return false;
    }
  }

  // Reschedule all notifications (useful after app restart or settings change)
  Future<void> rescheduleAllNotifications() async {
    try {
      await _notificationService.rescheduleAllNotifications();
      _listView?.showSuccess('Notifications rescheduled successfully');
    } catch (e) {
      _listView?.showError('Failed to reschedule notifications: ${_getErrorMessage(e)}');
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notificationService.cancelAllNotifications();
      _listView?.showSuccess('All notifications cancelled');
    } catch (e) {
      _listView?.showError('Failed to cancel notifications: ${_getErrorMessage(e)}');
    }
  }

  // Initialize notifications on app start
  Future<void> initializeNotifications() async {
    try {
      await _notificationService.initialize();
      if (_currentUserId != null) {
        await _scheduleUserNotifications();
      }
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  // Utility methods
  String _getErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '');
    }
    return 'An unexpected error occurred';
  }

  // Format event datetime for display
  String formatEventDateTime(Event event) {
    return _eventService.formatEventDateTime(event);
  }

  // Format event datetime in specific timezone
  String formatEventDateTimeInTimezone(Event event, String timezone) {
    return _eventService.formatEventDateTimeInTimezone(event, timezone);
  }

  // Get relative time string
  String getRelativeTimeString(Event event) {
    return _eventService.getRelativeTimeString(event);
  }

  // Check if event is happening soon
  bool isEventSoon(Event event) {
    return _eventService.isEventSoon(event);
  }

  // Check if event is today
  bool isEventToday(Event event, {String? timezone}) {
    return _eventService.isEventToday(event, timezone: timezone);
  }

  // Check if event is past
  bool isEventPast(Event event) {
    return _eventService.isEventPast(event);
  }

  // Get time until event
  Duration getTimeUntilEvent(Event event) {
    return _eventService.getTimeUntilEvent(event);
  }

  // Format duration until event
  String formatDurationUntilEvent(Event event) {
    return _eventService.formatDurationUntilEvent(event);
  }

  // Check if event is within specified duration
  bool isEventWithinDuration(Event event, Duration duration) {
    return _eventService.isEventWithinDuration(event, duration);
  }

  // Get timezone offset
  String getTimezoneOffset(String timezone) {
    return _eventService.getTimezoneOffset(timezone);
  }

  // Sort events by date
  void sortEventsByDate({bool ascending = true}) {
    _currentEvents.sort((a, b) {
      return ascending 
        ? a.eventDateTime.compareTo(b.eventDateTime)
        : b.eventDateTime.compareTo(a.eventDateTime);
    });
    _listView?.showEventList(_currentEvents);
  }

  // Sort events by title
  void sortEventsByTitle({bool ascending = true}) {
    _currentEvents.sort((a, b) {
      return ascending 
        ? a.title.compareTo(b.title)
        : b.title.compareTo(a.title);
    });
    _listView?.showEventList(_currentEvents);
  }

  // Filter current events by type
  void filterCurrentEventsByType(EventType? eventType) {
    if (eventType == null) {
      // Show all current events
      _listView?.showEventList(_currentEvents);
      return;
    }

    final filteredEvents = _currentEvents.where((event) => event.eventType == eventType).toList();
    _listView?.showEventList(filteredEvents);
  }

  // Get event statistics
  Map<String, int> getEventStatistics() {
    final stats = <String, int>{};
    stats['total'] = _currentEvents.length;
    stats['upcoming'] = _currentEvents.where((e) => !isEventPast(e)).length;
    stats['past'] = _currentEvents.where((e) => isEventPast(e)).length;
    stats['subscribed'] = _currentEvents.where((e) => e.isSubscribed == true).length;
    stats['with_notifications'] = _currentEvents.where((e) => e.notificationEnabled == true).length;
    
    // Count by event type
    for (final type in EventType.values) {
      final count = _currentEvents.where((e) => e.eventType == type).length;
      stats[type.name] = count;
    }
    
    return stats;
  }

  // Cleanup method - should be called when user logs out
  Future<void> cleanup() async {
    try {
      // Cancel all notifications for the current user
      if (_currentUserId != null) {
        await _notificationService.cancelAllNotifications();
      }
      
      // Clear current state
      _currentEvents.clear();
      _currentEvent = null;
      _currentUserId = null;
      _lastQuery = '';
      _lastEventType = null;
      _lastFilterType = 'upcoming';
      
      print('Event presenter cleaned up successfully');
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }

  // Getters
  List<Event> get currentEvents => _currentEvents;
  Event? get currentEvent => _currentEvent;
  EventService get eventService => _eventService;
  NotificationService get notificationService => _notificationService;
  String get lastQuery => _lastQuery;
  EventType? get lastEventType => _lastEventType;
  String get lastFilterType => _lastFilterType;
  int? get currentUserId => _currentUserId;
  
  // Check if presenter has events loaded
  bool get hasEvents => _currentEvents.isNotEmpty;
  
  // Check if current view is filtered
  bool get isFiltered => _lastQuery.isNotEmpty || _lastEventType != null || _lastFilterType != 'upcoming';
}