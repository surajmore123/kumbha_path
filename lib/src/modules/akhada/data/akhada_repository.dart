import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/modules/akhada/models/akhada_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AkhadaFailure { offline, notFound, server }

class AkhadaException implements Exception {
  const AkhadaException(this.kind);

  final AkhadaFailure kind;

  @override
  String toString() => 'AkhadaException($kind)';
}

/// Everything the Akhadas & Sadhus screens read from `/api/akhadas/`.
abstract class AkhadaRepository {
  Future<ContentPage<AkhadaSummary>> akhadas({
    required String language,
    String? query,
    String? tradition,
    String? location,
    int page,
  });
  Future<Fetched<AkhadaDetail>> akhada(String slug, String language);
  Future<ContentPage<SaintSummary>> saints({
    required String language,
    String? query,
    String? akhada,
    String? title,
    int page,
  });
  Future<Fetched<SaintDetail>> saint(String slug, String language);
  Future<ContentPage<ArticleSummary>> articles({
    required String language,
    String? query,
    String? category,
    int page,
  });
  Future<Fetched<ArticleDetail>> article(String slug, String language);
  Future<ContentPage<AkhadaActivity>> activities({
    required String language,
    String? confirmation,
    int page,
  });
  Future<ContentFilters> filters(String language);
}

/// Keeps recent responses so content already seen opens without a network.
abstract class ContentStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PrefsContentStore implements ContentStore {
  static const _prefix = 'akhadas_content:';
  static const _indexKey = 'akhadas_content_index';
  static const _maxEntries = 80;

  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString('$_prefix$key');

  @override
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getStringList(_indexKey) ?? <String>[];
    index
      ..remove(key)
      ..add(key);
    while (index.length > _maxEntries) {
      await prefs.remove('$_prefix${index.removeAt(0)}');
    }
    await prefs.setStringList(_indexKey, index);
    await prefs.setString('$_prefix$key', value);
  }
}

/// The live backend. This is public reference content, so no token is sent.
class HttpAkhadaRepository implements AkhadaRepository {
  HttpAkhadaRepository({http.Client? client, ContentStore? store})
    : _client = client ?? http.Client(),
      _store = store ?? PrefsContentStore();

  final http.Client _client;
  final ContentStore _store;

  static const _timeout = Duration(seconds: 20);

  Uri _uri(String path, Map<String, String> query) {
    final p = '/api/akhadas/$path';
    return ApiConst.protocol == 'https'
        ? Uri.https(ApiConst.host, p, query)
        : Uri.http(ApiConst.host, p, query);
  }

  /// The `data` object, and whether it was read from the device. Searches
  /// aren't saved: their value is being current.
  Future<(Map<String, dynamic>, bool)> _get(
    String path,
    Map<String, String> query, {
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
    if (response.statusCode == 404) {
      throw const AkhadaException(AkhadaFailure.notFound);
    }
    if (response.statusCode != 200) {
      throw const AkhadaException(AkhadaFailure.server);
    }
    final text = utf8.decode(response.bodyBytes);
    final data = _decode(text);
    if (data == null) throw const AkhadaException(AkhadaFailure.server);
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
    final data = text == null ? null : _decode(text);
    if (data == null) throw const AkhadaException(AkhadaFailure.offline);
    return (data, true);
  }

  static Map<String, dynamic>? _decode(String text) {
    try {
      final json = jsonDecode(text);
      final data = json is Map<String, dynamic> ? json['data'] : null;
      return data is Map<String, dynamic> ? data : null;
    } on FormatException {
      return null;
    }
  }

  static Map<String, String> _query(
    String language,
    int page,
    Map<String, String?> extra,
  ) => {
    'language': language,
    if (page > 1) 'page': '$page',
    for (final e in extra.entries)
      if (e.value != null && e.value!.trim().isNotEmpty) e.key: e.value!.trim(),
  };

  Future<ContentPage<T>> _page<T>(
    String path,
    Map<String, String> query,
    T? Function(Map<String, dynamic>) parse,
  ) async {
    final (data, saved) = await _get(
      path,
      query,
      save: !query.containsKey('q'),
    );
    return ContentPage.fromJson(data, parse, isSavedCopy: saved);
  }

  Future<Fetched<T>> _detail<T>(
    String path,
    String language,
    T? Function(Map<String, dynamic>) parse,
  ) async {
    final (data, saved) = await _get(path, {'language': language});
    final value = parse(data);
    if (value == null) throw const AkhadaException(AkhadaFailure.server);
    return Fetched(value, isSavedCopy: saved);
  }

  @override
  Future<ContentPage<AkhadaSummary>> akhadas({
    required String language,
    String? query,
    String? tradition,
    String? location,
    int page = 1,
  }) => _page(
    '',
    _query(language, page, {
      'q': query,
      'tradition': tradition,
      'location': location,
    }),
    AkhadaSummary.fromJson,
  );

  @override
  Future<Fetched<AkhadaDetail>> akhada(String slug, String language) =>
      _detail('$slug/', language, AkhadaDetail.fromJson);

  @override
  Future<ContentPage<SaintSummary>> saints({
    required String language,
    String? query,
    String? akhada,
    String? title,
    int page = 1,
  }) => _page(
    'saints/',
    _query(language, page, {'q': query, 'akhada': akhada, 'title': title}),
    SaintSummary.fromJson,
  );

  @override
  Future<Fetched<SaintDetail>> saint(String slug, String language) =>
      _detail('saints/$slug/', language, SaintDetail.fromJson);

  @override
  Future<ContentPage<ArticleSummary>> articles({
    required String language,
    String? query,
    String? category,
    int page = 1,
  }) => _page(
    'articles/',
    _query(language, page, {'q': query, 'category': category}),
    ArticleSummary.fromJson,
  );

  @override
  Future<Fetched<ArticleDetail>> article(String slug, String language) =>
      _detail('articles/$slug/', language, ArticleDetail.fromJson);

  @override
  Future<ContentPage<AkhadaActivity>> activities({
    required String language,
    String? confirmation,
    int page = 1,
  }) => _page(
    'activities/',
    _query(language, page, {'confirmation': confirmation}),
    AkhadaActivity.fromJson,
  );

  @override
  Future<ContentFilters> filters(String language) async {
    final (data, _) = await _get('filters/', {'language': language});
    return ContentFilters.fromJson(data);
  }
}

/// The repository the screens use; tests swap in a fake.
class AkhadaServices {
  AkhadaServices._();

  static AkhadaRepository repository = HttpAkhadaRepository();
}
