/// Data for Kumbh Patrika (news and Learn), matching `/api/news/` and
/// `/api/learn/`. Unknown or malformed values are dropped, never guessed.
library;

import 'package:kumbha_path/src/modules/akhada/models/akhada_models.dart';

String? _str(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

String? _https(Object? v) {
  final s = _str(v);
  return s != null && s.startsWith('https://') ? s : null;
}

List<T> _list<T>(Object? v, T? Function(Map<String, dynamic>) parse) =>
    v is List
        ? v.whereType<Map<String, dynamic>>().map(parse).whereType<T>().toList()
        : <T>[];

Verification _verification(Object? v) => switch (v) {
  'official' => Verification.official,
  'sourced' => Verification.sourced,
  _ => Verification.awaiting,
};

class NewsCategory {
  const NewsCategory(this.slug, this.name);

  final String slug;
  final String name;

  static NewsCategory? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final slug = _str(json['slug']);
    final name = _str(json['name']);
    return slug == null || name == null ? null : NewsCategory(slug, name);
  }
}

class NewsPublisher {
  const NewsPublisher({
    required this.slug,
    required this.name,
    this.isOfficial = false,
  });

  final String slug;
  final String name;
  final bool isOfficial;

  static NewsPublisher? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final slug = _str(json['slug']);
    final name = _str(json['name']);
    if (slug == null || name == null) return null;
    return NewsPublisher(
      slug: slug,
      name: name,
      isOfficial: json['publisher_type'] == 'official',
    );
  }
}

class NewsStory {
  const NewsStory({
    required this.slug,
    required this.headline,
    required this.publisher,
    required this.publishedAt,
    required this.originalUrl,
    this.summary = '',
    this.category,
    this.image,
    this.isOfficial = false,
    this.contentLanguage,
    this.verification = Verification.awaiting,
    this.attribution,
  });

  final String slug;
  final String headline;
  final String summary;
  final NewsPublisher publisher;
  final NewsCategory? category;
  final ContentImage? image;
  final DateTime publishedAt;
  final String originalUrl;

  /// True only for a notice from an official publisher. Both must agree, so a
  /// wrongly flagged story can't look official.
  final bool isOfficial;
  final String? contentLanguage;
  final Verification verification;
  final String? attribution;

  static NewsStory? fromJson(Map<String, dynamic> json) {
    final slug = _str(json['slug']);
    final headline = _str(json['headline']);
    final publisher = NewsPublisher.fromJson(json['publisher']);
    final published = _date(json['published_at']);
    final url = _https(json['original_url']);
    if (slug == null ||
        headline == null ||
        publisher == null ||
        published == null ||
        url == null) {
      return null;
    }
    return NewsStory(
      slug: slug,
      headline: headline,
      publisher: publisher,
      publishedAt: published,
      originalUrl: url,
      summary: _str(json['summary']) ?? '',
      category: NewsCategory.fromJson(json['category']),
      image: ContentImage.fromJson(json['image']),
      isOfficial:
          json['is_official_announcement'] == true && publisher.isOfficial,
      contentLanguage: _str(json['content_language']),
      verification: _verification(json['verification_status']),
      attribution: _str(json['attribution']),
    );
  }
}

class NewsDetail {
  const NewsDetail(this.story, this.related);

  final NewsStory story;
  final List<NewsStory> related;

  static NewsDetail? fromJson(Map<String, dynamic> json) {
    final story = NewsStory.fromJson(json);
    if (story == null) return null;
    return NewsDetail(story, _list(json['related'], NewsStory.fromJson));
  }
}

class NewsHome {
  const NewsHome({
    this.lead,
    this.announcements = const [],
    this.latest = const [],
    this.categories = const [],
    this.publishers = const [],
    this.isSavedCopy = false,
  });

  final NewsStory? lead;
  final List<NewsStory> announcements;
  final List<NewsStory> latest;
  final List<NewsCategory> categories;
  final List<NewsPublisher> publishers;
  final bool isSavedCopy;

