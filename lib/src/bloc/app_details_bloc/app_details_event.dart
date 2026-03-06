import 'package:equatable/equatable.dart';

class AppDetailsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class GetTempleDetail extends AppDetailsEvent {
  final String templeId;
  final String latitude;
  final String longitude;

  GetTempleDetail({
    required this.templeId,
    required this.latitude,
    required this.longitude,
  });
}

class TempleNavigate extends AppDetailsEvent {
  final String templeId;
  final String latitude;
  final String longitude;

  TempleNavigate({
    required this.templeId,
    required this.latitude,
    required this.longitude,
  });
}

class FeaturedEvent extends AppDetailsEvent {}

class UpcomingEvent extends AppDetailsEvent {
  final String? date;

  UpcomingEvent([this.date = ""]);
}

class ReminderToggleEvent extends AppDetailsEvent {
  final String action;
  final String eventId;

  ReminderToggleEvent({required this.action, required this.eventId});
}

class CrowdLiveStatusEvent extends AppDetailsEvent {}

class GetZoneDetailEvent extends AppDetailsEvent {
  final String zoneCode;

  GetZoneDetailEvent({required this.zoneCode});
}

class QuickAlertsEvent extends AppDetailsEvent {}

class GetNotificationsEvent extends AppDetailsEvent {
  final String type;
  GetNotificationsEvent({required this.type});
}

class GetAiReflectionEvent extends AppDetailsEvent {}

class GetAiPromptEvent extends AppDetailsEvent {}

class CreateJournalEntryEvent extends AppDetailsEvent {
  final String title;
  final String notes;
   final String aiPrompt;
  final String aiReflection;
  final String mood;
  final String? imagePath;

  CreateJournalEntryEvent({
    required this.title,
    required this.notes,
    required this.aiPrompt,
    required this.aiReflection,
    required this.mood,
    this.imagePath,
  });
}

class GetJournalEntry extends AppDetailsEvent {
  final int page;

  GetJournalEntry({required this.page});
}

class GetJournalDetail extends AppDetailsEvent {
  final String id;

  GetJournalDetail({required this.id});
}
