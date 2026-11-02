import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/akhada/data/akhada_repository.dart'
    show ContentStore;
import 'package:kumbha_path/src/modules/akhada/models/akhada_models.dart';
import 'package:kumbha_path/src/modules/booking/booking_home_screen.dart';
import 'package:kumbha_path/src/modules/booking/data/booking_repository.dart';
import 'package:kumbha_path/src/modules/booking/models/booking_models.dart';
import 'package:kumbha_path/src/modules/booking/my_bookings_screens.dart';
import 'package:kumbha_path/src/modules/booking/stay_screens.dart';
import 'package:kumbha_path/src/modules/booking/transport_screen.dart';
import 'package:kumbha_path/src/modules/booking/widgets/booking_parts.dart';
import 'package:kumbha_path/src/modules/journey/data/journey_repository.dart'
    show JourneyServices;
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

class MemoryStore implements ContentStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

const _areaImage = {
  'url': 'https://example.org/a.jpg',
  'credit': 'A. Author',
  'representative': true,
};

Map<String, dynamic> stayJson({
  String id = 's1',
  int? price = 1333,
  String status = 'verified',
  String verification = 'verified',
}) => {
  'id': id,
  'name': 'Shivprasad Bhaktniwas',
  'stay_type': 'dharamshala',
  'area': {'slug': 'trimbakeshwar', 'name': 'Trimbakeshwar'},
  'amenities': [
    {'slug': 'ac', 'name': 'Air conditioning'},
  ],
  'image': _areaImage,
  'price_from': price,
  'price_unit': 'room per day',
  'price_status': status,
  'verification_status': verification,
  'last_verified_on': '2026-10-30',
  'distance_km': 1.5,
};

Map<String, dynamic> providerJson(
  String slug,
  String mode, {
  bool book = true,
}) => {
  'slug': slug,
  'mode': mode,
  'name': slug.toUpperCase(),
  'url': 'https://example.org/$slug',
  'is_official': true,
  'can_book': book,
  'note': 'Note for $slug',
};

class FakeBookings implements BookingRepository {
  final calls = <String>[];
  final sent = <Map<String, dynamic>>[];
  final bookings = <SavedBooking>[];
  JourneyException? fail;
  JourneyException? failSave;
  bool emptyStays = false;
  bool live = false;
  int _ids = 0;

  void _record(String call) {
    calls.add(call);
    final f = fail;
    if (f != null) throw f;
  }

  @override
  Future<StayFilters> stayFilters(String language) async {
    _record('filters');
    return StayFilters.fromJson({
      'areas': [
        {'slug': 'trimbakeshwar', 'name': 'Trimbakeshwar', 'image': _areaImage},
        {'slug': 'ramkund', 'name': 'Ramkund'},
      ],
      'amenities': [
        {'slug': 'parking', 'name': 'Parking'},
      ],
    });
  }

  @override
  Future<ContentPage<StaySummary>> stays(
    StaySearch search, {
    required String language,
    int page = 1,
  }) async {
    _record('stays:${jsonEncode(search.toQuery())}');
    return ContentPage(
      items: emptyStays ? [] : [StaySummary.fromJson(stayJson())!],
    );
  }

  @override
  Future<Fetched<StayDetail>> stay(String id, String language) async {
    _record('stay:$id');
    return Fetched(
      StayDetail.fromJson({
        ...stayJson(id: id),
        'address': 'Mahadevi Road',
        'phone': '02594-234251',
        'booking_url': 'https://trimbakeshwartrust.com/bhaktniwas',
        'latitude': 19.93,
        'longitude': 73.53,
        'rooms': [
          {'name': 'AC 2-bed room', 'price': 1714},
        ],
        'landmarks': [
          {'name': 'Ramkund', 'distance_km': 28.0},
        ],
        'temples': [
          {'id': 't1', 'name': 'Trimbakeshwar Mandir', 'distance_km': 0.5},
        ],
        'sources': [
          {'title': 'Trust page', 'url': 'https://trimbakeshwartrust.com/x'},
        ],
        'text': {
          'overview': 'Rooms run by the Trust.',
          'booking_instructions': 'Sign in with Google.',
          'cancellation_policy': 'Non-refundable.',
          'price_note': 'Ordinary published rates.',
          'content_language': 'en',
        },
      })!,
    );
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
    _record('transport:$from:$to:$mode:$passengers');
    return TransportSearchResult.fromJson({
      'live': live,
      'results': [
        if (live) {'provider': 'Live Rail', 'departs': '06:15', 'price': 240},
      ],
      'providers': [
        providerJson('$mode-one', mode ?? 'train'),
        providerJson('$mode-two', mode ?? 'train', book: false),
      ],
    });
  }