  bool get isEmpty => lead == null && latest.isEmpty && announcements.isEmpty;

  factory NewsHome.fromJson(
    Map<String, dynamic> json, {
    bool isSavedCopy = false,
  }) => NewsHome(
    lead:
        json['lead'] is Map<String, dynamic>
            ? NewsStory.fromJson(json['lead'] as Map<String, dynamic>)
            : null,
    announcements: _list(json['announcements'], NewsStory.fromJson),
    latest: _list(json['latest'], NewsStory.fromJson),
    categories: _list(json['categories'], NewsCategory.fromJson),
    publishers: _list(json['publishers'], NewsPublisher.fromJson),
    isSavedCopy: isSavedCopy,
  );
}

class LearnArticle {
  const LearnArticle({
    required this.slug,
    required this.title,
    this.dek = '',
    this.section = '',
    this.kind = 'article',
    this.image,
    this.readingMinutes = 1,
    this.isEditorial = false,
    this.verification = Verification.awaiting,
    this.lastVerified,
    this.contentLanguage,
  });

  final String slug;
  final String title;
  final String dek;
  final String section;
  final String kind;
  final ContentImage? image;
  final int readingMinutes;
  final bool isEditorial;
  final Verification verification;
  final DateTime? lastVerified;
  final String? contentLanguage;

  static LearnArticle? fromJson(Map<String, dynamic> json) {
    final slug = _str(json['slug']);
    final title = _str(json['title']);
    if (slug == null || title == null) return null;
    final minutes = json['reading_minutes'];
    return LearnArticle(
      slug: slug,
      title: title,
      dek: _str(json['dek']) ?? '',
      section: _str(json['section']) ?? '',
      kind: _str(json['kind']) ?? 'article',
      image: ContentImage.fromJson(json['image']),
      readingMinutes: minutes is int && minutes > 0 ? minutes : 1,
      isEditorial: json['is_editorial'] == true,
      verification: _verification(json['verification_status']),
      lastVerified: _date(json['last_verified_on']),
      contentLanguage: _str(json['content_language']),
    );
  }
}

class LearnSection {
  const LearnSection(this.slug, this.name, this.tagline, this.articles);

  final String slug;
  final String name;
  final String tagline;
  final List<LearnArticle> articles;

  static LearnSection? fromJson(Map<String, dynamic> json) {
    final slug = _str(json['slug']);
    final name = _str(json['name']);
    if (slug == null || name == null) return null;
    return LearnSection(
      slug,
      name,
      _str(json['tagline']) ?? '',
      _list(json['articles'], LearnArticle.fromJson),
    );
  }
}

class GlossaryEntry {
  const GlossaryEntry(this.slug, this.term, this.simple);

  final String slug;
  final String term;
  final String simple;

  static GlossaryEntry? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final slug = _str(json['slug']);
    final term = _str(json['term']);
    if (slug == null || term == null) return null;
    return GlossaryEntry(slug, term, _str(json['simple']) ?? '');
  }
}

class LearnHome {
  const LearnHome({
    this.cover,
    this.sections = const [],
    this.term,
    this.isSavedCopy = false,
  });

  final LearnArticle? cover;
  final List<LearnSection> sections;
  final GlossaryEntry? term;
  final bool isSavedCopy;

  bool get isEmpty => cover == null && sections.isEmpty;

  factory LearnHome.fromJson(
    Map<String, dynamic> json, {
    bool isSavedCopy = false,
  }) => LearnHome(
    cover:
        json['cover'] is Map<String, dynamic>
            ? LearnArticle.fromJson(json['cover'] as Map<String, dynamic>)
            : null,
    sections: _list(json['sections'], LearnSection.fromJson),
    term: GlossaryEntry.fromJson(json['term']),
    isSavedCopy: isSavedCopy,
  );
}

