// lib/models/event_model.dart

class Event {
  final int? id;
  final String title;
  final String? description;
  final EventType eventType;
  final DateTime eventDateTime; // Always stored in UTC
  final String timezone; // User's selected timezone
  final String? location;
  final int createdBy; // user_id
  final DateTime createdAt;
  final String? imageUrl;
  
  // Subscription info (when loaded with user context)
  final bool? isSubscribed;
  final bool? notificationEnabled;

  Event({
    this.id,
    required this.title,
    this.description,
    required this.eventType,
    required this.eventDateTime,
    required this.timezone,
    this.location,
    required this.createdBy,
    required this.createdAt,
    this.imageUrl,
    this.isSubscribed,
    this.notificationEnabled,
  });

  // Convert Event object to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'event_type': eventType.name,
      'event_date_time': eventDateTime.toUtc().toIso8601String(),
      'timezone': timezone,
      'location': location,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'image_url': imageUrl,
    };
  }

  // Create Event object from database Map
  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      eventType: EventType.fromString(map['event_type']),
      eventDateTime: DateTime.parse(map['event_date_time']).toUtc(),
      timezone: map['timezone'],
      location: map['location'],
      createdBy: map['created_by'],
      createdAt: DateTime.parse(map['created_at']),
      imageUrl: map['image_url'],
      isSubscribed: map['is_subscribed'] == 1,
      notificationEnabled: map['notification_enabled'] == 1,
    );
  }

  // Create a copy of Event with updated fields
  Event copyWith({
    int? id,
    String? title,
    String? description,
    EventType? eventType,
    DateTime? eventDateTime,
    String? timezone,
    String? location,
    int? createdBy,
    DateTime? createdAt,
    String? imageUrl,
    bool? isSubscribed,
    bool? notificationEnabled,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      eventType: eventType ?? this.eventType,
      eventDateTime: eventDateTime ?? this.eventDateTime,
      timezone: timezone ?? this.timezone,
      location: location ?? this.location,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
    );
  }

  @override
  String toString() {
    return 'Event{id: $id, title: $title, eventType: $eventType, eventDateTime: $eventDateTime, timezone: $timezone}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Event &&
        other.id == id &&
        other.title == title &&
        other.eventDateTime == eventDateTime;
  }

  @override
  int get hashCode {
    return id.hashCode ^ title.hashCode ^ eventDateTime.hashCode;
  }
}

enum EventType {
  vinylRelease,
  concert,
  listeningParty,
  albumLaunch,
  recordStoreDayEvent,
  vinylFair,
  musicFestival,
  other;

  String get displayName {
    switch (this) {
      case EventType.vinylRelease:
        return 'Vinyl Release';
      case EventType.concert:
        return 'Concert/Live Show';
      case EventType.listeningParty:
        return 'Listening Party';
      case EventType.albumLaunch:
        return 'Album Launch';
      case EventType.recordStoreDayEvent:
        return 'Record Store Day Event';
      case EventType.vinylFair:
        return 'Vinyl Fair/Market';
      case EventType.musicFestival:
        return 'Music Festival';
      case EventType.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case EventType.vinylRelease:
        return '💿';
      case EventType.concert:
        return '🎵';
      case EventType.listeningParty:
        return '🎧';
      case EventType.albumLaunch:
        return '🚀';
      case EventType.recordStoreDayEvent:
        return '🏪';
      case EventType.vinylFair:
        return '🛍️';
      case EventType.musicFestival:
        return '🎪';
      case EventType.other:
        return '📅';
    }
  }

  static EventType fromString(String type) {
    switch (type) {
      case 'vinylRelease':
        return EventType.vinylRelease;
      case 'concert':
        return EventType.concert;
      case 'listeningParty':
        return EventType.listeningParty;
      case 'albumLaunch':
        return EventType.albumLaunch;
      case 'recordStoreDayEvent':
        return EventType.recordStoreDayEvent;
      case 'vinylFair':
        return EventType.vinylFair;
      case 'musicFestival':
        return EventType.musicFestival;
      case 'other':
      default:
        return EventType.other;
    }
  }
}

class EventSubscription {
  final int? id;
  final int eventId;
  final int userId;
  final bool notificationEnabled;
  final DateTime subscribedAt;

  EventSubscription({
    this.id,
    required this.eventId,
    required this.userId,
    required this.notificationEnabled,
    required this.subscribedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'notification_enabled': notificationEnabled ? 1 : 0,
      'subscribed_at': subscribedAt.toIso8601String(),
    };
  }

  factory EventSubscription.fromMap(Map<String, dynamic> map) {
    return EventSubscription(
      id: map['id'],
      eventId: map['event_id'],
      userId: map['user_id'],
      notificationEnabled: map['notification_enabled'] == 1,
      subscribedAt: DateTime.parse(map['subscribed_at']),
    );
  }
}