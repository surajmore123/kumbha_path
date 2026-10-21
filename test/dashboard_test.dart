import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_bloc.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_event.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_state.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_bloc.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/models/featured_model.dart';
import 'package:kumbha_path/src/models/journal_list.dart';
import 'package:kumbha_path/src/models/near_temple.dart';
import 'package:kumbha_path/src/models/quick_alert.dart';
import 'package:kumbha_path/src/models/upcoming_events.dart';
import 'package:kumbha_path/src/models/user_profile.dart';
import 'package:kumbha_path/src/models/zone_model.dart';
import 'package:kumbha_path/src/modules/dashboard/dashboard.dart';
import 'package:kumbha_path/src/modules/dashboard/dashboard_controller.dart';
import 'package:kumbha_path/src/modules/dashboard/dashboard_formatters.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------- fakes

/// Answers every request with [respond], or never if it returns null.
class FakeDetailsBloc extends Bloc<AppDetailsEvent, AppDetailsState> {
  FakeDetailsBloc(this.respond) : super(AppDetailsState()) {
    on<AppDetailsEvent>((event, emit) {
      requests++;
      emit(state.copyWith(status: AppDetailsStatus.loading));
      final next = respond(state);
      if (next != null) emit(next);
    });
  }

  AppDetailsState? Function(AppDetailsState current) respond;
  int requests = 0;
}

class FakeTemplesBloc extends Bloc<AppEvent, AppState> {
  FakeTemplesBloc(this.result) : super(const AppState()) {
    on<GetNearbyTemplesEvent>((event, emit) {
      requests++;
      emit(state.copyWith(status: AppStatus.loading));
      emit(result);
    });
  }

  final AppState result;
  int requests = 0;
}

class FakeLocation extends LocationGateway {
  FakeLocation(this.access);

  LocationAccess access;
  bool grantOnRequest = false;

  @override
  Future<LocationAccess> currentAccess() async => access;

