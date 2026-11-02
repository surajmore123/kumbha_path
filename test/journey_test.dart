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
import 'package:kumbha_path/src/modules/journey/data/journey_repository.dart';
import 'package:kumbha_path/src/modules/journey/journey_detail_screen.dart';
import 'package:kumbha_path/src/modules/journey/journey_form_screen.dart';
import 'package:kumbha_path/src/modules/journey/journeys_screen.dart';
import 'package:kumbha_path/src/modules/journey/models/journey_models.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_dashboard_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'journey_fakes.dart';

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    return json.decode(await file.readAsString()) as Map<String, dynamic>;
  }
}

late FakeJourneyRepository repo;
late List<String> pushed;

/// Pumps [home] in a localized app whose journey routes are real screens
/// backed by [repo]. Other routes are recorded in [pushed].
Future<void> pumpJourney(
  WidgetTester tester,
  Widget home, {
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  Route<dynamic> route(RouteSettings settings) {
    pushed.add(settings.name ?? '');
    final Widget page = switch (settings.name) {
      '/journeyForm' => JourneyFormScreen(
        initial: settings.arguments as JourneyPlan?,
        repository: repo,
      ),
      '/journeyDetail' => JourneyDetailScreen(
        journeyId: settings.arguments! as String,
        repository: repo,
        share: (text, subject) async => shared.add(text),
      ),
      '/journeys' => JourneysScreen(repository: repo),
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

final shared = <String>[];

/// A host page with a button that pushes [route] and keeps the result.
class _Host extends StatefulWidget {
  const _Host(this.route, {this.arguments});

  final String route;
  final Object? arguments;

  @override
  State<_Host> createState() => _HostState();
}

Object? hostResult;

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async {
          hostResult = await Navigator.pushNamed(
            context,
            widget.route,
            arguments: widget.arguments,
          );
        },
        child: const Text('open'),
      ),
    ),
  );
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
    repo = FakeJourneyRepository();
    JourneyServices.repository = repo;
    pushed = [];
    shared.clear();
    hostResult = null;
  });

  group('models', () {
    test('plan JSON is parsed and unsafe or broken values are dropped', () {
      final plan =
          JourneyPlan.fromJson({
            'id': 'p1',
            'title': 'Trip',
            'status': 'planned',
            'arrival_date': '2027-08-01',
            'departure_date': '2027-08-03',
            'adults': 2,
            'children': 1,
            'seniors': 0,
            'interests': ['bathing', 7],
            'days': [
              {
                'day_number': 1,
                'items': [
                  {'id': 1, 'title': 'Arrive', 'source': 'suggested'},
                  {'id': 'x', 'title': 'broken id'},
                  {'id': 2, 'title': '  '},
                ],
              },
            ],
            'references': [
              {
                'id': 9,
                'kind': 'transport',
                'title': 'Train',
                'url': 'http://insecure.example',
              },
            ],
          })!;
      expect(plan.travellers, 3);
      expect(plan.interests, ['bathing']);
      expect(plan.days.single.items.map((i) => i.title), ['Arrive']);
      expect(plan.days.single.items.single.isSuggested, isTrue);
      expect(plan.references.single.url, isNull);
      expect(JourneyPlan.fromJson({'title': 'no id'}), isNull);
    });

    test('guide drops links that are not https', () {
      final guide = PlanningGuide.fromJson({
        ...sampleGuide(DateTime(2027, 8, 2)),
        'accommodation': {
          'disclaimer': 'x',
          'categories': <Object>[],
          'links': [
            {'title': 'Bad', 'url': 'javascript:alert(1)'},
            {'title': 'Good', 'url': 'https://www.maharashtratourism.gov.in/'},
          ],
        },
      });
      expect(guide.stayLinks.map((l) => l.title), ['Good']);
      expect(guide.dates.single.name, 'First Amrit Snan');
      expect(guide.transport.first.links.single.status, 'official');
    });
  });

  group('http repository', () {
    setUpAll(
      () => dotenv.loadFromString(
        envString: 'API_PROTOCOL=https\nAPI_HOST=api.example.test',
      ),
    );

    test('token goes in the Authorization header, never the URL', () async {
      late http.BaseRequest seen;
      final r = HttpJourneyRepository(
        token: () async => 'secret-token',
        client: MockClient((req) async {
          seen = req;
          return http.Response(
            jsonEncode({
              'status': 'success',
              'data': {
                'count': 0,
                'page': 1,
                'has_next': false,
                'results': <Object>[],
              },
            }),
            200,
          );
        }),
      );
      await r.list(status: 'planned');
      expect(seen.headers['Authorization'], 'Bearer secret-token');
      expect(seen.url.toString(), isNot(contains('secret-token')));
      expect(seen.url.path, '/api/journeys/');
      expect(seen.url.queryParameters['status'], 'planned');
    });

    test('backend errors map to failure kinds with field messages', () async {
      Future<JourneyException> failWith(int code, Object body) async {
        final r = HttpJourneyRepository(
          token: () async => 't',
          client: MockClient(
            (_) async => http.Response(jsonEncode(body), code),
          ),
        );
        try {
          await r.create({'title': ''});
        } on JourneyException catch (e) {
          return e;
        }
        fail('expected a JourneyException');
      }

      final invalid = await failWith(400, {
        'status': 'error',
        'errors': {
          'title': ['Give the journey a name.'],
        },
      });
      expect(invalid.kind, JourneyFailure.invalid);
      expect(invalid.fieldErrors['title'], 'Give the journey a name.');
      expect((await failWith(401, {})).kind, JourneyFailure.unauthorized);
      expect((await failWith(404, {})).kind, JourneyFailure.notFound);
      expect((await failWith(500, {})).kind, JourneyFailure.server);
    });

    test('offline and signed-out requests fail without guessing', () async {
      var requests = 0;
      final offline = HttpJourneyRepository(
        token: () async => 't',
        client: MockClient((_) async => throw const SocketException('down')),
      );
      await expectLater(
        offline.get('p1'),
        throwsA(
          isA<JourneyException>().having(
            (e) => e.kind,
            'kind',
            JourneyFailure.offline,
          ),
        ),
      );
      final signedOut = HttpJourneyRepository(
        token: () async => null,
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        signedOut.get('p1'),
        throwsA(
          isA<JourneyException>().having(
            (e) => e.kind,
            'kind',
            JourneyFailure.unauthorized,
          ),
        ),
      );
      expect(requests, 0);
    });

    test('DELETE with 204 succeeds', () async {
      final r = HttpJourneyRepository(
        token: () async => 't',
        client: MockClient((req) async {
          expect(req.method, 'DELETE');
          return http.Response('', 204);
        }),
      );
      await r.delete('p1');
    });
  });

  group('form', () {
    testWidgets('validates each step and creates a plan with an itinerary', (
      tester,
    ) async {
      await pumpJourney(tester, const _Host('/journeyForm'));
      await tapText(tester, 'open');
      expect(find.text('Step 1 of 4'), findsOneWidget);

      await tapText(tester, 'Next');
      expect(find.text('Give the journey a name.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Our Kumbh');
      await tapText(tester, 'Next');

      // Dates: required unless undecided.
      expect(find.text('Step 2 of 4'), findsOneWidget);
      await tapText(tester, 'Next');
      expect(
        find.text('Choose both arrival and departure dates.'),
        findsOneWidget,
      );
      await tapText(tester, "I haven't fixed dates yet");
      await tester.tap(find.byTooltip('More Number of days'));
      await tester.pump();
      await tapText(tester, 'Next');

      expect(find.text('Step 3 of 4'), findsOneWidget);
      expect(find.byTooltip('Fewer Adults'), findsOneWidget);
      final fewerAdults = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byTooltip('Fewer Adults'),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(fewerAdults.onPressed, isNull, reason: 'at least one adult');
      await tester.tap(find.byTooltip('More Seniors'));
      await tester.pump();
      await tapText(tester, 'Next');

      expect(find.text('Step 4 of 4'), findsOneWidget);
      await tapText(tester, 'Train');
      await tapText(tester, 'Sacred bath');
      await tapText(tester, 'Create my plan');

      expect(repo.calls, contains('create:generate'));
      final body = repo.sent.last;
      expect(body['title'], 'Our Kumbh');
      expect(body['arrival_date'], isNull);
      expect(body['duration_days'], 4);
      expect(body['seniors'], 1);
      expect(body['transport_mode'], 'train');
      expect(body['interests'], ['bathing']);
      expect(body['language'], 'en');
      expect(
        body.containsKey('user'),
        isFalse,
        reason: 'owner comes from the token',
      );
      expect(hostResult, isA<JourneyPlan>());
      expect((hostResult! as JourneyPlan).hasItinerary, isTrue);
    });

    testWidgets('save draft needs only a name and skips the itinerary', (
      tester,
    ) async {
      await pumpJourney(tester, const _Host('/journeyForm'));
      await tapText(tester, 'open');
      await tester.enterText(find.byType(TextFormField).first, 'Someday');
      await tapText(tester, 'Save draft');
      expect(repo.calls.last, 'create');
      expect(repo.sent.last['arrival_date'], isNull);
      expect((hostResult! as JourneyPlan).status, JourneyStatus.draft);
    });

    testWidgets('server validation is shown on the step it belongs to', (
      tester,
    ) async {
      repo.failNext = const JourneyException(
        JourneyFailure.invalid,
        fieldErrors: {'title': 'Name already used.'},
      );
      await pumpJourney(tester, const _Host('/journeyForm'));
      await tapText(tester, 'open');
      await tester.enterText(find.byType(TextFormField).first, 'Trip');
      await tapText(tester, 'Save draft');
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('Name already used.'), findsWidgets);
      expect(hostResult, isNull);
    });

    testWidgets('edit is prefilled and saves changes', (tester) async {
      final id = repo.seed(title: 'Old name');
      final plan = await repo.get(id);
      await pumpJourney(tester, _Host('/journeyForm', arguments: plan));
      await tapText(tester, 'open');
      expect(find.text('Edit journey'), findsOneWidget);
      expect(find.text('Old name'), findsOneWidget);
      expect(find.text('Save draft'), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, 'New name');
      for (var i = 0; i < 3; i++) {
        await tapText(tester, 'Next');
      }
      await tapText(tester, 'Save changes');
      expect(repo.calls, contains('update'));
      expect(repo.plans[id]!['title'], 'New name');
      expect(hostResult, isA<JourneyPlan>());
    });

    testWidgets('editing a trip already under way keeps its arrival', (
      tester,
    ) async {
      final id = repo.seed(arrival: DateTime(2027, 7, 30));
      final plan = await repo.get(id);
      await pumpJourney(
        tester,
        JourneyFormScreen(
          initial: plan,
          repository: repo,
          today: DateTime(2027, 8, 1),
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, 'Renamed');
      for (var i = 0; i < 3; i++) {
        await tapText(tester, 'Next');
      }
      expect(find.byKey(const ValueKey('journey_form_error')), findsNothing);
      await tapText(tester, 'Save changes');
      expect(repo.sent.last['arrival_date'], '2027-07-30');
    });
  });

  group('list', () {
    testWidgets('shows plans by status with empty states and load more', (
      tester,
    ) async {
      repo.pageSize = 2;
      for (var i = 0; i < 3; i++) {
        repo.seed(title: 'Trip $i');
      }
      await pumpJourney(tester, JourneysScreen(repository: repo));
      expect(find.text('Trip 0'), findsOneWidget);
      expect(find.text('Trip 2'), findsNothing);
      await tapText(tester, 'Load more');
      expect(find.text('Trip 2'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
      expect(find.text('4 travellers'), findsWidgets);

      await tapText(tester, 'Drafts');
      expect(find.text('No drafts'), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (tester) async {
      repo.failNext = const JourneyException(JourneyFailure.offline);
      repo.seed(title: 'Trip A');
      await pumpJourney(tester, JourneysScreen(repository: repo));
      // The first tab's request failed; the others loaded.
      expect(find.textContaining('offline'), findsOneWidget);
      await tapText(tester, 'Try again');
      expect(find.text('Trip A'), findsOneWidget);
    });

    testWidgets('opening a plan goes to its detail', (tester) async {
      repo.seed(title: 'Trip A');
      await pumpJourney(tester, JourneysScreen(repository: repo));
      await tapText(tester, 'Trip A');
      expect(pushed, contains('/journeyDetail'));
      expect(find.text('Itinerary'), findsOneWidget);
    });
  });

  group('detail', () {
    Future<String> open(
      WidgetTester tester, {
      bool itinerary = true,
      String? budget = '20000',
    }) async {
      final id = repo.seed(
        title: 'Trip A',
        itinerary: itinerary,
        budget: budget,
      );
      await pumpJourney(
        tester,
        JourneyDetailScreen(
          journeyId: id,
          repository: repo,
          share: (text, subject) async => shared.add(text),
        ),
      );
      return id;
    }

    testWidgets('itinerary shows days; ticking and reordering are saved', (
      tester,
    ) async {
      final id = await open(tester);
      expect(find.text('Day 1 · ${_day(repo, id, 1)}'), findsOneWidget);
      expect(find.text('Reach Nashik and check in'), findsOneWidget);
      expect(find.textContaining('Suggestions only'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).first);
      await settle(tester);
      expect(repo.sent.last, {'is_done': true});

      await tester.tap(find.byTooltip('Activity options').first);
      await settle(tester);
      await tapText(tester, 'Move down');
      expect(repo.calls.any((c) => c.startsWith('reorder:')), isTrue);
    });

    testWidgets('add an activity to a day', (tester) async {
      final id = await open(tester);
      await tapText(tester, 'Add activity');
      await tester.enterText(find.byType(TextFormField).first, 'Meet cousins');
      await tapText(tester, 'Save');
      expect(repo.calls, contains('addItem'));
      expect(find.text('Meet cousins'), findsOneWidget);
      expect(find.textContaining('Added by you'), findsOneWidget);
      expect(repo.plans[id], isNotNull);
    });

    testWidgets('no itinerary: create one from the empty state', (
      tester,
    ) async {
      await open(tester, itinerary: false);
      expect(find.text('No itinerary yet'), findsOneWidget);
      await tapText(tester, 'Create itinerary');
      expect(repo.calls, contains('generate:en'));
      expect(find.text('Reach Nashik and check in'), findsOneWidget);
    });

    testWidgets('regenerate asks first and explains what is kept', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byTooltip('More actions'));
      await settle(tester);
      await tapText(tester, 'Update suggestions');
      expect(find.textContaining('are kept'), findsOneWidget);
      await tapText(tester, 'Cancel');
      expect(repo.calls.where((c) => c.startsWith('generate')), isEmpty);
    });

    testWidgets('delete asks for confirmation', (tester) async {
      final id = await open(tester);
      await tester.tap(find.byTooltip('More actions'));
      await settle(tester);
      await tapText(tester, 'Delete');
      expect(find.text('Delete this journey?'), findsOneWidget);
      await tapText(tester, 'Delete');
      expect(repo.plans.containsKey(id), isFalse);
    });

    testWidgets('share sends the exported text', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('Share itinerary'));
      await settle(tester);
      expect(shared.single, contains('Trip A'));
    });

    testWidgets('mark completed', (tester) async {
      final id = await open(tester);
      await tester.tap(find.byTooltip('More actions'));
      await settle(tester);
      await tapText(tester, 'Mark as completed');
      expect(repo.plans[id]!['status'], 'completed');
      expect(find.text('Completed'), findsWidgets);
    });

    testWidgets('checklist: tick and add', (tester) async {
      await open(tester);
      await tapText(tester, 'Checklist');
      expect(find.text('Checklist: 0 of 2 done'), findsOneWidget);
      await tester.tap(find.text('Basic medicines'));
      await settle(tester);
      expect(find.text('Checklist: 1 of 2 done'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Shawl');
      await tapText(tester, 'Add');
      expect(find.text('Shawl'), findsOneWidget);
    });

    testWidgets(
      'travel & stay: official links, no booking claims, own details',
      (tester) async {
        await open(tester);
        await tapText(tester, 'Travel & stay');
        expect(find.text('NTES train enquiry'), findsOneWidget);
        expect(find.text('Your choice'), findsOneWidget);
        expect(find.textContaining("doesn't make bookings"), findsOneWidget);
        await tapText(tester, 'Add booking details');
        expect(find.textContaining("this isn't a booking"), findsOneWidget);
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Train to Nashik Road');
        await tester.enterText(fields.at(2), 'PNR123');
        await tester.enterText(fields.at(3), 'http://not-secure.example');
        await tapText(tester, 'Save');
        expect(find.text('Use a link starting with https://'), findsOneWidget);
        await tester.enterText(fields.at(3), '');
        await tapText(tester, 'Save');
        expect(repo.calls, contains('addReference'));
        expect(find.text('Train to Nashik Road'), findsOneWidget);
        expect(find.text('Ref: PNR123'), findsOneWidget);
      },
    );

    testWidgets('budget: split of the user budget, or a prompt', (
      tester,
    ) async {
      await open(tester);
      await tapText(tester, 'Budget');
      expect(find.text('₹ 20,000'), findsOneWidget);
      expect(find.text('₹ 7,000'), findsOneWidget); // travel 35%
      expect(find.textContaining('not a price estimate'), findsOneWidget);
    });

    testWidgets('budget missing shows a prompt', (tester) async {
      await open(tester, budget: null);
      await tapText(tester, 'Budget');
      expect(find.text('No budget added'), findsOneWidget);
    });

    testWidgets('info: dates in the trip are marked, with sources', (
      tester,
    ) async {
      await open(tester);
      await tapText(tester, 'Info');
      expect(find.text('First Amrit Snan'), findsOneWidget);
      expect(find.textContaining('During your trip'), findsOneWidget);
      expect(find.text('Emergency'), findsOneWidget);
      expect(find.textContaining('checked on 2026-10-29'), findsOneWidget);
    });

    testWidgets('not found shows an error', (tester) async {
      await pumpJourney(
        tester,
        JourneyDetailScreen(journeyId: 'missing', repository: repo),
      );
      expect(
        find.text("This journey isn't available any more."),
        findsOneWidget,
      );
    });
  });

  group('dashboard panel', () {
    testWidgets('invites planning when there is no journey', (tester) async {
      var created = 0;
      await pumpJourney(
        tester,
        Scaffold(
          body: JourneyDashboardPanel(
            repository: repo,
            onOpenList: () {},
            onOpen: (_) {},
            onCreate: () => created++,
          ),
        ),
      );
      expect(find.text('Plan Your Kumbh Journey'), findsOneWidget);
      await tapText(tester, 'Plan My Journey');
      expect(created, 1);
    });

    testWidgets('shows the next planned journey', (tester) async {
      repo.seed(
        title: 'Past',
        arrival: DateTime.now().subtract(const Duration(days: 20)),
      );
      repo.seed(title: 'Next one');
      String? opened;
      await pumpJourney(
        tester,
        Scaffold(
          body: JourneyDashboardPanel(
            repository: repo,
            onOpenList: () {},
            onOpen: (id) => opened = id,
            onCreate: () {},
          ),
        ),
      );
      expect(find.text('Past'), findsNothing);
      await tapText(tester, 'Next one');
      expect(opened, isNotNull);
    });

    testWidgets('errors fall back to the invitation', (tester) async {
      repo.failNext = const JourneyException(JourneyFailure.offline);
      await pumpJourney(
        tester,
        Scaffold(
          body: JourneyDashboardPanel(
            repository: repo,
            onOpenList: () {},
            onOpen: (_) {},
            onCreate: () {},
          ),
        ),
      );
      expect(find.text('Plan My Journey'), findsOneWidget);
    });
  });

  group('robustness', () {
    for (final locale in const [Locale('en'), Locale('hi'), Locale('mr')]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'no overflow: ${locale.languageCode}, ${brightness.name}, 1.6x text, 320dp',
          (tester) async {
            final id = repo.seed(
              title: 'एक बहुत लंबा यात्रा नाम जो कई पंक्तियों में जाएगा',
            );
            await pumpJourney(
              tester,
              JourneyDetailScreen(journeyId: id, repository: repo),
              locale: locale,
              brightness: brightness,
              textScale: 1.6,
              size: const Size(320, 640),
            );
            expect(tester.takeException(), isNull);
            for (final tab
                in tester.widgetList<Tab>(find.byType(Tab)).toList()) {
              await tester.tap(find.text(tab.text!));
              await settle(tester);
              expect(tester.takeException(), isNull, reason: tab.text);
            }
          },
        );

        testWidgets(
          'form steps fit: ${locale.languageCode}, ${brightness.name}, 1.6x text, 320dp',
          (tester) async {
            await pumpJourney(
              tester,
              JourneyFormScreen(repository: repo),
              locale: locale,
              brightness: brightness,
              textScale: 1.6,
              size: const Size(320, 640),
            );
            await tester.enterText(find.byType(TextFormField).first, 'Trip');
            final next = find.byType(AppButton).last;
            await tester.tap(next);
            await settle(tester);
            await tester.tap(find.byType(Switch).first); // dates undecided
            await settle(tester);
            for (var step = 2; step <= 4; step++) {
              expect(tester.takeException(), isNull, reason: 'step $step');
              if (step < 4) {
                await tester.tap(next);
                await settle(tester);
              }
            }
            expect(find.byType(ChoiceChip), findsWidgets);
            expect(tester.takeException(), isNull);
          },
        );

        testWidgets(
          'list fits: ${locale.languageCode}, ${brightness.name}, 1.6x text, 320dp',
          (tester) async {
            repo.seed(title: 'Trip with a fairly long name for the card');
            await pumpJourney(
              tester,
              JourneysScreen(repository: repo),
              locale: locale,
              brightness: brightness,
              textScale: 1.6,
              size: const Size(320, 640),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}

String _day(FakeJourneyRepository repo, String id, int n) {
  final date = DateTime.parse(
    (repo.plans[id]!['days'] as List)[n - 1]['date'] as String,
  );
  return DateFormat('EEE, d MMM', 'en').format(date);
}
