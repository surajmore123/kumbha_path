import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/models/featured_model.dart';
import 'package:kumbha_path/src/models/temple_detail.dart';
import 'package:kumbha_path/src/models/upcoming_events.dart';

class AppDetailsBloc extends Bloc<AppDetailsEvent, AppDetailsState> {
  AppDetailsBloc() : super(AppDetailsState()) {
    on<GetTempleDetail>(_onGetTempleDetail);
    on<TempleNavigate>(_onTempleNavigate);
    on<FeaturedEvent>(_onGetFeaturedEvent);
    on<UpcomingEvent>(_onGetUpcomingEvent);
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
}