/// One piece of an article body.
sealed class ArticleBlock {
  const ArticleBlock();

  static ArticleBlock? fromJson(Map<String, dynamic> json) {
    final text = _str(json['text']) ?? '';
    switch (json['type']) {
      case 'paragraph' when text.isNotEmpty:
        return ParagraphBlock(text);
      case 'heading' when text.isNotEmpty:
        return HeadingBlock(text);
      case 'quote' when text.isNotEmpty:
        return QuoteBlock(text);
      case 'callout' when text.isNotEmpty:
        return CalloutBlock(text, warning: json['tone'] == 'warn');
      case 'list':
        final items = json['items'];
        if (items is! List) return null;
        final texts = items.whereType<String>().toList();
        return texts.isEmpty ? null : ListBlock(texts);
      case 'image':
        final image = ContentImage.fromJson(json['image']);
        return image == null
            ? null
            : ImageBlock(image, _str(json['caption']) ?? '');
    }
    return null; // a block type this version doesn't know is skipped
  }
}

class ParagraphBlock extends ArticleBlock {
  const ParagraphBlock(this.text);
  final String text;
}

class HeadingBlock extends ArticleBlock {
  const HeadingBlock(this.text);
  final String text;
}

class QuoteBlock extends ArticleBlock {
  const QuoteBlock(this.text);
  final String text;
}

class CalloutBlock extends ArticleBlock {
  const CalloutBlock(this.text, {this.warning = false});
  final String text;
  final bool warning;
}

class ListBlock extends ArticleBlock {
  const ListBlock(this.items);
  final List<String> items;
}

class ImageBlock extends ArticleBlock {
  const ImageBlock(this.image, this.caption);
  final ContentImage image;
  final String caption;
}

class TempleLink {
  const TempleLink(this.id, this.name);

  final String id;
  final String name;

  static TempleLink? fromJson(Map<String, dynamic> json) {
    final id = _str(json['id']);
    final name = _str(json['name']);
    return id == null || name == null ? null : TempleLink(id, name);
  }
}

class LearnArticleDetail {
  const LearnArticleDetail({
    required this.article,
    this.blocks = const [],
    this.temples = const [],
    this.akhadas = const [],
    this.related = const [],
    this.sources = const [],
  });

  final LearnArticle article;
  final List<ArticleBlock> blocks;
  final List<TempleLink> temples;
  final List<AkhadaRef> akhadas;
  final List<LearnArticle> related;
  final List<ContentSource> sources;

  static LearnArticleDetail? fromJson(Map<String, dynamic> json) {
    final article = LearnArticle.fromJson(json);
    if (article == null) return null;
    return LearnArticleDetail(
      article: article,
      blocks: _list(json['blocks'], ArticleBlock.fromJson),
      temples: _list(json['temples'], TempleLink.fromJson),
      akhadas: _list(json['akhadas'], AkhadaRef.fromJson),
      related: _list(json['related'], LearnArticle.fromJson),
      sources: _list(json['sources'], ContentSource.fromJson),
    );
  }
}

class GlossaryDetail {
  const GlossaryDetail({
    required this.entry,
    this.detail = '',
    this.articles = const [],
    this.akhadas = const [],
    this.temples = const [],
  });

  final GlossaryEntry entry;
  final String detail;
  final List<LearnArticle> articles;
  final List<AkhadaRef> akhadas;
  final List<TempleLink> temples;

  static GlossaryDetail? fromJson(Map<String, dynamic> json) {
    final entry = GlossaryEntry.fromJson(json);
    if (entry == null) return null;
    return GlossaryDetail(
      entry: entry,
      detail: _str(json['detail']) ?? '',
      articles: _list(json['articles'], LearnArticle.fromJson),
      akhadas: _list(json['akhadas'], AkhadaRef.fromJson),
      temples: _list(json['temples'], TempleLink.fromJson),
    );
  }
}
