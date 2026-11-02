/// Data for Akhadas & Sadhus, matching `/api/akhadas/` responses.
/// Unknown or malformed values are dropped, never guessed.
library;

String? _str(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

List<Map<String, dynamic>> _maps(Object? v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

String? _https(Object? v) {
  final s = _str(v);
  return s != null && s.startsWith('https://') ? s : null;
}

List<T> _parse<T>(Object? v, T? Function(Map<String, dynamic>) parse) =>
    _maps(v).map(parse).whereType<T>().toList();

enum Verification { official, sourced, awaiting }

Verification _verification(Object? v) => switch (v) {
  'official' => Verification.official,
  'sourced' => Verification.sourced,
  _ => Verification.awaiting,
};

enum Confirmation { confirmed, announced, awaiting, historical }

Confirmation _confirmation(Object? v) => switch (v) {
  'confirmed' => Confirmation.confirmed,
  'announced' => Confirmation.announced,
  'historical' => Confirmation.historical,
  _ => Confirmation.awaiting,
};

class ContentImage {
  const ContentImage(
    this.url,
    this.credit, {
    this.sourceUrl,
    this.representative = false,
  });

  final String url;
  final String credit;

  /// Where the image and its licence can be checked.
  final String? sourceUrl;

  /// A related place or scene rather than the subject itself.
  final bool representative;

  /// Only images the backend sends with a credit are ever shown.
  static ContentImage? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final url = _str(json['url']);
    final credit = _str(json['credit']);
    if (url == null || credit == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !const ['https', 'http'].contains(uri.scheme)) {
      return null;
    }
    return ContentImage(
      url,
      credit,
      sourceUrl: _https(json['source_url']),
      representative: json['representative'] == true,
    );
  }
}

class ContentSource {
  const ContentSource({
    required this.title,
    this.url,
    this.organization,
    this.type,
    this.accessedOn,
  });

  final String title;
  final String? url;
  final String? organization;
  final String? type;
  final DateTime? accessedOn;

  bool get isOfficial => type == 'government' || type == 'official_akhada';

  static ContentSource? fromJson(Map<String, dynamic> json) {
    final title = _str(json['title']);
    if (title == null) return null;
    return ContentSource(
      title: title,
      url: _https(json['url']),
      organization: _str(json['organization']),
      type: _str(json['source_type']),
      accessedOn: _date(json['accessed_on']),
    );
  }
}

class TraditionInfo {
  const TraditionInfo({
    required this.slug,
    required this.name,
    this.summary = '',
    this.philosophy = '',
    this.practices = '',
  });

  final String slug;
  final String name;
  final String summary;
  final String philosophy;
  final String practices;

  static TraditionInfo? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final slug = _str(json['slug']);
    final name = _str(json['name']);
    if (slug == null || name == null) return null;
    return TraditionInfo(
      slug: slug,
      name: name,
      summary: _str(json['summary']) ?? '',
      philosophy: _str(json['philosophy']) ?? '',
      practices: _str(json['practices']) ?? '',
    );
  }
}

class TitleInfo {
  const TitleInfo({required this.slug, required this.name, this.meaning = ''});

  final String slug;
  final String name;
  final String meaning;

  static TitleInfo? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final slug = _str(json['slug']);
    final name = _str(json['name']);
    if (slug == null || name == null) return null;
    return TitleInfo(
      slug: slug,
      name: name,
      meaning: _str(json['meaning']) ?? '',
    );
  }
}

class AkhadaRef {
  const AkhadaRef({required this.slug, required this.name, this.commonName});

  final String slug;
  final String name;
  final String? commonName;

  String get label => commonName ?? name;

  static AkhadaRef? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final slug = _str(json['slug']);
    final name = _str(json['name']);
    if (slug == null || name == null) return null;
    return AkhadaRef(
      slug: slug,
      name: name,
      commonName: _str(json['common_name']),
    );
  }
}

class AkhadaSummary {
  const AkhadaSummary({
    required this.slug,
    required this.name,
    this.commonName,
    this.summary = '',
    this.tradition,
    this.headquarters,
    this.image,
    this.verification = Verification.awaiting,
    this.lastVerified,
    this.contentLanguage,
  });

  final String slug;
  final String name;
  final String? commonName;
  final String summary;
  final TraditionInfo? tradition;
  final String? headquarters;
  final ContentImage? image;
  final Verification verification;
  final DateTime? lastVerified;
  final String? contentLanguage;

  static AkhadaSummary? fromJson(Map<String, dynamic> json) {
    final slug = _str(json['slug']);
    final name = _str(json['name']);
    if (slug == null || name == null) return null;
    return AkhadaSummary(
      slug: slug,
      name: name,
      commonName: _str(json['common_name']),
      summary: _str(json['summary']) ?? '',
      tradition: TraditionInfo.fromJson(json['tradition']),
      headquarters: _str(json['headquarters']),
      image: ContentImage.fromJson(json['image']),
      verification: _verification(json['verification_status']),
      lastVerified: _date(json['last_verified_on']),
      contentLanguage: _str(json['content_language']),
    );
  }
}

