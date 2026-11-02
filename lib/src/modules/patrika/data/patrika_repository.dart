import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/modules/akhada/data/akhada_repository.dart';
import 'package:kumbha_path/src/modules/akhada/models/akhada_models.dart';
import 'package:kumbha_path/src/modules/patrika/models/patrika_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything Kumbh Patrika reads from `/api/news/` and `/api/learn/`.
abstract class PatrikaRepository {
  Future<NewsHome> newsHome(String language);
  Future<ContentPage<NewsStory>> news({
    required String language,
    String? query,
    String? category,
    String? publisher,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool relevant,
    int page,
  });
  Future<Fetched<NewsDetail>> story(String slug, String language);
  Future<LearnHome> learnHome(String language);
  Future<Fetched<LearnArticleDetail>> article(String slug, String language);
  Future<ContentPage<GlossaryEntry>> glossary({
    required String language,
    String? query,
    int page,
  });
  Future<GlossaryDetail> term(String slug, String language);
}

/// The live backend. Public content, so no token is sent. Pages already seen
/// are kept on the device and shown, labelled, when there's no network.
class HttpPatrikaRepository implements PatrikaRepository {
  HttpPatrikaRepository({http.Client? client, ContentStore? store})
    : _client = client ?? http.Client(),
      _store = store ?? PrefsContentStore();

  final http.Client _client;
  final ContentStore _store;

  static const _timeout = Duration(seconds: 20);

  Uri _uri(String path, Map<String, String> query) {
    final p = '/api/$path';
    return ApiConst.protocol == 'https'
        ? Uri.https(ApiConst.host, p, query)
        : Uri.http(ApiConst.host, p, query);
  }

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

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<NewsHome> newsHome(String language) async {
    final (data, saved) = await _get('news/home/', {'language': language});
    return NewsHome.fromJson(data, isSavedCopy: saved);
  }

  @override
  Future<ContentPage<NewsStory>> news({
    required String language,
    String? query,
    String? category,
    String? publisher,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool relevant = false,
    int page = 1,
  }) async {
    final q = query?.trim() ?? '';
    final (data, saved) = await _get('news/', {
      'language': language,
      if (page > 1) 'page': '$page',
      if (q.isNotEmpty) 'q': q,
      if (category != null) 'category': category,
      if (publisher != null) 'publisher': publisher,
      if (dateFrom != null) 'date_from': _day(dateFrom),
      if (dateTo != null) 'date_to': _day(dateTo),
      if (relevant) 'ordering': 'relevant',
    }, save: q.isEmpty);
    return ContentPage.fromJson(data, NewsStory.fromJson, isSavedCopy: saved);
  }

  @override
  Future<Fetched<NewsDetail>> story(String slug, String language) async {
    final (data, saved) = await _get('news/$slug/', {'language': language});
    final detail = NewsDetail.fromJson(data);
    if (detail == null) throw const AkhadaException(AkhadaFailure.server);
    return Fetched(detail, isSavedCopy: saved);
  }

  @override
  Future<LearnHome> learnHome(String language) async {
    final (data, saved) = await _get('learn/home/', {'language': language});
    return LearnHome.fromJson(data, isSavedCopy: saved);
  }

  @override
  Future<Fetched<LearnArticleDetail>> article(
    String slug,
    String language,
  ) async {
    final (data, saved) = await _get('learn/articles/$slug/', {
      'language': language,
    });
    final detail = LearnArticleDetail.fromJson(data);
    if (detail == null) throw const AkhadaException(AkhadaFailure.server);
    return Fetched(detail, isSavedCopy: saved);
  }

  @override
  Future<ContentPage<GlossaryEntry>> glossary({
    required String language,
    String? query,
    int page = 1,
  }) async {
    final q = query?.trim() ?? '';
    final (data, saved) = await _get('learn/glossary/', {
      'language': language,
      'page_size': '50',
      if (page > 1) 'page': '$page',
      if (q.isNotEmpty) 'q': q,
    }, save: q.isEmpty);
    return ContentPage.fromJson(
      data,
      GlossaryEntry.fromJson,
      isSavedCopy: saved,
    );
  }

  @override
  Future<GlossaryDetail> term(String slug, String language) async {
    final (data, _) = await _get('learn/glossary/$slug/', {
      'language': language,
    });
    final detail = GlossaryDetail.fromJson(data);
    if (detail == null) throw const AkhadaException(AkhadaFailure.server);
    return detail;
  }
}

/// The repository the screens use; tests swap in a fake.
class PatrikaServices {
  PatrikaServices._();

  static PatrikaRepository repository = HttpPatrikaRepository();
  static PatrikaBookmarks bookmarks = PatrikaBookmarks();
}

class SavedItem {
  const SavedItem({
    required this.kind,
    required this.slug,
    required this.title,
    this.subtitle = '',
    this.imageUrl,
  });

  final String kind; // story | article
  final String slug;
  final String title;
  final String subtitle;
  final String? imageUrl;

  String get id => '$kind:$slug';

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'slug': slug,
    'title': title,
    'subtitle': subtitle,
    'image_url': imageUrl,
  };

  static SavedItem? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final kind = json['kind'];
    final slug = json['slug'];
    final title = json['title'];
    if (kind is! String || slug is! String || title is! String) return null;
    final image = json['image_url'];
    return SavedItem(
      kind: kind,
      slug: slug,
      title: title,
      subtitle: json['subtitle'] is String ? json['subtitle'] as String : '',
      imageUrl: image is String ? image : null,
    );
  }
}

/// Saved stories and articles, kept only on this device.
class PatrikaBookmarks extends ChangeNotifier {
  static const _key = 'patrika_saved';

  List<SavedItem>? _items;

  List<SavedItem> get items => List.unmodifiable(_items ?? const []);

  bool isSaved(String id) => _items?.any((i) => i.id == id) ?? false;

  Future<void> load() async {
    if (_items != null) return;
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    var loaded = <SavedItem>[];
    if (raw != null) {
      try {
        final list = jsonDecode(raw);
        if (list is List) {
          loaded = list.map(SavedItem.fromJson).whereType<SavedItem>().toList();
        }
      } on FormatException {
        loaded = [];
      }
    }
    _items = loaded;
    notifyListeners();
  }

  Future<void> toggle(SavedItem item) async {
    await load();
    final items = _items!;
    if (items.any((i) => i.id == item.id)) {
      items.removeWhere((i) => i.id == item.id);
    } else {
      items.insert(0, item);
    }
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(items.map((i) => i.toJson()).toList()),
    );
  }
}
