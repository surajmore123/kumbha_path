import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/models/temple_detail.dart';

class AppDetailsBloc extends Bloc<AppDetailsEvent, AppDetailsState> {
  AppDetailsBloc() : super(AppDetailsState()) {
    on<GetTempleDetail>(_onGetTempleDetail);
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
}
