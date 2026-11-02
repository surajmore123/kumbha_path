import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/akhada/data/akhada_repository.dart';
import 'package:kumbha_path/src/modules/patrika/data/patrika_repository.dart';
import 'package:kumbha_path/src/modules/patrika/learn_screens.dart';
import 'package:kumbha_path/src/modules/patrika/models/patrika_models.dart';
import 'package:kumbha_path/src/modules/patrika/news_screens.dart';
import 'package:kumbha_path/src/modules/patrika/widgets/discover_panel.dart';
import 'package:kumbha_path/src/modules/patrika/widgets/patrika_parts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'patrika_fakes.dart';

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

late FakePatrikaRepository repo;
late List<String> pushed;
final shared = <String>[];

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
    final slug =
        settings.arguments is String ? settings.arguments as String : '';
    final Widget page = switch (settings.name) {
      '/newsArticle' => NewsArticleScreen(
        slug: slug,
        repository: repo,
        share: (text) async => shared.add(text),
      ),
      '/learnArticle' => LearnReaderScreen(
        slug: slug,
        repository: repo,
        share: (text) async => shared.add(text),
      ),
      '/newsSearch' => NewsSearchScreen(repository: repo),
      '/glossary' => GlossaryScreen(repository: repo),
      '/patrikaSaved' => const PatrikaSavedScreen(),
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
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Scrolls the page itself; screens also hold horizontal shelves.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump();
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
    repo = FakePatrikaRepository();
    PatrikaServices.repository = repo;
    PatrikaServices.bookmarks = PatrikaBookmarks();
    pushed = [];
    shared.clear();
  });

  group('models', () {
    test('a news outlet can never look official', () {
      final json = storyJson('x', official: true);
      expect(NewsStory.fromJson(json)!.isOfficial, isTrue);
      final spoofed = {
        ...json,
        'publisher': {'slug': 'p', 'name': 'Paper', 'publisher_type': 'news'},
      };
      expect(NewsStory.fromJson(spoofed)!.isOfficial, isFalse);
    });

    test('stories without a safe link or date are dropped', () {
      expect(
        NewsStory.fromJson({...storyJson('x'), 'original_url': 'http://x.org'}),
        isNull,
      );
      expect(
        NewsStory.fromJson({...storyJson('x'), 'published_at': 'soon'}),
        isNull,
      );
    });

    test('unknown block types are skipped, known ones parsed', () {
      expect(ArticleBlock.fromJson({'type': 'video'}), isNull);
      expect(
        ArticleBlock.fromJson({'type': 'callout', 'tone': 'warn', 'text': 'x'}),
        isA<CalloutBlock>().having((b) => b.warning, 'warning', isTrue),
      );
      expect(ArticleBlock.fromJson({'type': 'paragraph', 'text': ' '}), isNull);
    });
  });

  group('repository', () {
    setUpAll(
      () => dotenv.loadFromString(
        envString: 'API_PROTOCOL=https\nAPI_HOST=api.example.test',
      ),
    );

    test('sends no token, and falls back to a labelled saved copy', () async {
      var online = true;
      late http.BaseRequest seen;
      final store = MemoryStore();
      final r = HttpPatrikaRepository(
        store: store,
        client: MockClient((req) async {
          seen = req;
          if (!online) throw const SocketException('down');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'status': 'success',
                'data': {'lead': storyJson('lead')},
              }),
            ),
            200,
          );
        }),
      );
      await r.newsHome('hi');
      expect(seen.headers.containsKey('Authorization'), isFalse);
      expect(seen.url.path, '/api/news/home/');
      online = false;
      final saved = await r.newsHome('hi');
      expect(saved.isSavedCopy, isTrue);
      expect(saved.lead!.slug, 'lead');
    });

    test('filters reach the API, and searches are not saved', () async {
      late Uri seen;
      final store = MemoryStore();
      final r = HttpPatrikaRepository(
        store: store,
        client: MockClient((req) async {
          seen = req.url;
          return http.Response(
            jsonEncode({
              'data': {'results': <Object>[]},
            }),
            200,
          );
        }),
      );
      await r.news(
        language: 'en',
        query: 'road',
        publisher: 'sakal',
        dateFrom: DateTime(2026, 10, 1),
        relevant: true,
      );
      expect(seen.queryParameters, {
        'language': 'en',
        'q': 'road',
        'publisher': 'sakal',
        'date_from': '2026-10-01',
        'ordering': 'relevant',
      });
      expect(store.values, isEmpty);
    });
  });

  group('bookmarks', () {
    const item = SavedItem(kind: 'story', slug: 'a', title: 'Title');

    test('persist across sessions on the device', () async {
      await PatrikaServices.bookmarks.toggle(item);
      final again = PatrikaBookmarks();
      await again.load();
      expect(again.isSaved('story:a'), isTrue);
      await again.toggle(item);
      expect(again.items, isEmpty);
    });

    test('corrupt data is ignored', () async {
      SharedPreferences.setMockInitialValues({'patrika_saved': 'not json'});
      final b = PatrikaBookmarks();
      await b.load();
      expect(b.items, isEmpty);
    });
  });

  group('front page', () {
    testWidgets('leads with one story and varies the rest', (tester) async {
      await pumpApp(tester, KumbhNewsScreen(repository: repo));
      expect(find.text('Kumbh Patrika'), findsOneWidget);
      expect(find.byType(LeadStoryView), findsOneWidget);
      expect(find.text('Headline lead'), findsOneWidget);
      await scrollTo(tester, find.byType(FeatureStoryRow));
      expect(find.byType(FeatureStoryRow), findsWidgets);
      await scrollTo(tester, find.byType(CompactStoryRow));
      await scrollTo(tester, find.byType(TextStoryRow));
      expect(find.byType(TextStoryRow), findsOneWidget);
    });

    testWidgets('official notices are distinct, and only when real', (
      tester,
    ) async {
      await pumpApp(tester, KumbhNewsScreen(repository: repo));
      expect(find.byType(OfficialNoticePanel), findsOneWidget);
      expect(find.text('Official notice'), findsOneWidget);
      repo.withNotice = false;
      await pumpApp(
        tester,
        KumbhNewsScreen(key: UniqueKey(), repository: repo),
      );
      expect(find.byType(OfficialNoticePanel), findsNothing);
    });

    testWidgets('choosing a category reloads only the feed', (tester) async {
      await pumpApp(tester, KumbhNewsScreen(repository: repo));
      final homes = repo.calls.where((c) => c.startsWith('home')).length;
      final rail = find.descendant(
        of: find.byType(CategoryRail),
        matching: find.text('Important Dates'),
      );
      await scrollTo(tester, rail);
      await tester.ensureVisible(rail);
      await tester.pump();
      await tester.tap(rail);
      await settle(tester);
      expect(repo.calls.last, 'news::dates::false:1');
      expect(repo.calls.where((c) => c.startsWith('home')).length, homes);
    });

    testWidgets('older stories load on request', (tester) async {
      repo.hasNextPage = true;
      await pumpApp(tester, KumbhNewsScreen(repository: repo));
      await scrollTo(tester, find.text('Older stories'));
      await tapText(tester, 'Older stories');
      expect(repo.calls.last, 'news::::false:2');
    });

    testWidgets('empty says so plainly, with no invented content', (
      tester,
    ) async {
      repo.empty = true;
      await pumpApp(tester, KumbhNewsScreen(repository: repo));
      expect(find.text('No stories yet'), findsOneWidget);
      expect(find.byType(LeadStoryView), findsNothing);
    });

    testWidgets('errors can be retried', (tester) async {
      repo.fail = const AkhadaException(AkhadaFailure.offline);
      await pumpApp(tester, KumbhNewsScreen(repository: repo));
      expect(find.textContaining('offline'), findsOneWidget);
      repo.fail = null;
      await tapText(tester, 'Try again');
      expect(find.byType(LeadStoryView), findsOneWidget);
    });
  });

  group('story', () {
    testWidgets('credits the publisher, and links out', (tester) async {
      await pumpApp(tester, NewsArticleScreen(slug: 'one', repository: repo));
      expect(find.text('Headline one'), findsOneWidget);
      expect(find.text('What we know'), findsOneWidget);
      expect(find.text('Summary of one'), findsOneWidget);
      expect(find.textContaining('Illustrative.'), findsOneWidget);
      await scrollTo(tester, find.text('Read the full report'));
      expect(find.text('Originally reported by'), findsOneWidget);
      expect(find.textContaining('written by KumbhaPath'), findsOneWidget);
    });

    testWidgets('save and share', (tester) async {
      await pumpApp(
        tester,
        NewsArticleScreen(
          slug: 'one',
          repository: repo,
          share: (text) async => shared.add(text),
        ),
      );
      await tester.tap(find.byTooltip('Save'));
      await settle(tester);
      expect(PatrikaServices.bookmarks.isSaved('story:one'), isTrue);
      expect(find.byTooltip('Remove from saved'), findsOneWidget);
      await tester.tap(find.byTooltip('Share'));
      await settle(tester);
      expect(shared.single, contains('https://example.org/one'));
    });

    testWidgets('notices are labelled, and fallback language stated', (
      tester,
    ) async {
      repo.contentLanguage = 'en';
      await pumpApp(
        tester,
        NewsArticleScreen(slug: 'notice', repository: repo),
        locale: const Locale('hi'),
      );
      expect(find.text('आधिकारिक सूचना'), findsOneWidget);
      expect(find.textContaining('अंग्रेज़ी'), findsOneWidget);
    });

    testWidgets('a missing story can be retried', (tester) async {
      repo.fail = const AkhadaException(AkhadaFailure.notFound);
      await pumpApp(tester, NewsArticleScreen(slug: 'x', repository: repo));
      expect(find.text("This page isn't available any more."), findsOneWidget);
      repo.fail = null;
      await tapText(tester, 'Try again');
      expect(find.text('Headline x'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('searches after typing, with filters', (tester) async {
      await pumpApp(tester, NewsSearchScreen(repository: repo));
      expect(find.text('Search headlines, places and topics.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'road');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(repo.calls.last, 'news:road:::false:1');
      expect(find.text('Headline one'), findsOneWidget);
      await tapText(tester, 'Latest first');
      expect(repo.calls.last, 'news:road:::true:1');
      await tapText(tester, 'Sakal');
      expect(repo.calls.last, 'news:road::sakal:true:1');
    });
  });

  group('learn', () {
    testWidgets('each chapter has its own layout', (tester) async {
      await pumpApp(tester, LearnHomeScreen(repository: repo));
      expect(find.text('Gyan'), findsOneWidget);
      expect(find.text('Title cover'), findsOneWidget);
      await scrollTo(tester, find.text('Understanding Kumbh'));
      expect(find.text('१'), findsOneWidget);
      await scrollTo(tester, find.text('Pilgrim Guides'));
      expect(find.text('Dek of g1'), findsOneWidget);
      await scrollTo(tester, find.text('Places of Discovery'));
      expect(
        find.byWidgetPredicate((w) {
          return w is ClipPath && w.clipper is ArchClipper;
        }),
        findsOneWidget,
      );
      await scrollTo(tester, find.text('A word to know'));
      expect(find.text('Ghat'), findsOneWidget);
    });

    testWidgets('the reader shows every block and its links', (tester) async {
      await pumpApp(tester, LearnReaderScreen(slug: 'one', repository: repo));
      expect(find.text('Title one'), findsOneWidget);
      expect(find.text('3 min read  ·  Reviewed 30 Oct 2026'), findsOneWidget);
      for (final text in [
        'Opening paragraph.',
        'A heading',
        'First item',
        'A quotation',
        'Take care',
        'Good to know',
        'A caption',
        'Trimbakeshwar Mandir',
        'Juna Akhada',
        'UNESCO page',
      ]) {
        final finder = find.text(text);
        await scrollTo(tester, finder);
        expect(finder, findsOneWidget, reason: text);
      }
      expect(find.text('skipped'), findsNothing);
    });

    testWidgets('unverified pages say so', (tester) async {
      repo.verification = 'awaiting';
      await pumpApp(
        tester,
        LearnReaderScreen(slug: 'sita-gufa', repository: repo),
      );
      expect(find.textContaining('still confirming'), findsOneWidget);
    });

    testWidgets('temple links open Temple Explorer', (tester) async {
      await pumpApp(tester, LearnReaderScreen(slug: 'one', repository: repo));
      await scrollTo(tester, find.text('Trimbakeshwar Mandir'));
      await tapText(tester, 'Trimbakeshwar Mandir');
      expect(pushed.last, '/templeDetail');
    });

    testWidgets('glossary: search, then a term opens with links', (
      tester,
    ) async {
      await pumpApp(tester, GlossaryScreen(repository: repo));
      expect(find.text('Kund'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'gh');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(repo.calls.last, 'glossary:gh');
      await tapText(tester, 'Ghat');
      expect(find.text('Used for bathing and worship.'), findsOneWidget);
      expect(find.text('Title at-ramkund'), findsOneWidget);
    });
  });

  group('saved', () {
    testWidgets('empty, then listed', (tester) async {
      await pumpApp(tester, const PatrikaSavedScreen());
      expect(find.text('Nothing saved yet'), findsOneWidget);
      await PatrikaServices.bookmarks.toggle(
        const SavedItem(kind: 'story', slug: 'a', title: 'Kept story'),
      );
      await settle(tester);
      expect(find.text('Kept story'), findsOneWidget);
      await tapText(tester, 'Kept story');
      expect(pushed.last, '/newsArticle');
    });
  });

  group('discover panel', () {
    testWidgets('shows today\'s story and the three ways in', (tester) async {
      final opened = <String>[];
      await pumpApp(
        tester,
        Scaffold(
          body: DiscoverPanel(
            repository: repo,
            onOpen: (route, {arguments}) => opened.add(route),
          ),
        ),
      );
      await tapText(tester, 'Headline lead');
      await tapText(tester, 'Learn');
      expect(opened, ['/newsArticle', '/learn']);
    });

    testWidgets('links still work without a story', (tester) async {
      repo.fail = const AkhadaException(AkhadaFailure.offline);
      await pumpApp(
        tester,
        Scaffold(
          body: DiscoverPanel(
            repository: repo,
            onOpen: (route, {arguments}) {},
          ),
        ),
      );
      expect(find.text('News'), findsOneWidget);
      expect(find.text("Today's story"), findsNothing);
    });
  });

  group('shapes', () {
    test('the ghat edge steps down and stays inside its box', () {
      const size = Size(300, 200);
      final path = const GhatEdgeClipper().getClip(size);
      expect(path.getBounds().right, 300);
      expect(path.getBounds().bottom, 200);
      expect(path.contains(const Offset(10, 195)), isTrue);
      expect(path.contains(const Offset(295, 195)), isFalse);
    });

    test('the arch comes to a point', () {
      final path = const ArchClipper().getClip(const Size(150, 200));
      expect(path.contains(const Offset(75, 5)), isTrue);
      expect(path.contains(const Offset(5, 5)), isFalse);
    });

    testWidgets('editorial type follows the theme and language', (
      tester,
    ) async {
      late AppEditorial style;
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            style = context.editorial;
            return const SizedBox();
          },
        ),
        locale: const Locale('mr'),
        brightness: Brightness.dark,
      );
      expect(style.lead.fontFamily, 'TiroMarathi');
      expect(style.lead.color, AppTheme.dark.colorScheme.onSurface);
    });
  });

  group('robustness', () {
    for (final locale in const [Locale('en'), Locale('hi'), Locale('mr')]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'no overflow: ${locale.languageCode}, ${brightness.name}, 1.6x, 320dp',
          (tester) async {
            for (final screen in <Widget>[
              KumbhNewsScreen(repository: repo),
              NewsArticleScreen(slug: 'one', repository: repo),
              NewsSearchScreen(repository: repo),
              LearnHomeScreen(repository: repo),
              LearnReaderScreen(slug: 'one', repository: repo),
              GlossaryScreen(repository: repo),
              const PatrikaSavedScreen(),
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

    testWidgets('respects reduced motion', (tester) async {
      await pumpApp(
        tester,
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: NewsArticleScreen(slug: 'one', repository: repo),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
