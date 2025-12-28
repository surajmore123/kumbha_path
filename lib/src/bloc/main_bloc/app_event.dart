import 'package:equatable/equatable.dart';

class AppEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class GetNearbyTemplesEvent extends AppEvent {
  final String latitude;
  final String longitude;
  final String? radius;
  final int limit;
  final bool isLoadMore;

  GetNearbyTemplesEvent({
    this.limit = 5,
    this.isLoadMore = false,
    required this.latitude,
    required this.longitude,
     this.radius = '5',
  });
}
