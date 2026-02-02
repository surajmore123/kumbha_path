import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_event.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_state.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/models/user_profile.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc() : super(UserState()) {
    on<UserCreateEvent>(_onUserCreate);
    on<VerifyOtpEvent>(_onVerifyUserOtp);
    on<UserProfileCreateEvent>(_onUserProfileCreate);
    on<ImageAddEvent>(_onUserProfileImageUpload);
    on<ProfileGetEvent>(_ongetUserProfile);
    on<FcmRegisterEvent>(_onregisterFcm);
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
      await storage.write(key: "session_id", value: token['session_id']);
      final fcmToken = await userAuthentication.getFcmToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        add(FcmRegisterEvent(fcmToken: fcmToken, deviceType: "ANDROID"));
      }

      print('tokeeeeennn ${token['access_token']}');
      emit(state.copyWith(status: UserStatus.success));
    } else {
      emit(state.copyWith(status: UserStatus.failure));
    }
  }



  FutureOr<void> _onUserProfileCreate(
    UserProfileCreateEvent event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(status: UserStatus.sending));
    final token = await storage.read(key: 'access_token');

    Map<String, Object> jsonData = {
      "access_token": token.toString(),
      "email": event.email,
      "full_name": event.fullName,
    };

    print('user profile data:$jsonData');

    dynamic result = await userRepository.userProfileCreate(jsonData);
    print('result of  user profile create :$result');

    if (result['status'] == "success") {
      emit(state.copyWith(status: UserStatus.profileUpdatedSuccess));
    } else {
      emit(state.copyWith(status: UserStatus.profileUpdatedFailure));
    }
  }

  FutureOr<void> _onUserProfileImageUpload(
    ImageAddEvent event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(status: UserStatus.sending));
    final token = await storage.read(key: 'access_token');
    Map<String, Object> jsonData = {
      "access_token": token.toString(),
      "profile_image": event.image,
    };
    print('user profile image upload data:$jsonData');
    dynamic result = await userRepository.userProfileImageUpload(jsonData);
    print('result of  user profile image upload :$result');
    if (result['status'] == "success") {
      emit(state.copyWith(status: UserStatus.profileImageUploadSuccess));
    } else {
      emit(state.copyWith(status: UserStatus.profileImageUploadFailure));
    }
  }

  FutureOr<void> _ongetUserProfile(
    ProfileGetEvent event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(status: UserStatus.loading));
    final token = await storage.read(key: 'access_token');
    Map<String, String> jsonData = {"access_token": token.toString()};
    print('get user profile data:$jsonData');
    dynamic result = await userRepository.getUserProfile(jsonData);
    print('result of get user profile :$result');
    if (result['status'] == "success") {
      UserData userData = UserData.fromJson(result['data']);
      emit(
        state.copyWith(status: UserStatus.profileLoaded, profileData: userData),
      );
    } else {
      emit(state.copyWith(status: UserStatus.failure));
    }
  }

  FutureOr<void> _onregisterFcm(
    FcmRegisterEvent event,
    Emitter<UserState> emit,
  ) async {
    emit(state.copyWith(status: UserStatus.sending));
    final token = await storage.read(key: 'access_token');
    Map<String, Object> jsonData = {
      "access_token": token.toString(),
      "token": event.fcmToken,
      "device_type": event.deviceType,
    };
    print('user fcm data:$jsonData');
    dynamic result = await userRepository.registerFcm(jsonData);
    print('result of  user fcm:$result');
    if (result['status'] == "success") {
      emit(state.copyWith(status: UserStatus.success));
    } else {
      emit(state.copyWith(status: UserStatus.failure));
    }
  }
}
