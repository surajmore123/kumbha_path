import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/components/maps/app_map.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/models/featured_model.dart';
import 'package:kumbha_path/src/models/notification_model.dart';
import 'package:kumbha_path/src/models/quick_alert.dart';
import 'package:kumbha_path/src/models/zone_detail.dart';
import 'package:kumbha_path/src/models/zone_model.dart';
import 'package:kumbha_path/src/modules/live_crowd/live_crowd_map.dart';
import 'package:kumbha_path/src/modules/live_crowd/widgets/live_info.dart';
import 'package:kumbha_path/src/modules/live_updates/live_updates.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Finds exactly [text], where the space before AM/PM may be a normal or a
/// narrow no-break space (U+202F, used by newer intl/CLDR time formats).
Finder findTimeText(String text) {
  final pattern = RegExp(
    '^${RegExp.escape(text).replaceAllMapped(RegExp(r' (AM|PM)'), (m) => '[  ]${m[1]}')}\$',
  );
  return find.textContaining(pattern);
}

// ------------------------------------------------------------------ fakes

typedef Responder =
    AppDetailsState? Function(AppDetailsState state, AppDetailsEvent event);

/// Every feed's bloc; all requests are recorded in [log].
class FakeDetailsBloc extends AppDetailsBloc {
  FakeDetailsBloc(this.respond, this.log);

  final Responder Function() respond;
  final List<AppDetailsEvent> log;

