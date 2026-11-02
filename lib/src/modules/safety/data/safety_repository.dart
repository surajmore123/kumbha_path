import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/safety/models/safety_models.dart';

export 'package:kumbha_path/src/modules/family/data/family_repository.dart'
    show FamilyException, FamilyFailure;

abstract class SafetyRepository {
  /// The member's active QR, or null if there isn't one.
  Future<SafetyQr?> qr(String familyId, String memberId);

  /// The active QR, made if needed. Safe to repeat.
  Future<SafetyQr> generate(String familyId, String memberId);
  Future<SafetyQr> regenerate(String familyId, String memberId);
  Future<void> revoke(String familyId, String memberId);

  Future<HelperStatus> helperStatus();
  Future<ScanResult> resolve(String token);
  Future<AlertReceipt?> confirm(
    String scanId, {
    required String situation,
    String? note,
    double? latitude,
    double? longitude,
  });
  Future<AlertReceipt> helperAlert(String alertId);

  Future<List<FamilyAlert>> alerts(String familyId);
  Future<void> acknowledge(String familyId, String alertId);
  Future<void> resolveAlert(String familyId, String alertId);
}

/// The last QR seen for each member, so a card can be shown with no signal.
/// Kept in the keystore-backed secure storage and removed on sign-out.
abstract class QrCache {
  Future<SafetyQr?> read(String memberId);
  Future<void> write(String memberId, SafetyQr qr);
  Future<void> remove(String memberId);
  Future<void> clear();
}

class SecureQrCache implements QrCache {
  const SecureQrCache();

  static const _key = 'safety_qr_cache';

  Future<Map<String, dynamic>> _all() async {
    try {
      final raw = await storage.read(key: _key);
      final json = raw == null ? null : jsonDecode(raw);
      return json is Map<String, dynamic> ? json : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(Map<String, dynamic> all) async {
    try {
      await storage.write(key: _key, value: jsonEncode(all));
    } catch (_) {
      // Only the offline copy is lost.
    }
  }

  @override
  Future<SafetyQr?> read(String memberId) async {
    final saved = (await _all())[memberId];
    return saved is Map<String, dynamic>
        ? SafetyQr.fromJson(saved).savedCopy()
        : null;
  }

  @override
  Future<void> write(String memberId, SafetyQr qr) async {
    await _save({...await _all(), memberId: qr.toJson()});
  }

  @override
  Future<void> remove(String memberId) async {
    await _save((await _all())..remove(memberId));
  }

  @override
  Future<void> clear() async {
    try {
      await storage.delete(key: _key);
    } catch (_) {
      // Nothing was saved.
    }
  }
}

/// The live backend. Tokens travel in request bodies and never in URLs.
class HttpSafetyRepository implements SafetyRepository {
  HttpSafetyRepository({
    http.Client? client,
    Future<String?> Function()? token,
    QrCache? cache,
    this.requireHttps = kReleaseMode,
  }) : _client = client ?? http.Client(),
       _token = token ?? (() => storage.read(key: 'access_token')),
       _cache = cache ?? const SecureQrCache();

  final http.Client _client;
  final Future<String?> Function() _token;
  final QrCache _cache;

  /// Release builds refuse to talk to a server over plain HTTP.
  final bool requireHttps;

  static const _timeout = Duration(seconds: 20);

  Uri _uri(String path) {
    final p = '/api/safety/$path';
    return ApiConst.protocol == 'https'
        ? Uri.https(ApiConst.host, p)
        : Uri.http(ApiConst.host, p);
  }

  Future<Object?> _call(String method, String path, [Object? body]) async {
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
    final request = http.Request(method, _uri(path))
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
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
    throw FamilyException(switch (code) {
      401 => FamilyFailure.signedOut,
      403 => FamilyFailure.forbidden,
      404 => FamilyFailure.notFound,
      400 => FamilyFailure.invalid,
      409 => FamilyFailure.conflict,
      410 => FamilyFailure.gone,
      _ => FamilyFailure.server,
    });
  }

  Map<String, dynamic> _map(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw const FamilyException(FamilyFailure.server);
  }

  String _qr(String familyId, String memberId) =>
      'circles/$familyId/members/$memberId/qr/';

  Future<SafetyQr> _saved(String memberId, Object? data) async {
    final qr = SafetyQr.fromJson(_map(data));
    await _cache.write(memberId, qr);
    return qr;
  }

  @override
  Future<SafetyQr?> qr(String familyId, String memberId) async {
    try {
      final data = await _call('GET', _qr(familyId, memberId));
      if (data == null) {
        await _cache.remove(memberId);
        return null;
      }
      return _saved(memberId, data);
    } on FamilyException catch (e) {
      if (e.kind == FamilyFailure.offline) {
        final saved = await _cache.read(memberId);
        if (saved != null) return saved;
      }
      if (e.kind == FamilyFailure.forbidden ||
          e.kind == FamilyFailure.notFound) {
        await _cache.remove(memberId);
      }
      rethrow;
    }
  }

  @override
  Future<SafetyQr> generate(String familyId, String memberId) async =>
      _saved(memberId, await _call('POST', _qr(familyId, memberId), {}));

  @override
  Future<SafetyQr> regenerate(String familyId, String memberId) async => _saved(
    memberId,
    await _call('POST', '${_qr(familyId, memberId)}regenerate/', {}),
  );

  @override
  Future<void> revoke(String familyId, String memberId) async {
    await _call('POST', '${_qr(familyId, memberId)}revoke/', {});
    await _cache.remove(memberId);
  }

  @override
  Future<HelperStatus> helperStatus() async =>
      HelperStatus.fromJson(_map(await _call('GET', 'helper/me/')));

  @override
  Future<ScanResult> resolve(String token) async => ScanResult.fromJson(
    _map(await _call('POST', 'scan/resolve/', {'token': token})),
  );

  @override
  Future<AlertReceipt?> confirm(
    String scanId, {
    required String situation,
    String? note,
    double? latitude,
    double? longitude,
  }) async {
    final data = _map(
      await _call('POST', 'scan/$scanId/confirm/', {
        'situation': situation,
        'confirmed': true,
        if (note != null && note.isNotEmpty) 'note': note,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      }),
    );
    return data.containsKey('reference') ? AlertReceipt.fromJson(data) : null;
  }

  @override
  Future<AlertReceipt> helperAlert(String alertId) async =>
      AlertReceipt.fromJson(
        _map(await _call('GET', 'helper/alerts/$alertId/')),
      );

  @override
  Future<List<FamilyAlert>> alerts(String familyId) async {
    final data = await _call('GET', 'circles/$familyId/alerts/');
    if (data is! List) throw const FamilyException(FamilyFailure.server);
    return [
      for (final item in data.whereType<Map<String, dynamic>>())
        FamilyAlert.fromJson(item, familyId),
    ];
  }

  @override
  Future<void> acknowledge(String familyId, String alertId) =>
      _call('POST', 'circles/$familyId/alerts/$alertId/acknowledge/', {});

  @override
  Future<void> resolveAlert(String familyId, String alertId) =>
      _call('POST', 'circles/$familyId/alerts/$alertId/resolve/', {});
}

/// Swappable in tests.
class SafetyServices {
  SafetyServices._();

  static SafetyRepository repository = HttpSafetyRepository();
  static QrCache cache = const SecureQrCache();
}
