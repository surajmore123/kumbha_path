import 'package:kumbha_path/src/modules/akhada/data/akhada_repository.dart';
import 'package:kumbha_path/src/modules/akhada/models/akhada_models.dart';
import 'package:kumbha_path/src/modules/patrika/data/patrika_repository.dart';
import 'package:kumbha_path/src/modules/patrika/models/patrika_models.dart';

const _image = {
  'url': 'https://example.org/a.jpg',
  'credit': 'A. Author, CC BY 4.0',
  'source_url': 'https://commons.wikimedia.org/wiki/File:A.jpg',
  'representative': true,
};

Map<String, dynamic> storyJson(
  String slug, {
  String? day,
  bool official = false,
  String lang = 'en',
}) => {
  'slug': slug,
  'headline': 'Headline $slug',
  'summary': 'Summary of $slug',
  'content_language': lang,
  'category': {'slug': 'transport', 'name': 'Transport'},
  'publisher': {
    'slug': official ? 'pib' : 'sakal',
    'name': official ? 'Press Information Bureau' : 'Sakal',
    'publisher_type': official ? 'official' : 'news',
  },
  'image': _image,
  'published_at': day ?? '2026-10-30T10:00:00+05:30',
  'is_official_announcement': official,
  'verification_status': 'sourced',
  'original_url': 'https://example.org/$slug',
};

Map<String, dynamic> articleJson(String slug, {String kind = 'article'}) => {
  'slug': slug,
  'title': 'Title $slug',
  'dek': 'Dek of $slug',
  'section': 'understanding',
  'kind': kind,
  'image': _image,
  'reading_minutes': 3,
  'verification_status': 'sourced',
  'last_verified_on': '2026-10-30',
  'content_language': 'en',
};

/// Backend-shaped responses for every Patrika screen.
class FakePatrikaRepository implements PatrikaRepository {
  final calls = <String>[];
  AkhadaException? fail;
  bool empty = false;
  bool withNotice = true;
  bool hasNextPage = false;
  bool savedCopy = false;
  String? contentLanguage;
  String verification = 'sourced';

  void _record(String call) {
    calls.add(call);
    final f = fail;
    if (f != null) throw f;
  }

  @override
  Future<NewsHome> newsHome(String language) async {
    _record('home:$language');
    if (empty) return const NewsHome();
    return NewsHome.fromJson({
      'lead': storyJson('lead'),
      'announcements': [if (withNotice) storyJson('notice', official: true)],
      'latest': [storyJson('one')],
      'categories': [
        {'slug': 'transport', 'name': 'Transport'},
        {'slug': 'dates', 'name': 'Important Dates'},
      ],
      'publishers': [
        {'slug': 'sakal', 'name': 'Sakal', 'publisher_type': 'news'},
      ],
    }, isSavedCopy: savedCopy);
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
    _record(
      'news:${query ?? ''}:${category ?? ''}:${publisher ?? ''}:$relevant:$page',
    );
    if (empty) return const ContentPage(items: []);
    return ContentPage.fromJson({
      'page': page,
      'has_next': hasNextPage && page == 1,
      'results': [
        if (page == 1) ...[
          storyJson('lead'),
          storyJson('one'),
          storyJson('two'),
          storyJson('three'),
          storyJson('four'),
          storyJson('older', day: '2026-06-11T10:00:00+05:30'),
        ] else
          storyJson('page-two', day: '2026-01-01T10:00:00+05:30'),
      ],
    }, NewsStory.fromJson);
  }

  @override
  Future<Fetched<NewsDetail>> story(String slug, String language) async {
    _record('story:$slug');
    return Fetched(
      NewsDetail.fromJson({
        ...storyJson(
          slug,
          official: slug == 'notice',
          lang: contentLanguage ?? 'en',
        ),
        'related': [storyJson('related')],
      })!,
      isSavedCopy: savedCopy,
    );
  }

  @override
  Future<LearnHome> learnHome(String language) async {
    _record('learn:$language');
    if (empty) return const LearnHome();
    return LearnHome.fromJson({
      'cover': articleJson('cover'),
      'sections': [
        {
          'slug': 'understanding',
          'name': 'Understanding Kumbh',
          'tagline': 'What it is',
          'articles': [articleJson('a1'), articleJson('a2')],
        },
        {
          'slug': 'guides',
          'name': 'Pilgrim Guides',
          'articles': [articleJson('g1', kind: 'guide')],
        },
        {
          'slug': 'places',
          'name': 'Places of Discovery',
          'articles': [articleJson('p1', kind: 'place')],
        },
      ],
      'term': {'slug': 'ghat', 'term': 'Ghat', 'simple': 'Steps to a river'},
    });
  }

  @override
  Future<Fetched<LearnArticleDetail>> article(
    String slug,
    String language,
  ) async {
    _record('article:$slug');
    return Fetched(
      LearnArticleDetail.fromJson({
        ...articleJson(slug),
        'verification_status': verification,
        'blocks': [
          {'type': 'paragraph', 'text': 'Opening paragraph.'},
          {'type': 'heading', 'text': 'A heading'},
          {'type': 'paragraph', 'text': 'Second paragraph.'},
          {
            'type': 'list',
            'items': ['First item', 'Second item'],
          },
          {'type': 'quote', 'text': 'A quotation'},
          {'type': 'callout', 'tone': 'warn', 'text': 'Take care'},
          {'type': 'callout', 'tone': 'info', 'text': 'Good to know'},
          {'type': 'image', 'image': _image, 'caption': 'A caption'},
          {'type': 'future-type', 'text': 'skipped'},
        ],
        'temples': [
          {'id': 'temple-1', 'name': 'Trimbakeshwar Mandir'},
        ],
        'akhadas': [
          {'slug': 'juna', 'name': 'Shri Juna', 'common_name': 'Juna Akhada'},
        ],
        'related': [articleJson('next')],
        'sources': [
          {'title': 'UNESCO page', 'url': 'https://ich.unesco.org/x'},
        ],
      })!,
    );
  }

  @override
  Future<ContentPage<GlossaryEntry>> glossary({
    required String language,
    String? query,
    int page = 1,
  }) async {
    _record('glossary:${query ?? ''}');
    return ContentPage.fromJson({
      'results': [
        {'slug': 'ghat', 'term': 'Ghat', 'simple': 'Steps to a river'},
        {'slug': 'kund', 'term': 'Kund', 'simple': 'A sacred tank'},
      ],
    }, GlossaryEntry.fromJson);
  }

  @override
  Future<GlossaryDetail> term(String slug, String language) async {
    _record('term:$slug');
    return GlossaryDetail.fromJson({
      'slug': slug,
      'term': 'Ghat',
      'simple': 'Steps to a river',
      'detail': 'Used for bathing and worship.',
      'articles': [articleJson('at-ramkund')],
      'akhadas': <Object>[],
      'temples': <Object>[],
    })!;
  }
}
