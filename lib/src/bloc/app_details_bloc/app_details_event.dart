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
