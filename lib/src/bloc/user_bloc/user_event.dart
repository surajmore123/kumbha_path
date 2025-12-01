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
  final UserStatus? status;
  final String phoneNumber;
  final String otp;

  VerifyOtpEvent({this.status, required this.otp,required this.phoneNumber});
}
