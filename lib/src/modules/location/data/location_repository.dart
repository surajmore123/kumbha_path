import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/location/models/location_models.dart';

export 'package:kumbha_path/src/modules/family/data/family_repository.dart'
    show FamilyException, FamilyFailure;

/// The server refused a position because the session isn't taking them.
class SharingClosed implements Exception {
  const SharingClosed(this.status);

  /// paused, stopped or expired.
  final String status;

  @override
  String toString() => 'SharingClosed($status)';
}

abstract class LocationRepository {
  Future<EligibleViewers> eligible(String familyId, {String? memberId});
  Future<List<SharingSession>> sessions(String familyId);
  Future<SharingSession> start(
    String familyId, {
    required bool consent,
    required List<String> recipientIds,
    String? memberId,
    int? minutes,
    bool untilStopped,
  });
  Future<SharingSession> session(String id);
  Future<SharingSession> pause(String id);
  Future<SharingSession> resume(String id);
  Future<SharingSession> stop(String id);
  Future<SharingSession> setRecipients(String id, List<String> recipientIds);
  Future<SharingSession> changeDuration(
    String id, {
    int? minutes,
    bool untilStopped,
  });

  /// True if stored. False means a newer position was already there.
  Future<bool> sendUpdate(String id, LocationFix fix);
  Future<LocationFeed> feed(String familyId);

  /// Null unless this person was already chosen to see the location.
  Future<LocationPerson?> caseLocation(String caseId);
}

/// The live backend. Release builds refuse plain HTTP.
class HttpLocationRepository implements LocationRepository {
  HttpLocationRepository({
    http.Client? client,
    Future<String?> Function()? token,
    this.requireHttps = kReleaseMode,
  }) : _client = client ?? http.Client(),
       _token = token ?? (() => storage.read(key: 'access_token'));

  final http.Client _client;
  final Future<String?> Function() _token;
  final bool requireHttps;

  static const _timeout = Duration(seconds: 15);

  Uri _uri(String path, [Map<String, String>? query]) {
    final p = '/api/location/$path';
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
    final errors = decoded?['errors'];
    if (code == 410) {
      final status = errors is Map ? errors['status'] : null;
      throw SharingClosed(status is String ? status : 'stopped');
    }
    throw FamilyException(switch (code) {
      401 => FamilyFailure.signedOut,
      403 => FamilyFailure.forbidden,
      404 => FamilyFailure.notFound,
      400 => FamilyFailure.invalid,
      409 => FamilyFailure.conflict,
      _ => FamilyFailure.server,
    }, fieldErrors: _errors(errors));
  }

  Map<String, dynamic> _map(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw const FamilyException(FamilyFailure.server);
  }

  Future<SharingSession> _session(String path, [Object? body]) async =>
      SharingSession.fromJson(
        _map(await _call('POST', 'sessions/$path', body: body ?? {})),
      );

  @override
  Future<EligibleViewers> eligible(String familyId, {String? memberId}) async =>
      EligibleViewers.fromJson(
        _map(
          await _call(
            'GET',
            'circles/$familyId/eligible/',
            query: memberId == null ? null : {'member_id': memberId},
          ),
        ),
      );

  @override
  Future<List<SharingSession>> sessions(String familyId) async {
    final data = await _call('GET', 'circles/$familyId/sessions/');
    if (data is! List) throw const FamilyException(FamilyFailure.server);
    return [
      for (final item in data.whereType<Map<String, dynamic>>())
        SharingSession.fromJson(item),
    ];
  }

  @override
  Future<SharingSession> start(
    String familyId, {
    required bool consent,
    required List<String> recipientIds,
    String? memberId,
    int? minutes,
    bool untilStopped = false,
  }) async => SharingSession.fromJson(
    _map(
      await _call(
        'POST',
        'circles/$familyId/sessions/',
        body: {
          'consent': consent,
          'recipient_ids': recipientIds,
          if (memberId != null) 'member_id': memberId,
          if (minutes != null) 'duration_minutes': minutes,
          'until_stopped': untilStopped,
        },
      ),
    ),
  );

  @override
  Future<SharingSession> session(String id) async =>
      SharingSession.fromJson(_map(await _call('GET', 'sessions/$id/')));

  @override
  Future<SharingSession> pause(String id) => _session('$id/pause/');

  @override
  Future<SharingSession> resume(String id) => _session('$id/resume/');

  @override
  Future<SharingSession> stop(String id) => _session('$id/stop/');

  @override
  Future<SharingSession> setRecipients(String id, List<String> recipientIds) =>
      _session('$id/recipients/', {'recipient_ids': recipientIds});

  @override
  Future<SharingSession> changeDuration(
    String id, {
    int? minutes,
    bool untilStopped = false,
  }) => _session('$id/duration/', {
    if (minutes != null) 'duration_minutes': minutes,
    'until_stopped': untilStopped,
  });

  @override
  Future<bool> sendUpdate(String id, LocationFix fix) async {
    final data = await _call(
      'POST',
      'sessions/$id/update/',
      body: fix.toJson(),
    );
    return data is Map && data['accepted'] == true;
  }

  @override
  Future<LocationFeed> feed(String familyId) async => LocationFeed.fromJson(
    _map(await _call('GET', 'circles/$familyId/feed/')),
  );

  @override
  Future<LocationPerson?> caseLocation(String caseId) async {
    final data = _map(await _call('GET', 'cases/$caseId/'));
    if (data['state'] == 'not_shared') return null;
    return LocationPerson.fromJson(data, fetchedAt: DateTime.now());
  }
}

class LocationServices {
  LocationServices._();

  static LocationRepository repository = HttpLocationRepository();

  /// The last feed per family, for this run of the app only, so a dropped
  /// connection shows what was last known. Never written to storage.
  static final Map<String, LocationFeed> lastFeed = {};
}
