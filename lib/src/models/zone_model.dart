import 'package:equatable/equatable.dart';



class ZoneModel extends Equatable {
  final String? code;
  final String? name;
  final double? latitude;
  final double? longitude;
  final int? capacity;
  final int? totalPeople;
  final double? occupancyPercent;
  final String? status;

  const ZoneModel({
    this.code,
    this.name,
    this.latitude,
    this.longitude,
    this.capacity,
    this.totalPeople,
    this.occupancyPercent,
    this.status,
  });

  @override
  List<Object?> get props => [
        code,
        name,
        latitude,
        longitude,
        capacity,
        totalPeople,
        occupancyPercent,
        status,
      ];

  ZoneModel copyWith({
    String? code,
    String? name,
    double? latitude,
    double? longitude,
    int? capacity,
    int? totalPeople,
    double? occupancyPercent,
    String? status,
  }) {
    return ZoneModel(
      code: code ?? this.code,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      capacity: capacity ?? this.capacity,
      totalPeople: totalPeople ?? this.totalPeople,
      occupancyPercent: occupancyPercent ?? this.occupancyPercent,
      status: status ?? this.status,
    );
  }

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    return ZoneModel(
      code: json['code'],
      name: json['name'],
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      capacity: json['capacity'],
      totalPeople: json['total_people'],
      occupancyPercent:
          (json['occupancy_percent'] as num?)?.toDouble(),
      status: json['status'],
    );
  }

  static const empty = ZoneModel(
    code: "",
    name: "",
    latitude: 0,
    longitude: 0,
    capacity: 0,
    totalPeople: 0,
    occupancyPercent: 0,
    status: "",
  );

  @override
  String toString() =>
      '{code: $code, name: $name, totalPeople: $totalPeople, occupancyPercent: $occupancyPercent, status: $status}';
}