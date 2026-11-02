import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/akhada/akhadas_screens.dart';
import 'package:kumbha_path/src/modules/akhada/data/akhada_repository.dart';
import 'package:kumbha_path/src/modules/akhada/models/akhada_models.dart';
import 'package:kumbha_path/src/modules/akhada/widgets/akhada_cards.dart';
import 'package:kumbha_path/src/modules/akhada/widgets/akhada_dashboard_panel.dart';
import 'package:kumbha_path/src/modules/akhada/widgets/akhada_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    return json.decode(await file.readAsString()) as Map<String, dynamic>;
  }
}

class MemoryStore implements ContentStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

const _source = {
  'title': 'Gazette',
  'url': 'https://example.gov.in/a',
  'organization': 'PIB',
  'source_type': 'government',
  'accessed_on': '2026-10-30',
};

Map<String, dynamic> akhadaJson(
  String slug,
  String name, {
  String lang = 'en',
}) => {
  'slug': slug,
  'name': 'Shri $name Akhara',
  'common_name': '$name Akhada',
  'summary': 'About $name',
  'tradition': {
    'slug': 'shaiva',
    'name': 'Shaiva',
    'summary': 'Devoted to Shiva',
  },
  'image': null,
  'verification_status': 'sourced',
  'last_verified_on': '2026-10-30',
  'content_language': lang,
};

Map<String, dynamic> saintJson() => {
  'slug': 'sant',
  'name': 'Swami Example',
  'era': 'contemporary',
  'title': {'slug': 'mahant', 'name': 'Mahant', 'meaning': 'Head'},
  'akhada': {'slug': 'juna', 'name': 'Shri Juna', 'common_name': 'Juna Akhada'},
  'verification_status': 'sourced',
  'last_verified_on': '2026-10-30',
  'content_language': 'en',
};

Map<String, dynamic> articleJson() => {
  'slug': 'what',
  'title': 'What is an Akhada?',
  'intro': 'An order of ascetics.',
  'category': 'basics',
  'is_editorial': true,
  'verification_status': 'sourced',
  'last_verified_on': '2026-10-30',
  'content_language': 'en',
};

Map<String, dynamic> activityJson(String confirmation) => {
  'slug': 'a-$confirmation',
  'title': 'Item $confirmation',
  'description': 'Details',
  'location': 'Ramkund',
  'kind': 'ceremony',
  'confirmation': confirmation,
  'start_date': '2027-08-02',
  'akhadas': [
    {'slug': 'juna', 'name': 'Shri Juna', 'common_name': 'Juna Akhada'},
  ],
  'sources': [_source],
};

class FakeRepository implements AkhadaRepository {
  final calls = <String>[];
  AkhadaException? fail;
  int pages = 1;
  String? contentLanguage;
  bool savedCopy = false;

  void _record(String call) {
    calls.add(call);
    final f = fail;
    if (f != null) throw f;
  }

  ContentPage<T> _one<T>(T item, int page) => ContentPage(
    items: [item],
    page: page,
    hasNext: page < pages,
    isSavedCopy: savedCopy,
  );

  @override
  Future<ContentPage<AkhadaSummary>> akhadas({
    required String language,
    String? query,
    String? tradition,
    String? location,
    int page = 1,
  }) async {
    _record(
      'akhadas:$language:${query ?? ''}:${tradition ?? ''}:${location ?? ''}:$page',
    );
    return _one(
      AkhadaSummary.fromJson(akhadaJson('juna$page', 'Juna $page'))!,
      page,
    );
  }

  @override
  Future<Fetched<AkhadaDetail>> akhada(String slug, String language) async {
    _record('akhada:$slug:$language');
    return Fetched(
      AkhadaDetail.fromJson({
        ...akhadaJson(slug, 'Juna', lang: contentLanguage ?? 'en'),
        'history': 'Old history',
        'nashik_note': 'Reported in 2026',
        'titles': [
          {'slug': 'mahant', 'name': 'Mahant', 'meaning': 'A head'},
        ],
        'saints': [saintJson()],
        'articles': [articleJson()],
        'activities': [activityJson('awaiting')],
        'sources': [_source],
      })!,
      isSavedCopy: savedCopy,
    );
  }

