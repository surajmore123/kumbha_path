/// Models for family location sharing. Everything comes from `/api/location/`.
/// Positions are never written to the device: the feed is held in memory only.
library;

DateTime? _date(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

const sharingMinutes = [30, 60, 180, 360];

/// How much a position can be trusted right now. Worked out from when the
/// phone took it, never from when it was received.
enum Freshness { live, recent, lastKnown, unavailable, paused, expired }

/// One reading from this phone's GPS, with the time it was actually taken.
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.accuracyM,
    this.speedMps,
    this.heading,
  });

  final double latitude;
  final double longitude;
  final DateTime capturedAt;
  final double? accuracyM;
  final double? speedMps;
  final double? heading;

  Map<String, dynamic> toJson() => {
    'latitude': latitude.toStringAsFixed(6),
    'longitude': longitude.toStringAsFixed(6),
    'captured_at': capturedAt.toUtc().toIso8601String(),
    if (accuracyM != null) 'accuracy_m': accuracyM,
    if (speedMps != null) 'speed_mps': speedMps,
    if (heading != null) 'heading': heading,
  };
}

class EligibleViewer {
  const EligibleViewer({required this.memberId, required this.name});

  factory EligibleViewer.fromJson(Map<String, dynamic> json) => EligibleViewer(
    memberId: json['member_id'] as String,
    name: json['name'] as String? ?? '',
  );

  final String memberId;
  final String name;
}

class EligibleViewers {
  const EligibleViewers({required this.people, this.maxHours = 12});

  factory EligibleViewers.fromJson(Map<String, dynamic> json) =>
      EligibleViewers(
        maxHours: (json['max_hours'] as num?)?.toInt() ?? 12,
        people: [
          for (final p in json['people'] as List? ?? const [])
            EligibleViewer.fromJson(p as Map<String, dynamic>),
        ],
      );

  final List<EligibleViewer> people;
  final int maxHours;
}

class SharingRecipient {
  const SharingRecipient({
    required this.memberId,
    required this.name,
    this.lastViewedAt,
  });

  factory SharingRecipient.fromJson(Map<String, dynamic> json) =>
      SharingRecipient(
        memberId: json['member_id'] as String,
        name: json['name'] as String? ?? '',
        lastViewedAt: _date(json['last_viewed_at']),
      );

  final String memberId;
  final String name;
  final DateTime? lastViewedAt;
}