  @override
  Future<Position> currentPosition() async {
    if (access != LocationAccess.available && !grantOnRequest) {
      throw Exception('denied');
    }
    access = LocationAccess.available;
    return Position(
      latitude: 19.9975,
      longitude: 73.7898,
      timestamp: DateTime(2027),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    return json.decode(await file.readAsString()) as Map<String, dynamic>;
  }
}

// ---------------------------------------------------------------- data

final _now = DateTime.now();
String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _longMarathi =
    'त्र्यंबकेश्वर कुशावर्त तीर्थ येथे सिंहस्थ पर्वणीचे शाही स्नान';

EventDetailsModel featuredEvent({String? date}) => EventDetailsModel(
  eventId: 'ev-1',
  eventName: 'Shahi Snan – $_longMarathi',
  shortDescription: 'First royal bath of the Simhastha at Kushavarta.',
  eventDate: date ?? _isoDate(_now.add(const Duration(days: 12))),
  startTime: '05:30:00',
  endTime: '09:00:00',
  isAllDay: false,
  locationName: 'Kushavarta Kund, Trimbakeshwar',
);

final _upcoming = [
  EventSummaryModel(
    eventId: 'ev-1', // same as featured: must be skipped
    eventName: 'Shahi Snan',
    eventDate: _isoDate(_now.add(const Duration(days: 12))),
  ),
  EventSummaryModel(
    eventId: 'ev-2',
    eventName: 'Ganga Aarti at Ramkund – $_longMarathi',
    eventDate: _isoDate(_now.add(const Duration(days: 3))),
    startTime: '18:30',
    locationName: 'Ramkund, Panchavati',
  ),
  const EventSummaryModel(
    eventId: 'ev-3',
    eventName: 'Kalaram Temple Utsav',
    eventDate: 'not-a-date',
    isAllDay: true,
  ),
];

const _zones = [
  ZoneModel(
    code: 'RK',
    name: 'Ramkund Ghat',
    occupancyPercent: 92,
    status: 'HIGH',
  ),
  ZoneModel(
    code: 'TK',
    name: 'Trimbak Road',
    occupancyPercent: 48,
    status: 'MEDIUM',
  ),
  ZoneModel(code: 'PV', name: 'Panchavati', status: 'LOW'),
  ZoneModel(code: 'XX', name: 'Sadhugram'),
];

const _alerts = [
  AlertDetailsModel(
    id: 'a1',
    zoneName: 'Ramkund Ghat',
    title: 'Heavy crowd near the ghat',
    description: 'Use the Gandhi Talav approach.',
  ),
];

const _temples = NearbyTemplesModel(
  count: 2,
  temples: [
    TempleModel(
      templeId: 't1',
      name: 'Shri Kalaram Mandir',
      city: 'Nashik',
      distanceKm: 1.234,
      crowdLevel: 'LOW',
    ),
    TempleModel(templeId: 't2', name: 'Sita Gufa'),
  ],
);

const _journal = JournalEntryListModel(
  count: 1,
  results: [
    JournalEntryModel(
      id: 1,
      title: 'Morning at Ramkund',
      notes: 'The aarti lamps on the Godavari.',
      createdAt: '2027-01-14T06:10:00Z',
    ),
  ],
);

// ---------------------------------------------------------------- harness

class Harness {
  Harness({
    EventDetailsModel? featured,
    List<EventSummaryModel>? upcoming,
    List<ZoneModel> zones = _zones,
    List<AlertDetailsModel> alerts = _alerts,
    JournalEntryListModel journal = _journal,
    LocationAccess access = LocationAccess.available,
    bool failCrowd = false,
  }) {
    final ok = AppDetailsStatus.success;
    featuredBloc = FakeDetailsBloc(
      (s) => s.copyWith(
        status: ok,
        eventDetailsModel: featured ?? featuredEvent(),
      ),
    );
    upcomingBloc = FakeDetailsBloc(
      (s) => s.copyWith(status: ok, upcomingEvents: upcoming ?? _upcoming),
    );
    crowdBloc = FakeDetailsBloc(
      (s) =>
          failCrowd
              ? s.copyWith(status: AppDetailsStatus.failed)
              : s.copyWith(status: ok, zoneModel: zones),
    );
    alertsBloc = FakeDetailsBloc(
      (s) => s.copyWith(status: ok, quickAlerts: alerts),
    );
    journalBloc = FakeDetailsBloc(
      (s) => s.copyWith(
        status: AppDetailsStatus.journalEntryoaded,
        journalEntryListModel: journal,
      ),
    );
    templesBloc = FakeTemplesBloc(
      const AppState(status: AppStatus.success, nearbyTemples: _temples),
    );
    location = FakeLocation(access);
  }

  late final FakeDetailsBloc featuredBloc;
  late final FakeDetailsBloc upcomingBloc;
  late final FakeDetailsBloc crowdBloc;
  late final FakeDetailsBloc alertsBloc;
  late final FakeDetailsBloc journalBloc;
  late final FakeTemplesBloc templesBloc;
  late final FakeLocation location;

  DashboardController controller() => DashboardController(
    templesBloc: templesBloc,
    location: location,
    featured: _feed(featuredBloc, (s) => s == AppDetailsStatus.success),
    upcoming: _feed(upcomingBloc, (s) => s == AppDetailsStatus.success),
    crowd: _feed(crowdBloc, (s) => s == AppDetailsStatus.success),
    alerts: _feed(alertsBloc, (s) => s == AppDetailsStatus.success),
    journal: _feed(journalBloc, (s) => s == AppDetailsStatus.journalEntryoaded),
  );

