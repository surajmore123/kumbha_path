import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/lostfound/models/lf_ai_models.dart';
import 'package:kumbha_path/src/modules/lostfound/models/lf_models.dart';

export 'package:kumbha_path/src/modules/family/data/family_repository.dart'
    show FamilyException, FamilyFailure;

abstract class LostFoundRepository {
  Future<LfCapabilities> capabilities();
  Future<List<CaseSummary>> myCases();
  Future<CaseDetail> caseDetail(String id);
  Future<CaseSummary> reportLost(Map<String, dynamic> data);
  Future<CaseSummary> reportFound(Map<String, dynamic> data);
  Future<void> addInfo(String id, String body);
  Future<void> requestCorrection(String id, String body);
  Future<void> cancel(String id, String reason);
  Future<void> confirmReunion(String id);
  Future<void> addSighting(String id, Map<String, dynamic> data);
  Future<void> uploadPhoto(String id, Uint8List bytes, {String? clientId});
  Future<Uint8List?> attachment(String id);

  Future<OpsPage> opsCases({
    String? type,
    String? status,
    String? query,
    bool mine,
  });
  Future<OpsCase> opsCase(String id);
  Future<OpsCase> changeStatus(String id, String status, String reason);
  Future<OpsCase> assignToMe(String id);
  Future<OpsCase> addNote(String id, String kind, String body);
  Future<String?> revealContact(String id);
  Future<OpsCase> findMatches(String id);
  Future<OpsCase> verify(String id, String method, String remarks);
  Future<OpsCase> reunite(
    String id, {
    required String method,
    required String remarks,
    required bool identityChecked,
    required bool personRecognised,
  });
  Future<OpsCase> reviewSighting(
    String sightingId, {
    required bool approve,
    bool verified,
  });
  Future<void> approveMatch(String id, {required bool notifyFamily});
  Future<void> dismissMatch(String id, String reason);
  Future<void> confirmMatch(String id, String method, String remarks);
  Future<CaseAi> caseAi(String id);
  Future<void> translateCase(String id, String field, String language);
  Future<void> reviewTranslation(String translationId, String text);
  Future<void> extractCase(String id);
  Future<void> reviewExtraction(
    String id,
    bool accept, {
    Map<String, Object?> corrections,
  });
}

