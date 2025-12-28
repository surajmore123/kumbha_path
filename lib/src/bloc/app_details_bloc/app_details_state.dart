import 'package:equatable/equatable.dart';
import 'package:kumbha_path/src/models/temple_detail.dart';

enum AppDetailsStatus { initial, loading, success, failed, updating, updated }

class AppDetailsState extends Equatable {
  final AppDetailsStatus status;
  final TempleDetailsModel templeDetail;

  const AppDetailsState({
    this.status = AppDetailsStatus.initial,
    this.templeDetail = TempleDetailsModel.empty,
  });

  @override
  List<Object?> get props => [status, templeDetail];

  AppDetailsState copyWith({
    AppDetailsStatus? status,
    TempleDetailsModel? templeDetail,
  }) {
    return AppDetailsState(
      status: status ?? this.status,
      templeDetail: templeDetail ?? this.templeDetail,
    );
  }
}

