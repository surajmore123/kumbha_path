import 'package:equatable/equatable.dart';
import 'package:kumbha_path/src/models/featured_model.dart';
import 'package:kumbha_path/src/models/notification_model.dart';
import 'package:kumbha_path/src/models/quick_alert.dart';
import 'package:kumbha_path/src/models/temple_detail.dart';
import 'package:kumbha_path/src/models/upcoming_events.dart';
import 'package:kumbha_path/src/models/zone_detail.dart';
import 'package:kumbha_path/src/models/zone_model.dart';

enum AppDetailsStatus { initial, loading, success, failed, updating, updated,sending }

class AppDetailsState extends Equatable {
  final AppDetailsStatus status;
  final TempleDetailsModel templeDetail;
  final EventDetailsModel eventDetailsModel;
  final List<EventSummaryModel> upcomingEvents;
   String? reminderMsg;
 final Map<String, bool> reminderStatus;
 final List<ZoneModel> zoneModel;
 final List<AlertDetailsModel> quickAlerts;
 final ZoneLiveDetailsModel zoneDetails;
 List<NotificationModel> notificationList;





  AppDetailsState({
  this.status = AppDetailsStatus.initial,
  this.templeDetail = TempleDetailsModel.empty,
  this.eventDetailsModel = EventDetailsModel.empty,
  this.zoneDetails = ZoneLiveDetailsModel.empty,
  this.zoneModel = const [] ,
  this.upcomingEvents = const [],
  this.reminderMsg,
  this.reminderStatus = const {},
  this.quickAlerts = const [],
  this.notificationList = const [],
});


  @override
  List<Object?> get props => [
    status,
    templeDetail,
    eventDetailsModel,
    upcomingEvents,
    reminderMsg,
    reminderStatus,
    zoneModel,
    zoneDetails,
    quickAlerts,
    notificationList,
  ];

  AppDetailsState copyWith({
    AppDetailsStatus? status,
    TempleDetailsModel? templeDetail,
    EventDetailsModel? eventDetailsModel,
    List<EventSummaryModel>? upcomingEvents,
    String? reminderMsg,
    bool? reminderEnabled,
    Map<String, bool>? reminderStatus,
   List<ZoneModel>? zoneModel,
    ZoneLiveDetailsModel? zoneDetails,
    List<AlertDetailsModel>? quickAlerts,
    List<NotificationModel>? notificationList,
  }) {
    return AppDetailsState(
      status: status ?? this.status,
      templeDetail: templeDetail ?? this.templeDetail,
      eventDetailsModel: eventDetailsModel ?? this.eventDetailsModel,
      upcomingEvents: upcomingEvents ?? this.upcomingEvents,
      reminderMsg: reminderMsg?? this.reminderMsg,
     reminderStatus: reminderStatus ?? this.reminderStatus,
      zoneModel: zoneModel ?? this.zoneModel,
      zoneDetails: zoneDetails ?? this.zoneDetails,
      quickAlerts: quickAlerts ?? this.quickAlerts,
      notificationList: notificationList ?? this.notificationList,
    );
  }
}