/// The live backend. Nothing here is cached on the device, and release builds
/// refuse plain HTTP.
class HttpLostFoundRepository implements LostFoundRepository {
  HttpLostFoundRepository({
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
    final p = '/api/lostfound/$path';
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

  Future<http.Response> _send(http.BaseRequest request) async {
    try {
      return await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      );
    } on SocketException {
      throw const FamilyException(FamilyFailure.offline);
    } on TimeoutException {
      throw const FamilyException(FamilyFailure.offline);
    } on http.ClientException {
      throw const FamilyException(FamilyFailure.offline);
    }
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

  Object? _result(http.Response response) {
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
    return _result(await _send(request));
  }

  Map<String, dynamic> _map(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw const FamilyException(FamilyFailure.server);
  }

  Future<OpsCase> _ops(String path, [Object? body]) async =>
      OpsCase.fromJson(_map(await _call('POST', path, body: body ?? {})));

  @override
  Future<LfCapabilities> capabilities() async =>
      LfCapabilities.fromJson(_map(await _call('GET', 'me/')));

  @override
  Future<List<CaseSummary>> myCases() async {
    final data = await _call('GET', 'cases/');
    if (data is! List) throw const FamilyException(FamilyFailure.server);
    return [
      for (final item in data.whereType<Map<String, dynamic>>())
        CaseSummary.fromJson(item),
    ];
  }

  @override
  Future<CaseDetail> caseDetail(String id) async =>
      CaseDetail.fromJson(_map(await _call('GET', 'cases/$id/')));

  @override
  Future<CaseSummary> reportLost(Map<String, dynamic> data) async =>
      CaseSummary.fromJson(_map(await _call('POST', 'cases/', body: data)));

  @override
  Future<CaseSummary> reportFound(Map<String, dynamic> data) async =>
      CaseSummary.fromJson(_map(await _call('POST', 'found/', body: data)));

  @override
  Future<void> addInfo(String id, String body) =>
      _call('POST', 'cases/$id/info/', body: {'body': body});

  @override
  Future<void> requestCorrection(String id, String body) =>
      _call('POST', 'cases/$id/correction/', body: {'body': body});

  @override
  Future<void> cancel(String id, String reason) =>
      _call('POST', 'cases/$id/cancel/', body: {'reason': reason});

  @override
  Future<void> confirmReunion(String id) =>
      _call('POST', 'cases/$id/confirm-reunion/', body: {});

  @override
  Future<void> addSighting(String id, Map<String, dynamic> data) =>
      _call('POST', 'cases/$id/sightings/', body: data);

  @override
  Future<void> uploadPhoto(
    String id,
    Uint8List bytes, {
    String? clientId,
  }) async {
    final request =
        http.MultipartRequest('POST', _uri('cases/$id/attachments/'))
          ..headers['Authorization'] = 'Bearer ${await _bearer()}'
          ..files.add(
            http.MultipartFile.fromBytes('photo', bytes, filename: 'photo.jpg'),
          );
    if (clientId != null) request.fields['client_id'] = clientId;
    _result(await _send(request));
  }

  @override
  Future<Uint8List?> attachment(String id) async {
    final request = http.Request('GET', _uri('attachments/$id/'))
      ..headers['Authorization'] = 'Bearer ${await _bearer()}';
    final response = await _send(request);
    return response.statusCode == 200 ? response.bodyBytes : null;
  }

  @override
  Future<OpsPage> opsCases({
    String? type,
    String? status,
    String? query,
    bool mine = false,
  }) async {
    final data = _map(
      await _call(
        'GET',
        'ops/cases/',
        query: {
          if (type != null) 'type': type,
          if (status != null) 'status': status,
          if (query != null && query.isNotEmpty) 'q': query,
          if (mine) 'mine': 'true',
        },
      ),
    );
    return OpsPage(
      rows: [
        for (final item
            in (data['results'] as List).whereType<Map<String, dynamic>>())
          OpsCaseRow.fromJson(item),
      ],
      count: data['count'] as int? ?? 0,
      hasNext: data['has_next'] == true,
    );
  }

  @override
  Future<OpsCase> opsCase(String id) async =>
      OpsCase.fromJson(_map(await _call('GET', 'ops/cases/$id/')));

  @override
  Future<OpsCase> changeStatus(String id, String status, String reason) =>
      _ops('ops/cases/$id/status/', {'status': status, 'reason': reason});

  @override
  Future<OpsCase> assignToMe(String id) => _ops('ops/cases/$id/assign/');

  @override
  Future<OpsCase> addNote(String id, String kind, String body) =>
      _ops('ops/cases/$id/notes/', {'kind': kind, 'body': body});

  @override
  Future<String?> revealContact(String id) async {
    final data = _map(await _call('POST', 'ops/cases/$id/contact/', body: {}));
    return data['phone'] as String?;
  }

  @override
  Future<CaseAi> caseAi(String id) async =>
      CaseAi.fromJson(_map(await _call('GET', 'ops/cases/$id/ai/')));

  @override
  Future<void> translateCase(String id, String field, String language) => _call(
    'POST',
    'ops/cases/$id/ai/translate/',
    body: {
      'source_type': 'field',
      'source_ref': field,
      'target_language': language,
    },
  );

  @override
  Future<void> reviewTranslation(String translationId, String text) => _call(
    'POST',
    'ops/translations/$translationId/review/',
    body: {'text': text},
  );

  @override
  Future<void> extractCase(String id) =>
      _call('POST', 'ops/cases/$id/ai/extract/', body: {});

  @override
  Future<void> reviewExtraction(
    String id,
    bool accept, {
    Map<String, Object?> corrections = const {},
  }) => _call(
    'POST',
    'ops/cases/$id/ai/extract/review/',
    body: {'accept': accept, 'corrections': corrections},
  );

  @override
  Future<OpsCase> findMatches(String id) => _ops('ops/cases/$id/find-matches/');

  @override
  Future<OpsCase> verify(String id, String method, String remarks) =>
      _ops('ops/cases/$id/verify/', {'method': method, 'remarks': remarks});

  @override
  Future<OpsCase> reunite(
    String id, {
    required String method,
    required String remarks,
    required bool identityChecked,
    required bool personRecognised,
  }) => _ops('ops/cases/$id/reunite/', {
    'method': method,
    'remarks': remarks,
    'identity_checked': identityChecked,
    'person_recognised': personRecognised,
  });

  @override
  Future<OpsCase> reviewSighting(
    String sightingId, {
    required bool approve,
    bool verified = false,
  }) => _ops('ops/sightings/$sightingId/review/', {
    'approve': approve,
    'verified': verified,
  });

  @override
  Future<void> approveMatch(String id, {required bool notifyFamily}) => _call(
    'POST',
    'ops/matches/$id/approve/',
    body: {'notify_family': notifyFamily},
  );

  @override
  Future<void> dismissMatch(String id, String reason) =>
      _call('POST', 'ops/matches/$id/dismiss/', body: {'reason': reason});

  @override
  Future<void> confirmMatch(String id, String method, String remarks) => _call(
    'POST',
    'ops/matches/$id/confirm/',
    body: {'method': method, 'remarks': remarks},
  );
}

/// Swappable in tests.
class LostFoundServices {
  LostFoundServices._();

  static LostFoundRepository repository = HttpLostFoundRepository();
}
