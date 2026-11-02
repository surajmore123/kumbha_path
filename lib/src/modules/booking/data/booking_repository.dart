import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/modules/akhada/data/akhada_repository.dart'
    show ContentStore, PrefsContentStore;
import 'package:kumbha_path/src/modules/akhada/models/akhada_models.dart'
    show ContentPage, Fetched;
import 'package:kumbha_path/src/modules/booking/models/booking_models.dart';
import 'package:kumbha_path/src/modules/journey/data/journey_repository.dart'
    show JourneyException, JourneyFailure;

export 'package:kumbha_path/src/modules/journey/data/journey_repository.dart'
    show JourneyException, JourneyFailure;

/// Everything Booking & Stay needs from `/api/bookings/`.
abstract class BookingRepository {
  Future<StayFilters> stayFilters(String language);
  Future<ContentPage<StaySummary>> stays(
    StaySearch search, {
    required String language,
    int page,
  });
  Future<Fetched<StayDetail>> stay(String id, String language);
  Future<TransportSearchResult> transport({
    required String language,
    String? from,
    String? to,
    DateTime? date,
    String? mode,
    int passengers,
  });
  Future<ContentPage<SavedBooking>> saved({String? when, int page});
  Future<SavedBooking> savedOne(String id);
  Future<SavedBooking> create(Map<String, dynamic> data);
  Future<SavedBooking> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
}

/// The live backend. Stays and transport are public; saved bookings carry the
/// access token in the header, and are never stored on the device.
class HttpBookingRepository implements BookingRepository {
  HttpBookingRepository({
    http.Client? client,
    ContentStore? store,
    Future<String?> Function()? token,
  }) : _client = client ?? http.Client(),
       _store = store ?? PrefsContentStore(),
       _token = token ?? (() => storage.read(key: 'access_token'));

  final http.Client _client;
  final ContentStore _store;
  final Future<String?> Function() _token;

  static const _timeout = Duration(seconds: 20);

  Uri _uri(String path, Map<String, dynamic> query) {
    final p = '/api/bookings/$path';
    final q = query.isEmpty ? null : query;
    return ApiConst.protocol == 'https'
        ? Uri.https(ApiConst.host, p, q)
        : Uri.http(ApiConst.host, p, q);
  }

  static Map<String, dynamic>? _decode(String text) {
    try {
      final json = jsonDecode(text);
      return json is Map<String, dynamic> ? json : null;
    } on FormatException {
      return null;
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

  /// Public content: saved for offline use, unless it's a live search.
  Future<(Map<String, dynamic>, bool)> _public(
    String path,
    Map<String, dynamic> query, {
    bool save = true,
  }) async {
    final uri = _uri(path, query);
    final key = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
    } on SocketException {
      return _saved(key);
    } on TimeoutException {
      return _saved(key);
    } on http.ClientException {
      return _saved(key);
    }
    final text = utf8.decode(response.bodyBytes);
    final body = _decode(text);
    if (response.statusCode == 404) {
      throw const JourneyException(JourneyFailure.notFound);
    }
    if (response.statusCode == 400) {
      throw JourneyException(
        JourneyFailure.invalid,
        fieldErrors: _errors(body?['errors']),
      );
    }
    final data = body?['data'];
    if (response.statusCode != 200 || data is! Map<String, dynamic>) {
      throw const JourneyException(JourneyFailure.server);
    }
    if (save) {
      try {
        await _store.write(key, text);
      } catch (_) {
        // A full or unavailable store only costs the offline copy.
      }
    }
    return (data, false);
  }

  Future<(Map<String, dynamic>, bool)> _saved(String key) async {
    String? text;
    try {
      text = await _store.read(key);
    } catch (_) {
      text = null;
    }
    final data = text == null ? null : _decode(text)?['data'];
    if (data is! Map<String, dynamic>) {
      throw const JourneyException(JourneyFailure.offline);
    }
    return (data, true);
  }

  Future<dynamic> _private(
    String method,
    String path, {
    Map<String, dynamic> query = const {},
    Object? body,
  }) async {
    String? token;
    try {
      token = await _token();
    } catch (_) {
      token = null;
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
      );
    } on SocketException {
      throw const JourneyException(JourneyFailure.offline);
    } on TimeoutException {
      throw const JourneyException(JourneyFailure.offline);
    } on http.ClientException {
      throw const JourneyException(JourneyFailure.offline);
    }
    final code = response.statusCode;
    if (code == 204) return null;
    final decoded = _decode(utf8.decode(response.bodyBytes));
    if (code >= 200 && code < 300) return decoded?['data'];
    throw JourneyException(switch (code) {
      401 || 403 => JourneyFailure.unauthorized,
      404 => JourneyFailure.notFound,
      400 => JourneyFailure.invalid,
      _ => JourneyFailure.server,
    }, fieldErrors: _errors(decoded?['errors']));
  }

  SavedBooking _booking(Object? data) {
    final booking =
        data is Map<String, dynamic> ? SavedBooking.fromJson(data) : null;
    if (booking == null) throw const JourneyException(JourneyFailure.server);
    return booking;
  }

  @override
  Future<StayFilters> stayFilters(String language) async {
    final (data, _) = await _public('stays/filters/', {'language': language});
    return StayFilters.fromJson(data);
  }

  @override
  Future<ContentPage<StaySummary>> stays(
    StaySearch search, {
    required String language,
    int page = 1,
  }) async {
    final (data, saved) = await _public('stays/', {
      ...search.toQuery(),
      'language': language,
      if (page > 1) 'page': '$page',
    });
    return ContentPage.fromJson(data, StaySummary.fromJson, isSavedCopy: saved);
  }

  @override
  Future<Fetched<StayDetail>> stay(String id, String language) async {
    final (data, saved) = await _public('stays/$id/', {'language': language});
    final detail = StayDetail.fromJson(data);
    if (detail == null) throw const JourneyException(JourneyFailure.server);
    return Fetched(detail, isSavedCopy: saved);
  }

  @override
  Future<TransportSearchResult> transport({
    required String language,
    String? from,
    String? to,
    DateTime? date,
    String? mode,
    int passengers = 1,
  }) async {
    final (data, _) = await _public('transport/search/', {
      'language': language,
      'from': from ?? 'Any',
      'to': to ?? 'Nashik',
      if (date != null) 'date': isoDay(date),
      if (mode != null) 'mode': mode,
      'passengers': '$passengers',
    }, save: false);
    return TransportSearchResult.fromJson(data);
  }

  @override
  Future<ContentPage<SavedBooking>> saved({String? when, int page = 1}) async {
    final data = await _private(
      'GET',
      'saved/',
      query: {if (when != null) 'when': when, if (page > 1) 'page': '$page'},
    );
    if (data is! Map<String, dynamic>) {
      throw const JourneyException(JourneyFailure.server);
    }
    return ContentPage.fromJson(data, SavedBooking.fromJson);
  }

  @override
  Future<SavedBooking> savedOne(String id) async =>
      _booking(await _private('GET', 'saved/$id/'));

  @override
  Future<SavedBooking> create(Map<String, dynamic> data) async =>
      _booking(await _private('POST', 'saved/', body: data));

  @override
  Future<SavedBooking> update(String id, Map<String, dynamic> data) async =>
      _booking(await _private('PATCH', 'saved/$id/', body: data));

  @override
  Future<void> delete(String id) => _private('DELETE', 'saved/$id/');
}

/// The repository the screens use; tests swap in a fake.
class BookingServices {
  BookingServices._();

  static BookingRepository repository = HttpBookingRepository();
}