  @override
  Future<ContentPage<SaintSummary>> saints({
    required String language,
    String? query,
    String? akhada,
    String? title,
    int page = 1,
  }) async {
    _record('saints:${query ?? ''}:${akhada ?? ''}:${title ?? ''}');
    return _one(SaintSummary.fromJson(saintJson())!, page);
  }

  @override
  Future<Fetched<SaintDetail>> saint(String slug, String language) async {
    _record('saint:$slug');
    return Fetched(
      SaintDetail.fromJson({
        ...saintJson(),
        'biography': 'Life story',
        'teachings': '',
        'sources': [_source],
      })!,
    );
  }

  @override
  Future<ContentPage<ArticleSummary>> articles({
    required String language,
    String? query,
    String? category,
    int page = 1,
  }) async {
    _record('articles:${category ?? ''}');
    return _one(ArticleSummary.fromJson(articleJson())!, page);
  }

  @override
  Future<Fetched<ArticleDetail>> article(String slug, String language) async {
    _record('article:$slug');
    return Fetched(
      ArticleDetail.fromJson({
        ...articleJson(),
        'body': 'First paragraph.\n\nSecond paragraph.',
        'akhadas': [
          {'slug': 'juna', 'name': 'Shri Juna', 'common_name': 'Juna Akhada'},
        ],
        'saints': [saintJson()],
        'sources': [_source],
      })!,
    );
  }

  @override
  Future<ContentPage<AkhadaActivity>> activities({
    required String language,
    String? confirmation,
    int page = 1,
  }) async {
    _record('activities:${confirmation ?? ''}');
    return ContentPage(
      items: [
        for (final c in const [
          'confirmed',
          'announced',
          'awaiting',
          'historical',
        ])
          if (confirmation == null || confirmation == c)
            AkhadaActivity.fromJson(activityJson(c))!,
      ],
    );
  }

  @override
  Future<ContentFilters> filters(String language) async {
    _record('filters');
    return ContentFilters.fromJson({
      'traditions': [
        {'slug': 'shaiva', 'name': 'Shaiva'},
        {'slug': 'vaishnava', 'name': 'Vaishnava'},
      ],
      'locations': ['Varanasi'],
      'titles': [
        {'slug': 'mahant', 'name': 'Mahant'},
      ],
      'saint_akhadas': [
        {'slug': 'juna', 'name': 'Shri Juna', 'common_name': 'Juna Akhada'},
      ],
      'article_categories': ['basics', 'kumbh'],
    });
  }
}

late FakeRepository repo;
late List<String> pushed;

