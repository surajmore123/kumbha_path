import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/modules/journey/models/journey_models.dart';

enum JourneyFailure { offline, unauthorized, notFound, invalid, server }

/// A failed journey request. [fieldErrors] holds the backend's validation
/// messages by field name (`non_field_errors` for the whole request).
class JourneyException implements Exception {
  const JourneyException(this.kind, {this.fieldErrors = const {}});

  final JourneyFailure kind;
  final Map<String, String> fieldErrors;

  /// The first message the backend gave, if any.
  String? get message =>
      fieldErrors['non_field_errors'] ??
      (fieldErrors.isEmpty ? null : fieldErrors.values.first);

  @override
  String toString() => 'JourneyException($kind, $fieldErrors)';
}

/// Everything the journey screens need from `/api/journeys/`.
abstract class JourneyRepository {
  Future<JourneyPage> list({String? status, String ordering, int page});
  Future<JourneyPlan> get(String id);
  Future<JourneyPlan> create(Map<String, dynamic> data, {bool generate});
  Future<JourneyPlan> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
  Future<JourneyPlan> generate(String id, {String? language});
  Future<JourneyPlan> duplicate(String id);
  Future<String> exportText(String id);
  Future<void> addItem(String id, int dayNumber, Map<String, dynamic> data);
  Future<void> updateItem(String id, int itemId, Map<String, dynamic> data);
  Future<void> deleteItem(String id, int itemId);
  Future<void> reorderDay(String id, int dayNumber, List<int> itemIds);
  Future<void> addChecklist(String id, Map<String, dynamic> data);
  Future<void> updateChecklist(
    String id,
    int itemId,
    Map<String, dynamic> data,
  );
  Future<void> deleteChecklist(String id, int itemId);
  Future<void> addReference(String id, Map<String, dynamic> data);
  Future<void> updateReference(String id, int refId, Map<String, dynamic> data);
  Future<void> deleteReference(String id, int refId);
  Future<PlanningGuide> guide(String language);
}

/// The live backend. The access token goes in the Authorization header,
/// never the URL, and responses are never logged.
class HttpJourneyRepository implements JourneyRepository {
  HttpJourneyRepository({
    http.Client? client,
    Future<String?> Function()? token,
  }) : _client = client ?? http.Client(),
       _token = token ?? (() => storage.read(key: 'access_token'));

  final http.Client _client;
  final Future<String?> Function() _token;

  static const _timeout = Duration(seconds: 30);
  static const _root = 'api/journeys/';

  Uri _uri(String path, [Map<String, String>? query]) {
    final p = '/$_root$path';
    return ApiConst.protocol == 'https'
        ? Uri.https(ApiConst.host, p, query)
        : Uri.http(ApiConst.host, p, query);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    String? token;
    try {
      token = await _token();
    } catch (_) {
      token = null; // secure storage unavailable
    }
    if (token == null || token.isEmpty || token == 'null') {
      throw const JourneyException(JourneyFailure.unauthorized);
    }
    final request = http.Request(method, _uri(path, query))
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
      ).timeout(_timeout);
    } on SocketException {
      throw const JourneyException(JourneyFailure.offline);
    } on TimeoutException {
      throw const JourneyException(JourneyFailure.offline);
    } on http.ClientException {
      throw const JourneyException(JourneyFailure.offline);
    }

    final code = response.statusCode;
    if (code == 204) return null;
    Object? decoded;
    try {
      decoded =
          response.body.isEmpty
              ? null
              : jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      decoded = null;
    }
    if (code >= 200 && code < 300) {
      return decoded is Map<String, dynamic> ? decoded['data'] : null;
    }
    final errors =
        decoded is Map<String, dynamic>
            ? _errors(decoded['errors'])
            : <String, String>{};
    throw JourneyException(switch (code) {
      401 || 403 => JourneyFailure.unauthorized,
      404 => JourneyFailure.notFound,
      400 => JourneyFailure.invalid,
      _ => JourneyFailure.server,
    }, fieldErrors: errors);
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

  Map<String, dynamic> _map(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw const JourneyException(JourneyFailure.server);
  }

  JourneyPlan _plan(Object? data) =>
      JourneyPlan.fromJson(_map(data)) ??
      (throw const JourneyException(JourneyFailure.server));

  @override
  Future<JourneyPage> list({
    String? status,
    String ordering = 'arrival',
    int page = 1,
  }) async => JourneyPage.fromJson(
    _map(
      await _send(
        'GET',
        '',
        query: {
          'ordering': ordering,
          'page': '$page',
          if (status != null) 'status': status,
        },
      ),
    ),
  );

  @override
  Future<JourneyPlan> get(String id) async => _plan(await _send('GET', '$id/'));

  @override
  Future<JourneyPlan> create(
    Map<String, dynamic> data, {
    bool generate = false,
  }) async => _plan(
    await _send(
      'POST',
      '',
      query: generate ? {'generate': 'true'} : null,
      body: data,
    ),
  );

  @override
  Future<JourneyPlan> update(String id, Map<String, dynamic> data) async =>
      _plan(await _send('PATCH', '$id/', body: data));

  @override
  Future<void> delete(String id) => _send('DELETE', '$id/');

  @override
  Future<JourneyPlan> generate(String id, {String? language}) async => _plan(
    await _send(
      'POST',
      '$id/generate/',
      body: {if (language != null) 'language': language},
    ),
  );

  @override
  Future<JourneyPlan> duplicate(String id) async =>
      _plan(await _send('POST', '$id/duplicate/', body: const {}));

  @override
  Future<String> exportText(String id) async {
    final text = _map(await _send('GET', '$id/export/'))['text'];
    if (text is String) return text;
    throw const JourneyException(JourneyFailure.server);
  }

  @override
  Future<void> addItem(String id, int dayNumber, Map<String, dynamic> data) =>
      _send('POST', '$id/items/', body: {...data, 'day_number': dayNumber});

  @override
  Future<void> updateItem(String id, int itemId, Map<String, dynamic> data) =>
      _send('PATCH', '$id/items/$itemId/', body: data);

  @override
  Future<void> deleteItem(String id, int itemId) =>
      _send('DELETE', '$id/items/$itemId/');

  @override
  Future<void> reorderDay(String id, int dayNumber, List<int> itemIds) => _send(
    'POST',
    '$id/days/$dayNumber/reorder/',
    body: {'item_ids': itemIds},
  );

  @override
  Future<void> addChecklist(String id, Map<String, dynamic> data) =>
      _send('POST', '$id/checklist/', body: data);

  @override
  Future<void> updateChecklist(
    String id,
    int itemId,
    Map<String, dynamic> data,
  ) => _send('PATCH', '$id/checklist/$itemId/', body: data);

  @override
  Future<void> deleteChecklist(String id, int itemId) =>
      _send('DELETE', '$id/checklist/$itemId/');

  @override
  Future<void> addReference(String id, Map<String, dynamic> data) =>
      _send('POST', '$id/references/', body: data);

  @override
  Future<void> updateReference(
    String id,
    int refId,
    Map<String, dynamic> data,
  ) => _send('PATCH', '$id/references/$refId/', body: data);

  @override
  Future<void> deleteReference(String id, int refId) =>
      _send('DELETE', '$id/references/$refId/');

  @override
  Future<PlanningGuide> guide(String language) async => PlanningGuide.fromJson(
    _map(await _send('GET', 'guide/', query: {'language': language})),
  );
}

/// The repository the screens use; tests swap in a fake.
class JourneyServices {
  JourneyServices._();

  static JourneyRepository repository = HttpJourneyRepository();
}
