import 'package:equatable/equatable.dart';

class AlertDetailsModel extends Equatable {
  final String? id;
  final String? zoneCode;
  final String? zoneName;
  final String? type;
  final String? severity;
  final String? title;
  final String? description;
  final String? startTime;

  const AlertDetailsModel({
    this.id,
    this.zoneCode,
    this.zoneName,
    this.type,
    this.severity,
    this.title,
    this.description,
    this.startTime,
  });

  @override
  List<Object?> get props => [
        id,
        zoneCode,
        zoneName,
        type,
        severity,
        title,
        description,
        startTime,
      ];

  AlertDetailsModel copyWith({
    String? id,
    String? zoneCode,
    String? zoneName,
    String? type,
    String? severity,
    String? title,
    String? description,
    String? startTime,
  }) {
    return AlertDetailsModel(
      id: id ?? this.id,
      zoneCode: zoneCode ?? this.zoneCode,
      zoneName: zoneName ?? this.zoneName,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
    );
  }

  factory AlertDetailsModel.fromJson(Map<String, dynamic> json) {
    return AlertDetailsModel(
      id: json['id'] ?? "",
      zoneCode: json['zone_code'] ?? "",
      zoneName: json['zone_name'] ?? "",
      type: json['type'] ?? "",
      severity: json['severity'] ?? "",
      title: json['title'] ?? "",
      description: json['description'] ?? "",
      startTime: json['start_time'] ?? "",
    );
  }

  static const empty = AlertDetailsModel(
    id: "",
    zoneCode: "",
    zoneName: "",
    type: "",
    severity: "",
    title: "",
    description: "",
    startTime: "",
  );

  @override
  String toString() =>
      '{id:$id, zone:$zoneName, type:$type, severity:$severity, startTime:$startTime}';
}