Future<void> pumpApp(
  WidgetTester tester,
  Widget home, {
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  Route<dynamic> route(RouteSettings settings) {
    pushed.add(settings.name ?? '');
    final slug = settings.arguments as String? ?? '';
    final Widget page = switch (settings.name) {
      '/akhadaDetail' => AkhadaDetailScreen(slug: slug, repository: repo),
      '/saintDetail' => SaintDetailScreen(slug: slug, repository: repo),
      '/akhadaArticle' => AkhadaArticleScreen(slug: slug, repository: repo),
      '/akhadaList' => AkhadaListScreen(repository: repo),
      _ => const Scaffold(body: Text('destination')),
    };
    return MaterialPageRoute(settings: settings, builder: (_) => page);
  }

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
      path: 'assets/translations',
      assetLoader: const _FileAssetLoader(),
      fallbackLocale: const Locale('en'),
      startLocale: locale,
      saveLocale: false,
      child: Builder(
        builder:
            (context) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode:
                  brightness == Brightness.dark
                      ? ThemeMode.dark
                      : ThemeMode.light,
              onGenerateRoute: route,
              home: home,
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(textScale)),
                    child: child!,
                  ),
            ),
      ),
    ),
  );
  for (var i = 0; i < 20 && find.byType(Navigator).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = FakeRepository();
    pushed = [];
  });

  group('models', () {
    test('unsafe or broken values are dropped', () {
      final detail =
          AkhadaDetail.fromJson({
            ...akhadaJson('juna', 'Juna'),
            'website_url': 'http://insecure.example',
            'image': {'url': 'https://example.org/a.jpg'},
            'sources': [
              {'title': 'Book', 'url': 'javascript:alert(1)'},
              {'url': 'https://no-title.example'},
            ],
          })!;
      expect(detail.websiteUrl, isNull);
      expect(detail.summary.image, isNull, reason: 'no credit, no image');
      expect(detail.sources.single.url, isNull);
      expect(AkhadaSummary.fromJson({'slug': 'x'}), isNull);
    });

    test('image attribution and representative flag are parsed', () {
      final image =
          ContentImage.fromJson({
            'url': 'https://example.org/a.jpg',
            'credit': 'A. Author, CC BY 4.0',
            'source_url': 'https://commons.wikimedia.org/wiki/File:A.jpg',
            'representative': true,
          })!;
      expect(image.representative, isTrue);
      expect(image.sourceUrl, contains('commons'));
      final insecure =
          ContentImage.fromJson({
            'url': 'https://example.org/a.jpg',
            'credit': 'Author',
            'source_url': 'javascript:alert(1)',
          })!;
      expect(insecure.sourceUrl, isNull);
    });

    test('an unknown confirmation never reads as confirmed', () {
      final a =
          AkhadaActivity.fromJson({
            ...activityJson('confirmed'),
            'confirmation': 'maybe',
          })!;
      expect(a.confirmation, Confirmation.awaiting);
    });

    test('article body splits into paragraphs', () {
      final a =
          ArticleDetail.fromJson({
            ...articleJson(),
            'body': 'One.\n\n  Two.\n\n',
          })!;
      expect(a.paragraphs, ['One.', 'Two.']);
    });
  });

  group('http repository', () {
    setUpAll(
      () => dotenv.loadFromString(
        envString: 'API_PROTOCOL=https\nAPI_HOST=api.example.test',
      ),
    );

    final body = jsonEncode({
      'status': 'success',
      'data': {
        'count': 1,
        'page': 1,
        'has_next': false,
        'results': [akhadaJson('juna', 'Juna')],
      },
    });

    test('sends no token and passes filters', () async {
      late http.BaseRequest seen;
      final r = HttpAkhadaRepository(
        store: MemoryStore(),
        client: MockClient((req) async {
          seen = req;
          return http.Response.bytes(utf8.encode(body), 200);
        }),
      );
      final page = await r.akhadas(language: 'hi', tradition: 'shaiva');
      expect(page.items.single.slug, 'juna');
      expect(seen.headers.containsKey('Authorization'), isFalse);
      expect(seen.url.path, '/api/akhadas/');
      expect(seen.url.queryParameters, {
        'language': 'hi',
        'tradition': 'shaiva',
      });
    });

    test('offline falls back to the saved copy and says so', () async {
      final store = MemoryStore();
      var online = true;
      final r = HttpAkhadaRepository(
        store: store,
        client: MockClient((_) async {
          if (!online) throw const SocketException('down');
          return http.Response.bytes(utf8.encode(body), 200);
        }),
      );
      expect((await r.akhadas(language: 'en')).isSavedCopy, isFalse);
      online = false;
      final saved = await r.akhadas(language: 'en');
      expect(saved.isSavedCopy, isTrue);
      expect(saved.items.single.slug, 'juna');
      await expectLater(
        r.akhadas(language: 'hi'),
        throwsA(
          isA<AkhadaException>().having(
            (e) => e.kind,
            'kind',
            AkhadaFailure.offline,
          ),
        ),
      );
    });

    test('searches are not saved', () async {
      final store = MemoryStore();
      final r = HttpAkhadaRepository(
        store: store,
        client: MockClient(
          (_) async => http.Response.bytes(utf8.encode(body), 200),
        ),
      );
      await r.akhadas(language: 'en', query: 'juna');
      expect(store.values, isEmpty);
    });

    test('404 and 500 map to failures, and a 404 keeps no copy', () async {
      Future<AkhadaFailure> failWith(int code) async {
        final store = MemoryStore();
        final r = HttpAkhadaRepository(
          store: store,
          client: MockClient((_) async => http.Response('{}', code)),
        );
        try {
          await r.akhada('x', 'en');
        } on AkhadaException catch (e) {
          expect(store.values, isEmpty);
          return e.kind;
        }
        fail('expected a failure');
      }

      expect(await failWith(404), AkhadaFailure.notFound);
      expect(await failWith(500), AkhadaFailure.server);
    });

    test('the saved store evicts the oldest entries', () async {
      final store = PrefsContentStore();
      for (var i = 0; i < 85; i++) {
        await store.write('k$i', 'v$i');
      }
      expect(await store.read('k0'), isNull);
      expect(await store.read('k84'), 'v84');
    });
  });

  group('directory', () {
    testWidgets('search and filters reach the repository', (tester) async {
      await pumpApp(tester, AkhadaListScreen(repository: repo));
      expect(find.text('Juna 1 Akhada'), findsOneWidget);
      expect(find.text('Shaiva'), findsWidgets);

      await tester.enterText(find.byType(TextFormField), 'juna');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(repo.calls.last, 'akhadas:en:juna:::1');

      await tapText(tester, 'Vaishnava');
      expect(repo.calls.last, 'akhadas:en:juna:vaishnava::1');
      await tapText(tester, 'Varanasi');
      expect(repo.calls.last, 'akhadas:en:juna::Varanasi:1');
      await tapText(tester, 'All');
      expect(repo.calls.last, 'akhadas:en:juna:::1');
    });

    testWidgets('loads more pages', (tester) async {
      repo.pages = 2;
      await pumpApp(tester, AkhadaListScreen(repository: repo));
      await tapText(tester, 'Load more');
      expect(find.text('Juna 2 Akhada'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('error then retry', (tester) async {
      repo.fail = const AkhadaException(AkhadaFailure.offline);
      await pumpApp(tester, AkhadaListScreen(repository: repo));
      expect(find.textContaining('offline'), findsOneWidget);
      repo.fail = null;
      await tapText(tester, 'Try again');
      expect(find.text('Juna 1 Akhada'), findsOneWidget);
    });

    testWidgets('saved copies are labelled', (tester) async {
      repo.savedCopy = true;
      await pumpApp(tester, AkhadaListScreen(repository: repo));
      expect(find.textContaining('saved copy'), findsOneWidget);
    });

    testWidgets('saints filter by title and Akhada', (tester) async {
      await pumpApp(tester, SaintListScreen(repository: repo));
      expect(find.text('Swami Example'), findsOneWidget);
      expect(find.textContaining("doesn't mean endorsement"), findsOneWidget);
      await tapText(tester, 'Mahant');
      expect(
        repo.calls.last,
        'saints::'
        ':mahant',
      );
      await tapText(tester, 'Juna Akhada');
      expect(repo.calls.last, 'saints::juna:');
    });

    testWidgets('articles filter by category', (tester) async {
      await pumpApp(tester, AkhadaLearnScreen(repository: repo));
      await tapText(tester, 'Kumbh and Amrit Snan');
      expect(repo.calls.last, 'articles:kumbh');
    });
  });

  group('activities', () {
    testWidgets('every status is labelled, kept apart from fact', (
      tester,
    ) async {
      await pumpApp(tester, AkhadaActivitiesScreen(repository: repo));
      expect(find.textContaining('Nothing here is confirmed'), findsOneWidget);
      expect(find.text('Item confirmed'), findsOneWidget);
      expect(find.text('Officially confirmed'), findsWidgets);
      final chip = find.widgetWithText(ChoiceChip, 'Awaiting confirmation');
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await settle(tester);
      expect(repo.calls.last, 'activities:awaiting');
      expect(find.text('Item confirmed'), findsNothing);
      expect(find.text('Item awaiting'), findsOneWidget);
    });

    testWidgets('links through to the Akhada', (tester) async {
      await pumpApp(tester, AkhadaActivitiesScreen(repository: repo));
      await tapText(tester, 'Juna Akhada');
      expect(pushed.last, '/akhadaDetail');
    });
  });

  group('detail', () {
    testWidgets('Akhada shows sections, hides empty ones, cites sources', (
      tester,
    ) async {
      await pumpApp(tester, AkhadaDetailScreen(slug: 'juna', repository: repo));
      expect(find.text('Old history'), findsOneWidget);
      expect(find.text('Organization'), findsNothing, reason: 'empty section');
      expect(find.text('Last checked 30 Oct 2026'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Gazette'), 300);
      expect(find.text('Sources and references'), findsOneWidget);
    });

    testWidgets('related saint opens their profile', (tester) async {
      await pumpApp(tester, AkhadaDetailScreen(slug: 'juna', repository: repo));
      await tester.scrollUntilVisible(find.text('Swami Example'), 300);
      await tapText(tester, 'Swami Example');
      expect(pushed.last, '/saintDetail');
      expect(find.text('Life story'), findsOneWidget);
      expect(find.text('Teachings'), findsNothing);
    });

    testWidgets('English fallback is stated in other languages', (
      tester,
    ) async {
      await pumpApp(
        tester,
        AkhadaDetailScreen(slug: 'juna', repository: repo),
        locale: const Locale('hi'),
      );
      expect(repo.calls.first, 'akhada:juna:hi');
      expect(find.textContaining('अंग्रेज़ी'), findsOneWidget);
    });

    testWidgets('not found is an error, and retry reloads', (tester) async {
      repo.fail = const AkhadaException(AkhadaFailure.notFound);
      await pumpApp(tester, AkhadaDetailScreen(slug: 'x', repository: repo));
      expect(find.text("This page isn't available any more."), findsOneWidget);
      repo.fail = null;
      await tapText(tester, 'Try again');
      expect(find.text('Old history'), findsOneWidget);
    });

    testWidgets('representative images are labelled and credited', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: ContentBanner(
            image: ContentImage(
              'https://example.org/a.jpg',
              'A. Author, CC BY 4.0',
              representative: true,
            ),
          ),
        ),
      );
      expect(find.textContaining('Representative image'), findsOneWidget);
      expect(find.text('Image: A. Author, CC BY 4.0'), findsOneWidget);
    });

    testWidgets('article cards fit with an image at large text', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Scaffold(
          body: ListView(
            children: [
              ArticleCard(
                article:
                    ArticleSummary.fromJson({
                      ...articleJson(),
                      'image': {
                        'url': 'https://example.org/a.jpg',
                        'credit': 'A. Author',
                      },
                    })!,
              ),
            ],
          ),
        ),
        textScale: 1.6,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AspectRatio), findsOneWidget);
    });

    testWidgets('no image means no empty banner', (tester) async {
      await pumpApp(tester, const Scaffold(body: ContentBanner(image: null)));
      expect(find.byType(AspectRatio), findsNothing);
    });

    testWidgets('saint page says a profile is not an endorsement', (
      tester,
    ) async {
      await pumpApp(tester, SaintDetailScreen(slug: 'sant', repository: repo));
      await tester.scrollUntilVisible(
        find.textContaining('imply endorsement'),
        300,
      );
      expect(find.textContaining('imply endorsement'), findsOneWidget);
    });

    testWidgets('article shows paragraphs, editorial label and links', (
      tester,
    ) async {
      await pumpApp(
        tester,
        AkhadaArticleScreen(slug: 'what', repository: repo),
      );
      expect(find.text('Second paragraph.'), findsOneWidget);
      expect(find.textContaining('own guidance'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Juna Akhada'), 300);
      await tapText(tester, 'Juna Akhada');
      expect(pushed.last, '/akhadaDetail');
    });
  });

  group('entry points', () {
    testWidgets('landing page opens each section', (tester) async {
      await pumpApp(tester, const AkhadasHomeScreen());
      for (final title in const [
        'Akhada directory',
        'Saints and leaders',
        'Learn about traditions',
        'Nashik Kumbh activities',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      await tapText(tester, 'Akhada directory');
      expect(pushed.last, '/akhadaList');
    });

    testWidgets('dashboard panel makes no request', (tester) async {
      String? opened;
      await pumpApp(
        tester,
        Scaffold(body: AkhadaDashboardPanel(onOpen: (r) => opened = r)),
      );
      await tapText(tester, 'Saints and leaders');
      expect(opened, '/saints');
      expect(repo.calls, isEmpty);
    });
  });

  group('robustness', () {
    for (final locale in const [Locale('en'), Locale('hi'), Locale('mr')]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'no overflow: ${locale.languageCode}, ${brightness.name}, 1.6x, 320dp',
          (tester) async {
            for (final screen in <Widget>[
              const AkhadasHomeScreen(),
              AkhadaListScreen(repository: repo),
              SaintListScreen(repository: repo),
              AkhadaLearnScreen(repository: repo),
              AkhadaActivitiesScreen(repository: repo),
              AkhadaDetailScreen(slug: 'juna', repository: repo),
              SaintDetailScreen(slug: 'sant', repository: repo),
              AkhadaArticleScreen(slug: 'what', repository: repo),
            ]) {
              await pumpApp(
                tester,
                KeyedSubtree(key: UniqueKey(), child: screen),
                locale: locale,
                brightness: brightness,
                textScale: 1.6,
                size: const Size(320, 640),
              );
              expect(tester.takeException(), isNull, reason: '$screen');
            }
          },
        );
      }
    }
  });
}
