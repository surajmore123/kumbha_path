import 'package:equatable/equatable.dart';

/// Data the website (kumbhapath.in) publishes through `/api/v1/`: admin
/// announcements, partner listings and CMS page text. Parsing is tolerant:
/// a missing or wrong-typed field becomes its empty default, never a crash.

String _str(Object? v) => v is String ? v.trim() : '';
String? _optStr(Object? v) {
  final s = _str(v);
  return s.isEmpty ? null : s;
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// `official` (Mela authority, police…), `info` (Kumbh Path) or `alert`
/// (route closures, weather, crowd warnings).
enum AnnouncementKind {
  official,
  info,
  alert;

  static AnnouncementKind parse(Object? v) => switch (_str(v)) {
    'official' => official,
    'alert' => alert,
    _ => info,
  };
}

/// One notice written in the website admin panel (Announcements).
class Announcement extends Equatable {
  const Announcement({
    required this.id,
    required this.title,
    this.body,
    this.link,
    this.kind = AnnouncementKind.info,
    this.pinned = false,
    this.startsOn,
    this.endsOn,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? body;

  /// Absolute URL or a website path such as `/today`.
  final String? link;
  final AnnouncementKind kind;
  final bool pinned;
  final DateTime? startsOn;
  final DateTime? endsOn;
  final DateTime? createdAt;

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: _str(json['id']),
    title: _str(json['title']),
    body: _optStr(json['body']),
    link: _optStr(json['link']),
    kind: AnnouncementKind.parse(json['kind']),
    pinned: json['pinned'] == true,
    startsOn: _date(json['starts_on']),
    endsOn: _date(json['ends_on']),
    createdAt: _date(json['created_at'])?.toLocal(),
  );

  @override
  List<Object?> get props => [id, title, body, link, kind, pinned, createdAt];
}

/// The website's four service categories, in its own order.
enum ListingCategory {
  hotels,
  cabs,
  tours,
  packages;

  static ListingCategory? parse(Object? v) {
    for (final c in values) {
      if (c.name == v) return c;
    }
    return null;
  }
}

/// A published stay, cab, tour or package (partner or official).
class Listing extends Equatable {
  const Listing({
    required this.id,
    required this.category,
    required this.name,
    this.type = '',
    this.town = '',
    this.area = '',
    this.priceFrom = 0,
    this.unit = '',
    this.highlights = const [],
    this.distance,
    this.duration,
    this.official = false,
    this.wheelchair = false,
    this.image,
    this.isSample = false,
  });

  final String id;
  final ListingCategory category;
  final String name;
  final String type;
  final String town;
  final String area;

  /// Whole rupees; 0 means "see official rates".
  final int priceFrom;
  final String unit;
  final List<String> highlights;
  final String? distance;
  final String? duration;

  /// `trust == "official"`: run by the Mela authority or government.
  final bool official;
  final bool wheelchair;

  /// Website photo id (e.g. `ramkund`), served at
  /// `<website>/images/photos/<id>.webp`.
  final String? image;
  final bool isSample;

  /// Null when the row has no id, name or known category (skipped).
  static Listing? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.cast<String, dynamic>();
    final category = ListingCategory.parse(json['category']);
    final id = _str(json['id']);
    final name = _str(json['name']);
    if (category == null || id.isEmpty || name.isEmpty) return null;
    final price = json['price_from'];
    return Listing(
      id: id,
      category: category,
      name: name,
      type: _str(json['type']),
      town: _str(json['town']),
      area: _str(json['area']),
      priceFrom: price is num ? price.toInt() : 0,
      unit: _str(json['unit']),
      highlights: [
        if (json['highlights'] is List)
          for (final h in json['highlights'] as List)
            if (_str(h).isNotEmpty) _str(h),
      ],
      distance: _optStr(json['distance']),
      duration: _optStr(json['duration']),
      official: json['trust'] == 'official',
      wheelchair: json['wheelchair'] == true,
      image: _optStr(json['image']),
      isSample: json['is_sample'] == true,
    );
  }

  @override
  List<Object?> get props => [id, category, name, priceFrom, image];
}

/// Edited CMS values for one website page (key → value). Only edited keys
/// are present; anything else falls back to the app's own text.
class PageContent extends Equatable {
  const PageContent(this.values, {this.apiBase = ''});

  static const PageContent empty = PageContent({});

  final Map<String, String> values;

  /// `<protocol>://<host>/api/v1`, used to build `/media/...` image URLs.
  final String apiBase;

  factory PageContent.fromJson(Object? raw, {String apiBase = ''}) {
    if (raw is! Map) return empty;
    return PageContent({
      for (final e in raw.entries)
        if (e.key is String && _str(e.value).isNotEmpty)
          e.key as String: _str(e.value),
    }, apiBase: apiBase);
  }

  /// The admin's text for [key], or [fallback] when it was never edited.
  String text(String key, String fallback) => values[key] ?? fallback;

  /// Full URL of an image chosen in the admin panel, or null.
  String? image(String key) {
    final v = values[key];
    return v != null && v.startsWith('/media/') ? '$apiBase$v' : null;
  }

  @override
  List<Object?> get props => [values, apiBase];
}