  @override
  void add(AppDetailsEvent event) {
    log.add(event);
    final next = respond()(state, event);
    // ignore: invalid_use_of_visible_for_testing_member
    emit(state.copyWith(status: AppDetailsStatus.loading));
    // ignore: invalid_use_of_visible_for_testing_member
    if (next != null) emit(next);
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

/// Map stand-in: markers become buttons (tap = marker tap) and every
/// marker / circle property under test is printed.
Widget fakeMap(BuildContext context, AppMapConfig c) => SingleChildScrollView(
  child: Column(
    children: [
      // Keep tappable markers below the status strip overlay.
      const SizedBox(height: 180),
      Wrap(
        children: [
          TextButton(
            onPressed: () => c.onTap?.call(c.target),
            child: const Text('map-background'),
          ),
          for (final m in c.markers)
            TextButton(
              onPressed: m.onTap,
              child: Text('marker:${m.markerId.value}'),
            ),
        ],
      ),
      for (final m in c.markers) ...[
        Text('hue:${m.markerId.value}:${m.icon.toJson()}'),
        Text('info:${m.markerId.value}:${m.infoWindow.snippet}'),
      ],
      for (final ci in c.circles)
        Text(
          'circle:${ci.circleId.value}:${ci.radius.round()}:${ci.strokeWidth}',
        ),
    ],
  ),
);

// ------------------------------------------------------------------- data

final now = DateTime(2027, 1, 10, 10, 0);

const zones = [
  ZoneModel(
    code: 'RK',
    name: 'Ramkund Ghat',
    latitude: 20.006,
    longitude: 73.792,
    capacity: 2000,
    totalPeople: 1840,
    occupancyPercent: 92,
    status: 'HIGH',
  ),
  ZoneModel(
    code: 'KK',
    name: 'Kushavarta Kund',
    latitude: 19.932,
    longitude: 73.531,
    occupancyPercent: 101,
    status: 'CRITICAL',
  ),
  ZoneModel(
    code: 'PV',
    name: 'Panchavati',
    latitude: 20.008,
    longitude: 73.795,
    status: 'LOW',
  ),
  ZoneModel(code: 'SG', name: 'Sadhugram', latitude: 20.02, longitude: 73.80),
  ZoneModel(code: 'NO', name: 'No coordinates', status: 'LOW'),
];

const alerts = [
  AlertDetailsModel(
    id: 'a1',
    zoneCode: 'RK',
    zoneName: 'Ramkund Ghat',
    type: 'CROWD',
    severity: 'HIGH',
    title: 'Heavy crowd near the ghat',
    description: 'Use the Gandhi Talav approach.',
    startTime: '2027-01-10T08:30:00',
  ),
];

const featured = EventDetailsModel(
  eventId: 'e1',
  eventName: 'Pratham Shahi Snan',
  eventDate: '2027-01-22',
);

ZoneLiveDetailsModel zoneDetail(String code) => ZoneLiveDetailsModel(
  status: 'success',
  zone: ZoneInfoModel(code: code),
  alerts: [
    if (code == 'RK')
      const AlertModel(title: 'Barricades at east steps', severity: 'MEDIUM'),
  ],
);

const updates = [
  NotificationModel(
    id: 3,
    title: 'Crowd surge at Ramkund',
    body: 'Avoid the east steps.',
    type: 'ALERT',
    severity: 'HIGH',
    zoneName: 'Ramkund Ghat',
    createdAt: '2027-01-10T08:30:00',
  ),
  NotificationModel(
    id: 2,
    title: 'Aarti timings',
    body: 'Evening aarti at 6:30 PM.',
    type: 'MESSAGE',
    severity: 'LOW',
    createdAt: '2027-01-09T19:05:00',
  ),
  NotificationModel(
    id: 3,
    title: 'Crowd surge at Ramkund',
    type: 'ALERT',
    severity: 'HIGH',
  ),
  NotificationModel(
    id: 1,
    title: 'Bad timestamp',
    type: 'MESSAGE',
    createdAt: 'yesterday-ish',
  ),
];

class Backend {
  final List<AppDetailsEvent> log = [];
  bool zonesFail = false;
  bool alertsFail = false;
  bool detailFails = false;
  bool updatesFail = false;
  List<ZoneModel> zoneList = zones;
  List<AlertDetailsModel> alertList = alerts;
  List<NotificationModel> Function(String type) updateList =
      (type) =>
          type == '' ? updates : updates.where((u) => u.type == type).toList();

  AppDetailsState? respond(AppDetailsState s, AppDetailsEvent e) {
    AppDetailsState ok(AppDetailsState n) =>
        n.copyWith(status: AppDetailsStatus.success);
    AppDetailsState fail() => s.copyWith(status: AppDetailsStatus.failed);
    return switch (e) {
      CrowdLiveStatusEvent() =>
        zonesFail ? fail() : ok(s.copyWith(zoneModel: zoneList)),
      QuickAlertsEvent() =>
        alertsFail ? fail() : ok(s.copyWith(quickAlerts: alertList)),
      FeaturedEvent() => ok(s.copyWith(eventDetailsModel: featured)),
      GetZoneDetailEvent(:final zoneCode) =>
        detailFails
            ? fail()
            : ok(s.copyWith(zoneDetails: zoneDetail(zoneCode))),
      GetNotificationsEvent(:final type) =>
        updatesFail
            ? fail()
            : ok(s.copyWith(notificationList: updateList(type))),
      _ => null,
    };
  }

  Bloc<AppDetailsEvent, AppDetailsState> newBloc() =>
      FakeDetailsBloc(() => respond, log);

  int count<T>() => log.whereType<T>().length;
}

// ---------------------------------------------------------------- harness

final List<(String, Object?)> pushed = [];

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Object? args,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  AppFontScale fontScale = AppFontScale.standard,
  double deviceScale = 1.0,
}) async {
  pushed.clear();
  AppMap.debugBuilder = fakeMap;
  addTearDown(() => AppMap.debugBuilder = null);
  await tester.runAsync(EasyLocalization.ensureInitialized);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
      path: 'assets/translations',
      assetLoader: const _FileAssetLoader(),
      fallbackLocale: const Locale('en'),
      startLocale: locale,
      saveLocale: false,
      child: BlocProvider<AppDetailsBloc>(
        create: (_) => AppDetailsBloc(),
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
                        settings: RouteSettings(
                          name: '/screen',
                          arguments: args,
                        ),
                        builder: (_) => screen,
                      ),
                    ],
                onGenerateRoute: (s) {
                  pushed.add((s.name!, s.arguments));
                  return MaterialPageRoute(
                    settings: s,
                    builder: (_) => Scaffold(body: Text('page ${s.name}')),
                  );
                },
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
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget crowdMap(Backend b) =>
    LiveCrowdMap(blocFactory: b.newBloc, now: () => now);
Widget liveUpdates(Backend b) => LiveUpdates(bloc: b.newBloc(), now: () => now);

