/// Models for Emergency SOS. Each stage of telling someone is its own field,
/// because "saved", "sent", "reached their app" and "acknowledged" are
/// different things and must never be shown as one.
library;

DateTime? _date(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

const sosCategories = [
  'medical',
  'separated_vulnerable',
  'lost',
  'safety_threat',
  'accident',
  'crowd',
  'other',
];

/// Works with no network, so the phone can always offer it. The server can
/// add to this list.
const fallbackEmergencyNumbers = [
  EmergencyNumber(label: 'emergency', number: '112'),
];

class EmergencyNumber {
  const EmergencyNumber({required this.label, required this.number});

  factory EmergencyNumber.fromJson(Map<String, dynamic> json) =>
      EmergencyNumber(
        label: json['label'] as String? ?? 'emergency',
        number: json['number'] as String? ?? '',
      );

  final String label;
  final String number;
}

class SosRow {
  const SosRow({
    required this.id,
    required this.reference,
    required this.category,
    required this.status,
    this.isActive = false,
    this.personName = '',
    this.createdAt,
    this.updatedAt,
  });

  factory SosRow.fromJson(Map<String, dynamic> json) => SosRow(
    id: json['id'] as String,
    reference: json['reference'] as String? ?? '',
    category: json['category'] as String? ?? 'other',
    status: json['status'] as String? ?? 'SUBMITTED',
    isActive: json['is_active'] == true,
    personName: json['person_name'] as String? ?? '',
    createdAt: _date(json['created_at']),
    updatedAt: _date(json['updated_at']),
  );

  final String id;
  final String reference;
  final String category;
  final String status;
  final bool isActive;
  final String personName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class SosPage {
  const SosPage({required this.rows, this.hasNext = false});

  final List<SosRow> rows;
  final bool hasNext;
}

class SosOverview {
  const SosOverview({
    this.active,
    this.family = const [],
    this.numbers = fallbackEmergencyNumbers,
    this.dispatchIntegration = false,
  });

  factory SosOverview.fromJson(Map<String, dynamic> json) {
    final numbers = [
      for (final n in json['emergency_numbers'] as List? ?? const [])
        EmergencyNumber.fromJson(n as Map<String, dynamic>),
    ];
    return SosOverview(
      active:
          json['active'] is Map<String, dynamic>
              ? SosRow.fromJson(json['active'] as Map<String, dynamic>)
              : null,
      family: [for (final name in json['family'] as List? ?? const []) '$name'],
      numbers: numbers.isEmpty ? fallbackEmergencyNumbers : numbers,
      dispatchIntegration: json['dispatch_integration'] == true,
    );
  }

  final SosRow? active;

  /// Who'd be told. Empty means nobody in a family would hear about it.
  final List<String> family;
  final List<EmergencyNumber> numbers;
  final bool dispatchIntegration;
}

class SosStep {
  const SosStep({required this.status, required this.by, this.at});

  factory SosStep.fromJson(Map<String, dynamic> json) => SosStep(
    status: json['status'] as String? ?? '',
    by: json['by'] as String? ?? 'system',
    at: _date(json['at']),
  );

  final String status;

  /// system, person or responder.
  final String by;
  final DateTime? at;
}

class SosNote {
  const SosNote({required this.kind, this.body = '', this.at});

  factory SosNote.fromJson(Map<String, dynamic> json) => SosNote(
    kind: json['kind'] as String? ?? 'person',
    body: json['body'] as String? ?? '',
    at: _date(json['at']),
  );

  final String kind;
  final String body;
  final DateTime? at;
}

class SosRecipient {
  const SosRecipient({
    required this.name,
    this.notification = 'pending',
    this.reachedAppAt,
    this.acknowledgedAt,
  });

  factory SosRecipient.fromJson(Map<String, dynamic> json) => SosRecipient(
    name: json['name'] as String? ?? '',
    notification: json['notification'] as String? ?? 'pending',
    reachedAppAt: _date(json['reached_app_at']),
    acknowledgedAt: _date(json['acknowledged_at']),
  );

  final String name;

  /// pending, sent (the provider accepted it), no_device or failed.
  final String notification;
  final DateTime? reachedAppAt;
  final DateTime? acknowledgedAt;

  bool get sent => notification == 'sent';
}

class SosDetail {
  SosDetail({
    required this.id,
    required this.reference,
    required this.category,
    required this.status,
    required this.role,
    this.isActive = false,
    this.personName = '',
    this.details = '',
    this.createdAt,
    this.updatedAt,
    this.writtenAt,
    this.locationText = '',
    this.latitude,
    this.longitude,
    this.accuracyM,
    this.locationAt,
    this.cancelReason = '',
    this.resolutionNote = '',
    this.responderAcknowledgedAt,
    this.timeline = const [],
    this.updates = const [],
    this.family = const [],
    this.iAcknowledged = false,
  });

  factory SosDetail.fromJson(Map<String, dynamic> json) => SosDetail(
    id: json['id'] as String,
    reference: json['reference'] as String? ?? '',
    category: json['category'] as String? ?? 'other',
    status: json['status'] as String? ?? 'SUBMITTED',
    role: json['role'] as String? ?? 'family',
    isActive: json['is_active'] == true,
    personName: json['person_name'] as String? ?? '',
    details: json['details'] as String? ?? '',
    createdAt: _date(json['created_at']),
    updatedAt: _date(json['updated_at']),
    writtenAt: _date(json['written_at']),
    locationText: json['location_text'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
    locationAt: _date(json['location_at']),
    cancelReason: json['cancel_reason'] as String? ?? '',
    resolutionNote: json['resolution_note'] as String? ?? '',
    responderAcknowledgedAt: _date(json['responder_acknowledged_at']),
    timeline: [
      for (final t in json['timeline'] as List? ?? const [])
        SosStep.fromJson(t as Map<String, dynamic>),
    ],
    updates: [
      for (final u in json['updates'] as List? ?? const [])
        SosNote.fromJson(u as Map<String, dynamic>),
    ],
    family: [
      for (final f in json['family'] as List? ?? const [])
        SosRecipient.fromJson(f as Map<String, dynamic>),
    ],
    iAcknowledged: json['i_acknowledged'] == true,
  );

  final String id;
  final String reference;
  final String category;
  final String status;

  /// owner, family or ops.
  final String role;
  final bool isActive;
  final String personName;
  final String details;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? writtenAt;
  final String locationText;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final DateTime? locationAt;
  final String cancelReason;
  final String resolutionNote;
  final DateTime? responderAcknowledgedAt;
  final List<SosStep> timeline;
  final List<SosNote> updates;
  final List<SosRecipient> family;
  final bool iAcknowledged;

  bool get isOwner => role == 'owner';
  bool get isFamily => role == 'family';
  bool get hasPosition => latitude != null && longitude != null;
}

/// An SOS being sent, or one that couldn't be. The id stays the same across
/// tries, so a retry can never create a second emergency.
class SosDraft {
  const SosDraft({
    required this.clientId,
    required this.category,
    required this.writtenAt,
    this.details = '',
    this.locationText = '',
    this.latitude,
    this.longitude,
    this.accuracyM,
    this.locationAt,
    this.account,
  });

  factory SosDraft.fromJson(Map<String, dynamic> json) => SosDraft(
    clientId: json['client_id'] as String,
    category: json['category'] as String? ?? 'other',
    writtenAt: DateTime.parse(json['written_at'] as String).toLocal(),
    details: json['details'] as String? ?? '',
    locationText: json['location_text'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
    locationAt: _date(json['location_at']),
    account: json['account'] as String?,
  );

  final String clientId;
  final String category;
  final DateTime writtenAt;
  final String details;
  final String locationText;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final DateTime? locationAt;
  final String? account;

  SosDraft forAccount(String? value) => SosDraft(
    clientId: clientId,
    category: category,
    writtenAt: writtenAt,
    details: details,
    locationText: locationText,
    latitude: latitude,
    longitude: longitude,
    accuracyM: accuracyM,
    locationAt: locationAt,
    account: value,
  );

  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'category': category,
    'written_at': writtenAt.toUtc().toIso8601String(),
    'details': details,
    'location_text': locationText,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (accuracyM != null) 'accuracy_m': accuracyM,
    if (locationAt != null)
      'location_at': locationAt!.toUtc().toIso8601String(),
    if (account != null) 'account': account,
  };

  /// What goes to the server. `written_at` is added only for a delayed send,
  /// so a responder can see it isn't new.
  Map<String, dynamic> toRequest({bool delayed = false}) => {
    'client_id': clientId,
    'category': category,
    if (details.isNotEmpty) 'details': details,
    if (locationText.isNotEmpty) 'location_text': locationText,
    if (latitude != null) 'latitude': latitude!.toStringAsFixed(6),
    if (longitude != null) 'longitude': longitude!.toStringAsFixed(6),
    if (accuracyM != null) 'accuracy_m': accuracyM,
    if (locationAt != null)
      'location_at': locationAt!.toUtc().toIso8601String(),
    if (delayed) 'written_at': writtenAt.toUtc().toIso8601String(),
  };
}
