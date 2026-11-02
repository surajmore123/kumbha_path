import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/reunion/models/reunion_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:kumbha_path/src/modules/family/data/family_repository.dart'
    show FamilyException, FamilyFailure;

/// The routing provider can't answer. Nothing about a route is known.
class RouteUnavailable implements Exception {
  const RouteUnavailable();
}

/// The server refused because this person belongs with staff.
class UseSafePoint implements Exception {
  const UseSafePoint();
}

abstract class ReunionRepository {
  Future<ReunionOverview> overview({String? familyId});
  Future<List<MeetingPoint>> points({String? category, bool verifiedOnly});
  Future<MeetingPoint> addFamilyPoint(
    String familyId, {
    required String name,
    required double latitude,
    required double longitude,
    String description,
  });
  Future<void> suggestPoint(String id);
  Future<void> removePoint(String id);
  Future<ReunionCase> caseView(String id);
  Future<List<MeetingPoint>> guidance(
    String caseId, {
    (double, double)? origin,
  });
  Future<void> choosePoint(String caseId, String pointId);
  Future<void> coordinate(String caseId, {String? event, String? update});
  Future<WalkingRoute> route(RouteTarget target, (double, double) origin);
  Future<int> notifyFamily(String familyId, String kind, {String? pointId});
}

/// The live backend. Release builds refuse plain HTTP.
class HttpReunionRepository implements ReunionRepository {
  HttpReunionRepository({
    http.Client? client,
    Future<String?> Function()? token,
    this.requireHttps = kReleaseMode,
  }) : _client = client ?? http.Client(),
       _token = token ?? (() => storage.read(key: 'access_token'));

  final http.Client _client;
  final Future<String?> Function() _token;
  final bool requireHttps;

  static const _timeout = Duration(seconds: 20);

  Uri _uri(String path, [Map<String, String>? query]) {
    final p = '/api/reunification/$path';
    return ApiConst.protocol == 'https'
        ? Uri.https(ApiConst.host, p, query)
        : Uri.http(ApiConst.host, p, query);
  }