/// Drags the sheet down to its smallest size, uncovering the map.
Future<void> collapseSheet(WidgetTester tester) async {
  final scrollable = find.descendant(
    of: find.byType(DraggableScrollableSheet),
    matching: find.byType(Scrollable),
  );
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pump();
  final top = tester.getRect(scrollable).topCenter;
  await tester.dragFrom(top + const Offset(0, 12), const Offset(0, 900));
  await settle(tester);
}

/// Scrolls the bottom sheet until [f] is visible.
Future<void> sheetTo(WidgetTester tester, Finder f) async {
  final scrollable = find.descendant(
    of: find.byType(DraggableScrollableSheet),
    matching: find.byType(Scrollable),
  );
  // Expand the sheet (it snaps), then start from the top so content above
  // the current offset is found too.
  final top = tester.getRect(scrollable).topCenter;
  await tester.dragFrom(top + const Offset(0, 12), const Offset(0, -900));
  await settle(tester);
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(f, 200, scrollable: scrollable);
  await settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('severity mapping is literal', () {
    expect(severityOf('high'), Severity.high);
    expect(severityOf('CRITICAL'), Severity.critical);
    expect(severityOf(''), Severity.none);
    expect(severityOf('INFO'), Severity.other);
    expect(isUrgent('MEDIUM'), isFalse);
    expect(isUrgent('HIGH'), isTrue);
  });

  group('crowd map', () {
    testWidgets('one request each; markers only for zones with coordinates', (
      tester,
    ) async {
      final b = Backend();
      await pumpScreen(tester, crowdMap(b));
      expect(b.count<CrowdLiveStatusEvent>(), 1);
      expect(b.count<QuickAlertsEvent>(), 1);
      expect(b.count<FeaturedEvent>(), 1);

      for (final code in ['RK', 'KK', 'PV', 'SG']) {
        expect(find.text('marker:$code'), findsOneWidget);
      }
      expect(find.text('marker:NO'), findsNothing);
      // Status in words on every marker; unknown is not "Low".
      expect(find.text('info:RK:High · 92% full'), findsOneWidget);
      expect(find.text('info:KK:Critical · 101% full'), findsOneWidget);
      expect(find.text('info:PV:Low'), findsOneWidget);
      expect(find.text('info:SG:Unavailable'), findsOneWidget);
      // Hues: unknown is azure (210), critical red (0), not the same.
      expect(find.text('hue:SG:[defaultMarker, 210.0]'), findsOneWidget);
      expect(find.text('hue:KK:[defaultMarker, 0.0]'), findsOneWidget);
      // Legend + freshness (device fetch time; zones have no timestamp).
      expect(find.text('Critical'), findsWidgets);
      expect(
        find.textContaining('5 zones reporting · Checked at'),
        findsOneWidget,
      );
    });

    testWidgets('selecting a zone loads its details; switching resets', (
      tester,
    ) async {
      final b = Backend();
      await pumpScreen(tester, crowdMap(b));
      await tester.tap(find.text('marker:RK'));
      await settle(tester);

      expect((b.log.last as GetZoneDetailEvent).zoneCode, 'RK');
      expect(find.text('Ramkund Ghat'), findsWidgets);
      expect(
        find.text('92% full · 1840 people · Capacity 2000'),
        findsOneWidget,
      );
      expect(find.text('circle:RK:60:4'), findsOneWidget); // selected ring
      await sheetTo(tester, find.text('Barricades at east steps'));

      await collapseSheet(tester);
      await tester.tap(find.text('marker:PV'));
      await settle(tester);
      expect((b.log.last as GetZoneDetailEvent).zoneCode, 'PV');
      expect(find.text('Barricades at east steps'), findsNothing);
      await sheetTo(tester, find.text('No alerts reported for this zone.'));
      // Missing occupancy/people: nothing shown, never "0%".
      expect(find.textContaining('% full ·'), findsNothing);
      expect(find.text('circle:RK:30:2'), findsOneWidget);
    });

    testWidgets('tapping the map deselects; close button too', (tester) async {
      final b = Backend();
      await pumpScreen(tester, crowdMap(b));
      await tester.tap(find.text('marker:RK'));
      await settle(tester);
      expect(find.byTooltip('Back to all zones'), findsOneWidget);
      await tester.tap(find.text('map-background'));
      await settle(tester);
      expect(find.byTooltip('Back to all zones'), findsNothing);
      expect(
        find.text('Tap a zone on the map to see its details.'),
        findsOneWidget,
      );
    });

    testWidgets('zone detail failure is contained with retry', (tester) async {
      final b = Backend()..detailFails = true;
      await pumpScreen(tester, crowdMap(b));
      await tester.tap(find.text('marker:RK'));
      await settle(tester);
      await sheetTo(tester, find.text("Couldn't load this zone's alerts."));
      b.detailFails = false;
      await tester.tap(find.text('Try again').first);
      await settle(tester);
      await sheetTo(tester, find.text('Barricades at east steps'));
    });

    testWidgets('quick alerts: severity, source time; tap selects zone', (
      tester,
    ) async {
      final b = Backend();
      await pumpScreen(tester, crowdMap(b));
      await sheetTo(tester, find.text('Heavy crowd near the ghat'));
      expect(findTimeText('Started Today, 8:30 AM'), findsOneWidget);
      expect(find.text('High'), findsWidgets);
      await tester.tap(find.text('Heavy crowd near the ghat'));
      await settle(tester);
      expect((b.log.last as GetZoneDetailEvent).zoneCode, 'RK');
    });

    testWidgets('no alerts', (tester) async {
      final b = Backend()..alertList = const [];
      await pumpScreen(tester, crowdMap(b));
      await sheetTo(tester, find.text('No active alerts right now.'));
    });

    testWidgets('failed alerts are not shown as "no alerts"', (tester) async {
      final b = Backend()..alertsFail = true;
      await pumpScreen(tester, crowdMap(b));
      await sheetTo(tester, find.text("Couldn't load alerts."));
      expect(find.text('No active alerts right now.'), findsNothing);
    });

    testWidgets('zones failure shows retry that reloads zones only', (
      tester,
    ) async {
      final b = Backend()..zonesFail = true;
      await pumpScreen(tester, crowdMap(b));
      expect(find.text("Couldn't load crowd data."), findsOneWidget);
      expect(find.textContaining('marker:'), findsNothing);
      b.zonesFail = false;
      await tester.tap(find.text('Try again').first);
      await settle(tester);
      expect(b.count<CrowdLiveStatusEvent>(), 2);
      expect(b.count<QuickAlertsEvent>(), 1);
      expect(find.text('marker:RK'), findsOneWidget);
    });

    testWidgets('no zones reporting', (tester) async {
      final b = Backend()..zoneList = const [];
      await pumpScreen(tester, crowdMap(b));
      expect(
        find.text('No crowd zones are reporting right now.'),
        findsOneWidget,
      );
    });

    testWidgets('refresh reloads every feed once', (tester) async {
      final b = Backend();
      await pumpScreen(tester, crowdMap(b));
      await tester.tap(find.text('marker:RK'));
      await settle(tester);
      await tester.tap(find.byTooltip('Refresh'));
      await settle(tester);
      expect(b.count<CrowdLiveStatusEvent>(), 2);
      expect(b.count<QuickAlertsEvent>(), 2);
      expect(b.count<FeaturedEvent>(), 2);
      expect(b.count<GetZoneDetailEvent>(), 2);
    });

    testWidgets('route argument preselects a zone by name', (tester) async {
      final b = Backend();
      await pumpScreen(tester, crowdMap(b), args: {'zoneName': 'ramkund ghat'});
      expect((b.log.last as GetZoneDetailEvent).zoneCode, 'RK');
      expect(find.byTooltip('Back to all zones'), findsOneWidget);
    });

    testWidgets('notifications and next event navigate', (tester) async {
      final b = Backend();
      await pumpScreen(tester, crowdMap(b));
      await tester.tap(find.byTooltip('Notifications'));
      await settle(tester);
      expect(pushed.last.$1, '/notifications');
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settle(tester);
      await sheetTo(tester, find.text('Pratham Shahi Snan'));
      await tester.tap(find.text('Pratham Shahi Snan'));
      await settle(tester);
      expect(pushed.last.$1, '/shahiEvents');
    });
  });

  group('live updates', () {
    testWidgets('feed in API order, deduped, with source times', (
      tester,
    ) async {
      final b = Backend();
      await pumpScreen(tester, liveUpdates(b));
      expect((b.log.single as GetNotificationsEvent).type, '');

      expect(find.text('Crowd surge at Ramkund'), findsOneWidget); // id 3 once
      final a = tester.getTopLeft(find.text('Crowd surge at Ramkund')).dy;
      final c = tester.getTopLeft(find.text('Aarti timings')).dy;
      expect(a, lessThan(c));
      expect(findTimeText('Today, 8:30 AM'), findsOneWidget);
      expect(findTimeText('Yesterday, 7:05 PM'), findsOneWidget);
      expect(find.text('Alert'), findsWidgets);
      expect(find.text('High'), findsWidgets);
      // Unparseable timestamp: no time shown, no crash.
      await tester.scrollUntilVisible(
        find.text('Bad timestamp'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tabs use the API type filter', (tester) async {
      final b =
          Backend()
            ..updateList = (type) => type == 'ALERT' ? const [] : updates;
      await pumpScreen(tester, liveUpdates(b));
      await tester.tap(find.text('Alerts'));
      await settle(tester);
      expect((b.log.last as GetNotificationsEvent).type, 'ALERT');
      expect(find.text('No alerts right now.'), findsOneWidget);
      await tester.tap(find.text('Messages'));
      await settle(tester);
      expect((b.log.last as GetNotificationsEvent).type, 'MESSAGE');
    });

    testWidgets('failure is not shown as an empty feed', (tester) async {
      final b = Backend()..updatesFail = true;
      await pumpScreen(tester, liveUpdates(b));
      expect(find.text("Couldn't load updates."), findsOneWidget);
      expect(find.text('No updates yet.'), findsNothing);
      b.updatesFail = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Crowd surge at Ramkund'), findsOneWidget);
    });

    testWidgets('empty feed', (tester) async {
      final b = Backend()..updateList = (_) => const [];
      await pumpScreen(tester, liveUpdates(b));
      expect(find.text('No updates yet.'), findsOneWidget);
    });

    testWidgets('view on map opens the crowd map with the zone', (
      tester,
    ) async {
      final b = Backend();
      await pumpScreen(tester, liveUpdates(b));
      await tester.tap(find.text('View on crowd map').first);
      await settle(tester);
      expect(pushed.last.$1, '/liveCroud');
      expect(pushed.last.$2, {'zoneName': 'Ramkund Ghat'});
    });

    testWidgets('refresh repeats the current filter', (tester) async {
      final b = Backend();
      await pumpScreen(tester, liveUpdates(b));
      await tester.tap(find.text('Messages'));
      await settle(tester);
      await tester.tap(find.byTooltip('Refresh'));
      await settle(tester);
      expect(b.log.map((e) => (e as GetNotificationsEvent).type), [
        '',
        'MESSAGE',
        'MESSAGE',
      ]);
    });
  });

  group('layout', () {
    for (final locale in const [Locale('en'), Locale('hi'), Locale('mr')]) {
      for (final br in Brightness.values) {
        for (final s in AppFontScale.values) {
          testWidgets(
            'no overflow: map + updates ${locale.languageCode} ${br.name} ${s.name}',
            (tester) async {
              final b = Backend();
              await pumpScreen(
                tester,
                crowdMap(b),
                locale: locale,
                brightness: br,
                fontScale: s,
                deviceScale: 1.3,
                size: const Size(320, 640),
              );
              await tester.tap(find.text('marker:RK'));
              await settle(tester);
              final sheet = find.descendant(
                of: find.byType(DraggableScrollableSheet),
                matching: find.byType(Scrollable),
              );
              await tester.drag(sheet, const Offset(0, -400));
              await settle(tester);
              for (var i = 0; i < 8; i++) {
                await tester.drag(sheet, const Offset(0, -300));
                await tester.pump(const Duration(milliseconds: 50));
              }
              expect(tester.takeException(), isNull);

              final b2 = Backend();
              await pumpScreen(
                tester,
                liveUpdates(b2),
                locale: locale,
                brightness: br,
                fontScale: s,
                deviceScale: 1.3,
                size: const Size(320, 640),
              );
              for (var i = 0; i < 8; i++) {
                await tester.drag(
                  find.byType(Scrollable).first,
                  const Offset(0, -400),
                );
                await tester.pump(const Duration(milliseconds: 50));
              }
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });
}
