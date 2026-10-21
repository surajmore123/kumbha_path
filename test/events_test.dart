import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/models/featured_model.dart';
import 'package:kumbha_path/src/models/upcoming_events.dart';
import 'package:kumbha_path/src/modules/event/event_detail_screen.dart';
import 'package:kumbha_path/src/modules/event/event_item.dart';
import 'package:kumbha_path/src/modules/event/events.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ------------------------------------------------------------------ fakes

/// Answers with [reply], or never when it returns null.
class FakeDetailsBloc extends AppDetailsBloc {
  final List<AppDetailsEvent> events = [];
  AppDetailsState? Function(AppDetailsState state, AppDetailsEvent e)? reply;

  @override
  void add(AppDetailsEvent event) {
    events.add(event);
    final next = reply?.call(state, event);
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

// ------------------------------------------------------------------- data

/// Fixed "now": 10 Jan 2027, 10:00 local.
final now = DateTime(2027, 1, 10, 10, 0);

const _featured = EventDetailsModel(
  eventId: 'ev-1',
  eventName: 'Pratham Shahi Snan',
  shortDescription: 'First royal bath at Kushavarta Kund.',
  description: 'The first of the three Shahi Snans of the Simhastha.',
  eventCategory: 'SHAHI_SNAN',
  eventDate: '2027-01-22',
  startTime: '04:00:00',
  endTime: '09:00:00',
  isAllDay: false,
  locationName: 'Kushavarta Kund, Trimbakeshwar',
  expectedCrowdLevel: 'HIGH',
);

const _upcoming = [
  // Deliberately out of order; ev-1 duplicates the featured event.
  EventSummaryModel(
    eventId: 'ev-4',
    eventName: 'Ramkund Maha Aarti',
    eventCategory: 'AARTI',
    eventDate: '2027-01-12',
    startTime: '18:30:00',
    endTime: '19:30:00',
    locationName: 'Ramkund, Panchavati',
  ),
  EventSummaryModel(eventId: 'ev-1', eventName: 'Pratham Shahi Snan'),
  EventSummaryModel(
    eventId: 'ev-3',
    eventName: 'Morning Ganga Pujan',
    eventCategory: 'AARTI',
    eventDate: '2027-01-10',
    startTime: '06:00:00',
    endTime: '08:00:00',
  ),
  EventSummaryModel(
    eventId: 'ev-2',
    eventName: 'Sadhu Akhada Procession',
    eventCategory: 'PROCESSION',
    eventDate: '2027-01-10',
    startTime: '09:00:00',
    endTime: '12:00:00',
    description: 'Akhadas walk from Tapovan to Ramkund.',
    expectedCrowdLevel: 'HIGH',
  ),
  EventSummaryModel(eventId: 'ev-5', eventName: 'Kalaram Utsav'),
  EventSummaryModel(eventId: 'ev-4', eventName: 'Ramkund Maha Aarti'),
];

AppDetailsState ok(
  AppDetailsState s, {
  EventDetailsModel? featured,
  List<EventSummaryModel>? upcoming,
}) => s.copyWith(
  status: AppDetailsStatus.success,
  eventDetailsModel: featured,
  upcomingEvents: upcoming,
);

// ---------------------------------------------------------------- harness

class Harness {
  Harness({
    EventDetailsModel featured = _featured,
    List<EventSummaryModel> upcoming = _upcoming,
    bool featuredFails = false,
    bool upcomingFails = false,
  }) {
    featuredBloc.reply =
        (s, _) =>
            featuredFails
                ? s.copyWith(status: AppDetailsStatus.failed)
                : ok(s, featured: featured);
    upcomingBloc.reply =
        (s, _) =>
            upcomingFails
                ? s.copyWith(status: AppDetailsStatus.failed)
                : ok(s, upcoming: upcoming);
    // Reminder API succeeds by default.
    global.reply = (s, e) {
      final r = e as ReminderToggleEvent;
      return s.copyWith(
        status: AppDetailsStatus.success,
        reminderStatus: {...s.reminderStatus, r.eventId: r.action == 'ENABLE'},
      );
    };
  }

  final featuredBloc = FakeDetailsBloc();
  final upcomingBloc = FakeDetailsBloc();
  final global = FakeDetailsBloc();
  bool notificationsBlocked = false;

  List<UpcomingEvent> get upcomingRequests =>
      upcomingBloc.events.cast<UpcomingEvent>();
}

Future<Harness> pumpEvents(
  WidgetTester tester, {
  Harness? harness,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  AppFontScale fontScale = AppFontScale.standard,
  double deviceScale = 1.0,
  Widget? home,
}) async {
  final h = harness ?? Harness();
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
      child: BlocProvider<AppDetailsBloc>.value(
        value: h.global,
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
                home:
                    home ??
                    ShahiEvents(
                      featuredBloc: h.featuredBloc,
                      upcomingBloc: h.upcomingBloc,
                      now: () => now,
                      notificationsBlocked: () async => h.notificationsBlocked,
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

Finder inList(Finder f) =>
    find.descendant(of: find.byType(ListView), matching: f);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('event model', () {
    EventItem item(
      String id,
      String? date, {
      String? start,
      String? end,
      bool allDay = false,
    }) => EventItem(
      id: id,
      name: id,
      date: date,
      startTime: start,
      endTime: end,
      isAllDay: allDay,
    );

    test('chronological, stable, undated last', () {
      final sorted = sortChronologically([
        item('c', '2027-01-12', start: '07:00'),
        item('x', null),
        item('b', '2027-01-10', start: '09:00'),
        item('a', '2027-01-10', allDay: true),
        item('y', 'soon'),
        item('d', '2027-01-12', start: '07:00'),
      ]);
      expect(sorted.map((e) => e.id), ['a', 'b', 'c', 'd', 'x', 'y']);
    });

    test('phases come only from the data', () {
      expect(item('p', '2027-01-09').phaseAt(now), EventPhase.past);
      expect(item('u', '2027-01-11').phaseAt(now), EventPhase.upcoming);
      expect(
        item('o', '2027-01-10', start: '09:00', end: '11:00').phaseAt(now),
        EventPhase.ongoing,
      );
      expect(
        item('l', '2027-01-10', start: '12:00').phaseAt(now),
        EventPhase.upcoming,
      );
      expect(
        item('e', '2027-01-10', start: '06:00', end: '08:00').phaseAt(now),
        EventPhase.past,
      );
      expect(item('t', '2027-01-10').phaseAt(now), EventPhase.today);
      expect(
        item('t2', '2027-01-10', start: '06:00').phaseAt(now),
        EventPhase.today,
      );
      expect(
        item('a', '2027-01-10', allDay: true).phaseAt(now),
        EventPhase.ongoing,
      );
      expect(item('n', null).phaseAt(now), EventPhase.unknown);
    });

    test('dedupe by id and drop featured / unnamed', () {
      final out = dedupeEvents([
        item('a', null),
        item('b', null),
        item('a', null),
        const EventItem(id: 'z', name: ''),
      ], excludeId: 'b');
      expect(out.map((e) => e.id), ['a']);
    });

    test('category codes are prettified, readable text kept', () {
      expect(prettifyCode('SHAHI_SNAN'), 'Shahi Snan');
      expect(prettifyCode('aarti'), 'Aarti');
      expect(prettifyCode('Ganga Aarti'), 'Ganga Aarti');
      expect(prettifyCode(''), isNull);
    });
  });

  group('events screen', () {
    testWidgets('featured + chronological schedule without duplicates', (
      tester,
    ) async {
      final h = await pumpEvents(tester);
      expect(h.featuredBloc.events.single, isA<FeaturedEvent>());
      expect(h.upcomingRequests.single.date, '');

      expect(find.text('Featured event'), findsOneWidget);
      expect(find.text('Pratham Shahi Snan'), findsOneWidget); // not repeated
      expect(find.text('In 12 days'), findsOneWidget);
      expect(find.text('Shahi Snan'), findsOneWidget);
      expect(find.text('Kushavarta Kund, Trimbakeshwar'), findsOneWidget);

      await scrollTo(tester, inList(find.text('Kalaram Utsav')));
      final order = [
        'Morning Ganga Pujan',
        'Sadhu Akhada Procession',
        'Ramkund Maha Aarti',
        'Kalaram Utsav',
      ];
      expect(find.text('Ramkund Maha Aarti'), findsOneWidget); // deduped
      final ys = [for (final t in order) tester.getTopLeft(find.text(t)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
      expect(find.text('Date not announced'), findsOneWidget);
    });

    testWidgets('phases on today: ongoing and concluded', (tester) async {
      await pumpEvents(tester);
      await scrollTo(tester, inList(find.text('Sadhu Akhada Procession')));
      expect(find.text('Happening now'), findsOneWidget); // 09:00–12:00
      expect(find.text('Concluded'), findsOneWidget); // 06:00–08:00
      expect(find.text('Today'), findsOneWidget); // group header
      expect(find.text('In 2 days'), findsOneWidget); // 12 Jan header
    });

    testWidgets('no featured event: schedule still shows', (tester) async {
      await pumpEvents(
        tester,
        harness: Harness(featured: EventDetailsModel.empty),
      );
      expect(find.text('Featured event'), findsNothing);
      expect(find.text('Schedule'), findsOneWidget);
      await scrollTo(tester, inList(find.text('Pratham Shahi Snan')));
    });

    testWidgets('featured failure is contained and retryable', (tester) async {
      final h = await pumpEvents(tester, harness: Harness(featuredFails: true));
      expect(find.text("Couldn't load the featured event."), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      h.featuredBloc.reply = (s, _) => ok(s, featured: _featured);
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(h.featuredBloc.events, hasLength(2));
      expect(h.upcomingRequests, hasLength(1));
      expect(find.text('Featured event'), findsOneWidget);
    });

    testWidgets('schedule failure shows retry', (tester) async {
      final h = await pumpEvents(tester, harness: Harness(upcomingFails: true));
      await scrollTo(tester, find.text('Something went wrong'));
      h.upcomingBloc.reply = (s, _) => ok(s, upcoming: _upcoming);
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(h.upcomingRequests, hasLength(2));
    });

    testWidgets('date filter uses the API date parameter and clears', (
      tester,
    ) async {
      final h = await pumpEvents(tester);
      h.upcomingBloc.reply = (s, _) => ok(s, upcoming: const []);
      await tester.tap(find.byTooltip('Choose a date'));
      await settle(tester);
      await tester.tap(find.text('OK'));
      await settle(tester);

      final d = DateTime.now();
      final iso =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      expect(h.upcomingRequests.last.date, iso);
      await scrollTo(tester, find.textContaining('No events on'));

      await tester.tap(find.text('Show all dates').last);
      await settle(tester);
      expect(h.upcomingRequests.last.date, '');
    });

    testWidgets('category chips filter the loaded events', (tester) async {
      await pumpEvents(tester);
      await scrollTo(tester, find.widgetWithText(ChoiceChip, 'Procession'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Procession'));
      await settle(tester);
      expect(find.text('Sadhu Akhada Procession'), findsOneWidget);
      expect(inList(find.text('Morning Ganga Pujan')), findsNothing);
    });

    testWidgets('a single category shows no chips', (tester) async {
      await pumpEvents(
        tester,
        harness: Harness(
          upcoming: const [
            EventSummaryModel(
              eventId: 'a',
              eventName: 'A',
              eventCategory: 'AARTI',
              eventDate: '2027-01-11',
            ),
          ],
        ),
      );
      expect(find.byType(ChoiceChip), findsNothing);
    });
  });

  group('reminders', () {
    Finder bell(String tooltip) => find.byTooltip(tooltip);

    testWidgets('toggle on and off with feedback; explicit actions', (
      tester,
    ) async {
      final h = await pumpEvents(tester);
      await scrollTo(tester, inList(find.text('Ramkund Maha Aarti')));
      final tile =
          find
              .ancestor(
                of: find.text('Ramkund Maha Aarti'),
                matching: find.byType(Row),
              )
              .first;
      await tester.tap(find.descendant(of: tile, matching: bell('Remind Me')));
      await settle(tester);
      final first = h.global.events.single as ReminderToggleEvent;
      expect((first.eventId, first.action), ('ev-4', 'ENABLE'));
      expect(find.text('Reminder set for Ramkund Maha Aarti'), findsOneWidget);

      await tester.tap(
        find.descendant(of: tile, matching: bell('Disable Reminder')),
      );
      await settle(tester);
      final second = h.global.events.last as ReminderToggleEvent;
      expect((second.eventId, second.action), ('ev-4', 'DISABLE'));
      expect(
        find.text('Reminder turned off for Ramkund Maha Aarti'),
        findsOneWidget,
      );
    });

    testWidgets('failure explains and retries the same action', (tester) async {
      final h = await pumpEvents(tester);
      h.global.reply = (s, _) => s.copyWith(status: AppDetailsStatus.failed);
      await tester.tap(find.widgetWithText(FilledButton, 'Remind Me'));
      await settle(tester);
      expect(
        find.text("Couldn't update the reminder. Please try again."),
        findsOneWidget,
      );
      expect(find.text('Reminder on'), findsNothing);

      h.global.reply =
          (s, e) => s.copyWith(
            status: AppDetailsStatus.success,
            reminderStatus: {(e as ReminderToggleEvent).eventId: true},
          );
      await tester.tap(find.text('Try again'));
      await settle(tester);
      final retry = h.global.events.last as ReminderToggleEvent;
      expect((retry.eventId, retry.action), ('ev-1', 'ENABLE'));
      expect(find.text('Reminder on'), findsOneWidget);
    });

    testWidgets('no response: fails after the timeout', (tester) async {
      final h = await pumpEvents(tester);
      h.global.reply = (_, __) => null;
      await tester.tap(find.widgetWithText(FilledButton, 'Remind Me'));
      await tester.pump(const Duration(seconds: 31));
      await settle(tester);
      expect(
        find.text("Couldn't update the reminder. Please try again."),
        findsOneWidget,
      );
    });

    testWidgets('notifications blocked: says so and offers settings', (
      tester,
    ) async {
      final h = Harness()..notificationsBlocked = true;
      await pumpEvents(tester, harness: h);
      await tester.tap(find.widgetWithText(FilledButton, 'Remind Me'));
      await settle(tester);
      expect(
        find.textContaining('notifications are turned off'),
        findsOneWidget,
      );
      expect(find.text('Open settings'), findsOneWidget);
    });

    testWidgets('concluded events offer no reminder', (tester) async {
      await pumpEvents(tester);
      await scrollTo(tester, inList(find.text('Morning Ganga Pujan')));
      final tile =
          find
              .ancestor(
                of: find.text('Morning Ganga Pujan'),
                matching: find.byType(Row),
              )
              .first;
      expect(
        find.descendant(of: tile, matching: bell('Remind Me')),
        findsNothing,
      );
    });
  });

  group('event detail', () {
    testWidgets('opens from the list with the event\'s own fields', (
      tester,
    ) async {
      await pumpEvents(tester);
      await scrollTo(tester, inList(find.text('Sadhu Akhada Procession')));
      await tester.tap(inList(find.text('Sadhu Akhada Procession')));
      await settle(tester);

      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(find.text('Event details'), findsOneWidget);
      expect(find.text('Happening now'), findsOneWidget);
      expect(find.text('Procession'), findsOneWidget);
      expect(find.text('When'), findsOneWidget);
      expect(find.text('Where'), findsNothing); // API sent no location
      expect(find.text('High'), findsOneWidget);
      expect(
        find.text('Akhadas walk from Tapovan to Ramkund.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Remind Me'), findsOneWidget);
    });

    testWidgets('featured event detail; undated shows "not announced"', (
      tester,
    ) async {
      await pumpEvents(tester);
      await tester.tap(find.text('View details'));
      await settle(tester);
      expect(find.text('Kushavarta Kund, Trimbakeshwar'), findsOneWidget);
      expect(
        find.text('The first of the three Shahi Snans of the Simhastha.'),
        findsOneWidget,
      );

      await tester.pageBack();
      await settle(tester);
      await scrollTo(tester, inList(find.text('Kalaram Utsav')));
      await tester.tap(inList(find.text('Kalaram Utsav')));
      await settle(tester);
      expect(find.text('Date not announced'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final locale in const [Locale('en'), Locale('hi'), Locale('mr')]) {
      for (final b in Brightness.values) {
        for (final s in AppFontScale.values) {
          testWidgets(
            'no overflow: list + detail ${locale.languageCode} ${b.name} ${s.name}',
            (tester) async {
              final long = Harness(
                featured: _featured.copyWith(
                  eventName:
                      'द्वितीय शाही स्नान – त्र्यंबकेश्वर कुशावर्त तीर्थावरील पर्वणी',
                ),
              );
              await pumpEvents(
                tester,
                harness: long,
                locale: locale,
                brightness: b,
                fontScale: s,
                deviceScale: 1.3,
                size: const Size(320, 640),
              );
              for (var i = 0; i < 12; i++) {
                await tester.drag(
                  find.byType(Scrollable).first,
                  const Offset(0, -500),
                );
                await tester.pump(const Duration(milliseconds: 50));
              }
              expect(tester.takeException(), isNull);

              await tester.tap(inList(find.text('Kalaram Utsav')));
              await settle(tester);
              expect(find.byType(EventDetailScreen), findsOneWidget);
              await tester.drag(
                find.byType(Scrollable).first,
                const Offset(0, -800),
              );
              await tester.pump();
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    testWidgets('wide screens center the content', (tester) async {
      await pumpEvents(tester, size: const Size(1280, 900));
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text('Featured event')).dx,
        greaterThan(250),
      );
    });
  });
}
