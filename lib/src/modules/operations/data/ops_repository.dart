import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';

export 'package:kumbha_path/src/modules/family/data/family_repository.dart'
    show FamilyException, FamilyFailure;

DateTime? _date(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

const availabilityStates = ['AVAILABLE', 'BUSY', 'OFF_DUTY', 'UNAVAILABLE'];

class OpsZone {
  const OpsZone({required this.id, required this.name, this.code = ''});

  factory OpsZone.fromJson(Map<String, dynamic> json) => OpsZone(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    code: json['code'] as String? ?? '',
  );

  final String id;
  final String name;
  final String code;
}

/// Who the server says this person is. The app only ever reads this: nothing
/// stored on the phone decides a role.
class OpsMe {
  const OpsMe({
    required this.role,
    this.userId = '',
    this.status,
    this.fullName = '',
    this.availability = 'AVAILABLE',
    this.zones = const [],
    this.canManageCases = false,
    this.canViewSos = false,
    this.canAssign = false,
    this.canViewTeam = false,
    this.canScan = false,
  });

  factory OpsMe.fromJson(Map<String, dynamic> json) {
    final can = json['can'] is Map ? json['can'] as Map : const {};
    return OpsMe(
      role: json['role'] as String? ?? 'PILGRIM',
      userId: json['user_id'] as String? ?? '',
      status: json['status'] as String?,
      fullName: json['full_name'] as String? ?? '',
      availability: json['availability'] as String? ?? 'AVAILABLE',
      zones: [
        for (final z in json['zones'] as List? ?? const [])
          OpsZone.fromJson(z as Map<String, dynamic>),
      ],
      canManageCases: can['manage_cases'] == true,
      canViewSos: can['view_sos'] == true,
      canAssign: can['assign_cases'] == true,
      canViewTeam: can['view_team'] == true,
      canScan: can['scan'] == true,
    );
  }

  final String role;
  final String userId;
  final String? status;
  final String fullName;
  final String availability;
  final List<OpsZone> zones;
  final bool canManageCases;
  final bool canViewSos;
  final bool canAssign;
  final bool canViewTeam;
  final bool canScan;

  bool get isPilgrim => role == 'PILGRIM';
  bool get isActive => status == 'active';
}

class OpsOverview {
  const OpsOverview({
    this.active = 0,
    this.pending = 0,
    this.completed = 0,
    this.openSos,
    this.openCases,
    this.unassigned,
    this.escalations,
  });

  factory OpsOverview.fromJson(Map<String, dynamic> json) => OpsOverview(
    active: (json['active'] as num?)?.toInt() ?? 0,
    pending: (json['pending'] as num?)?.toInt() ?? 0,
    completed: (json['completed'] as num?)?.toInt() ?? 0,
    openSos: (json['open_sos'] as num?)?.toInt(),
    openCases: (json['open_cases'] as num?)?.toInt(),
    unassigned: (json['unassigned'] as num?)?.toInt(),
    escalations: (json['escalations'] as num?)?.toInt(),
  );

  final int active;
  final int pending;
  final int completed;
  final int? openSos;
  final int? openCases;
  final int? unassigned;
  final int? escalations;
}

class OpsAssignment {
  const OpsAssignment({
    required this.id,
    required this.status,
    this.notes = '',
    this.escalationReason = '',
    this.volunteerId = '',
    this.volunteerName = '',
    this.assignedAt,
  });

  factory OpsAssignment.fromJson(Map<String, dynamic> json) => OpsAssignment(
    id: json['id'] as String,
    status: json['status'] as String? ?? 'ASSIGNED',
    notes: json['notes'] as String? ?? '',
    escalationReason: json['escalation_reason'] as String? ?? '',
    volunteerId: json['volunteer_id'] as String? ?? '',
    volunteerName: json['volunteer_name'] as String? ?? '',
    assignedAt: _date(json['assigned_at']),
  );

  final String id;
  final String status;
  final String notes;
  final String escalationReason;
  final String volunteerId;
  final String volunteerName;
  final DateTime? assignedAt;
}

class OpsCase {
  const OpsCase({
    required this.id,
    required this.reference,
    required this.caseType,
    required this.status,
    this.priority = 'normal',
    this.locationText = '',
    this.eventAt,
    this.zone,
    this.assignment,
    this.personName = '',
    this.ageMin,
    this.ageMax,
    this.physical = '',
    this.clothing = '',
    this.marks = '',
    this.safeFacility = '',
    this.latitude,
    this.longitude,
  });

  factory OpsCase.fromJson(Map<String, dynamic> json) => OpsCase(
    id: json['id'] as String,
    reference: json['reference'] as String? ?? '',
    caseType: json['case_type'] as String? ?? 'lost',
    status: json['status'] as String? ?? 'SUBMITTED',
    priority: json['priority'] as String? ?? 'normal',
    locationText: json['location_text'] as String? ?? '',
    eventAt: _date(json['event_at']),
    zone:
        json['zone'] is Map<String, dynamic>
            ? OpsZone.fromJson(json['zone'] as Map<String, dynamic>)
            : null,
    assignment:
        json['assignment'] is Map<String, dynamic>
            ? OpsAssignment.fromJson(json['assignment'] as Map<String, dynamic>)
            : null,
    personName: json['person_name'] as String? ?? '',
    ageMin: (json['age_min'] as num?)?.toInt(),
    ageMax: (json['age_max'] as num?)?.toInt(),
    physical: json['physical_description'] as String? ?? '',
    clothing: json['clothing_description'] as String? ?? '',
    marks: json['identifying_marks'] as String? ?? '',
    safeFacility: json['safe_facility'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );

  final String id;
  final String reference;
  final String caseType;
  final String status;
  final String priority;
  final String locationText;
  final DateTime? eventAt;
  final OpsZone? zone;
  final OpsAssignment? assignment;
  final String personName;
  final int? ageMin;
  final int? ageMax;
  final String physical;
  final String clothing;
  final String marks;
  final String safeFacility;
  final double? latitude;
  final double? longitude;

  bool get isHighPriority => priority == 'high';
}

class TeamMember {
  const TeamMember({
    required this.userId,
    required this.name,
    required this.role,
    this.availability = 'AVAILABLE',
    this.openCases = 0,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
    userId: json['user_id'] as String,
    name: json['name'] as String? ?? '',
    role: json['role'] as String? ?? 'VOLUNTEER',
    availability: json['availability'] as String? ?? 'AVAILABLE',
    openCases: (json['open_cases'] as num?)?.toInt() ?? 0,
  );

  final String userId;
  final String name;
  final String role;
  final String availability;
  final int openCases;

  bool get canTakeWork => availability == 'AVAILABLE' || availability == 'BUSY';
}

class ZonePoint {
  const ZonePoint({
    required this.name,
    required this.category,
    this.isOfficial = false,
  });

  factory ZonePoint.fromJson(Map<String, dynamic> json) => ZonePoint(
    name: json['name'] as String? ?? '',
    category: json['category'] as String? ?? 'help_desk',
    isOfficial: json['is_official'] == true,
  );

  final String name;
  final String category;
  final bool isOfficial;
}

class ZoneInfo {
  const ZoneInfo({required this.zone, this.city = '', this.points = const []});

  factory ZoneInfo.fromJson(Map<String, dynamic> json) => ZoneInfo(
    zone: OpsZone.fromJson(json),
    city: json['city'] as String? ?? '',
    points: [
      for (final p in json['points'] as List? ?? const [])
        ZonePoint.fromJson(p as Map<String, dynamic>),
    ],
  );

  final OpsZone zone;
  final String city;
  final List<ZonePoint> points;
}

class OpsSosRow {
  const OpsSosRow({
    required this.id,
    required this.reference,
    required this.category,
    required this.status,
    this.createdAt,
  });

  factory OpsSosRow.fromJson(Map<String, dynamic> json) => OpsSosRow(
    id: json['id'] as String,
    reference: json['reference'] as String? ?? '',
    category: json['category'] as String? ?? 'other',
    status: json['status'] as String? ?? 'SUBMITTED',
    createdAt: _date(json['created_at']),
  );

  final String id;
  final String reference;
  final String category;
  final String status;
  final DateTime? createdAt;
}

abstract class OpsRepository {
  /// Sign-in needs no token, and returns one.
  Future<String> signIn(String phone, String password);
  Future<String> completeSetup(String phone, String code, String password);

  Future<OpsMe> me();
  Future<OpsOverview> overview();
  Future<void> setAvailability(String availability);
  Future<List<OpsCase>> myCases({String status, String? type});
  Future<List<OpsCase>> unassigned();
  Future<List<OpsCase>> escalations();
  Future<OpsCase> caseDetail(String id);
  Future<void> progress(String id, String status);
  Future<void> addObservation(String id, String body);
  Future<void> escalate(String id, String reason);
  Future<void> assign(String id, String volunteerId, {String notes});
  Future<void> unassign(String id);
  Future<List<OpsAssignment>> history(String id);
  Future<List<TeamMember>> team();
  Future<List<ZoneInfo>> zones();
  Future<List<OpsSosRow>> sosList();

  /// acknowledge, coordinate, update, escalate, resolve or close.
  Future<void> sosAction(String id, String action, {String? body});
}

class HttpOpsRepository implements OpsRepository {
  HttpOpsRepository({
    http.Client? client,
    Future<String?> Function()? token,
    this.requireHttps = kReleaseMode,
  }) : _client = client ?? http.Client(),
       _token = token ?? (() => storage.read(key: 'access_token'));

  final http.Client _client;
  final Future<String?> Function() _token;
  final bool requireHttps;

  static const _timeout = Duration(seconds: 15);

  static Map<String, String> _errors(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, String>{};
    raw.forEach((key, value) {
      final msg = value is List ? value.whereType<String>().firstOrNull : value;
      if (msg is String && msg.trim().isNotEmpty) out['$key'] = msg.trim();
    });
    return out;
  }

  Future<Object?> _call(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool signedIn = true,
  }) async {
    if (requireHttps && ApiConst.protocol != 'https') {
      throw const FamilyException(FamilyFailure.server);
    }
    final uri =
        ApiConst.protocol == 'https'
            ? Uri.https(ApiConst.host, path, query)
            : Uri.http(ApiConst.host, path, query);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      });
    if (signedIn) {
      String? token;
      try {
        token = await _token();
      } catch (_) {
        token = null;
      }
      if (token == null || token.isEmpty || token == 'null') {
        throw const FamilyException(FamilyFailure.signedOut);
      }
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) request.body = jsonEncode(body);
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      );
    } on SocketException {
      throw const FamilyException(FamilyFailure.offline);
    } on TimeoutException {
      throw const FamilyException(FamilyFailure.offline);
    } on http.ClientException {
      throw const FamilyException(FamilyFailure.offline);
    }
    Map<String, dynamic>? decoded;
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      decoded = json is Map<String, dynamic> ? json : null;
    } on FormatException {
      decoded = null;
    }
    final code = response.statusCode;
    if (code >= 200 && code < 300) return decoded?['data'];
    throw FamilyException(switch (code) {
      401 => FamilyFailure.signedOut,
      403 => FamilyFailure.forbidden,
      404 => FamilyFailure.notFound,
      400 => FamilyFailure.invalid,
      409 => FamilyFailure.conflict,
      _ => FamilyFailure.server,
    }, fieldErrors: _errors(decoded?['errors']));
  }

  Map<String, dynamic> _map(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw const FamilyException(FamilyFailure.server);
  }

  static const _ops = '/api/operations';

  String _accessToken(Object? data) {
    final token = _map(data)['access_token'];
    if (token is String && token.isNotEmpty) return token;
    throw const FamilyException(FamilyFailure.server);
  }

  List<OpsCase> _cases(Object? data) => [
    for (final row in _map(data)['results'] as List? ?? const [])
      OpsCase.fromJson(row as Map<String, dynamic>),
  ];

  @override
  Future<String> signIn(String phone, String password) async => _accessToken(
    await _call(
      'POST',
      '$_ops/auth/login/',
      body: {'phone_number': phone, 'password': password},
      signedIn: false,
    ),
  );

  @override
  Future<String> completeSetup(
    String phone,
    String code,
    String password,
  ) async => _accessToken(
    await _call(
      'POST',
      '$_ops/auth/setup/',
      body: {'phone_number': phone, 'code': code, 'password': password},
      signedIn: false,
    ),
  );

  @override
  Future<OpsMe> me() async =>
      OpsMe.fromJson(_map(await _call('GET', '$_ops/me/')));

  @override
  Future<OpsOverview> overview() async =>
      OpsOverview.fromJson(_map(await _call('GET', '$_ops/overview/')));

  @override
  Future<void> setAvailability(String availability) async {
    await _call(
      'PATCH',
      '$_ops/me/availability/',
      body: {'availability': availability},
    );
  }

  @override
  Future<List<OpsCase>> myCases({String status = 'open', String? type}) async =>
      _cases(
        await _call(
          'GET',
          '$_ops/cases/',
          query: {'status': status, if (type != null) 'type': type},
        ),
      );

  @override
  Future<List<OpsCase>> unassigned() async {
    final data = _map(
      await _call(
        'GET',
        '/api/lostfound/ops/cases/',
        query: {'unassigned': 'true'},
      ),
    );
    return [
      for (final row in data['results'] as List? ?? const [])
        OpsCase(
          id: (row as Map<String, dynamic>)['id'] as String,
          reference: row['reference'] as String? ?? '',
          caseType: row['case_type'] as String? ?? 'lost',
          status: row['status'] as String? ?? 'SUBMITTED',
          priority: row['is_vulnerable'] == true ? 'high' : 'normal',
          locationText: row['location_text'] as String? ?? '',
          eventAt: _date(row['event_at']),
        ),
    ];
  }

  @override
  Future<List<OpsCase>> escalations() async =>
      _cases(await _call('GET', '$_ops/escalations/'));

  @override
  Future<OpsCase> caseDetail(String id) async =>
      OpsCase.fromJson(_map(await _call('GET', '$_ops/cases/$id/')));

  @override
  Future<void> progress(String id, String status) async {
    await _call('POST', '$_ops/cases/$id/progress/', body: {'status': status});
  }

  @override
  Future<void> addObservation(String id, String body) async {
    await _call('POST', '$_ops/cases/$id/observation/', body: {'body': body});
  }

  @override
  Future<void> escalate(String id, String reason) async {
    await _call('POST', '$_ops/cases/$id/escalate/', body: {'reason': reason});
  }

  @override
  Future<void> assign(
    String id,
    String volunteerId, {
    String notes = '',
  }) async {
    await _call(
      'POST',
      '$_ops/cases/$id/assign/',
      body: {'volunteer_id': volunteerId, 'notes': notes},
    );
  }

  @override
  Future<void> unassign(String id) async {
    await _call('POST', '$_ops/cases/$id/unassign/', body: {});
  }

  @override
  Future<List<OpsAssignment>> history(String id) async {
    final data = await _call('GET', '$_ops/cases/$id/assignments/');
    return [
      for (final row in data as List? ?? const [])
        OpsAssignment.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<TeamMember>> team() async {
    final data = await _call('GET', '$_ops/team/');
    return [
      for (final row in data as List? ?? const [])
        TeamMember.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<ZoneInfo>> zones() async {
    final data = await _call('GET', '$_ops/zones/');
    return [
      for (final row in data as List? ?? const [])
        ZoneInfo.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<OpsSosRow>> sosList() async {
    final data = _map(await _call('GET', '/api/emergency/ops/sos/'));
    return [
      for (final row in data['results'] as List? ?? const [])
        OpsSosRow.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> sosAction(String id, String action, {String? body}) async {
    await _call(
      'POST',
      '/api/emergency/ops/sos/$id/$action/',
      body: {if (body != null) 'body': body},
    );
  }
}

class OpsServices {
  OpsServices._();

  static OpsRepository repository = HttpOpsRepository();
}
