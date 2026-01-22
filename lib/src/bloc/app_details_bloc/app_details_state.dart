import 'package:equatable/equatable.dart';
import 'package:kumbha_path/src/models/featured_model.dart';
import 'package:kumbha_path/src/models/temple_detail.dart';
import 'package:kumbha_path/src/models/upcoming_events.dart';

enum AppDetailsStatus { initial, loading, success, failed, updating, updated }

class AppDetailsState extends Equatable {
  final AppDetailsStatus status;
  final TempleDetailsModel templeDetail;
  final EventDetailsModel eventDetailsModel;
  final List<EventSummaryModel> upcomingEvents;


  const AppDetailsState({
    this.status = AppDetailsStatus.initial,
    this.templeDetail = TempleDetailsModel.empty,
    this.eventDetailsModel = EventDetailsModel.empty,
    this.upcomingEvents = const [],
  });

  @override
  List<Object?> get props => [
    status,
    templeDetail,
    eventDetailsModel,
    upcomingEvents,
  ];

  AppDetailsState copyWith({
    AppDetailsStatus? status,
    TempleDetailsModel? templeDetail,
    EventDetailsModel? eventDetailsModel,
    List<EventSummaryModel>? upcomingEvents,
  }) {
    return AppDetailsState(
      status: status ?? this.status,
      templeDetail: templeDetail ?? this.templeDetail,
      eventDetailsModel: eventDetailsModel ?? this.eventDetailsModel,
      upcomingEvents: upcomingEvents ?? this.upcomingEvents,
    );
  }
}
