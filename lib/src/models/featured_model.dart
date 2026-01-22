import 'package:equatable/equatable.dart';

class EventDetailsModel extends Equatable {
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

  const EventDetailsModel({
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

  EventDetailsModel copyWith({
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
    return EventDetailsModel(
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

  factory EventDetailsModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;

    return EventDetailsModel(
      eventId: data['event_id'] ?? "",
      eventName: data['event_name'] ?? "",
      shortDescription: data['short_description'] ?? "",
      description: data['description'] ?? "",
      eventCategory: data['event_category'] ?? "",
      eventSubtype: data['event_subtype'] ?? "",
      eventDate: data['event_date'] ?? "",
      startTime: data['start_time'] ?? "",
      endTime: data['end_time'] ?? "",
      isAllDay: data['is_all_day'] ?? false,
      locationType: data['location_type'] ?? "",
      locationName: data['location_name'] ?? "",
      priorityLevel: data['priority_level'] ?? "",
      expectedCrowdLevel: data['expected_crowd_level'] ?? "",
    );
  }

  static const empty = EventDetailsModel(
    eventId: "",
    eventName: "",
    shortDescription: "",
    description: "",
    eventCategory: "",
    eventSubtype: "",
    eventDate: "",
    startTime: "",
    endTime: "",
    isAllDay: false,
    locationType: "",
    locationName: "",
    priorityLevel: "",
    expectedCrowdLevel: "",
  );

  @override
  String toString() {
    return '{eventId: $eventId, eventName: $eventName, eventDate: $eventDate, locationName: $locationName, crowdLevel: $expectedCrowdLevel}';
  }
}
