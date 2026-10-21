import 'package:equatable/equatable.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_state.dart';

class UserEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class UserCreateEvent extends UserEvent {
  final UserStatus? status;
  final String phoneNumber;

  UserCreateEvent({this.status, required this.phoneNumber});
}

class VerifyOtpEvent extends UserEvent {

  final String phoneNumber;
  final String otp;

  VerifyOtpEvent({ required this.otp, required this.phoneNumber});
}

class UserProfileCreateEvent extends UserEvent {
  final String email;
  final String fullName;

  UserProfileCreateEvent({required this.email, required this.fullName});
}

class ImageAddEvent extends UserEvent {
  final String image;

  ImageAddEvent({required this.image});
}

class ProfileGetEvent extends UserEvent {
  final UserStatus status;

  ProfileGetEvent({required this.status});
}

class FcmRegisterEvent extends UserEvent {
  final String fcmToken;
  final String deviceType;

  FcmRegisterEvent({required this.fcmToken, required this.deviceType});
}
