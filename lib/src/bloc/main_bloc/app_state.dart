import 'package:equatable/equatable.dart';
import 'package:kumbha_path/src/models/near_temple.dart';

enum AppStatus {
  initial,
  loading,
  failure,
  sending,
  updated,
  success,
  singleLoadedForView,
  deleting,
  deleted,
}
class AppState extends Equatable {
  final AppStatus status;
  final NearbyTemplesModel nearbyTemples;
  final String? lastUserLat;
  final String? lastUserLng;

  const AppState({
    this.status = AppStatus.initial,
    this.nearbyTemples = NearbyTemplesModel.empty,
    this.lastUserLat,
    this.lastUserLng,
  });

  @override
  List<Object?> get props => [
        status,
        nearbyTemples,
        lastUserLat,
        lastUserLng,
      ];

  AppState copyWith({
    AppStatus? status,
    NearbyTemplesModel? nearbyTemples,
    String? lastUserLat,
    String? lastUserLng,
  }) {
    return AppState(
      status: status ?? this.status,
      nearbyTemples: nearbyTemples ?? this.nearbyTemples,
      lastUserLat: lastUserLat ?? this.lastUserLat,
      lastUserLng: lastUserLng ?? this.lastUserLng,
    );
  }
}
