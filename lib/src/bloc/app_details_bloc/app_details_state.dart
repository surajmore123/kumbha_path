import 'package:equatable/equatable.dart';
import 'package:kumbha_path/src/models/featured_model.dart';
import 'package:kumbha_path/src/models/temple_detail.dart';
import 'package:kumbha_path/src/models/upcoming_events.dart';

enum AppDetailsStatus { initial, loading, success, failed, updating, updated,sending }

class AppDetailsState extends Equatable {
  final AppDetailsStatus status;
  final TempleDetailsModel templeDetail;
  final EventDetailsModel eventDetailsModel;
  final List<EventSummaryModel> upcomingEvents;
   String? reminderMsg;
 final Map<String, bool> reminderStatus;





  AppDetailsState({
  this.status = AppDetailsStatus.initial,
  this.templeDetail = TempleDetailsModel.empty,
  this.eventDetailsModel = EventDetailsModel.empty,
  this.upcomingEvents = const [],
  this.reminderMsg,
  this.reminderStatus = const {},
});


  @override
  List<Object?> get props => [
    status,
    templeDetail,
    eventDetailsModel,
    upcomingEvents,
    reminderMsg,
    reminderStatus
  ];

  AppDetailsState copyWith({
    AppDetailsStatus? status,
    TempleDetailsModel? templeDetail,
    EventDetailsModel? eventDetailsModel,
    List<EventSummaryModel>? upcomingEvents,
    String? reminderMsg,
    bool? reminderEnabled,
    Map<String, bool>? reminderStatus,
  }) {
    return AppDetailsState(
      status: status ?? this.status,
      templeDetail: templeDetail ?? this.templeDetail,
      eventDetailsModel: eventDetailsModel ?? this.eventDetailsModel,
      upcomingEvents: upcomingEvents ?? this.upcomingEvents,
      reminderMsg: reminderMsg?? this.reminderMsg,
     reminderStatus: reminderStatus ?? this.reminderStatus,
    );
  }
}
