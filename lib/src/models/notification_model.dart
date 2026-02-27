import 'package:equatable/equatable.dart';

class NotificationModel extends Equatable {
  final int? id;
  final String? title;
  final String? body;
  final String? type;
  final String? severity;
  final String? zoneName;
  final String? createdAt;

  const NotificationModel({
    this.id,
    this.title,
    this.body,
    this.type,
    this.severity,
    this.zoneName,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        body,
        type,
        severity,
        zoneName,
        createdAt,
      ];

  NotificationModel copyWith({
    int? id,
    String? title,
    String? body,
    String? type,
    String? severity,
    String? zoneName,
    String? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      zoneName: zoneName ?? this.zoneName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'] ?? "",
      body: json['body'] ?? "",
      type: json['type'] ?? "",
      severity: json['severity'] ?? "",
      zoneName: json['zone_name'],
      createdAt: json['created_at'] ?? "",
    );
  }

  static const empty = NotificationModel(
    id: 0,
    title: "",
    body: "",
    type: "",
    severity: "",
    zoneName: "",
    createdAt: "",
  );

  @override
  String toString() {
    return 'NotificationModel(id: $id, title: $title, type: $type, severity: $severity)';
  }
}