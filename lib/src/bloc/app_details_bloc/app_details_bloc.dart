import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/models/featured_model.dart';
import 'package:kumbha_path/src/models/notification_model.dart';
import 'package:kumbha_path/src/models/quick_alert.dart';
import 'package:kumbha_path/src/models/temple_detail.dart';
import 'package:kumbha_path/src/models/upcoming_events.dart';
import 'package:kumbha_path/src/models/zone_detail.dart';
import 'package:kumbha_path/src/models/zone_model.dart';

class AppDetailsBloc extends Bloc<AppDetailsEvent, AppDetailsState> {
  AppDetailsBloc() : super(AppDetailsState()) {
    on<GetTempleDetail>(_onGetTempleDetail);
    on<TempleNavigate>(_onTempleNavigate);
    on<FeaturedEvent>(_onGetFeaturedEvent);
    on<UpcomingEvent>(_onGetUpcomingEvent);
    on<ReminderToggleEvent>(_onSetreminderEvent);
    on<CrowdLiveStatusEvent>(_onGetCrowdLiveStatus);
    on<GetZoneDetailEvent>(_onGetZoneDetail);
    on<QuickAlertsEvent>(_onGetQuickAlerts);
    on<GetNotificationsEvent>(_onGetNotifications);
  }

  FutureOr<void> _onGetTempleDetail(
    GetTempleDetail event,
    Emitter<AppDetailsState> emit,
  ) async {
    emit(state.copyWith(status: AppDetailsStatus.loading));
    final token = await storage.read(key: 'access_token');
    Map<String, Object> jsonData = {
      "access_token": token.toString(),
      "temple_id": event.templeId.toString(),
      "lat": event.latitude,
      "lng": event.longitude,
    };

    final result = await templeRepository.getTempleDetail(jsonData);

    print('temple detail result $result');

    if (result != null && result['status'] == 'success') {
      emit(
        state.copyWith(
          status: AppDetailsStatus.success,
          templeDetail: TempleDetailsModel.fromJson(result['data']),
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: AppDetailsStatus.failed,
          templeDetail: TempleDetailsModel.empty,
        ),
      );
    }
  }

  FutureOr<void> _onTempleNavigate(
    TempleNavigate event,
    Emitter<AppDetailsState> emit,
  ) async {
    emit(state.copyWith(status: AppDetailsStatus.loading));
    final token = await storage.read(key: 'access_token');
    Map<String, Object> jsonData = {
      "access_token": token.toString(),
      "temple_id": event.templeId.toString(),
      'user_latitude': event.latitude.toString(),
      'user_longitude': event.longitude.toString(),
    };

    final result = await templeRepository.templeNavigate(jsonData);
    print('temple navigate result $result');
    if (result != null && result['status'] == 'success') {
      emit(state.copyWith(status: AppDetailsStatus.success));
    } else {
      emit(state.copyWith(status: AppDetailsStatus.failed));
    }
  }

  FutureOr<void> _onGetFeaturedEvent(
    FeaturedEvent event,
    Emitter<AppDetailsState> emit,
  ) async {
    emit(state.copyWith(status: AppDetailsStatus.loading));
    final token = await storage.read(key: 'access_token');

    Map<String, Object> jsonData = {"access_token": token.toString()};
    final result = await templeRepository.getFeaturedEvent(jsonData);

    if (result != null && result['status'] == 'success') {
      emit(
        state.copyWith(
          status: AppDetailsStatus.success,
          eventDetailsModel: EventDetailsModel.fromJson(result['data']),
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: AppDetailsStatus.failed,
          eventDetailsModel: EventDetailsModel.empty,
        ),
      );
    }
  }

  FutureOr<void> _onGetUpcomingEvent(
    UpcomingEvent event,
    Emitter<AppDetailsState> emit,
  ) async {
    emit(state.copyWith(status: AppDetailsStatus.loading));
    final token = await storage.read(key: 'access_token');
    Map<String, String> jsonData = {
      "access_token": token.toString(),
      "date": event.date.toString(),
    };

    final result = await templeRepository.getUpcomingTemples(jsonData);
    if (result != null && result['status'] == 'success') {
      final List list = result['data'] as List;
      final upcomingEvents =
          list.map((e) => EventSummaryModel.fromJson(e)).toList();
      emit(
        state.copyWith(
          status: AppDetailsStatus.success,
          upcomingEvents: upcomingEvents,
        ),
      );
    } else {
      emit(state.copyWith(status: AppDetailsStatus.failed, upcomingEvents: []));
    }
  }