  @override
  Future<ContentPage<SavedBooking>> saved({String? when, int page = 1}) async {
    _record('saved:$when');
    final upcoming = when == 'upcoming';
    return ContentPage(
      items:
          bookings
              .where(
                (b) =>
                    upcoming ==
                    (b.status != BookingStatus.completed &&
                        b.status != BookingStatus.cancelled),
              )
              .toList(),
    );
  }

  SavedBooking _from(Map<String, dynamic> data, String id) =>
      SavedBooking.fromJson({...data, 'id': id})!;

  @override
  Future<SavedBooking> savedOne(String id) async {
    _record('one:$id');
    return bookings.firstWhere(
      (b) => b.id == id,
      orElse: () => throw const JourneyException(JourneyFailure.notFound),
    );
  }

  @override
  Future<SavedBooking> create(Map<String, dynamic> data) async {
    _record('create');
    sent.add(data);
    final f = failSave;
    if (f != null) throw f;
    final b = _from(data, 'b${++_ids}');
    bookings.add(b);
    return b;
  }

  @override
  Future<SavedBooking> update(String id, Map<String, dynamic> data) async {
    _record('update');
    sent.add(data);
    final b = _from(data, id);
    bookings[bookings.indexWhere((x) => x.id == id)] = b;
    return b;
  }

  @override
  Future<void> delete(String id) async {
    _record('delete');
    bookings.removeWhere((b) => b.id == id);
  }
}