class SaintSummary {
  const SaintSummary({
    required this.slug,
    required this.name,
    this.historical = false,
    this.title,
    this.akhada,
    this.image,
    this.verification = Verification.awaiting,
    this.lastVerified,
    this.contentLanguage,
  });

  final String slug;
  final String name;
  final bool historical;
  final TitleInfo? title;
  final AkhadaRef? akhada;
  final ContentImage? image;
  final Verification verification;
  final DateTime? lastVerified;
  final String? contentLanguage;

  static SaintSummary? fromJson(Map<String, dynamic> json) {
    final slug = _str(json['slug']);
    final name = _str(json['name']);
    if (slug == null || name == null) return null;
    return SaintSummary(
      slug: slug,
      name: name,
      historical: json['era'] == 'historical',
      title: TitleInfo.fromJson(json['title']),
      akhada: AkhadaRef.fromJson(json['akhada']),
      image: ContentImage.fromJson(json['image']),
      verification: _verification(json['verification_status']),
      lastVerified: _date(json['last_verified_on']),
      contentLanguage: _str(json['content_language']),
    );
  }
}

class ArticleSummary {
  const ArticleSummary({
    required this.slug,
    required this.title,
    this.intro = '',
    this.category = 'basics',
    this.isEditorial = false,
    this.image,
    this.verification = Verification.awaiting,
    this.lastVerified,
    this.publishedOn,
    this.contentLanguage,
  });

  final String slug;
  final String title;
  final String intro;
  final String category;
  final bool isEditorial;
  final ContentImage? image;
  final Verification verification;
  final DateTime? lastVerified;
  final DateTime? publishedOn;
  final String? contentLanguage;

  static ArticleSummary? fromJson(Map<String, dynamic> json) {
    final slug = _str(json['slug']);
    final title = _str(json['title']);
    if (slug == null || title == null) return null;
    return ArticleSummary(
      slug: slug,
      title: title,
      intro: _str(json['intro']) ?? '',
      category: _str(json['category']) ?? 'basics',
      isEditorial: json['is_editorial'] == true,
      image: ContentImage.fromJson(json['image']),
      verification: _verification(json['verification_status']),
      lastVerified: _date(json['last_verified_on']),
      publishedOn: _date(json['published_on']),
      contentLanguage: _str(json['content_language']),
    );
  }
}

class AkhadaActivity {
  const AkhadaActivity({
    required this.slug,
    required this.title,
    required this.confirmation,
    this.description = '',
    this.location,
    this.kind = 'announcement',
    this.akhadas = const [],
    this.startDate,
    this.endDate,
    this.lastVerified,
    this.sources = const [],
  });

  final String slug;
  final String title;
  final Confirmation confirmation;
  final String description;
  final String? location;
  final String kind;
  final List<AkhadaRef> akhadas;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? lastVerified;
  final List<ContentSource> sources;

  static AkhadaActivity? fromJson(Map<String, dynamic> json) {
    final slug = _str(json['slug']);
    final title = _str(json['title']);
    if (slug == null || title == null) return null;
    return AkhadaActivity(
      slug: slug,
      title: title,
      confirmation: _confirmation(json['confirmation']),
      description: _str(json['description']) ?? '',
      location: _str(json['location']),
      kind: _str(json['kind']) ?? 'announcement',
      akhadas: _parse(json['akhadas'], AkhadaRef.fromJson),
      startDate: _date(json['start_date']),
      endDate: _date(json['end_date']),
      lastVerified: _date(json['last_verified_on']),
      sources: _parse(json['sources'], ContentSource.fromJson),
    );
  }
}

class AkhadaDetail {
  const AkhadaDetail({
    required this.summary,
    this.history = '',
    this.philosophy = '',
    this.practices = '',
    this.organization = '',
    this.kumbhSignificance = '',
    this.nashikNote = '',
    this.websiteUrl,
    this.socialUrl,
    this.contactEmail,
    this.contactPhone,
    this.titles = const [],
    this.saints = const [],
    this.articles = const [],
    this.activities = const [],
    this.sources = const [],
  });

  final AkhadaSummary summary;
  final String history;
  final String philosophy;
  final String practices;
  final String organization;
  final String kumbhSignificance;
  final String nashikNote;
  final String? websiteUrl;
  final String? socialUrl;
  final String? contactEmail;
  final String? contactPhone;
  final List<TitleInfo> titles;
  final List<SaintSummary> saints;
  final List<ArticleSummary> articles;
  final List<AkhadaActivity> activities;
  final List<ContentSource> sources;

