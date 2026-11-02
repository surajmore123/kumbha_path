/// Models for Lost & Found, from `/api/lostfound/`. What a person receives
/// depends on who they are: the server leaves out anything they can't see.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:kumbha_path/src/modules/lostfound/models/lf_ai_models.dart';

export 'package:kumbha_path/src/modules/lostfound/models/lf_ai_models.dart';

const vulnerabilityKinds = [
  'child',
  'elderly',
  'medical',
  'communication',
  'other',
];
const foundCategories = [
  'found',
  'separated',
  'child_alone',
  'elderly',
  'medical',
  'other',
];
const contactPreferences = ['app', 'call', 'sms', 'whatsapp'];

/// The stages a family follows, in order. REJECTED and CLOSED sit outside it.
const caseStages = [
  'SUBMITTED',
  'UNDER_REVIEW',
  'VERIFICATION_REQUIRED',
  'POTENTIAL_MATCH_FOUND',
  'MATCH_CONFIRMED',
  'REUNITED',
];

DateTime? _date(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

double? _number(Object? raw) => switch (raw) {
  num n => n.toDouble(),
  String s => double.tryParse(s),
  _ => null,
};

List<String> _strings(Object? raw) => [
  for (final item in raw as List? ?? const []) '$item',
];

List<Map<String, dynamic>> _maps(Object? raw) =>
    (raw as List? ?? const []).whereType<Map<String, dynamic>>().toList();

class LfCapabilities {
  const LfCapabilities({
    this.role,
    this.canReportFound = false,
    this.canOperate = false,
    this.isStaff = false,
  });

  factory LfCapabilities.fromJson(Map<String, dynamic> json) => LfCapabilities(
    role: json['role'] as String?,
    canReportFound: json['can_report_found'] == true,
    canOperate: json['can_operate'] == true,
    isStaff: json['is_staff'] == true,
  );

  final String? role;
  final bool canReportFound;
  final bool canOperate;
  final bool isStaff;
}

class CaseSummary {
  const CaseSummary({
    required this.id,
    required this.reference,
    required this.caseType,
    required this.status,
    this.personName = '',
    this.createdAt,
    this.latestUpdate,
    this.duplicate = false,
  });

  factory CaseSummary.fromJson(Map<String, dynamic> json) => CaseSummary(
    id: json['id'] as String,
    reference: json['reference'] as String? ?? '',
    caseType: json['case_type'] as String? ?? 'lost',
    status: json['status'] as String? ?? 'SUBMITTED',
    personName: json['person_name'] as String? ?? '',
    createdAt: _date(json['created_at']),
    latestUpdate: _date(json['latest_update'] ?? json['updated_at']),
    duplicate: json['duplicate'] == true,
  );

  final String id;
  final String reference;
  final String caseType;
  final String status;
  final String personName;
  final DateTime? createdAt;
  final DateTime? latestUpdate;

  /// The server already had this report, so nothing new was created.
  final bool duplicate;

  bool get isLost => caseType == 'lost';
  bool get isOpen => !const ['REUNITED', 'CLOSED', 'REJECTED'].contains(status);
}

class TimelineEvent {
  const TimelineEvent({
    required this.kind,
    this.status,
    this.noteKind,
    this.body,
    this.at,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) => TimelineEvent(
    kind: json['kind'] as String? ?? 'status',
    status: json['status'] as String?,
    noteKind: json['note_kind'] as String?,
    body: json['body'] as String?,
    at: _date(json['at']),
  );

  final String kind;
  final String? status;
  final String? noteKind;
  final String? body;
  final DateTime? at;
}

class Sighting {
  const Sighting({
    required this.id,
    required this.description,
    this.locationText = '',
    this.seenAt,
    this.latitude,
    this.longitude,
    this.verified = false,
    this.fromHelper = false,
    this.review = 'approved',
  });

  factory Sighting.fromJson(Map<String, dynamic> json) => Sighting(
    id: json['id'] as String,
    description: json['description'] as String? ?? '',
    locationText: json['location_text'] as String? ?? '',
    seenAt: _date(json['seen_at']),
    latitude: _number(json['latitude']),
    longitude: _number(json['longitude']),
    verified: json['location_label'] == 'verified' || json['verified'] == true,
    fromHelper:
        json['source'] == 'helper' ||
        (json['reporter_role'] != null && json['reporter_role'] != 'pilgrim'),
    review: json['review'] as String? ?? 'approved',
  );

  final String id;
  final String description;
  final String locationText;
  final DateTime? seenAt;
  final double? latitude;
  final double? longitude;

  /// Checked first-hand by staff, rather than only reported.
  final bool verified;
  final bool fromHelper;
  final String review;
}

class CaseDetail {
  const CaseDetail({
    required this.id,
    required this.reference,
    required this.caseType,
    required this.status,
    this.personName = '',
    this.ageMin,
    this.ageMax,
    this.physical = '',
    this.clothing = '',
    this.marks = '',
    this.circumstances = '',
    this.vulnerabilities = const [],
    this.foundCategory = '',
    this.safeFacility = '',
    this.eventAt,
    this.locationText = '',
    this.latitude,
    this.longitude,
    this.attachmentIds = const [],
    this.timeline = const [],
    this.sightings = const [],
    this.familyConfirmedAt,
    this.isMyReport = false,
    this.familyView = true,
  });

  factory CaseDetail.fromJson(Map<String, dynamic> json) => CaseDetail(
    id: json['id'] as String,
    reference: json['reference'] as String? ?? '',
    caseType: json['case_type'] as String? ?? 'lost',
    status: json['status'] as String? ?? 'SUBMITTED',
    personName: json['person_name'] as String? ?? '',
    ageMin: json['age_min'] as int?,
    ageMax: json['age_max'] as int?,
    physical: json['physical_description'] as String? ?? '',
    clothing: json['clothing_description'] as String? ?? '',
    marks: json['identifying_marks'] as String? ?? '',
    circumstances: json['circumstances'] as String? ?? '',
    vulnerabilities: _strings(json['vulnerabilities']),
    foundCategory: json['found_category'] as String? ?? '',
    safeFacility: json['safe_facility'] as String? ?? '',
    eventAt: _date(json['event_at']),
    locationText: json['location_text'] as String? ?? '',
    latitude: _number(json['latitude']),
    longitude: _number(json['longitude']),
    attachmentIds: _strings(json['attachment_ids']),
    timeline: _maps(json['timeline']).map(TimelineEvent.fromJson).toList(),
    sightings: _maps(json['sightings']).map(Sighting.fromJson).toList(),
    familyConfirmedAt: _date(json['family_confirmed_at']),
    isMyReport: json['is_my_report'] == true,
    familyView: json.containsKey('timeline'),
  );

  final String id;
  final String reference;
  final String caseType;
  final String status;
  final String personName;
  final int? ageMin;
  final int? ageMax;
  final String physical;
  final String clothing;
  final String marks;
  final String circumstances;
  final List<String> vulnerabilities;
  final String foundCategory;
  final String safeFacility;
  final DateTime? eventAt;
  final String locationText;
  final double? latitude;
  final double? longitude;
  final List<String> attachmentIds;
  final List<TimelineEvent> timeline;
  final List<Sighting> sightings;
  final DateTime? familyConfirmedAt;
  final bool isMyReport;

  /// False for a helper's own report, which holds far less.
  final bool familyView;

  bool get isLost => caseType == 'lost';
  bool get isOpen => !const ['REUNITED', 'CLOSED', 'REJECTED'].contains(status);
  bool get canCancel =>
      isOpen && isMyReport && isLost && status != 'MATCH_CONFIRMED';
}

class MatchReason {
  const MatchReason({
    required this.attribute,
    required this.points,
    required this.outOf,
    required this.detail,
  });

  factory MatchReason.fromJson(Map<String, dynamic> json) => MatchReason(
    attribute: json['attribute'] as String? ?? '',
    points: json['points'] as int? ?? 0,
    outOf: json['out_of'] as int? ?? 0,
    detail: json['detail'] as String? ?? '',
  );

  final String attribute;
  final int points;
  final int outOf;
  final String detail;
}

class MatchSide {
  const MatchSide({
    required this.id,
    required this.reference,
    this.ageMin,
    this.ageMax,
    this.physical = '',
    this.clothing = '',
    this.locationText = '',
    this.eventAt,
  });

  factory MatchSide.fromJson(Map<String, dynamic> json) => MatchSide(
    id: json['id'] as String,
    reference: json['reference'] as String? ?? '',
    ageMin: json['age_min'] as int?,
    ageMax: json['age_max'] as int?,
    physical: json['physical_description'] as String? ?? '',
    clothing: json['clothing_description'] as String? ?? '',
    locationText: json['location_text'] as String? ?? '',
    eventAt: _date(json['event_at']),
  );

  final String id;
  final String reference;
  final int? ageMin;
  final int? ageMax;
  final String physical;
  final String clothing;
  final String locationText;
  final DateTime? eventAt;
}

class CaseMatch {
  const CaseMatch({
    required this.id,
    required this.score,
    required this.state,
    required this.lost,
    required this.found,
    this.reasons = const [],
    this.explanation = const MatchExplanation(),
  });

  factory CaseMatch.fromJson(Map<String, dynamic> json) => CaseMatch(
    id: json['id'] as String,
    score: json['score'] as int? ?? 0,
    state: json['state'] as String? ?? 'suggested',
    lost: MatchSide.fromJson(json['lost'] as Map<String, dynamic>),
    found: MatchSide.fromJson(json['found'] as Map<String, dynamic>),
    reasons: _maps(json['reasons']).map(MatchReason.fromJson).toList(),
    explanation: MatchExplanation.fromJson(
      json['explanation'] as Map<String, dynamic>?,
    ),
  );

  final String id;
  final int score;
  final String state;
  final MatchSide lost;
  final MatchSide found;
  final List<MatchReason> reasons;
  final MatchExplanation explanation;
}

class OpsCaseRow {
  const OpsCaseRow({
    required this.id,
    required this.reference,
    required this.caseType,
    required this.status,
    this.personName = '',
    this.locationText = '',
    this.eventAt,
    this.isVulnerable = false,
    this.matchCount = 0,
    this.assignedToMe = false,
  });

  factory OpsCaseRow.fromJson(Map<String, dynamic> json) => OpsCaseRow(
    id: json['id'] as String,
    reference: json['reference'] as String? ?? '',
    caseType: json['case_type'] as String? ?? 'lost',
    status: json['status'] as String? ?? 'SUBMITTED',
    personName: json['person_name'] as String? ?? '',
    locationText: json['location_text'] as String? ?? '',
    eventAt: _date(json['event_at']),
    isVulnerable: json['is_vulnerable'] == true,
    matchCount: json['match_count'] as int? ?? 0,
    assignedToMe: json['assigned_to_me'] == true,
  );

  final String id;
  final String reference;
  final String caseType;
  final String status;
  final String personName;
  final String locationText;
  final DateTime? eventAt;
  final bool isVulnerable;
  final int matchCount;
  final bool assignedToMe;
}

class OpsPage {
  const OpsPage({required this.rows, this.count = 0, this.hasNext = false});

  final List<OpsCaseRow> rows;
  final int count;
  final bool hasNext;
}

class OpsNote {
  const OpsNote({required this.kind, required this.body, this.at});

  factory OpsNote.fromJson(Map<String, dynamic> json) => OpsNote(
    kind: json['kind'] as String? ?? 'internal',
    body: json['body'] as String? ?? '',
    at: _date(json['created_at']),
  );

  final String kind;
  final String body;
  final DateTime? at;
}

class OpsCase {
  const OpsCase({
    required this.row,
    required this.detail,
    this.notes = const [],
    this.sightings = const [],
    this.matches = const [],
    this.allowedStatuses = const [],
    this.linkedToFamily = false,
    this.assistance = '',
    this.familyConfirmed = false,
  });

  factory OpsCase.fromJson(Map<String, dynamic> json) => OpsCase(
    row: OpsCaseRow.fromJson(json),
    detail: CaseDetail.fromJson(json),
    notes: _maps(json['notes']).map(OpsNote.fromJson).toList(),
    sightings: _maps(json['sightings']).map(Sighting.fromJson).toList(),
    matches: _maps(json['matches']).map(CaseMatch.fromJson).toList(),
    allowedStatuses: _strings(json['allowed_statuses']),
    linkedToFamily: json['linked_to_family'] == true,
    assistance: json['assistance_needed'] as String? ?? '',
    familyConfirmed: json['family_confirmed_at'] != null,
  );

  final OpsCaseRow row;
  final CaseDetail detail;
  final List<OpsNote> notes;
  final List<Sighting> sightings;
  final List<CaseMatch> matches;
  final List<String> allowedStatuses;
  final bool linkedToFamily;
  final String assistance;
  final bool familyConfirmed;
}

enum DraftState {
  /// Being written. Only on this phone.
  editing,

  /// Finished, waiting for a connection. Not yet with anyone.
  waiting,

  /// The server has the report; its photo is still to go.
  uploadingPhoto,

  /// The server refused it. Needs editing.
  refused,
}

/// A report on this phone. Its id goes to the server as `client_id`, so however
/// many times it's retried, only one case can ever be created.
class ReportDraft {
  const ReportDraft({
    required this.id,
    required this.kind,
    required this.fields,
    this.photo,
    this.state = DraftState.editing,
    this.caseId,
    this.updatedAt,
  });

  factory ReportDraft.fromRow(Map<String, Object?> row) => ReportDraft(
    id: row['id']! as String,
    kind: row['kind']! as String,
    fields: jsonDecode(row['fields']! as String) as Map<String, dynamic>,
    photo: row['photo'] as Uint8List?,
    state: DraftState.values.byName(row['state']! as String),
    caseId: row['case_id'] as String?,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
  );

  final String id;

  /// `lost` or `found`.
  final String kind;
  final Map<String, dynamic> fields;
  final Uint8List? photo;
  final DraftState state;
  final String? caseId;
  final DateTime? updatedAt;

  ReportDraft copyWith({
    Map<String, dynamic>? fields,
    Uint8List? photo,
    bool clearPhoto = false,
    DraftState? state,
    String? caseId,
  }) => ReportDraft(
    id: id,
    kind: kind,
    fields: fields ?? this.fields,
    photo: clearPhoto ? null : (photo ?? this.photo),
    state: state ?? this.state,
    caseId: caseId ?? this.caseId,
    updatedAt: updatedAt,
  );

  /// Private, so this must never print its contents.
  @override
  String toString() => 'ReportDraft(${state.name})';
}
