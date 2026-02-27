import 'package:equatable/equatable.dart';

class ZoneLiveDetailsModel extends Equatable {
  final String? status;
  final ZoneInfoModel? zone;
  final List<GateModel>? gates;
  final List<AlertModel>? alerts;
  final List<AlternativeZoneModel>? alternatives;

  const ZoneLiveDetailsModel({
    this.status,
    this.zone,
    this.gates,
    this.alerts,
    this.alternatives,
  });

  @override
  List<Object?> get props => [
        status,
        zone,
        gates,
        alerts,
        alternatives,
      ];

  ZoneLiveDetailsModel copyWith({
    String? status,
    ZoneInfoModel? zone,
    List<GateModel>? gates,
    List<AlertModel>? alerts,
    List<AlternativeZoneModel>? alternatives,
  }) {
    return ZoneLiveDetailsModel(
      status: status ?? this.status,
      zone: zone ?? this.zone,
      gates: gates ?? this.gates,
      alerts: alerts ?? this.alerts,
      alternatives: alternatives ?? this.alternatives,
    );
  }

 factory ZoneLiveDetailsModel.fromJson(Map<String, dynamic> json) {
  return ZoneLiveDetailsModel(
    status: json['status'] ?? "",
    zone: json['zone'] != null
        ? ZoneInfoModel.fromJson(json['zone'])
        : null,
    gates: (json['gates'] as List<dynamic>?)
            ?.map((e) => GateModel.fromJson(e))
            .toList() ??
        [],
    alerts: (json['alerts'] as List<dynamic>?)
            ?.map((e) => AlertModel.fromJson(e))
            .toList() ??
        [],
    alternatives:
        (json['alternatives'] as List<dynamic>?)
                ?.map((e) =>
                    AlternativeZoneModel.fromJson(e))
                .toList() ??
            [],
  );
}

  static const empty = ZoneLiveDetailsModel(
    status: "",
    zone: null,
    gates: [],
    alerts: [],
    alternatives: [],
  );

  @override
  String toString() =>
      '{status:$status, zone:$zone, alertsCount:${alerts?.length}}';
}


class ZoneInfoModel extends Equatable {
  final String? code;
  final String? name;
  final int? capacity;
  final int? totalPeople;
  final double? occupancyPercent;
  final String? status;

  const ZoneInfoModel({
    this.code,
    this.name,
    this.capacity,
    this.totalPeople,
    this.occupancyPercent,
    this.status,
  });

  @override
  List<Object?> get props => [
        code,
        name,
        capacity,
        totalPeople,
        occupancyPercent,
        status,
      ];

  factory ZoneInfoModel.fromJson(Map<String, dynamic> json) {
    return ZoneInfoModel(
      code: json['code'] ?? "",
      name: json['name'] ?? "",
      capacity: json['capacity'] ?? 0,
      totalPeople: json['total_people'] ?? 0,
      occupancyPercent:
          (json['occupancy_percent'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? "",
    );
  }

  static const empty = ZoneInfoModel(
    code: "",
    name: "",
    capacity: 0,
    totalPeople: 0,
    occupancyPercent: 0.0,
    status: "",
  );

  @override
  String toString() =>
      '{code:$code, name:$name, occupancy:$occupancyPercent, status:$status}';
}

class AlertModel extends Equatable {
  final String? title;
  final String? severity;

  const AlertModel({
    this.title,
    this.severity,
  });

  @override
  List<Object?> get props => [title, severity];

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      title: json['title'] ?? "",
      severity: json['severity'] ?? "",
    );
  }

  static const empty = AlertModel(
    title: "",
    severity: "",
  );

  @override
  String toString() =>
      '{title:$title, severity:$severity}';
}

class GateModel extends Equatable {
  const GateModel();

  @override
  List<Object?> get props => [];

  factory GateModel.fromJson(Map<String, dynamic> json) {
    return const GateModel();
  }
}


class AlternativeZoneModel extends Equatable {
  const AlternativeZoneModel();

  @override
  List<Object?> get props => [];

  factory AlternativeZoneModel.fromJson(Map<String, dynamic> json) {
    return const AlternativeZoneModel();
  }
}