  static AkhadaDetail? fromJson(Map<String, dynamic> json) {
    final summary = AkhadaSummary.fromJson(json);
    if (summary == null) return null;
    return AkhadaDetail(
      summary: summary,
      history: _str(json['history']) ?? '',
      philosophy: _str(json['philosophy']) ?? '',
      practices: _str(json['practices']) ?? '',
      organization: _str(json['organization']) ?? '',
      kumbhSignificance: _str(json['kumbh_significance']) ?? '',
      nashikNote: _str(json['nashik_note']) ?? '',
      websiteUrl: _https(json['website_url']),
      socialUrl: _https(json['social_url']),
      contactEmail: _str(json['contact_email']),
      contactPhone: _str(json['contact_phone']),
      titles: _parse(json['titles'], TitleInfo.fromJson),
      saints: _parse(json['saints'], SaintSummary.fromJson),
      articles: _parse(json['articles'], ArticleSummary.fromJson),
      activities: _parse(json['activities'], AkhadaActivity.fromJson),
      sources: _parse(json['sources'], ContentSource.fromJson),
    );
  }
}

class SaintDetail {
  const SaintDetail({
    required this.summary,
    this.biography = '',
    this.teachings = '',
    this.publicActivities = '',
    this.significance = '',
    this.websiteUrl,
    this.socialUrl,
    this.articles = const [],
    this.sources = const [],
  });

  final SaintSummary summary;
  final String biography;
  final String teachings;
  final String publicActivities;
  final String significance;
  final String? websiteUrl;
  final String? socialUrl;
  final List<ArticleSummary> articles;
  final List<ContentSource> sources;

  static SaintDetail? fromJson(Map<String, dynamic> json) {
    final summary = SaintSummary.fromJson(json);
    if (summary == null) return null;
    return SaintDetail(
      summary: summary,
      biography: _str(json['biography']) ?? '',
      teachings: _str(json['teachings']) ?? '',
      publicActivities: _str(json['public_activities']) ?? '',
      significance: _str(json['significance']) ?? '',
      websiteUrl: _https(json['website_url']),
      socialUrl: _https(json['social_url']),
      articles: _parse(json['articles'], ArticleSummary.fromJson),
      sources: _parse(json['sources'], ContentSource.fromJson),
    );
  }
}

class ArticleDetail {
  const ArticleDetail({
    required this.summary,
    this.paragraphs = const [],
    this.akhadas = const [],
    this.saints = const [],
    this.sources = const [],
  });

  final ArticleSummary summary;
  final List<String> paragraphs;
  final List<AkhadaRef> akhadas;
  final List<SaintSummary> saints;
  final List<ContentSource> sources;

  static ArticleDetail? fromJson(Map<String, dynamic> json) {
    final summary = ArticleSummary.fromJson(json);
    if (summary == null) return null;
    return ArticleDetail(
      summary: summary,
      paragraphs:
          (_str(json['body']) ?? '')
              .split(RegExp(r'\n\s*\n'))
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .toList(),
      akhadas: _parse(json['akhadas'], AkhadaRef.fromJson),
      saints: _parse(json['saints'], SaintSummary.fromJson),
      sources: _parse(json['sources'], ContentSource.fromJson),
    );
  }
}

class ContentFilters {
  const ContentFilters({
    this.traditions = const [],
    this.locations = const [],
    this.titles = const [],
    this.saintAkhadas = const [],
    this.categories = const [],
  });

  final List<TraditionInfo> traditions;
  final List<String> locations;
  final List<TitleInfo> titles;
  final List<AkhadaRef> saintAkhadas;
  final List<String> categories;

  factory ContentFilters.fromJson(Map<String, dynamic> json) => ContentFilters(
    traditions: _parse(json['traditions'], TraditionInfo.fromJson),
    locations:
        (json['locations'] is List)
            ? (json['locations'] as List).whereType<String>().toList()
            : const [],
    titles: _parse(json['titles'], TitleInfo.fromJson),
    saintAkhadas: _parse(json['saint_akhadas'], AkhadaRef.fromJson),
    categories:
        (json['article_categories'] is List)
            ? (json['article_categories'] as List).whereType<String>().toList()
            : const [],
  );
}

class ContentPage<T> {
  const ContentPage({
    required this.items,
    this.page = 1,
    this.hasNext = false,
    this.isSavedCopy = false,
  });

  final List<T> items;
  final int page;
  final bool hasNext;

  /// Shown from the device because the network wasn't available.
  final bool isSavedCopy;

  static ContentPage<T> fromJson<T>(
    Map<String, dynamic> json,
    T? Function(Map<String, dynamic>) parse, {
    bool isSavedCopy = false,
  }) => ContentPage(
    items: _parse(json['results'], parse),
    page: json['page'] is int ? json['page'] as int : 1,
    hasNext: json['has_next'] == true,
    isSavedCopy: isSavedCopy,
  );
}

/// A detail response, and whether it came from the device.
class Fetched<T> {
  const Fetched(this.value, {this.isSavedCopy = false});

  final T value;
  final bool isSavedCopy;
}