  FutureOr<void> _onSetreminderEvent(
    ReminderToggleEvent event,
    Emitter<AppDetailsState> emit,
  ) async {
    emit(state.copyWith(status: AppDetailsStatus.sending));
    final token = await storage.read(key: 'access_token');
    Map<String, Object> jsonData = {
      "access_token": token.toString(),
      "event_id": event.eventId.toString(),
      "action": event.action.toString(),
    };

    final result = await templeRepository.eventNotification(jsonData);
    if (result != null && result['status'] == 'success') {
      final updatedMap = Map<String, bool>.from(state.reminderStatus);
      updatedMap[event.eventId] = event.action == "ENABLE";
      emit(
        state.copyWith(
          status: AppDetailsStatus.success,
          reminderMsg: result['message'],
          reminderStatus: updatedMap,
        ),
      );
    } else {
      emit(state.copyWith(status: AppDetailsStatus.failed));
    }
  }

  FutureOr<void> _onGetCrowdLiveStatus(
    CrowdLiveStatusEvent event,
    Emitter<AppDetailsState> emit,
  ) async {
    emit(state.copyWith(status: AppDetailsStatus.loading));
    final token = await storage.read(key: 'access_token');
    Map<String, String> jsonData = {"access_token": token.toString()};

    final result = await templeRepository.getCrowdLiveStatus(jsonData);
    if (result != null && result['status'] == 'success') {
      /*
   final List list = result['data'] as List;
      final upcomingEvents =
          list.map((e) => EventSummaryModel.fromJson(e)).toList();
      */
      final List list = result['zones'] as List;
      final List<ZoneModel> zoneList =
          list.map((e) => ZoneModel.fromJson(e)).toList();
      emit(
        state.copyWith(status: AppDetailsStatus.success, zoneModel: zoneList),
      );
    } else {
      emit(
        state.copyWith(status: AppDetailsStatus.failed, zoneModel: const []),
      );
    }
  }

  FutureOr<void> _onGetZoneDetail(
    GetZoneDetailEvent event,
    Emitter<AppDetailsState> emit,
  ) async {
    emit(state.copyWith(status: AppDetailsStatus.loading));
    final token = await storage.read(key: 'access_token');
    Map<String, String> jsonData = {
      "access_token": token.toString(),
      "code": event.zoneCode.toString(),
    };

    final result = await templeRepository.getZoneDetail(jsonData);
    print('zone detail result $result');
    if (result != null && result['status'] == 'success') {
      emit(
        state.copyWith(
          status: AppDetailsStatus.success,
          zoneDetails: ZoneLiveDetailsModel.fromJson(result),
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: AppDetailsStatus.failed,
          zoneDetails: ZoneLiveDetailsModel.empty,
        ),
      );
    }
  }

  FutureOr<void> _onGetQuickAlerts(
    QuickAlertsEvent event,
    Emitter<AppDetailsState> emit,
  ) async {
    emit(state.copyWith(status: AppDetailsStatus.loading));
    final token = await storage.read(key: 'access_token');
    Map<String, String> jsonData = {"access_token": token.toString()};
    final result = await templeRepository.getQuickAlerts(jsonData);
    print('quick alerts result $result');
    if (result != null && result['status'] == 'success') {
      final List list = result['alerts'] as List;
      final List<AlertDetailsModel> alertList =
          list.map((e) => AlertDetailsModel.fromJson(e)).toList();
      emit(
        state.copyWith(
          status: AppDetailsStatus.success,
          quickAlerts: alertList,
        ),
      );
    } else {
      emit(
        state.copyWith(status: AppDetailsStatus.failed, quickAlerts: const []),
      );
    }
  }

  FutureOr<void> _onGetNotifications(
    GetNotificationsEvent event,
    Emitter<AppDetailsState> emit,
  ) async {
    emit(state.copyWith(status: AppDetailsStatus.loading));
    final token = await storage.read(key: 'access_token');

    Map<String, String> jsonData = {
      "access_token": token.toString(),
      "type": event.type.toString(),
    };

    final result = await templeRepository.getNotifications(jsonData);
    print('notifications result $result');
    if (result != null && result['status'] == 'success') {
      final List list = result['notifications'] as List;
      final List<NotificationModel> notificationList =
          list.map((e) => NotificationModel.fromJson(e)).toList();
      emit(
        state.copyWith(
          status: AppDetailsStatus.success,
          notificationList: notificationList,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: AppDetailsStatus.failed,
          notificationList: const [],
        ),
      );
    }
  }
}
