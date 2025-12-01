import 'package:equatable/equatable.dart';

enum UserStatus { initial, loading, success, failure, sending }

class UserState extends Equatable {
  final UserStatus status;

  UserState({this.status = UserStatus.initial});

  @override
  List<Object?> get props => [status];

  UserState copyWith({UserStatus? status}) {
    return UserState(status: status ?? this.status);
  }
}