  static DashboardFeed _feed(
    FakeDetailsBloc bloc,
    bool Function(AppDetailsStatus) ready,
  ) => DashboardFeed(
    bloc: bloc,
    request: FeaturedEvent.new,
    isReady: ready,
    isFailed:
        (s) =>
            s == AppDetailsStatus.failed ||
            s == AppDetailsStatus.journalEntryError,
  );
}

final List<String> pushed = [];

Future<DashboardController> pumpDashboard(
  WidgetTester tester,
  Harness h, {
  Locale locale = const Locale('en'),
  Size size = const Size(360, 780),
  Brightness brightness = Brightness.light,
  AppFontScale fontScale = AppFontScale.standard,
  double deviceScale = 1.0,
  String? userName = 'Savitri Deshmukh',
}) async {
  pushed.clear();
  await tester.runAsync(EasyLocalization.ensureInitialized);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final userBloc = UserBloc();
  // ignore: invalid_use_of_visible_for_testing_member
  userBloc.emit(
    UserState(
      // With no name the dashboard would request the profile; "loading"
      // stands in for that request being in flight (no network in tests).
      status: userName == null ? UserStatus.loading : UserStatus.profileLoaded,
      profileData: UserData(
        userId: '1',
        phoneNumber: '',
        fullName: userName ?? '',
        email: '',
        profileUrl: '',
      ),
    ),
  );
  addTearDown(userBloc.close);
  final controller = h.controller();
  addTearDown(controller.dispose);

  Route<dynamic> route(RouteSettings settings) {
    if (settings.name == '/dashboardScreen') {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => Dashboard(controller: controller),
      );
    }
    // initialRoute '/dashboardScreen' also builds '/' underneath.
    if (settings.name != '/') pushed.add(settings.name!);
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const Scaffold(body: Text('destination')),
    );
  }

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
      path: 'assets/translations',
      assetLoader: const _FileAssetLoader(),
      fallbackLocale: const Locale('en'),
      startLocale: locale,
      saveLocale: false,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<UserBloc>.value(value: userBloc),
          BlocProvider<AppBloc>(create: (_) => AppBloc()),
          BlocProvider<AppDetailsBloc>(create: (_) => AppDetailsBloc()),
        ],
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
                navigatorObservers: [AppNavigation.observer],
                initialRoute: '/dashboardScreen',
                onGenerateRoute: route,
                builder:
                    (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(deviceScale)),
                      child: AppFontScaleScope(
                        fontScale: fontScale,
                        child: child,
                      ),
                    ),
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
  // Let feeds, fake location and image placeholders settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return controller;
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 300));
}

