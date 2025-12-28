import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_event.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_state.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/models/near_temple.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc() : super(AppState()) {
    on<GetNearbyTemplesEvent>(_onGetNearTemples);
  }

  FutureOr<void> _onGetNearTemples(
  GetNearbyTemplesEvent event,
  Emitter<AppState> emit,
) async {
  if (!event.isLoadMore) {
    emit(state.copyWith(status: AppStatus.loading));
  }

  final token = await storage.read(key: 'access_token');

  final Map<String, String> params = {
    "access_token": token.toString(),
    "lat": event.latitude,
    "lng": event.longitude,
    "radius": event.radius.toString(),
    "limit": event.limit.toString(),
  };

  if (event.isLoadMore && state.nearbyTemples?.nextCursor != null) {
    params["cursor"] = state.nearbyTemples!.nextCursor!;
  }

  final result = await templeRepository.getNearbyTemples(params);

  if (result != null && result['status'] == "success") {
    final newData = NearbyTemplesModel.fromJson(result);

    final merged = event.isLoadMore
        ? state.nearbyTemples!.copyWith(
            temples: [
              ...state.nearbyTemples!.temples!,
              ...newData.temples!,
            ],
            hasMore: newData.hasMore,
            nextCursor: newData.nextCursor,
            count: newData.count,
            radiusKm: newData.radiusKm,
          )
        : newData;

    emit(
      state.copyWith(
        status: AppStatus.success,
        nearbyTemples: merged,
      ),
    );
  } else {
    emit(
      state.copyWith(
        status: AppStatus.failure,
        nearbyTemples: NearbyTemplesModel.empty,
      ),
    );
  }
}

}