  Future<String> _bearer() async {
    if (requireHttps && ApiConst.protocol != 'https') {
      throw const FamilyException(FamilyFailure.server);
    }
    String? token;
    try {
      token = await _token();
    } catch (_) {
      token = null;
    }
    if (token == null || token.isEmpty || token == 'null') {
      throw const FamilyException(FamilyFailure.signedOut);
    }
    return token;
  }

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
  }) async {
    final request = http.Request(method, _uri(path, query))
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await _bearer()}',
      });
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
    final errors = _errors(decoded?['errors']);
    if (errors['code'] == 'routing_unavailable') throw const RouteUnavailable();
    if (errors['code'] == 'use_safe_point') throw const UseSafePoint();
    throw FamilyException(switch (code) {
      401 => FamilyFailure.signedOut,
      403 => FamilyFailure.forbidden,
      404 => FamilyFailure.notFound,
      400 => FamilyFailure.invalid,
      409 => FamilyFailure.conflict,
      _ => FamilyFailure.server,
    }, fieldErrors: errors);
  }

  Map<String, dynamic> _map(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw const FamilyException(FamilyFailure.server);
  }

  @override
  Future<ReunionOverview> overview({String? familyId}) async =>
      ReunionOverview.fromJson(
        _map(
          await _call(
            'GET',
            'overview/',
            query: familyId == null ? null : {'family_id': familyId},
          ),
        ),
      );

  @override
  Future<List<MeetingPoint>> points({
    String? category,
    bool verifiedOnly = false,
  }) async {
    final out = <MeetingPoint>[];
    for (var page = 1; ; page++) {
      final data = _map(
        await _call(
          'GET',
          'points/',
          query: {
            'page': '$page',
            if (category != null) 'category': category,
            if (verifiedOnly) 'verified': 'true',
          },
        ),
      );
      for (final row in data['results'] as List? ?? const []) {
        out.add(MeetingPoint.fromJson(row as Map<String, dynamic>));
      }
      if (data['has_next'] != true) return out;
    }
  }

  @override
  Future<MeetingPoint> addFamilyPoint(
    String familyId, {
    required String name,
    required double latitude,
    required double longitude,
    String description = '',
  }) async => MeetingPoint.fromJson(
    _map(
      await _call(
        'POST',
        'circles/$familyId/points/',
        body: {
          'name': name,
          'description': description,
          'latitude': latitude,
          'longitude': longitude,
        },
      ),
    ),
  );

  @override
  Future<void> suggestPoint(String id) async {
    await _call('POST', 'points/$id/suggest/', body: {});
  }

  @override
  Future<void> removePoint(String id) async {
    await _call('DELETE', 'points/$id/');
  }

  @override
  Future<ReunionCase> caseView(String id) async =>
      ReunionCase.fromJson(_map(await _call('GET', 'cases/$id/')));

  @override
  Future<List<MeetingPoint>> guidance(
    String caseId, {
    (double, double)? origin,
  }) async {
    final data = _map(
      await _call(
        'POST',
        'cases/$caseId/guidance/',
        body: {
          if (origin != null)
            'origin': {'latitude': origin.$1, 'longitude': origin.$2},
        },
      ),
    );
    return [
      for (final row in data['points'] as List? ?? const [])
        MeetingPoint.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> choosePoint(String caseId, String pointId) async {
    await _call(
      'POST',
      'cases/$caseId/meeting-point/',
      body: {'meeting_point_id': pointId},
    );
  }

  @override
  Future<void> coordinate(
    String caseId, {
    String? event,
    String? update,
  }) async {
    await _call(
      'POST',
      'cases/$caseId/coordination/',
      body: {
        if (event != null) 'event': event,
        if (update != null) 'update': update,
      },
    );
  }

  @override
  Future<WalkingRoute> route(
    RouteTarget target,
    (double, double) origin,
  ) async => WalkingRoute.fromJson(
    _map(
      await _call(
        'POST',
        'route/',
        body: {
          'origin': {'latitude': origin.$1, 'longitude': origin.$2},
          'kind': target.kind,
          'target_id': target.id,
          if (target.caseId != null) 'case_id': target.caseId,
        },
      ),
    ),
  );

  @override
  Future<int> notifyFamily(
    String familyId,
    String kind, {
    String? pointId,
  }) async {
    final data = _map(
      await _call(
        'POST',
        'circles/$familyId/notify/',
        body: {'kind': kind, if (pointId != null) 'point_id': pointId},
      ),
    );
    return (data['people'] as num?)?.toInt() ?? 0;
  }
}

/// The public help points saved for when the network fails. Private family
/// spots and anything about a person are never written to the phone.
class SavedPoints {
  const SavedPoints();

  static const _key = 'reunion_points';

  Future<void> save(List<MeetingPoint> points) async {
    try {
      final public = points.where((p) => !p.isPrivate).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'saved_at': DateTime.now().toUtc().toIso8601String(),
          'points': [for (final p in public) p.toJson()],
        }),
      );
    } catch (_) {
      // The map still works from the server.
    }
  }

  Future<PointPage?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return PointPage(
        savedAt:
            DateTime.tryParse(data['saved_at'] as String? ?? '')?.toLocal(),
        points: [
          for (final p in data['points'] as List? ?? const [])
            MeetingPoint.fromJson(p as Map<String, dynamic>),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // Nothing private is in here.
    }
  }
}

class ReunionServices {
  ReunionServices._();

  static ReunionRepository repository = HttpReunionRepository();
  static SavedPoints saved = const SavedPoints();

  /// The last answers, for this run of the app only.
  static ReunionOverview? lastOverview;
  static final Map<String, WalkingRoute> lastRoutes = {};

  static Future<void> wipe() async {
    lastOverview = null;
    lastRoutes.clear();
    await saved.clear();
  }
}
