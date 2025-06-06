// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../services/auth_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  final EventService _eventService = EventService();
  final AuthService _authService = AuthService();
  
  bool _isInitialized = false;
  bool _initializationInProgress = false;
  String? _lastError;

  // Initialize the notification service with comprehensive error handling
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_initializationInProgress) {
      // Wait for initialization to complete
      while (_initializationInProgress) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _initializationInProgress = true;
    _lastError = null;

    try {
      print('🔄 Starting notification service initialization...');
      
      // Initialize timezone data first
      try {
        tz.initializeTimeZones();
        print('✅ Timezone data initialized');
      } catch (e) {
        print('⚠️ Timezone initialization error: $e');
        _lastError = 'Timezone init failed: $e';
      }

      // Request permissions BEFORE initializing notifications (Android 13+)
      await _requestPermissionsFirst();

      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      print('🔄 Initializing Flutter Local Notifications...');
      final bool? initialized = await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      print('📱 Initialization result: $initialized');

      if (initialized == true || initialized == null) {
        // Check if we can actually use notifications
        final canUse = await _verifyNotificationCapability();
        
        if (canUse) {
          _isInitialized = true;
          print('✅ Notification service initialized successfully');
        } else {
          _lastError = 'Notification capability verification failed';
          print('❌ Notification capability verification failed');
        }
      } else {
        _lastError = 'Flutter Local Notifications initialization returned false';
        print('❌ Flutter Local Notifications initialization failed');
      }
    } catch (e) {
      _lastError = 'Initialization error: $e';
      print('❌ Notification service initialization error: $e');
    } finally {
      _initializationInProgress = false;
    }
  }

  // Request permissions first (especially important for Android 13+)
  Future<void> _requestPermissionsFirst() async {
    try {
      print('🔄 Requesting notification permissions...');
      
      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        final bool? granted = await androidImplementation.requestNotificationsPermission();
        print('📱 Android permission result: $granted');
        
        if (granted != true) {
          _lastError = 'Notification permissions denied';
          print('❌ Notification permissions denied');
        }
      } else {
        print('📱 Not running on Android, skipping Android-specific permissions');
      }
    } catch (e) {
      _lastError = 'Permission request error: $e';
      print('❌ Error requesting permissions: $e');
    }
  }

  // Verify that we can actually use notifications
  Future<bool> _verifyNotificationCapability() async {
    try {
      print('🔄 Verifying notification capability...');
      
      // Try to get pending notifications
      final pending = await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
      print('📱 Can access pending notifications: ${pending.length} found');
      
      // Check permissions
      final hasPermissions = await areNotificationsEnabled();
      print('📱 Has permissions: $hasPermissions');
      
      return true; // If we get here without errors, we're good
    } catch (e) {
      print('❌ Notification capability verification failed: $e');
      _lastError = 'Capability verification failed: $e';
      return false;
    }
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      try {
        final eventId = int.parse(payload);
        print('🔔 Notification tapped for event ID: $eventId');
        // TODO: Navigate to event detail page
      } catch (e) {
        print('❌ Error parsing notification payload: $e');
      }
    }
  }

  // Ensure initialization before any operation
  Future<bool> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _isInitialized;
  }

  // Show immediate notification (for testing)
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    print('🔄 Attempting to show immediate notification...');
    
    if (!await _ensureInitialized()) {
      throw Exception('Notification service not initialized: $_lastError');
    }

    try {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'vinyl_events_channel',
        'Vinyl Events',
        channelDescription: 'Notifications for vinyl events and releases',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      const DarwinNotificationDetails iosNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      print('🔔 Showing notification with ID: $notificationId');

      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      print('✅ Immediate notification sent successfully');
    } catch (e) {
      print('❌ Error showing immediate notification: $e');
      throw Exception('Failed to show notification: $e');
    }
  }

  // Schedule notification for an event
  Future<void> scheduleEventNotification(Event event) async {
    if (!await _ensureInitialized()) {
      print('❌ Cannot schedule notification - service not initialized: $_lastError');
      return;
    }

    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) return;

    try {
      // Calculate notification times
      final eventTime = event.eventDateTime;
      final now = DateTime.now().toUtc();

      // Schedule multiple notifications: 1 day before, 1 hour before, and at event time
      final notificationTimes = [
        eventTime.subtract(const Duration(days: 1)), // 1 day before
        eventTime.subtract(const Duration(hours: 1)), // 1 hour before
        eventTime, // At event time
      ];

      for (int i = 0; i < notificationTimes.length; i++) {
        final notificationTime = notificationTimes[i];
        
        // Only schedule future notifications
        if (notificationTime.isAfter(now)) {
          await _scheduleNotification(
            id: _generateNotificationId(event.id!, i),
            title: _getNotificationTitle(event, i),
            body: _getNotificationBody(event, i),
            scheduledTime: notificationTime,
            payload: event.id.toString(),
          );
        }
      }

      print('✅ Scheduled notifications for event: ${event.title}');
    } catch (e) {
      print('❌ Error scheduling event notification: $e');
    }
  }

  // Generate unique notification ID
  int _generateNotificationId(int eventId, int notificationType) {
    return int.parse('$eventId$notificationType');
  }

  // Get notification title based on timing
  String _getNotificationTitle(Event event, int notificationType) {
    switch (notificationType) {
      case 0: return '🎵 Event Reminder';
      case 1: return '⏰ Event Starting Soon';
      case 2: return '🎉 Event Started';
      default: return 'Event Notification';
    }
  }

  // Get notification body based on timing
  String _getNotificationBody(Event event, int notificationType) {
    switch (notificationType) {
      case 0: return '${event.title} is happening tomorrow! Don\'t forget to join.';
      case 1: return '${event.title} starts in 1 hour. Get ready!';
      case 2: return '${event.title} has started! Join now.';
      default: return event.title;
    }
  }

  // Schedule individual notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'vinyl_events_channel',
        'Vinyl Events',
        channelDescription: 'Notifications for vinyl events and releases',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      const DarwinNotificationDetails iosNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );

      final tz.TZDateTime scheduledTZTime = tz.TZDateTime.from(
        scheduledTime,
        tz.local,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTZTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      print('❌ Error scheduling individual notification: $e');
    }
  }

  // Cancel notifications for an event
  Future<void> cancelEventNotifications(int eventId) async {
    if (!await _ensureInitialized()) return;

    try {
      for (int i = 0; i < 3; i++) {
        final notificationId = _generateNotificationId(eventId, i);
        await _flutterLocalNotificationsPlugin.cancel(notificationId);
      }
      print('✅ Cancelled notifications for event ID: $eventId');
    } catch (e) {
      print('❌ Error cancelling event notifications: $e');
    }
  }

  // Update notifications when user subscribes to an event
  Future<void> onEventSubscribed(Event event, bool enableNotifications) async {
    try {
      if (enableNotifications) {
        await scheduleEventNotification(event);
      } else {
        await cancelEventNotifications(event.id!);
      }
    } catch (e) {
      print('❌ Error in onEventSubscribed: $e');
    }
  }

  // Update notifications when user unsubscribes from an event
  Future<void> onEventUnsubscribed(Event event) async {
    try {
      await cancelEventNotifications(event.id!);
    } catch (e) {
      print('❌ Error in onEventUnsubscribed: $e');
    }
  }

  // Update notifications when notification setting is toggled
  Future<void> onNotificationToggled(Event event, bool enabled) async {
    try {
      if (enabled) {
        await scheduleEventNotification(event);
      } else {
        await cancelEventNotifications(event.id!);
      }
    } catch (e) {
      print('❌ Error in onNotificationToggled: $e');
    }
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!await _ensureInitialized()) return [];

    try {
      return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      print('❌ Error getting pending notifications: $e');
      return [];
    }
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        final bool? granted = await androidImplementation.areNotificationsEnabled();
        return granted ?? false;
      }
      
      return true; // Assume enabled for iOS
    } catch (e) {
      print('❌ Error checking notification permissions: $e');
      return false;
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    if (!await _ensureInitialized()) return;

    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      print('✅ Cancelled all notifications');
    } catch (e) {
      print('❌ Error cancelling all notifications: $e');
    }
  }

  // Schedule notifications for all subscribed events with notifications enabled
  Future<void> scheduleAllUserNotifications() async {
    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) return;

    if (!await _ensureInitialized()) {
      print('❌ Cannot schedule user notifications - service not initialized: $_lastError');
      return;
    }

    try {
      final eventsWithNotifications = await _eventService
          .getUpcomingEventsWithNotifications(currentUser.id!);

      for (final event in eventsWithNotifications) {
        await scheduleEventNotification(event);
      }

      print('✅ Scheduled notifications for ${eventsWithNotifications.length} events');
    } catch (e) {
      print('❌ Error scheduling user notifications: $e');
    }
  }

  // Reschedule all notifications
  Future<void> rescheduleAllNotifications() async {
    try {
      await cancelAllNotifications();
      await scheduleAllUserNotifications();
    } catch (e) {
      print('❌ Error rescheduling all notifications: $e');
    }
  }

  // Get notification statistics
  Future<Map<String, int>> getNotificationStats() async {
    try {
      final pendingNotifications = await getPendingNotifications();
      final currentUser = _authService.getCurrentUser();
      
      if (currentUser == null) {
        return {'pending': pendingNotifications.length, 'subscribed': 0};
      }

      final subscribedEvents = await _eventService
          .getEventsWithNotificationsEnabled(currentUser.id!);

      return {
        'pending': pendingNotifications.length,
        'subscribed': subscribedEvents.length,
      };
    } catch (e) {
      print('❌ Error getting notification stats: $e');
      return {'pending': 0, 'subscribed': 0};
    }
  }

  // Getters
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;
}