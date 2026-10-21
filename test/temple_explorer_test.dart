import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kumbha_path/app_router.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_bloc.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_event.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_state.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/location_service.dart';
import 'package:kumbha_path/src/models/near_temple.dart';
import 'package:kumbha_path/src/models/temple_detail.dart';
import 'package:kumbha_path/src/modules/temple_explorer/near_temples.dart';
import 'package:kumbha_path/src/modules/temple_explorer/temple_detail_screen.dart';
import 'package:kumbha_path/src/modules/temple_explorer/temple_directions.dart';
import 'package:kumbha_path/src/modules/temple_explorer/temple_navigation_map.dart';
import 'package:kumbha_path/src/modules/temple_explorer/widgets/temple_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ------------------------------------------------------------------ fakes

class FakeAppBloc extends AppBloc {
  final List<GetNearbyTemplesEvent> events = [];
  AppState? Function(GetNearbyTemplesEvent e)? reply;

  @override
  void add(AppEvent event) {
    final e = event as GetNearbyTemplesEvent;
    events.add(e);
    final next = reply?.call(e);
    // ignore: invalid_use_of_visible_for_testing_member
    if (!e.isLoadMore) emit(state.copyWith(status: AppStatus.loading));
    // ignore: invalid_use_of_visible_for_testing_member
    if (next != null) emit(next);
  }

  // ignore: invalid_use_of_visible_for_testing_member
  void set(AppState s) => emit(s);
}

class FakeDetailsBloc extends AppDetailsBloc {
  final List<AppDetailsEvent> events = [];
  AppDetailsState? Function(AppDetailsEvent e)? reply;

  @override
  void add(AppDetailsEvent event) {
    events.add(event);
    final next = reply?.call(event);
    // ignore: invalid_use_of_visible_for_testing_member
    emit(state.copyWith(status: AppDetailsStatus.loading));
    // ignore: invalid_use_of_visible_for_testing_member
    if (next != null) emit(next);
  }

  // ignore: invalid_use_of_visible_for_testing_member
  void set(AppDetailsState s) => emit(s);
}

Position position(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime(2027),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class FakeLocation extends LocationGateway {
  FakeLocation(this.access, {this.grantOnRequest = false});

  LocationAccess access;
  bool grantOnRequest;
  int settingsOpened = 0;

  @override
  Future<LocationAccess> currentAccess() async => access;

  @override
  Future<Position> currentPosition() async {
    if (access != LocationAccess.available && !grantOnRequest) {
      throw Exception('denied');
    }
    access = LocationAccess.available;
    return position(19.9975, 73.7898);
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

class FakeDirections extends TempleDirections {
  FakeDirections({this.route, this.opens = true});

  RouteSummary? route;
  bool opens;
  final List<String> modes = [];
  final List<LatLng?> openedFrom = [];
  final List<String> openedModes = [];

  @override
  Future<RouteSummary?> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    required String mode,
  }) async {
    modes.add(mode);
    return route;
  }

  @override
  Future<bool> openInGoogleMaps({
    LatLng? origin,
    required LatLng destination,
    required String mode,
  }) async {
    openedFrom.add(origin);
    openedModes.add(mode);
    return opens;
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

/// Stands in for GoogleMap: lists markers/polylines/circles as text.
Widget fakeMap(BuildContext context, TempleMapConfig c) => ColoredBox(
  color: Colors.grey,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final m in c.markers) Text('marker:${m.markerId.value}'),
      for (final p in c.polylines) Text('polyline:${p.points.length}'),
      for (final ci in c.circles) Text('circle:${ci.radius.round()}'),
    ],
  ),
);

// ------------------------------------------------------------------- data

const _kalaram = TempleModel(
  templeId: 't1',
  name: 'Shri Kalaram Mandir',
  city: 'Nashik',
  latitude: 20.0063,
  longitude: 73.7924,
  distanceKm: 1.234,
  crowdLevel: 'LOW',
  crowdMessage: 'Short queues at the east gate',
);
const _sitaGufa = TempleModel(templeId: 't2', name: 'Sita Gufa');
const _trimbak = TempleModel(
  templeId: 't3',
  name: 'Trimbakeshwar Jyotirlinga – त्र्यंबकेश्वर ज्योतिर्लिंग मंदिर',
  city: 'Trimbak',
  latitude: 19.9324,
  longitude: 73.5310,
  distanceKm: 27.6,
  crowdLevel: 'HIGH',
);

