import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/modules/emergency/models/emergency_models.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/offline/contact_sync.dart'
    show accountFromToken;
import 'package:kumbha_path/src/modules/location/data/location_tracker.dart'
    show SecureTrackerStore, TrackerStore;

export 'package:kumbha_path/src/modules/family/data/family_repository.dart'
    show FamilyException, FamilyFailure;

/// This person already has an open SOS: the app shows that one.
class SosAlreadyActive implements Exception {
  const SosAlreadyActive(this.id);

  final String id;
}

abstract class EmergencyRepository {
  Future<SosOverview> overview();
  Future<SosDetail> create(SosDraft draft, {bool delayed});
  Future<SosDetail> detail(String id);
  Future<SosPage> history({bool family, int page});
  Future<SosDetail> cancel(String id, String reason);
  Future<SosDetail> addInfo(String id, String body);
  Future<SosDetail> updateLocation(String id, Map<String, dynamic> place);
  Future<SosDetail> acknowledgeAsFamily(String id);

  /// The person's number, only to dial it. Each use is logged by the server.
  Future<String?> contact(String id);
}

/// The live backend. Release builds refuse plain HTTP.
class HttpEmergencyRepository implements EmergencyRepository {
  HttpEmergencyRepository({
    http.Client? client,
    Future<String?> Function()? token,
    this.requireHttps = kReleaseMode,
  }) : _client = client ?? http.Client(),
       _token = token ?? (() => storage.read(key: 'access_token'));

  final http.Client _client;
  final Future<String?> Function() _token;
  final bool requireHttps;

  /// Short, because someone in trouble is watching this, and a retry can't
  /// create a second SOS.
  static const _timeout = Duration(seconds: 12);

  Uri _uri(String path, [Map<String, String>? query]) {
    final p = '/api/emergency/$path';
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
    final active = errors['active_id'];
    if (code == 409 && active != null) throw SosAlreadyActive(active);
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

  Future<SosDetail> _detail(String method, String path, [Object? body]) async =>
      SosDetail.fromJson(_map(await _call(method, path, body: body)));

  @override
  Future<SosOverview> overview() async =>
      SosOverview.fromJson(_map(await _call('GET', 'me/')));

  @override
  Future<SosDetail> create(SosDraft draft, {bool delayed = false}) =>
      _detail('POST', 'sos/', draft.toRequest(delayed: delayed));

  @override
  Future<SosDetail> detail(String id) => _detail('GET', 'sos/$id/');

  @override
  Future<SosPage> history({bool family = false, int page = 1}) async {
    final data = _map(
      await _call(
        'GET',
        'sos/',
        query: {'page': '$page', if (family) 'scope': 'family'},
      ),
    );
    return SosPage(
      hasNext: data['has_next'] == true,
      rows: [
        for (final row in data['results'] as List? ?? const [])
          SosRow.fromJson(row as Map<String, dynamic>),
      ],
    );
  }

  @override
  Future<SosDetail> cancel(String id, String reason) =>
      _detail('POST', 'sos/$id/cancel/', {'reason': reason});

  @override
  Future<SosDetail> addInfo(String id, String body) =>
      _detail('POST', 'sos/$id/info/', {'body': body});

  @override
  Future<SosDetail> updateLocation(String id, Map<String, dynamic> place) =>
      _detail('POST', 'sos/$id/location/', place);

  @override
  Future<SosDetail> acknowledgeAsFamily(String id) =>
      _detail('POST', 'sos/$id/acknowledge-family/', {});

  @override
  Future<String?> contact(String id) async {
    final data = _map(await _call('POST', 'sos/$id/contact/', body: {}));
    return data['phone'] as String?;
  }
}

/// The one SOS that couldn't be sent, kept encrypted on this phone. It's never
/// sent by itself: an old emergency mustn't reappear as a new one, so the
/// person has to choose. It belongs to the account that wrote it.
class UnsentSos {
  const UnsentSos({
    TrackerStore store = const SecureTrackerStore(),
    Future<String?> Function()? account,
  }) : _store = store,
       _account = account;

  static const _key = 'sos_unsent';

  final TrackerStore _store;
  final Future<String?> Function()? _account;

  Future<String?> _who() async {
    try {
      final reader = _account;
      if (reader != null) return await reader();
      return accountFromToken(await storage.read(key: 'access_token'));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(SosDraft draft) async {
    try {
      final owned = draft.forAccount(await _who());
      await _store.write(_key, jsonEncode(owned.toJson()));
    } catch (_) {
      // Nothing more can be done, and the screen says it wasn't sent.
    }
  }

  Future<SosDraft?> load() async {
    try {
      final raw = await _store.read(_key);
      if (raw == null) return null;
      final draft = SosDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (draft.account != await _who()) return null;
      return draft;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _store.write(_key, null);
    } catch (_) {
      // It stays hidden from any other account.
    }
  }
}

class EmergencyServices {
  EmergencyServices._();

  static EmergencyRepository repository = HttpEmergencyRepository();
  static UnsentSos unsent = const UnsentSos();
}
