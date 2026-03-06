import 'package:equatable/equatable.dart';
import 'package:kumbha_path/src/models/featured_model.dart';
import 'package:kumbha_path/src/models/journal_details.dart';
import 'package:kumbha_path/src/models/journal_list.dart';
import 'package:kumbha_path/src/models/notification_model.dart';
import 'package:kumbha_path/src/models/quick_alert.dart';
import 'package:kumbha_path/src/models/temple_detail.dart';
import 'package:kumbha_path/src/models/upcoming_events.dart';
import 'package:kumbha_path/src/models/zone_detail.dart';
import 'package:kumbha_path/src/models/zone_model.dart';

enum AppDetailsStatus {
  initial,
  loading,
  success,
  failed,
  updating,
  updated,
  sending,
  aiReflectionLoaded,
  aiReflectionError,
  aiPromptLoaded,
  aiPromptError,
  journalEntryCreated,
  journalEntryError,
  journalEntryoaded,
  journalDetailLoaded,
}

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
  String? aiReflection;
  String? aiPrompt;
  String? message;
  final JournalEntryListModel? journalEntryListModel;
  final JournalDetailsModel? journalDetailsModel;

  AppDetailsState({
    this.status = AppDetailsStatus.initial,
    this.templeDetail = TempleDetailsModel.empty,
    this.eventDetailsModel = EventDetailsModel.empty,
    this.zoneDetails = ZoneLiveDetailsModel.empty,
    this.zoneModel = const [],
    this.upcomingEvents = const [],
    this.reminderMsg,
    this.reminderStatus = const {},
    this.quickAlerts = const [],
    this.notificationList = const [],
    this.aiReflection,
    this.aiPrompt,
    this.message,
    this.journalEntryListModel = JournalEntryListModel.empty,
    this.journalDetailsModel = JournalDetailsModel.empty,
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
    aiReflection,
    message,
    aiPrompt,
    journalEntryListModel,
    journalDetailsModel,

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
    String? aiReflection,
    String? message,
    String? aiPrompt,
    JournalEntryListModel? journalEntryListModel,
    JournalDetailsModel? journalDetailsModel,
  }) {
    return AppDetailsState(
      status: status ?? this.status,
      templeDetail: templeDetail ?? this.templeDetail,
      eventDetailsModel: eventDetailsModel ?? this.eventDetailsModel,
      upcomingEvents: upcomingEvents ?? this.upcomingEvents,
      reminderMsg: reminderMsg ?? this.reminderMsg,
      reminderStatus: reminderStatus ?? this.reminderStatus,
      zoneModel: zoneModel ?? this.zoneModel,
      zoneDetails: zoneDetails ?? this.zoneDetails,
      quickAlerts: quickAlerts ?? this.quickAlerts,
      notificationList: notificationList ?? this.notificationList,
      aiReflection: aiReflection ?? this.aiReflection,
      message: message ?? this.message,
      aiPrompt: aiPrompt ?? this.aiPrompt,
      journalEntryListModel:
          journalEntryListModel ?? this.journalEntryListModel,
      journalDetailsModel: journalDetailsModel ?? this.journalDetailsModel,
    );
  }
}
