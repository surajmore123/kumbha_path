import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_event.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_state.dart';
import 'package:kumbha_path/src/constant/config.dart';


class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc() : super(UserState()) {
    on<UserCreateEvent>(_onUserCreate);
    on<VerifyOtpEvent>(_onVerifyUserOtp);
  }

  FutureOr<void> _onUserCreate(
    UserCreateEvent event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(status: UserStatus.sending));
    Map<String, dynamic> jsonData = {"phone_number": event.phoneNumber.trim()};

    print('user create data:$jsonData');

    dynamic result = await userRepository.createUser(jsonData);
    print('result of  create user :$result');

    if (result['status'] == "success") {
      emit(state.copyWith(status: UserStatus.success));
    } else {
      emit(state.copyWith(status: UserStatus.failure));
    }
  }

  FutureOr<void> _onVerifyUserOtp(
    VerifyOtpEvent event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(status: UserStatus.sending));

    Map<String, dynamic> jsonData = {
      "phone_number": event.phoneNumber.trim(),
      "otp_code": event.otp,
    };

    print('formdata otp: $jsonData');
    dynamic result = await userRepository.verifyUserOtp(jsonData);
    print(' otp result: $result');

    if (result['status'] == "success") {
      final token = result['data'];
      await storage.write(key: "access_token", value: token['access_token']);
      print('tokeeeeennn ${token['access_token']}');
      emit(state.copyWith(status: UserStatus.success));
    } else {
      emit(state.copyWith(status: UserStatus.failure));
    }
  }
}