late FakeBookings repo;
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
    final args = settings.arguments;
    final Widget page = switch (settings.name) {
      '/stays' => StayResultsScreen(
        search: args as StaySearch?,
        repository: repo,
      ),
      '/stayDetail' => StayDetailScreen(id: args! as String, repository: repo),
      '/bookingForm' => BookingFormScreen(
        draft: args is BookingDraft ? args : null,
        existing: args is SavedBooking ? args : null,
        repository: repo,
      ),
      '/bookingDetail' => BookingDetailScreen(
        id: args! as String,
        repository: repo,
      ),
      '/myBookings' => MyBookingsScreen(repository: repo),
      '/transport' => TransportScreen(repository: repo),
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

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await scrollTo(tester, find.text(text));
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = FakeBookings();
    BookingServices.repository = repo;
    JourneyServices.repository = FakeJourneyRepository();
    pushed = [];
  });

  group('models', () {
    test('a missing or on-request price never shows as a price', () {
      final none = StaySummary.fromJson(stayJson(price: 0))!;
      expect(none.priceFrom, isNull);
      final ask = StaySummary.fromJson(stayJson(status: 'on_request'))!;
      expect(ask.priceStatus, PriceStatus.onRequest);
    });

    test('unsafe links are dropped', () {
      final d =
          StayDetail.fromJson({
            ...stayJson(),
            'booking_url': 'http://not-secure.example',
          })!;
      expect(d.bookingUrl, isNull);
      expect(
        TransportProvider.fromJson({
          ...providerJson('x', 'bus'),
          'url': 'ftp://x',
        }),
        isNull,
      );
      final b =
          SavedBooking.fromJson({
            'id': '1',
            'category': 'bus',
            'title': 'x',
            'booking_url': 'javascript:alert(1)',
          })!;
      expect(b.bookingUrl, isNull);
    });

    test('search only sends what is set', () {
      final s = StaySearch(area: 'ramkund', family: true, maxPrice: 900);
      expect(s.toQuery(), {
        'area': 'ramkund',
        'near': 'ramkund',
        'max_price': '900',
        'family': 'true',
        'sort': 'recommended',
      });
      expect(s.activeFilters, 2);
    });

    test('ticket shape cuts notches at the perforation', () {
      final path = const TicketShape(
        stubHeight: 40,
      ).getOuterPath(const Rect.fromLTWH(0, 0, 300, 200));
      expect(path.contains(const Offset(2, 160)), isFalse);
      expect(path.contains(const Offset(2, 100)), isTrue);
    });
  });

  group('repository', () {
    setUpAll(
      () => dotenv.loadFromString(
        envString: 'API_PROTOCOL=https\nAPI_HOST=api.example.test',
      ),
    );

    test('saved bookings use the header, public data sends no token', () async {
      final seen = <http.BaseRequest>[];
      final r = HttpBookingRepository(
        token: () async => 'secret',
        store: MemoryStore(),
        client: MockClient((req) async {
          seen.add(req);
          return http.Response(
            jsonEncode({
              'data': {'results': <Object>[], 'areas': <Object>[]},
            }),
            200,
          );
        }),
      );
      await r.saved();
      await r.stayFilters('en');
      expect(seen[0].headers['Authorization'], 'Bearer secret');
      expect(seen[0].url.toString(), isNot(contains('secret')));
      expect(seen[1].headers.containsKey('Authorization'), isFalse);
    });

    test('amenities repeat, and stays fall back to a saved copy', () async {
      var online = true;
      late Uri seen;
      final r = HttpBookingRepository(
        token: () async => null,
        store: MemoryStore(),
        client: MockClient((req) async {
          seen = req.url;
          if (!online) throw const SocketException('down');
          return http.Response(
            jsonEncode({
              'data': {
                'results': [stayJson()],
              },
            }),
            200,
          );
        }),
      );
      final search = StaySearch(amenities: {'ac', 'food'});
      await r.stays(search, language: 'en');
      expect(seen.queryParametersAll['amenity'], ['ac', 'food']);
      online = false;
      final saved = await r.stays(search, language: 'en');
      expect(saved.isSavedCopy, isTrue);
      expect(saved.items.single.name, 'Shivprasad Bhaktniwas');
    });

    test('bookings aren\'t written to the device, and need sign-in', () async {
      final store = MemoryStore();
      final r = HttpBookingRepository(
        token: () async => null,
        store: store,
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      await expectLater(
        r.saved(),
        throwsA(
          isA<JourneyException>().having(
            (e) => e.kind,
            'kind',
            JourneyFailure.unauthorized,
          ),
        ),
      );
      expect(store.values, isEmpty);
    });

    test('field errors reach the form', () async {
      final r = HttpBookingRepository(
        token: () async => 't',
        store: MemoryStore(),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status': 'error',
              'errors': {
                'reference': ['This looks like a card number.'],
              },
            }),
            400,
          ),
        ),
      );
      await expectLater(
        r.create({}),
        throwsA(
          isA<JourneyException>().having(
            (e) => e.fieldErrors['reference'],
            'field',
            contains('card number'),
          ),
        ),
      );
    });
  });

  group('home', () {
    testWidgets('search leads to results, with journey dates offered', (
      tester,
    ) async {
      await pumpApp(
        tester,
        BookingHomeScreen(
          repository: repo,
          prefill: JourneyPrefill(
            title: 'Family trip',
            arrival: DateTime(2027, 8, 1),
            departure: DateTime(2027, 8, 3),
            travellers: 4,
          ),
        ),
      );
      expect(find.text('Stay & Travel'), findsOneWidget);
      expect(find.textContaining('Family trip'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      await tapText(tester, 'Find a stay');
      expect(pushed.last, '/stays');
    });

    testWidgets('switches to transport', (tester) async {
      await pumpApp(tester, BookingHomeScreen(repository: repo));
      await tapText(tester, 'Transport');
      expect(find.text('Taxi and cab'), findsOneWidget);
      await tapText(tester, 'Bus');
      expect(pushed.last, '/transport');
    });

    testWidgets('warns about payment before anything else is sold', (
      tester,
    ) async {
      await pumpApp(tester, BookingHomeScreen(repository: repo));
      await scrollTo(tester, find.text('Before you pay'));
      expect(
        find.textContaining('No official pilgrim booking'),
        findsOneWidget,
      );
    });
  });

  group('stays', () {
    testWidgets('shows trust, price kind and a labelled area photo', (
      tester,
    ) async {
      await pumpApp(tester, StayResultsScreen(repository: repo));
      expect(find.text('Shivprasad Bhaktniwas'), findsOneWidget);
      expect(find.textContaining('Verified'), findsOneWidget);
      expect(find.text('Area photo'), findsOneWidget);
      await scrollTo(tester, find.text('Published rate from'));
      expect(find.text('₹1,333'), findsOneWidget);
    });

    testWidgets('filters reach the search', (tester) async {
      await pumpApp(tester, StayResultsScreen(repository: repo));
      await tapText(tester, 'Filters');
      await tester.enterText(find.byType(TextFormField).at(1), '2000');
      await tester.tap(find.widgetWithText(FilterChip, 'Parking'));
      await settle(tester);
      await tapText(tester, 'Show stays');
      final call = repo.calls.lastWhere((c) => c.startsWith('stays:'));
      expect(call, contains('"max_price":"2000"'));
      expect(call, contains('"amenity":["parking"]'));
      expect(find.text('Filters (2)'), findsOneWidget);
    });

    testWidgets('empty and error states', (tester) async {
      repo.emptyStays = true;
      await pumpApp(tester, StayResultsScreen(repository: repo));
      expect(find.text('No stays match yet'), findsOneWidget);
      repo.fail = const JourneyException(JourneyFailure.offline);
      await pumpApp(
        tester,
        StayResultsScreen(key: UniqueKey(), repository: repo),
      );
      expect(find.textContaining('offline'), findsOneWidget);
      repo.fail = null;
      repo.emptyStays = false;
      await tapText(tester, 'Try again');
      expect(find.text('Shivprasad Bhaktniwas'), findsOneWidget);
    });

    testWidgets('detail shows facts, and external action is clear', (
      tester,
    ) async {
      await pumpApp(tester, StayDetailScreen(id: 's1', repository: repo));
      expect(find.text("Book on the provider's site"), findsOneWidget);
      expect(find.textContaining('not this property'), findsOneWidget);
      for (final text in [
        'AC 2-bed room',
        'Sign in with Google.',
        'Non-refundable.',
        '28.0 km',
        'Trust page',
      ]) {
        await scrollTo(tester, find.text(text));
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets('saving from a stay pre-fills the form', (tester) async {
      await pumpApp(tester, StayDetailScreen(id: 's1', repository: repo));
      await tester.tap(find.text('Already booked? Save it here'));
      await settle(tester);
      expect(pushed.last, '/bookingForm');
      expect(find.text('Shivprasad Bhaktniwas'), findsWidgets);
    });
  });

  group('transport', () {
    testWidgets('never invents results, and points to providers', (
      tester,
    ) async {
      await pumpApp(tester, TransportScreen(repository: repo));
      expect(
        find.textContaining("aren't available in KumbhaPath"),
        findsOneWidget,
      );
      await scrollTo(tester, find.text('train-one'.toUpperCase()));
      expect(find.text('Book with TRAIN-ONE'), findsOneWidget);
      expect(find.text('Open TRAIN-TWO'), findsOneWidget);
    });

    testWidgets('shows real results only when a provider returns them', (
      tester,
    ) async {
      repo.live = true;
      await pumpApp(tester, TransportScreen(repository: repo));
      await scrollTo(tester, find.text('Live Rail'));
      expect(find.text('₹240'), findsOneWidget);
      expect(find.textContaining("aren't available"), findsNothing);
    });

    testWidgets('each mode has its own layout', (tester) async {
      await pumpApp(tester, TransportScreen(repository: repo, mode: 'taxi'));
      await scrollTo(tester, find.text('TAXI-ONE'));
      expect(
        find.text('Book with TAXI-ONE'),
        findsNothing,
        reason: 'cab tiles',
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Bus'));
      await settle(tester);
      expect(repo.calls.last, contains(':bus:'));
    });

    testWidgets('uses the saved journey, and it can be changed', (
      tester,
    ) async {
      await pumpApp(
        tester,
        TransportScreen(
          repository: repo,
          prefill: const JourneyPrefill(origin: 'Pune', travellers: 3),
        ),
      );
      expect(repo.calls.last, 'transport:Pune:Nashik:train:3');
      await tester.tap(find.byTooltip('Swap'));
      await tester.pump();
      await tapText(tester, 'Check options');
      expect(repo.calls.last, 'transport:Nashik:Pune:train:3');
    });
  });

  group('my bookings', () {
    Future<void> add(FakeBookings r, {String status = 'saved'}) => r.create({
      'category': 'train',
      'title': 'Train to Nashik',
      'status': status,
      'reference': 'PNR1234567',
      'start_date': '2027-08-01',
      'from_place': 'Pune',
      'to_place': 'Nashik',
      'provider': 'IRCTC',
    });

    testWidgets('empty, and explains statuses are unverified', (tester) async {
      await pumpApp(tester, MyBookingsScreen(repository: repo));
      expect(find.text('Nothing saved yet'), findsOneWidget);
      expect(find.textContaining("doesn't book or verify"), findsOneWidget);
    });

    testWidgets('groups tickets and shows the reference', (tester) async {
      await add(repo);
      await pumpApp(tester, MyBookingsScreen(repository: repo));
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('Train to Nashik'), findsOneWidget);
      expect(find.text('PNR1234567'), findsOneWidget);
      expect(find.text('Pune → Nashik'), findsOneWidget);
    });

    testWidgets('sign-in and retry', (tester) async {
      repo.fail = const JourneyException(JourneyFailure.unauthorized);
      await pumpApp(tester, MyBookingsScreen(repository: repo));
      expect(find.textContaining('sign in'), findsOneWidget);
    });

    testWidgets('add a booking', (tester) async {
      await pumpApp(
        tester,
        BookingFormScreen(repository: repo),
        size: const Size(390, 2400),
      );
      await tapText(tester, 'Save');
      expect(find.text("This can't be empty."), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'My stay');
      await tapText(tester, 'Save');
      expect(repo.sent.single['title'], 'My stay');
      expect(repo.sent.single['status'], 'saved');
    });

    testWidgets('card-number refusal shows on the field', (tester) async {
      repo.failSave = const JourneyException(
        JourneyFailure.invalid,
        fieldErrors: {'reference': 'This looks like a card number.'},
      );
      await pumpApp(
        tester,
        BookingFormScreen(repository: repo),
        size: const Size(390, 2400),
      );
      await tester.enterText(find.byType(TextFormField).first, 'x');
      await tapText(tester, 'Save');
      expect(find.textContaining('card number'), findsWidgets);
    });

    testWidgets('https only', (tester) async {
      await pumpApp(
        tester,
        BookingFormScreen(repository: repo),
        size: const Size(390, 2400),
      );
      await tester.enterText(find.byType(TextFormField).first, 'x');
      final link = find.descendant(
        of: find.widgetWithText(AppTextField, 'Booking link (optional)'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(link, 'http://not-secure.example');
      await tapText(tester, 'Save');
      expect(find.text('Use a link starting with https://'), findsOneWidget);
      expect(repo.sent, isEmpty);
    });

    testWidgets('view, edit and delete', (tester) async {
      await add(repo);
      final id = repo.bookings.single.id;
      await pumpApp(tester, BookingDetailScreen(id: id, repository: repo));
      expect(find.text('PNR1234567'), findsWidgets);
      await tester.tap(find.byTooltip('Edit'));
      await settle(tester);
      expect(pushed.last, '/bookingForm');
      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.byTooltip('Delete'));
      await settle(tester);
      expect(find.textContaining("doesn't cancel anything"), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await settle(tester);
      expect(repo.bookings, isEmpty);
    });
  });

  group('robustness', () {
    for (final locale in const [Locale('en'), Locale('hi'), Locale('mr')]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'no overflow: ${locale.languageCode}, ${brightness.name}, 1.6x, 320dp',
          (tester) async {
            await repo.create({
              'category': 'stay',
              'title': 'A long stay name that runs across lines',
              'status': 'pending',
              'reference': 'ABCDEF1234567890',
              'start_date': '2027-08-01',
              'end_date': '2027-08-05',
            });
            for (final screen in <Widget>[
              BookingHomeScreen(repository: repo),
              StayResultsScreen(repository: repo),
              StayDetailScreen(id: 's1', repository: repo),
              TransportScreen(repository: repo),
              TransportScreen(repository: repo, mode: 'taxi'),
              TransportScreen(repository: repo, mode: 'bus'),
              MyBookingsScreen(repository: repo),
              BookingFormScreen(repository: repo),
              BookingDetailScreen(id: 'b1', repository: repo),
            ]) {
              await pumpApp(
                tester,
                KeyedSubtree(key: UniqueKey(), child: screen),
                locale: locale,
                brightness: brightness,
                textScale: 1.6,
                size: const Size(320, 640),
              );
              final problem = tester.takeException();
              expect(problem, isNull, reason: '$screen $problem');
            }
          },
        );
      }
    }
  });
}
