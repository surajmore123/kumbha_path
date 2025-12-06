import 'package:equatable/equatable.dart';
import 'package:kumbha_path/src/models/user_profile.dart';

enum UserStatus { initial, loading, success, failure, sending,profileUpdatedSuccess, profileUpdatedFailure,profileImageUploadSuccess,profileImageUploadFailure,profileLoaded }

class UserState extends Equatable {
  final UserStatus status;
  final UserData? profileData;

  UserState({
    this.status = UserStatus.initial,
    this.profileData = UserData.empty,
  });

  @override
  List<Object?> get props => [status, profileData];

  UserState copyWith({UserStatus? status, UserData? profileData}) {
    return UserState(
      status: status ?? this.status,
      profileData: profileData ?? this.profileData,
    );
  }
}