// ---------------------------------------------------------------- tests

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('formatters', () {
    final now = DateTime(2027, 1, 10, 22, 0);

    test('event timing by calendar day', () {
      expect(eventTiming('2027-01-10', now), isA<EventToday>());
      expect(eventTiming('2027-01-11', now), isA<EventTomorrow>());
      expect((eventTiming('2027-01-22', now) as EventInDays).days, 12);
      expect(eventTiming('2026-12-31', now), isA<EventPast>());
      expect(eventTiming('', now), isNull);
      expect(eventTiming('soon', now), isNull);
    });

    test('times and distances are omitted when invalid', () {
      expect(formatEventTimeRange('05:30:00', '09:00', 'en'), contains('–'));
      expect(formatEventTimeRange('', '09:00', 'en'), isNull);
      expect(formatEventTimeRange('25:00', null, 'en'), isNull);
      expect(formatDistanceKm(null, 'en'), isNull);
      expect(formatDistanceKm(1.234, 'en'), '1.2');
      expect(formatOccupancy(null, 'en'), isNull);
    });

    test('crowd levels never guess', () {
      expect(crowdLevelOf('low'), CrowdLevel.low);
      expect(crowdLevelOf('HIGH'), CrowdLevel.high);
      expect(crowdLevelOf(null), CrowdLevel.unknown);
      expect(crowdLevelOf('CRITICAL'), CrowdLevel.critical);
      expect(crowdLevelOf('SURGE'), CrowdLevel.other);
    });
  });

  group('content', () {
    testWidgets('renders real data in every section', (tester) async {
      final h = Harness();
      await pumpDashboard(tester, h);

      expect(find.text('Namaste, Savitri'), findsOneWidget);
      expect(find.text('Heavy crowd near the ghat'), findsOneWidget);
      expect(find.textContaining('Shahi Snan –'), findsOneWidget);
      expect(find.text('In 12 days'), findsOneWidget);

      await scrollTo(tester, find.text('Busiest zones'));
      expect(find.text('Ramkund Ghat'), findsWidgets);
      expect(find.text('92% full'), findsOneWidget);
      // A zone without a status counts as "Unavailable", never "Low".
      expect(find.text('Unavailable · 1'), findsOneWidget);
      expect(find.text('Low · 1'), findsOneWidget);

      await scrollTo(tester, find.text('Shri Kalaram Mandir'));
      expect(find.text('1.2 km away · Nashik'), findsOneWidget);
      // No distance from the API -> no distance shown.
      expect(find.textContaining('Sita Gufa'), findsOneWidget);
      expect(find.textContaining('km away'), findsOneWidget);

      await scrollTo(tester, find.textContaining('Ganga Aarti'));
      // Featured event is not repeated in the upcoming list.
      expect(find.text('Shahi Snan'), findsNothing);
      expect(find.text('Kalaram Temple Utsav'), findsOneWidget);
      expect(find.text('All day'), findsOneWidget);

      await scrollTo(tester, find.text('Morning at Ramkund'));
      expect(find.text('The aarti lamps on the Godavari.'), findsOneWidget);
    });

    testWidgets('greets without a name when the profile has none', (
      tester,
    ) async {
      await pumpDashboard(tester, Harness(), userName: null);
      expect(find.text('Namaste'), findsOneWidget);
    });

    testWidgets('past featured event says Concluded', (tester) async {
      final past = _isoDate(_now.subtract(const Duration(days: 3)));
      await pumpDashboard(tester, Harness(featured: featuredEvent(date: past)));
      expect(find.text('Concluded'), findsOneWidget);
    });

    testWidgets('no featured event and no alerts: both hidden', (tester) async {
      await pumpDashboard(
        tester,
        Harness(featured: EventDetailsModel.empty, alerts: const []),
      );
      expect(find.text('Featured event'), findsNothing);
      expect(find.text('Active alert'), findsNothing);
      expect(find.text('Plan your visit'), findsOneWidget);
    });

    testWidgets('empty states', (tester) async {
      await pumpDashboard(
        tester,
        Harness(
          zones: const [],
          upcoming: const [],
          journal: JournalEntryListModel.empty,
        ),
      );
      await scrollTo(
        tester,
        find.text('No crowd data is available right now.'),
      );
      await scrollTo(tester, find.text('No upcoming events right now.'));
      await scrollTo(
        tester,
        find.text(
          'Capture your darshans, thoughts and moments from the Kumbh.',
        ),
      );
    });
  });

  group('states', () {
    testWidgets('a failed section offers retry and only it reloads', (
      tester,
    ) async {
      final h = Harness(failCrowd: true);
      await pumpDashboard(tester, h);
      await scrollTo(tester, find.text('Try again'));
      expect(h.crowdBloc.requests, 1);
      final featuredBefore = h.featuredBloc.requests;

      h.crowdBloc.respond =
          (s) =>
              s.copyWith(status: AppDetailsStatus.success, zoneModel: _zones);
      await tester.tap(find.text('Try again'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(h.crowdBloc.requests, 2);
      expect(h.featuredBloc.requests, featuredBefore);
      expect(find.text('Busiest zones'), findsOneWidget);
    });

    testWidgets('loading shows placeholders, then a stalled request fails', (
      tester,
    ) async {
      final h = Harness();
      h.crowdBloc.respond = (_) => null; // never answers
      await pumpDashboard(tester, h);
      await scrollTo(tester, find.text('Crowd status'));
      expect(find.text('Busiest zones'), findsNothing);
      expect(find.text('Try again'), findsNothing);

      await tester.pump(const Duration(seconds: 31));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('pull to refresh reloads every feed once', (tester) async {
      final h = Harness();
      await pumpDashboard(tester, h);
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 500),
        1000,
      );
      await tester.pumpAndSettle();
      expect(h.featuredBloc.requests, 2);
      expect(h.crowdBloc.requests, 2);
      expect(h.journalBloc.requests, 2);
      expect(h.templesBloc.requests, 2);
    });

    testWidgets('location is not requested until the user asks', (
      tester,
    ) async {
      final h = Harness(access: LocationAccess.needsPermission);
      await pumpDashboard(tester, h);
      await scrollTo(tester, find.text('Allow location'));
      expect(h.templesBloc.requests, 0);
      expect(find.textContaining('km away'), findsNothing);

      h.location.grantOnRequest = true;
      await tester.tap(find.text('Allow location'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.templesBloc.requests, 1);
      expect(find.text('Shri Kalaram Mandir'), findsOneWidget);
    });

    testWidgets('location unavailable explains how to fix it', (tester) async {
      await pumpDashboard(tester, Harness(access: LocationAccess.unavailable));
      await scrollTo(tester, find.textContaining('device settings'));
      expect(find.text('See all'), findsOneWidget); // only upcoming's
    });
  });

  group('navigation', () {
    Future<void> expectRoute(
      WidgetTester tester,
      Finder target,
      String route,
    ) async {
      await scrollTo(tester, target);
      await tester.tap(target.first);
      await tester.pumpAndSettle();
      expect(pushed, [route]);
    }

    testWidgets('notifications', (tester) async {
      await pumpDashboard(tester, Harness());
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(pushed, ['/notifications']);
    });

    for (final (label, route) in [
      ('Crowd map', '/liveCroud'),
      ('Events', '/shahiEvents'),
      ('Updates', '/notifications'),
      ('View events', '/shahiEvents'),
      ('Open crowd map', '/liveCroud'),
      ('Ask AI Guru', '/aichat'),
      ('Open journal', '/journal'),
    ]) {
      testWidgets('"$label" opens $route', (tester) async {
        await pumpDashboard(tester, Harness());
        await expectRoute(
          tester,
          find.descendant(
            of: find.byType(ListView),
            matching: find.text(label),
          ),
          route,
        );
      });
    }

    testWidgets('Temples quick action opens /nearTemples with coordinates', (
      tester,
    ) async {
      await pumpDashboard(tester, Harness());
      await expectRoute(
        tester,
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Temples'),
        ),
        '/nearTemples',
      );
    });

    testWidgets('Temples quick action without location shows a message', (
      tester,
    ) async {
      await pumpDashboard(tester, Harness(access: LocationAccess.unavailable));
      await scrollTo(tester, find.text('Temples'));
      await tester.tap(find.text('Temples'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(pushed, isEmpty);
      expect(find.text('Could not get your location.'), findsOneWidget);
    });
  });

  group('robustness', () {
    for (final locale in const [Locale('en'), Locale('hi'), Locale('mr')]) {
      for (final brightness in Brightness.values) {
        for (final scale in AppFontScale.values) {
          testWidgets(
            'no overflow: ${locale.languageCode}, ${brightness.name}, '
            '${scale.name}, device 1.3x, 320dp',
            (tester) async {
              await pumpDashboard(
                tester,
                Harness(),
                locale: locale,
                brightness: brightness,
                fontScale: scale,
                deviceScale: 1.3,
                size: const Size(320, 640),
              );
              final scrollable = find.byType(Scrollable).first;
              for (var i = 0; i < 40; i++) {
                await tester.drag(scrollable, const Offset(0, -400));
                await tester.pump(const Duration(milliseconds: 50));
              }
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    testWidgets('tablet width centers content and uses the rail', (
      tester,
    ) async {
      await pumpDashboard(tester, Harness(), size: const Size(1024, 900));
      expect(find.byType(NavigationRail), findsOneWidget);
      final hero = tester.getRect(find.text('Namaste, Savitri'));
      expect(hero.left, greaterThan(150));
      expect(tester.takeException(), isNull);
    });

    testWidgets('localized: Marathi strings and dates', (tester) async {
      await pumpDashboard(tester, Harness(), locale: const Locale('mr'));
      expect(find.text('नमस्कार, Savitri'), findsOneWidget);
      await scrollTo(tester, find.text('तुमच्या भेटीचे नियोजन करा'));
      expect(find.text('तुमच्या भेटीचे नियोजन करा'), findsOneWidget);
    });
  });
}
