/// Models for the Family Reunification Map. Family positions aren't here: they
/// stay in the location feed, and case facts stay in Lost & Found.
library;

import 'package:kumbha_path/src/modules/lostfound/models/lf_models.dart';

DateTime? _date(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

const pointCategories = [
  'help_desk',
  'lost_found',
  'police',
  'emergency',
  'medical',
  'hospital',
  'ambulance',
  'fire_rescue',
  'family_meeting',
];

/// The stages shown on a case, in order.
const reunionStages = [
  'reported',
  'point_chosen',
  'at_point',
  'verifying',
  'reunited',
];

class MeetingPoint {
  const MeetingPoint({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.description = '',
    this.isVerified = false,
    this.isOfficial = false,
    this.sourceDetail = '',
    this.isPrivate = false,
    this.address = '',
    this.openingHours = '',
    this.contactPhone = '',
    this.verifiedAt,
    this.straightLineKm,
  });

  factory MeetingPoint.fromJson(Map<String, dynamic> json) => MeetingPoint(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    category: json['category'] as String? ?? 'family_meeting',
    status: json['status'] as String? ?? 'community',
    isVerified: json['is_verified'] == true,
    isOfficial: json['is_official'] == true,
    sourceDetail: json['source_detail'] as String? ?? '',
    isPrivate: json['is_private'] == true,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    address: json['address'] as String? ?? '',
    openingHours: json['opening_hours'] as String? ?? '',
    contactPhone: json['contact_phone'] as String? ?? '',
    verifiedAt: _date(json['verified_at']),
    straightLineKm: (json['straight_line_km'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'status': status,
    'is_verified': isVerified,
    'is_official': isOfficial,
    'source_detail': sourceDetail,
    'is_private': isPrivate,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'opening_hours': openingHours,
    'contact_phone': contactPhone,
    'verified_at': verifiedAt?.toUtc().toIso8601String(),
  };

  final String id;
  final String name;
  final String description;
  final String category;
  final String status;
  final bool isVerified;
  final bool isOfficial;
  final String sourceDetail;
  final bool isPrivate;
  final double latitude;
  final double longitude;
  final String address;
  final String openingHours;
  final String contactPhone;
  final DateTime? verifiedAt;

  /// As the crow flies, from the server. Never a walking distance.
  final double? straightLineKm;

  bool get isFamilySpot => category == 'family_meeting';
}

class ReunionPlan {
  const ReunionPlan({
    this.stage = 'reported',
    this.meetingPoint,
    this.selectedAt,
    this.familyArrivedAt,
    this.personArrivedAt,
  });

  factory ReunionPlan.fromJson(Map<String, dynamic> json) {
    final point = json['meeting_point'];
    return ReunionPlan(
      stage: json['stage'] as String? ?? 'reported',
      meetingPoint:
          point is Map<String, dynamic> ? MeetingPoint.fromJson(point) : null,
      selectedAt: _date(json['selected_at']),
      familyArrivedAt: _date(json['family_arrived_at']),
      personArrivedAt: _date(json['person_arrived_at']),
    );
  }

  final String stage;
  final MeetingPoint? meetingPoint;
  final DateTime? selectedAt;
  final DateTime? familyArrivedAt;
  final DateTime? personArrivedAt;
}

/// An open case as the map may show it. A place the viewer isn't allowed to
/// see simply arrives as null.
class CaseMarker {
  const CaseMarker({
    required this.id,
    required this.reference,
    required this.status,
    required this.personName,
    this.memberId,
    this.isProtected = false,
    this.eventAt,
    this.locationText = '',
    this.latitude,
    this.longitude,
    this.sightings = const [],
    this.plan = const ReunionPlan(),
  });

  factory CaseMarker.fromJson(Map<String, dynamic> json) => CaseMarker(
    id: json['id'] as String,
    reference: json['reference'] as String? ?? '',
    status: json['status'] as String? ?? 'SUBMITTED',
    personName: json['person_name'] as String? ?? '',
    memberId: json['member_id'] as String?,
    isProtected: json['protected'] == true,
    eventAt: _date(json['event_at']),
    locationText: json['location_text'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    sightings: [
      for (final s in json['sightings'] as List? ?? const [])
        Sighting.fromJson(s as Map<String, dynamic>),
    ],
    plan:
        json['plan'] is Map<String, dynamic>
            ? ReunionPlan.fromJson(json['plan'] as Map<String, dynamic>)
            : const ReunionPlan(),
  );

  final String id;
  final String reference;
  final String status;
  final String personName;
  final String? memberId;
  final bool isProtected;
  final DateTime? eventAt;
  final String locationText;
  final double? latitude;
  final double? longitude;
  final List<Sighting> sightings;
  final ReunionPlan plan;

  bool get hasPlace => latitude != null && longitude != null;
}

class ReunionOverview {
  const ReunionOverview({this.cases = const [], this.selfProtected = false});

  factory ReunionOverview.fromJson(Map<String, dynamic> json) =>
      ReunionOverview(
        selfProtected: json['self_protected'] == true,
        cases: [
          for (final c in json['cases'] as List? ?? const [])
            CaseMarker.fromJson(c as Map<String, dynamic>),
        ],
      );

  final List<CaseMarker> cases;

  /// This phone is with someone who should go to staff, not walk to family.
  final bool selfProtected;
}

class ReunionCase {
  const ReunionCase({
    required this.detail,
    required this.plan,
    this.isProtected = false,
    this.canOperate = false,
  });

  factory ReunionCase.fromJson(Map<String, dynamic> json) => ReunionCase(
    detail: CaseDetail.fromJson(json['case'] as Map<String, dynamic>),
    plan: ReunionPlan.fromJson(json['plan'] as Map<String, dynamic>),
    isProtected: json['protected'] == true,
    canOperate: json['can_operate'] == true,
  );

  final CaseDetail detail;
  final ReunionPlan plan;
  final bool isProtected;
  final bool canOperate;
}

class PointPage {
  const PointPage({required this.points, this.savedAt});

  final List<MeetingPoint> points;

  /// Set when this is the copy on the phone, not an answer from the server.
  final DateTime? savedAt;
}

/// Where a route goes. The server looks the destination up again and checks
/// permission: the coordinates here are only for opening Google Maps.
class RouteTarget {
  const RouteTarget({
    required this.kind,
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.caseId,
  });

  final String kind;
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? caseId;

  String get key => '$kind:$id:${caseId ?? ''}';
}

class WalkingRoute {
  WalkingRoute({
    required this.name,
    required this.distanceM,
    required this.durationS,
    required this.polyline,
    this.state,
    this.capturedAt,
    this.caution,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  factory WalkingRoute.fromJson(Map<String, dynamic> json) => WalkingRoute(
    name: json['name'] as String? ?? '',
    distanceM: (json['distance_m'] as num).toInt(),
    durationS: (json['duration_s'] as num).toInt(),
    polyline: json['polyline'] as String? ?? '',
    state: json['state'] as String?,
    capturedAt: _date(json['captured_at']),
    caution: json['caution'] as String?,
  );

  final String name;
  final int distanceM;
  final int durationS;
  final String polyline;

  /// How fresh the destination is, for a family member.
  final String? state;
  final DateTime? capturedAt;
  final String? caution;
  final DateTime fetchedAt;
}