class SharingSession {
  SharingSession({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.status,
    required this.remainingSeconds,
    this.reportsFromMe = true,
    this.lastUpdate,
    this.recipients = const [],
    this.updateSeconds = 30,
    this.distanceMetres = 25,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  factory SharingSession.fromJson(Map<String, dynamic> json) => SharingSession(
    id: json['id'] as String,
    memberId: json['member_id'] as String,
    memberName: json['member_name'] as String? ?? '',
    status: json['status'] as String? ?? 'stopped',
    remainingSeconds: (json['remaining_seconds'] as num?)?.toInt() ?? 0,
    reportsFromMe: json['reports_from_me'] != false,
    lastUpdate: _date(json['last_update']),
    recipients: [
      for (final r in json['recipients'] as List? ?? const [])
        SharingRecipient.fromJson(r as Map<String, dynamic>),
    ],
    updateSeconds: (json['update_seconds'] as num?)?.toInt() ?? 30,
    distanceMetres: (json['distance_metres'] as num?)?.toInt() ?? 25,
  );

  final String id;
  final String memberId;
  final String memberName;
  final String status;

  /// Measured by the server, so a wrong phone clock can't extend it.
  final int remainingSeconds;
  final bool reportsFromMe;
  final DateTime? lastUpdate;
  final List<SharingRecipient> recipients;
  final int updateSeconds;
  final int distanceMetres;
  final DateTime fetchedAt;

  bool get isPaused => status == 'paused';
  bool get isOpen => status == 'active' || status == 'paused';

  DateTime get endsAt => fetchedAt.add(Duration(seconds: remainingSeconds));

  Duration remainingAt(DateTime now) {
    final left = endsAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }
}

class LocationPerson {
  LocationPerson({
    required this.memberId,
    required this.name,
    required this.state,
    required this.remainingSeconds,
    required this.fetchedAt,
    this.hasPhoto = false,
    this.isMe = false,
    this.ageSeconds,
    this.capturedAt,
    this.accuracyM,
    this.latitude,
    this.longitude,
    this.caseId,
    this.caseReference,
    this.liveSeconds = 120,
    this.recentSeconds = 600,
  });

  factory LocationPerson.fromJson(
    Map<String, dynamic> json, {
    required DateTime fetchedAt,
    int liveSeconds = 120,
    int recentSeconds = 600,
  }) {
    final activeCase = json['case'];
    return LocationPerson(
      memberId: json['member_id'] as String,
      name: json['name'] as String? ?? '',
      state: json['state'] as String? ?? 'unavailable',
      remainingSeconds: (json['remaining_seconds'] as num?)?.toInt() ?? 0,
      fetchedAt: fetchedAt,
      hasPhoto: json['has_photo'] == true,
      isMe: json['is_me'] == true,
      ageSeconds: (json['age_seconds'] as num?)?.toInt(),
      capturedAt: _date(json['captured_at']),
      accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      caseId: activeCase is Map ? activeCase['id'] as String? : null,
      caseReference:
          activeCase is Map ? activeCase['reference'] as String? : null,
      liveSeconds: liveSeconds,
      recentSeconds: recentSeconds,
    );
  }

  final String memberId;
  final String name;
  final String state;
  final int remainingSeconds;
  final DateTime fetchedAt;
  final bool hasPhoto;
  final bool isMe;
  final int? ageSeconds;
  final DateTime? capturedAt;
  final double? accuracyM;
  final double? latitude;
  final double? longitude;
  final String? caseId;
  final String? caseReference;
  final int liveSeconds;
  final int recentSeconds;

  bool get hasPosition => latitude != null && longitude != null;

  /// Ages from the moment it was fetched, so "Live" can't outlast the
  /// connection: with no new data, a position simply gets older on screen.
  Freshness freshnessAt(DateTime now) {
    final held = now.difference(fetchedAt).inSeconds;
    if (held >= remainingSeconds) return Freshness.expired;
    if (state == 'paused') return Freshness.paused;
    final age = ageSeconds;
    if (age == null || !hasPosition) return Freshness.unavailable;
    final current = age + held;
    if (current <= liveSeconds) return Freshness.live;
    if (current <= recentSeconds) return Freshness.recent;
    return Freshness.lastKnown;
  }
}

class EndedSharing {
  const EndedSharing({
    required this.memberId,
    required this.name,
    required this.state,
  });

  factory EndedSharing.fromJson(Map<String, dynamic> json) => EndedSharing(
    memberId: json['member_id'] as String,
    name: json['name'] as String? ?? '',
    state: json['state'] as String? ?? 'stopped',
  );

  final String memberId;
  final String name;
  final String state;
}

class LocationFeed {
  const LocationFeed({
    required this.people,
    this.ended = const [],
    this.pollSeconds = 20,
  });

  factory LocationFeed.fromJson(Map<String, dynamic> json, {DateTime? at}) {
    final fetchedAt = at ?? DateTime.now();
    final live = (json['live_seconds'] as num?)?.toInt() ?? 120;
    final recent = (json['recent_seconds'] as num?)?.toInt() ?? 600;
    return LocationFeed(
      pollSeconds: (json['poll_seconds'] as num?)?.toInt() ?? 20,
      people: [
        for (final p in json['people'] as List? ?? const [])
          LocationPerson.fromJson(
            p as Map<String, dynamic>,
            fetchedAt: fetchedAt,
            liveSeconds: live,
            recentSeconds: recent,
          ),
      ],
      ended: [
        for (final e in json['ended'] as List? ?? const [])
          EndedSharing.fromJson(e as Map<String, dynamic>),
      ],
    );
  }

  final List<LocationPerson> people;
  final List<EndedSharing> ended;
  final int pollSeconds;

  /// People still allowed on screen. Someone whose time ran out goes even with
  /// no connection to confirm it.
  List<LocationPerson> visibleAt(DateTime now) => [
    for (final p in people)
      if (p.freshnessAt(now) != Freshness.expired) p,
  ];
}