AppState loaded({List<TempleModel>? temples, int? count, double radius = 5}) {
  final list = temples ?? const [_kalaram, _sitaGufa, _trimbak];
  return AppState(
    status: AppStatus.success,
    nearbyTemples: NearbyTemplesModel(
      radiusKm: radius,
      count: count ?? list.length,
      temples: list,
      hasMore: false,
    ),
  );
}

const _detail = TempleDetailsModel(
  templeId: 't1',
  name: 'Shri Kalaram Mandir',
  description:
      'Built in 1792 by Sardar Rangarao Odhekar, the temple houses black '
      'stone idols of Rama, Sita and Lakshmana.',
  latitude: '20.0063',
  longitude: '73.7924',
  imageUrl: '',
  city: 'Nashik',
  state: 'Maharashtra',
  crowdLevel: 'MEDIUM',
  crowdMessage: 'Moderate crowd near the main hall',
);

// ---------------------------------------------------------------- harness

final List<(String, Object?)> pushed = [];

class Harness {
  final appBloc = FakeAppBloc();
  final detailsBloc = FakeDetailsBloc();
  late FakeLocation location = FakeLocation(LocationAccess.available);
}

Future<Harness> pump(
  WidgetTester tester, {
  required String route,
  Object? args,
  Harness? harness,
  Widget? home,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  AppFontScale fontScale = AppFontScale.standard,
  double deviceScale = 1.0,
}) async {
  final h = harness ?? Harness();
  pushed.clear();
  TempleMap.debugBuilder = fakeMap;
  addTearDown(() => TempleMap.debugBuilder = null);
  await tester.runAsync(EasyLocalization.ensureInitialized);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  Route<dynamic> gen(RouteSettings s) {
    if (s.name != route) pushed.add((s.name!, s.arguments));
    final Widget page = switch (s.name) {
      '/nearTemples' => NearTemples(location: h.location),
      '/templeDetail' => TempleDetailsScreen(location: h.location),
      '/map' => home!,
      _ => Scaffold(body: Text('page ${s.name}')),
    };
    return MaterialPageRoute(settings: s, builder: (_) => page);
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
          BlocProvider<AppBloc>.value(value: h.appBloc),
          BlocProvider<AppDetailsBloc>.value(value: h.detailsBloc),
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
                onGenerateInitialRoutes:
                    (_) => [
                      MaterialPageRoute(
                        builder: (_) => const Scaffold(body: Text('root')),
                      ),
                      gen(RouteSettings(name: route, arguments: args)),
                    ],
                onGenerateRoute: gen,
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
  await settle(tester);
  return h;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await settle(tester);
}

const _args = {'lat': '19.9975', 'lng': '73.7898'};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('AppRouter passes route settings (names + arguments)', () {
    final router = AppRouter();
    for (final name in [
      '/loginScreen',
      '/dashboardScreen',
      '/shahiEvents',
      '/liveCroud',
      '/journal',
      '/notifications',
      '/nearTemples',
      '/templeDetail',
      '/setting',
      '/launchScreen',
    ]) {
      final route =
          router.onGenerateRoute(RouteSettings(name: name, arguments: _args))!;
      expect(route.settings.name, name);
      expect(route.settings.arguments, _args);
    }
  });

  test('coordinates are parsed strictly', () {
    expect(parseTempleLatLng('20.0', '73.7'), const LatLng(20.0, 73.7));
    expect(parseTempleLatLng(null, 73.7), isNull);
    expect(parseTempleLatLng('', ''), isNull);
    expect(parseTempleLatLng(0, 0), isNull);
    expect(parseTempleLatLng(95, 10), isNull);
  });

  group('nearby temples', () {
    testWidgets('loads with route coordinates and renders API data only', (
      tester,
    ) async {
      final h = Harness();
      h.appBloc.reply = (_) => loaded();
      await pump(tester, route: '/nearTemples', args: _args, harness: h);

      final e = h.appBloc.events.single;
      expect(
        (e.latitude, e.longitude, e.radius, e.limit, e.isLoadMore),
        ('19.9975', '73.7898', '5', 5, false),
      );
      expect(find.text('Temple Explorer'), findsOneWidget);
      expect(find.text('3 of 3 temples within 5 km'), findsOneWidget);
      expect(find.text('Shri Kalaram Mandir'), findsOneWidget);
      expect(find.text('1.2 km away · Nashik'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(find.text('Short queues at the east gate'), findsOneWidget);
      // Temples without distance never show one.
      expect(find.textContaining('null'), findsNothing);
      // Map: user + the two temples that have coordinates.
      expect(find.text('marker:user'), findsOneWidget);
      expect(find.text('marker:temple-t1'), findsOneWidget);
      expect(find.text('marker:temple-t3'), findsOneWidget);
      expect(find.text('marker:temple-t2'), findsNothing);
      expect(find.text('circle:5000'), findsOneWidget);
    });

    testWidgets('does not refetch what the dashboard already loaded', (
      tester,
    ) async {
      final h = Harness();
      h.appBloc.set(loaded(radius: 10));
      await pump(tester, route: '/nearTemples', args: _args, harness: h);
      expect(h.appBloc.events, isEmpty);
      // Selected radius reflects the loaded results.
      expect(find.text('3 of 3 temples within 10 km'), findsOneWidget);
    });

    testWidgets('radius chips re-query with the chosen radius', (tester) async {
      final h = Harness();
      h.appBloc.reply = (_) => loaded();
      await pump(tester, route: '/nearTemples', args: _args, harness: h);
      await tester.tap(find.text('10 km'));
      await settle(tester);
      expect(h.appBloc.events.last.radius, '10');
    });

    testWidgets('load more uses the existing pagination', (tester) async {
      final h = Harness();
      h.appBloc.reply = (_) => loaded(count: 7);
      await pump(tester, route: '/nearTemples', args: _args, harness: h);
      await scrollTo(tester, find.text('Load more temples'));

      h.appBloc.reply = null; // response pending
      await tester.tap(find.text('Load more temples'));
      await settle(tester);
      expect(h.appBloc.events.last.isLoadMore, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      h.appBloc.set(
        loaded(
          temples: const [_kalaram, _sitaGufa, _trimbak, _kalaram],
          count: 7,
        ),
      );
      await settle(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('empty results offer a wider radius', (tester) async {
      final h = Harness();
      h.appBloc.reply = (_) => loaded(temples: const []);
      await pump(tester, route: '/nearTemples', args: _args, harness: h);
      expect(find.text('No temples found within 5 km'), findsOneWidget);
      await tester.tap(find.text('Search within 10 km'));
      await settle(tester);
      expect(h.appBloc.events.last.radius, '10');
    });

    testWidgets('API failure shows retry that re-queries', (tester) async {
      final h = Harness();
      h.appBloc.reply = (_) => const AppState(status: AppStatus.failure);
      await pump(tester, route: '/nearTemples', args: _args, harness: h);
      expect(find.text('Something went wrong'), findsOneWidget);
      h.appBloc.reply = (_) => loaded();
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(h.appBloc.events, hasLength(2));
      expect(find.text('Shri Kalaram Mandir'), findsOneWidget);
    });

    testWidgets('no coordinates + permission not granted: asks first', (
      tester,
    ) async {
      final h =
          Harness()..location = FakeLocation(LocationAccess.needsPermission);
      h.appBloc.reply = (_) => loaded();
      await pump(tester, route: '/nearTemples', harness: h);
      expect(
        find.text('Location is needed to find nearby temples'),
        findsOneWidget,
      );
      expect(h.appBloc.events, isEmpty);

      h.location.grantOnRequest = true;
      await tester.tap(find.text('Allow location'));
      await settle(tester);
      expect(h.appBloc.events, hasLength(1));
      expect(find.text('Shri Kalaram Mandir'), findsOneWidget);
    });

    testWidgets('permission denied on request: explains, no fake data', (
      tester,
    ) async {
      final h =
          Harness()..location = FakeLocation(LocationAccess.needsPermission);
      await pump(tester, route: '/nearTemples', harness: h);
      await tester.tap(find.text('Allow location'));
      await settle(tester);
      expect(find.text('Could not get your location.'), findsOneWidget);
      expect(h.appBloc.events, isEmpty);
    });

    testWidgets('location off / permanently denied: opens settings', (
      tester,
    ) async {
      final h = Harness()..location = FakeLocation(LocationAccess.unavailable);
      await pump(tester, route: '/nearTemples', harness: h);
      expect(find.textContaining('device settings'), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      await settle(tester);
      expect(h.location.settingsOpened, 1);
    });

    testWidgets('no coordinates but permission granted: loads directly', (
      tester,
    ) async {
      final h = Harness();
      h.appBloc.reply = (_) => loaded();
      await pump(tester, route: '/nearTemples', harness: h);
      expect(h.appBloc.events, hasLength(1));
    });

    testWidgets('opening a temple requests detail and passes arguments', (
      tester,
    ) async {
      final h = Harness();
      h.appBloc.reply = (_) => loaded();
      await pump(tester, route: '/nearTemples', args: _args, harness: h);
      await scrollTo(tester, find.text('Shri Kalaram Mandir'));
      await tester.tap(find.text('Shri Kalaram Mandir'));
      await settle(tester);

      final req = h.detailsBloc.events.single as GetTempleDetail;
      expect(
        (req.templeId, req.latitude, req.longitude),
        ('t1', '19.9975', '73.7898'),
      );
      final (name, args) = pushed.single;
      expect(name, '/templeDetail');
      expect((args as TempleDetailArgs).templeId, 't1');
    });
  });

  group('temple detail', () {
    const args = TempleDetailArgs(
      templeId: 't1',
      latitude: '19.9975',
      longitude: '73.7898',
    );

    testWidgets('loading, then the API fields only', (tester) async {
      final h = Harness();
      h.detailsBloc.set(AppDetailsState(status: AppDetailsStatus.loading));
      await pump(tester, route: '/templeDetail', args: args, harness: h);
      expect(find.text('Shri Kalaram Mandir'), findsNothing);

      h.detailsBloc.set(
        AppDetailsState(
          status: AppDetailsStatus.success,
          templeDetail: _detail,
        ),
      );
      await settle(tester);
      expect(find.text('Shri Kalaram Mandir'), findsOneWidget);
      // Hero and Location card.
      expect(find.text('Nashik, Maharashtra'), findsNWidgets(2));
      expect(find.text('Moderate'), findsOneWidget);
      expect(find.text('Moderate crowd near the main hall'), findsOneWidget);
      await scrollTo(tester, find.text('About the temple'));
      expect(find.textContaining('Built in 1792'), findsOneWidget);
      // No fabricated actions or data.
      expect(find.byIcon(Icons.bookmark_border), findsNothing);
      expect(find.textContaining('Journal'), findsNothing);
      expect(find.textContaining('Open'), findsNothing);
    });

    testWidgets('never shows the previous temple for a new one', (
      tester,
    ) async {
      final h = Harness();
      h.detailsBloc.set(
        AppDetailsState(
          status: AppDetailsStatus.success,
          templeDetail: _detail,
        ),
      );
      await pump(
        tester,
        route: '/templeDetail',
        args: const TempleDetailArgs(
          templeId: 't9',
          latitude: '',
          longitude: '',
        ),
        harness: h,
      );
      expect(find.text('Shri Kalaram Mandir'), findsNothing);
    });

    testWidgets('failed load can be retried with the same request', (
      tester,
    ) async {
      final h = Harness();
      h.detailsBloc.set(AppDetailsState(status: AppDetailsStatus.failed));
      await pump(tester, route: '/templeDetail', args: args, harness: h);
      h.detailsBloc.reply =
          (_) => AppDetailsState(
            status: AppDetailsStatus.success,
            templeDetail: _detail,
          );
      await tester.tap(find.text('Try again'));
      await settle(tester);
      final req = h.detailsBloc.events.single as GetTempleDetail;
      expect(req.templeId, 't1');
      expect(find.text('Shri Kalaram Mandir'), findsOneWidget);
    });

    testWidgets('long descriptions collapse with Read more', (tester) async {
      final h = Harness();
      h.detailsBloc.set(
        AppDetailsState(
          status: AppDetailsStatus.success,
          templeDetail: _detail.copyWith(
            description: List.filled(30, 'The sanctum faces east.').join(' '),
          ),
        ),
      );
      await pump(tester, route: '/templeDetail', args: args, harness: h);
      await scrollTo(tester, find.text('Read more'));
      await tester.tap(find.text('Read more'));
      await settle(tester);
      expect(find.text('Show less'), findsOneWidget);
    });

    testWidgets('missing coordinates: directions disabled and explained', (
      tester,
    ) async {
      final h = Harness();
      h.detailsBloc.set(
        AppDetailsState(
          status: AppDetailsStatus.success,
          templeDetail: _detail.copyWith(latitude: '', longitude: ''),
        ),
      );
      await pump(tester, route: '/templeDetail', args: args, harness: h);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Get directions'),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text("A map location isn't available for this temple."),
        findsOneWidget,
      );
      expect(find.text('Location'), findsNothing);
    });

    testWidgets('directions opens the map and reports TempleNavigate', (
      tester,
    ) async {
      final h = Harness();
      h.detailsBloc.set(
        AppDetailsState(
          status: AppDetailsStatus.success,
          templeDetail: _detail,
        ),
      );
      await pump(tester, route: '/templeDetail', args: args, harness: h);
      await tester.tap(find.widgetWithText(FilledButton, 'Get directions'));
      await settle(tester);

      expect(find.byType(TempleNavigationMap), findsOneWidget);
      final map = tester.widget<TempleNavigationMap>(
        find.byType(TempleNavigationMap),
      );
      expect(
        (map.templelat, map.templelng, map.templeName),
        (20.0063, 73.7924, 'Shri Kalaram Mandir'),
      );
      final nav = h.detailsBloc.events.single as TempleNavigate;
      expect(
        (nav.templeId, nav.latitude, nav.longitude),
        ('t1', '19.9975', '73.7898'),
      );
    });
  });

  group('navigation map', () {
    Widget mapScreen(FakeLocation loc, FakeDirections dir) =>
        TempleNavigationMap(
          templelat: 20.0063,
          templelng: 73.7924,
          templeName: 'Shri Kalaram Mandir',
          location: loc,
          directions: dir,
        );

    const route = RouteSummary(
      distanceText: '4.5 km',
      durationText: '12 mins',
      points: [LatLng(19.99, 73.78), LatLng(20.0, 73.79)],
    );

    testWidgets('route preview, mode switch and Start hand-off', (
      tester,
    ) async {
      final dir = FakeDirections(route: route);
      await pump(
        tester,
        route: '/map',
        home: mapScreen(FakeLocation(LocationAccess.available), dir),
      );
      expect(find.text('12 mins · 4.5 km'), findsOneWidget);
      expect(find.text('marker:temple'), findsOneWidget);
      expect(find.text('polyline:2'), findsOneWidget);
      expect(dir.modes, ['driving']);

      await tester.tap(find.text('Walk'));
      await settle(tester);
      expect(dir.modes, ['driving', 'walking']);

      await tester.tap(find.text('Start in Google Maps'));
      await settle(tester);
      expect(dir.openedFrom.single, const LatLng(19.9975, 73.7898));
      expect(dir.openedModes.single, 'walking');
    });

    testWidgets('no location: explains, Start still works without origin', (
      tester,
    ) async {
      final dir = FakeDirections(route: route);
      final loc = FakeLocation(LocationAccess.unavailable);
      await pump(tester, route: '/map', home: mapScreen(loc, dir));
      expect(find.textContaining('location is unavailable'), findsOneWidget);
      expect(dir.modes, isEmpty);
      expect(find.text('polyline:2'), findsNothing);

      await tester.tap(find.text('Start in Google Maps'));
      await settle(tester);
      expect(dir.openedFrom.single, isNull);

      loc.access = LocationAccess.available;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('12 mins · 4.5 km'), findsOneWidget);
    });

    testWidgets('route failure: no fabricated distance or time', (
      tester,
    ) async {
      await pump(
        tester,
        route: '/map',
        home: mapScreen(
          FakeLocation(LocationAccess.available),
          FakeDirections(),
        ),
      );
      expect(
        find.text("Route preview isn't available right now."),
        findsOneWidget,
      );
      expect(find.textContaining('km'), findsNothing);
    });

    testWidgets('Google Maps failing to open is reported', (tester) async {
      await pump(
        tester,
        route: '/map',
        home: mapScreen(
          FakeLocation(LocationAccess.available),
          FakeDirections(route: route, opens: false),
        ),
      );
      await tester.tap(find.text('Start in Google Maps'));
      await settle(tester);
      expect(find.text("Couldn't open Google Maps."), findsOneWidget);
    });

    testWidgets('back returns to the previous screen', (tester) async {
      await pump(
        tester,
        route: '/map',
        home: mapScreen(
          FakeLocation(LocationAccess.available),
          FakeDirections(route: route),
        ),
      );
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(find.text('root'), findsOneWidget);
    });
  });

  group('layout', () {
    final screens = <
      String,
      Future<void> Function(WidgetTester, Locale, Brightness, AppFontScale)
    >{
      'list': (t, l, b, s) async {
        final h = Harness();
        h.appBloc.reply = (_) => loaded(count: 9);
        await pump(
          t,
          route: '/nearTemples',
          args: _args,
          harness: h,
          locale: l,
          brightness: b,
          fontScale: s,
          deviceScale: 1.3,
          size: const Size(320, 640),
        );
      },
      'detail': (t, l, b, s) async {
        final h = Harness();
        h.detailsBloc.set(
          AppDetailsState(
            status: AppDetailsStatus.success,
            templeDetail: _detail.copyWith(name: _trimbak.name),
          ),
        );
        await pump(
          t,
          route: '/templeDetail',
          args: const TempleDetailArgs(
            templeId: 't1',
            latitude: '',
            longitude: '',
          ),
          harness: h,
          locale: l,
          brightness: b,
          fontScale: s,
          deviceScale: 1.3,
          size: const Size(320, 640),
        );
      },
      'map': (t, l, b, s) async {
        await pump(
          t,
          route: '/map',
          home: TempleNavigationMap(
            templelat: 20,
            templelng: 73.7,
            templeName: _trimbak.name!,
            location: FakeLocation(LocationAccess.available),
            directions: FakeDirections(
              route: const RouteSummary(
                distanceText: '27.6 km',
                durationText: '48 mins',
                points: [],
              ),
            ),
          ),
          locale: l,
          brightness: b,
          fontScale: s,
          deviceScale: 1.3,
          size: const Size(320, 640),
        );
      },
    };
    for (final MapEntry(key: name, value: open) in screens.entries) {
      for (final locale in const [Locale('en'), Locale('hi'), Locale('mr')]) {
        for (final b in Brightness.values) {
          for (final s in AppFontScale.values) {
            testWidgets(
              'no overflow: $name ${locale.languageCode} ${b.name} ${s.name}',
              (tester) async {
                await open(tester, locale, b, s);
                final scrollables = find.byType(Scrollable);
                if (scrollables.evaluate().isNotEmpty) {
                  for (var i = 0; i < 12; i++) {
                    await tester.drag(scrollables.first, const Offset(0, -500));
                    await tester.pump(const Duration(milliseconds: 50));
                  }
                }
                expect(tester.takeException(), isNull);
              },
            );
          }
        }
      }
    }

    testWidgets('tablet: two-column temple grid', (tester) async {
      final h = Harness();
      h.appBloc.reply = (_) => loaded();
      await pump(
        tester,
        route: '/nearTemples',
        args: _args,
        harness: h,
        size: const Size(900, 1200),
      );
      final a = tester.getRect(find.text('Shri Kalaram Mandir'));
      final b = tester.getRect(find.text('Sita Gufa'));
      expect(a.top, b.top);
      expect(b.left, greaterThan(a.right));
    });
  });
}
