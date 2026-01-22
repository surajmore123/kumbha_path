import 'package:equatable/equatable.dart';

class EventListModel extends Equatable {
  final int? count;
  final List<EventSummaryModel>? events;

  const EventListModel({
    this.count,
    this.events,
  });

  @override
  List<Object?> get props => [count, events];

  EventListModel copyWith({
    int? count,
    List<EventSummaryModel>? events,
  }) {
    return EventListModel(
      count: count ?? this.count,
      events: events ?? this.events,
    );
  }

  factory EventListModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    
    // Handle if data is a list directly or a map containing a list
    List<dynamic> list = [];
    if (data is List) {
      list = data;
    } else if (data is Map && data['events'] is List) {
      list = data['events'];
    }

    return EventListModel(
      count: list.length,
      events: list.map((e) => EventSummaryModel.fromJson(e)).toList(),
    );
  }

  static const empty = EventListModel(
    count: 0,
    events: [],
  );

  @override
  String toString() => '{count: $count, events: $events}';
}

class EventSummaryModel extends Equatable {
  final String? eventId;
  final String? eventName;
  final String? shortDescription;
  final String? description;
  final String? eventCategory;
  final String? eventSubtype;
  final String? eventDate;
  final String? startTime;
  final String? endTime;
  final bool? isAllDay;
  final String? locationType;
  final String? locationName;
  final String? priorityLevel;
  final String? expectedCrowdLevel;

  const EventSummaryModel({
    this.eventId,
    this.eventName,
    this.shortDescription,
    this.description,
    this.eventCategory,
    this.eventSubtype,
    this.eventDate,
    this.startTime,
    this.endTime,
    this.isAllDay,
    this.locationType,
    this.locationName,
    this.priorityLevel,
    this.expectedCrowdLevel,
  });

  @override
  List<Object?> get props => [
        eventId,
        eventName,
        shortDescription,
        description,
        eventCategory,
        eventSubtype,
        eventDate,
        startTime,
        endTime,
        isAllDay,
        locationType,
        locationName,
        priorityLevel,
        expectedCrowdLevel,
      ];

  EventSummaryModel copyWith({
    String? eventId,
    String? eventName,
    String? shortDescription,
    String? description,
    String? eventCategory,
    String? eventSubtype,
    String? eventDate,
    String? startTime,
    String? endTime,
    bool? isAllDay,
    String? locationType,
    String? locationName,
    String? priorityLevel,
    String? expectedCrowdLevel,
  }) {
    return EventSummaryModel(
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      shortDescription: shortDescription ?? this.shortDescription,
      description: description ?? this.description,
      eventCategory: eventCategory ?? this.eventCategory,
      eventSubtype: eventSubtype ?? this.eventSubtype,
      eventDate: eventDate ?? this.eventDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      locationType: locationType ?? this.locationType,
      locationName: locationName ?? this.locationName,
      priorityLevel: priorityLevel ?? this.priorityLevel,
      expectedCrowdLevel: expectedCrowdLevel ?? this.expectedCrowdLevel,
    );
  }

  factory EventSummaryModel.fromJson(Map<String, dynamic> json) {
    return EventSummaryModel(
      eventId: json['event_id'],
      eventName: json['event_name'],
      shortDescription: json['short_description'],
      description: json['description'],
      eventCategory: json['event_category'],
      eventSubtype: json['event_subtype'],
      eventDate: json['event_date'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      isAllDay: json['is_all_day'] ?? false,
      locationType: json['location_type'],
      locationName: json['location_name'],
      priorityLevel: json['priority_level'],
      expectedCrowdLevel: json['expected_crowd_level'],
    );
  }

  @override
  String toString() =>
      '{eventId: $eventId, eventName: $eventName, eventDate: $eventDate, crowdLevel: $expectedCrowdLevel}';
}
