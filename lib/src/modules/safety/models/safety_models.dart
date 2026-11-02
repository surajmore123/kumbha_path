/// Models for the Digital Safety QR, from `/api/safety/`.
library;

const _base = 'https://kumbhapath.in/safety/qr';
final _token = RegExp(r'^[A-Za-z0-9_-]{32,128}$');

DateTime? _date(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

/// The token in a scanned code, or null if it isn't a Kumbh Path safety QR.
/// Anything else a camera sees, including other sites' links, is ignored.
String? safetyTokenFrom(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  if ('${uri.scheme}://${uri.host}${uri.path}' != _base) return null;
  if (uri.hasPort && uri.port != 443) return null;
  if (!uri.fragment.startsWith('t=')) return null;
  final token = uri.fragment.substring(2);
  return _token.hasMatch(token) ? token : null;
}

class SafetyQr {
  const SafetyQr({
    required this.id,
    required this.memberName,
    required this.status,
    required this.payload,
    this.createdAt,
    this.lastScannedAt,
    this.fromDevice = false,
  });

  factory SafetyQr.fromJson(Map<String, dynamic> json) => SafetyQr(
    id: json['id'] as String,
    memberName: json['member_name'] as String? ?? '',
    status: json['status'] as String? ?? 'active',
    payload: json['payload'] as String? ?? '',
    createdAt: _date(json['created_at']),
    lastScannedAt: _date(json['last_scanned_at']),
  );

  final String id;
  final String memberName;
  final String status;

  /// Holds the token, so it's never printed or logged.
  final String payload;
  final DateTime? createdAt;
  final DateTime? lastScannedAt;

  /// Shown from this phone's saved copy, because the server can't be reached.
  final bool fromDevice;

  bool get isActive => status == 'active';

  Map<String, dynamic> toJson() => {
    'id': id,
    'member_name': memberName,
    'status': status,
    'payload': payload,
    'created_at': createdAt?.toUtc().toIso8601String(),
  };

  SafetyQr savedCopy() => SafetyQr(
    id: id,
    memberName: memberName,
    status: status,
    payload: payload,
    createdAt: createdAt,
    fromDevice: true,
  );

  @override
  String toString() => 'SafetyQr($status)';
}

class HelperStatus {
  const HelperStatus({required this.isHelper, this.role});

  factory HelperStatus.fromJson(Map<String, dynamic> json) => HelperStatus(
    isHelper: json['is_helper'] == true,
    role: json['role'] as String?,
  );

  final bool isHelper;
  final String? role;
}

/// What a helper learns from a scan: the least needed to help.
class ScanResult {
  const ScanResult({
    required this.scanId,
    required this.firstName,
    required this.category,
    this.language = 'en',
    this.openAlerts = const [],
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
    scanId: json['scan_id'] as String,
    firstName: json['first_name'] as String? ?? '',
    category: json['category'] as String? ?? 'other',
    language: json['language'] as String? ?? 'en',
    openAlerts: [
      for (final a in json['open_alerts'] as List? ?? const [])
        (a as Map)['reference'] as String,
    ],
  );

  final String scanId;
  final String firstName;
  final String category;
  final String language;

  /// References of reports already open for this person.
  final List<String> openAlerts;

  bool get isChild => category == 'child';
}

/// The outcome of a helper's report.
class AlertReceipt {
  const AlertReceipt({
    required this.id,
    required this.reference,
    required this.delivery,
    this.familyAcknowledged = false,
    this.duplicate = false,
  });

  factory AlertReceipt.fromJson(Map<String, dynamic> json) => AlertReceipt(
    id: json['id'] as String,
    reference: json['reference'] as String? ?? '',
    delivery: json['delivery'] as String? ?? 'pending',
    familyAcknowledged: json['family_acknowledged'] == true,
    duplicate: json['duplicate'] == true,
  );

  final String id;
  final String reference;
  final String delivery;
  final bool familyAcknowledged;
  final bool duplicate;

  /// True only if a push reached at least one device.
  bool get familyNotified => delivery == 'sent';
}

class FamilyAlert {
  const FamilyAlert({
    required this.id,
    required this.reference,
    required this.kind,
    required this.status,
    required this.familyId,
    required this.memberName,
    this.note = '',
    this.helperRole = 'volunteer',
    this.latitude,
    this.longitude,
    this.locationWithheld = false,
    this.createdAt,
  });

  factory FamilyAlert.fromJson(Map<String, dynamic> json, String familyId) {
    final location = json['location'];
    return FamilyAlert(
      id: json['id'] as String,
      reference: json['reference'] as String? ?? '',
      kind: json['kind'] as String? ?? 'other',
      status: json['status'] as String? ?? 'open',
      familyId: familyId,
      memberName: json['member_name'] as String? ?? '',
      note: json['note'] as String? ?? '',
      helperRole: json['helper_role'] as String? ?? 'volunteer',
      latitude:
          location is Map ? (location['latitude'] as num?)?.toDouble() : null,
      longitude:
          location is Map ? (location['longitude'] as num?)?.toDouble() : null,
      locationWithheld: json['location_withheld'] == true,
      createdAt: _date(json['created_at']),
    );
  }

  final String id;
  final String reference;
  final String kind;
  final String status;
  final String familyId;
  final String memberName;
  final String note;
  final String helperRole;
  final double? latitude;
  final double? longitude;
  final bool locationWithheld;
  final DateTime? createdAt;

  bool get isResolved => status == 'resolved';
  bool get isOpen => status == 'open';
}
