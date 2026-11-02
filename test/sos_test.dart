import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumbha_path/src/modules/emergency/assistance_screen.dart';
import 'package:kumbha_path/src/modules/emergency/data/emergency_repository.dart';
import 'package:kumbha_path/src/modules/emergency/models/emergency_models.dart';
import 'package:kumbha_path/src/modules/emergency/sos_detail_screen.dart';
import 'package:kumbha_path/src/modules/emergency/sos_screen.dart';
import 'package:kumbha_path/src/modules/emergency/widgets/sos_parts.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart'
    show EmergencyContact;
import 'package:kumbha_path/src/modules/location/data/location_tracker.dart';
import 'package:kumbha_path/src/modules/location/models/location_models.dart';
import 'package:kumbha_path/src/modules/notification_centre/notification_centre_screen.dart';
import 'package:kumbha_path/src/modules/reunion/data/reunion_repository.dart';
import 'package:kumbha_path/src/modules/reunion/models/reunion_models.dart';
import 'package:kumbha_path/src/modules/setting/widgets/notification_preferences_card.dart';
import 'package:kumbha_path/src/services/notification_preferences.dart';
import 'package:kumbha_path/src/services/notification_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_test.dart' as t;
import 'reunion_test.dart' as r;

const offline = FamilyException(FamilyFailure.offline);
const sosId = '3f2b8c1e-7a44-4d19-9f0e-6c1d2a7b4e55';

SosDetail detailOf({
  String role = 'owner',
  String status = 'FAMILY_NOTIFIED',
  bool active = true,
  List<SosRecipient> family = const [],
  DateTime? responder,
  double? lat,
  bool acknowledged = false,
  String resolution = '',
}) => SosDetail(
  id: sosId,
  reference: 'SOS-ABCD2345',
  category: 'medical',
  status: status,
  role: role,
  isActive: active,
  personName: 'Asha More',
  createdAt: DateTime(2026, 11, 1, 10),
  latitude: lat,
  longitude: lat == null ? null : 73.78,
  responderAcknowledgedAt: responder,
  family: family,
  iAcknowledged: acknowledged,
  resolutionNote: resolution,
  timeline: const [
    SosStep(status: 'SUBMITTED', by: 'person'),
    SosStep(status: 'FAMILY_NOTIFIED', by: 'system'),
  ],
);

class FakeSos implements EmergencyRepository {
  SosOverview overviewResult = const SosOverview();
  Object? overviewError;
  Object? createError;
  int failFirst = 0;
  final created = <SosDraft>[];
  final delayed = <bool>[];
  SosDetail result = detailOf();
  Object? detailError;
  final cancelled = <String>[];
  final info = <String>[];
  final places = <Map<String, dynamic>>[];
  int acknowledged = 0;
  int contacts = 0;

  @override
  Future<SosOverview> overview() async {
    final error = overviewError;
    if (error != null) throw error;
    return overviewResult;
  }

  @override
  Future<SosDetail> create(SosDraft draft, {bool delayed = false}) async {
    created.add(draft);
    this.delayed.add(delayed);
    if (failFirst > 0) {
      failFirst--;
      throw offline;
    }
    final error = createError;
    if (error != null) throw error;
    return result;
  }

  @override
  Future<SosDetail> detail(String id) async {
    final error = detailError;
    if (error != null) throw error;
    return result;
  }

  @override
  Future<SosPage> history({bool family = false, int page = 1}) async =>
      const SosPage(rows: []);

  @override
  Future<SosDetail> cancel(String id, String reason) async {
    cancelled.add(reason);
    return detailOf(status: 'CANCELLED', active: false);
  }

  @override
  Future<SosDetail> addInfo(String id, String body) async {
    info.add(body);
    return result;
  }

  @override
  Future<SosDetail> updateLocation(
    String id,
    Map<String, dynamic> place,
  ) async {
    places.add(place);
    return result;
  }

  @override
  Future<SosDetail> acknowledgeAsFamily(String id) async {
    acknowledged++;
    return detailOf(role: 'family', acknowledged: true);
  }

  @override
  Future<String?> contact(String id) async {
    contacts++;
    return '+919000000000';
  }
}

class HangingSource extends t.FakeSource {
  @override
  Future<LocationFix?> current() => Completer<LocationFix?>().future;
}

class FakeNotes implements NotificationRepository {
  List<AppNote> notes = const [];
  Object? error;
  final read = <String>[];
  final all = <String?>[];
  String? lastCategory;
  int unread = 0;

  @override
  Future<NotePage> list({String? category, int page = 1}) async {
    lastCategory = category;
    final failed = error;
    if (failed != null) throw failed;
    return NotePage(
      notes: [
        for (final n in notes)
          if (category == null || n.category == category) n,
      ],
    );
  }

  @override
  Future<int> unreadCount() async => unread;

  @override
  Future<void> markRead(String id) async => read.add(id);

  @override
  Future<void> markAllRead({String? category}) async => all.add(category);
}

class FakePrefs extends NotificationPreferencesApi {
  final changes = <NotificationCategory>[];

  @override
  Future<Map<NotificationCategory, bool>?> load() async => {
    for (final c in NotificationCategory.values) c: true,
  };

  @override
  Future<Map<NotificationCategory, bool>?> update(
    NotificationCategory category,
    bool enabled,
  ) async {
    changes.add(category);
    return {
      for (final c in NotificationCategory.values)
        c: c == category ? enabled : true,
    };
  }
}

const note = AppNote(
  id: 'n1',
  category: 'emergency',
  title: 'Asha More sent an SOS',
  body: 'Medical emergency · SOS-ABCD2345',
  data: {'route': '/sosDetail', 'sos_id': sosId},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    dotenv.loadFromString(envString: 'API_HOST=example.test');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  UnsentSos storeWith(t.MemoryStore store, [String account = 'u1']) =>
      UnsentSos(store: store, account: () async => account);

  Future<(FakeSos, t.MemoryStore, t.FakeSource)> openSos(
    WidgetTester tester, {
    SosOverview overview = const SosOverview(),
    t.FakeSource? source,
    t.MemoryStore? store,
    void Function(FakeSos)? setup,
    List<EmergencyContact> contacts = const [],
  }) async {
    final repo = FakeSos()..overviewResult = overview;
    setup?.call(repo);
    final memory = store ?? t.MemoryStore();
    final gps = source ?? t.FakeSource();
    await t.pumpApp(
      tester,
      SosScreen(
        repository: repo,
        unsent: storeWith(memory),
        source: gps,
        contacts: () async => contacts,
        locationWait: const Duration(milliseconds: 50),
      ),
      size: const Size(1080, 6000),
    );
    return (repo, memory, gps);
  }

  Future<void> hold(WidgetTester tester, Duration time) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SosHoldButton)),
    );
    // A press only registers after Flutter's short tap delay.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(time);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
  }

  Future<void> holdToSend(WidgetTester tester) async {
    await hold(tester, const Duration(seconds: 3));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await t.settle(tester);
  }

  group('activation', () {
    testWidgets('a short press sends nothing', (tester) async {
      final (repo, _, _) = await openSos(tester);
      await hold(tester, const Duration(milliseconds: 500));
      await t.settle(tester);
      expect(repo.created, isEmpty);
      expect(find.byType(SosHoldButton), findsOneWidget);
    });

    testWidgets('holding sends it', (tester) async {
      final (repo, _, _) = await openSos(tester);
      await holdToSend(tester);
      expect(repo.created, hasLength(1));
      expect(find.text('route:/sosDetail'), findsOneWidget);
    });

    testWidgets('there is a way that needs no long press', (tester) async {
      final (repo, _, _) = await openSos(tester);
      await tester.tap(find.text('Can\'t hold? Use a 5 second countdown'));
      await t.settle(tester);
      expect(find.text('5'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await t.settle(tester);
      expect(repo.created, hasLength(1));
    });

    testWidgets('screen readers get the countdown', (tester) async {
      final handle = tester.ensureSemantics();
      await openSos(tester);
      expect(tester.getSemantics(find.byType(SosHoldButton).first), isNotNull);
      expect(
        find.bySemanticsLabel(RegExp('Starts a 5 second countdown')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the countdown can be cancelled', (tester) async {
      final (repo, _, _) = await openSos(tester);
      await tester.tap(find.text('Can\'t hold? Use a 5 second countdown'));
      await t.settle(tester);
      await tester.tap(find.text('Cancel, don\'t send'));
      await t.settle(tester);
      await tester.pump(const Duration(seconds: 7));
      expect(repo.created, isEmpty);
      expect(find.text('Cancelled. Nothing was sent.'), findsOneWidget);
    });
  });

  group('submission', () {
    testWidgets('sends the chosen category', (tester) async {
      final (repo, _, _) = await openSos(tester);
      await tester.tap(find.text('Crowd-related emergency'));
      await t.settle(tester);
      await holdToSend(tester);
      expect(repo.created.single.category, 'crowd');
    });

    testWidgets('includes the position when allowed', (tester) async {
      final source =
          t.FakeSource()
            ..reading = t.fixAt(DateTime.utc(2026, 11, 1, 10), lat: 19.9975);
      final (repo, _, _) = await openSos(tester, source: source);
      await holdToSend(tester);
      expect(repo.created.single.latitude, 19.9975);
      expect(repo.created.single.accuracyM, 12);
      expect(repo.created.single.locationAt, DateTime.utc(2026, 11, 1, 10));
    });

    testWidgets('denied location still sends, without a prompt', (
      tester,
    ) async {
      final source = t.FakeSource()..permit = LocationPermit.denied;
      final (repo, _, _) = await openSos(tester, source: source);
      await holdToSend(tester);
      expect(repo.created.single.latitude, isNull);
      expect(source.requests, 0);
    });

    testWidgets('slow GPS can\'t hold up an SOS', (tester) async {
      final (repo, _, _) = await openSos(tester, source: HangingSource());
      await holdToSend(tester);
      expect(repo.created.single.latitude, isNull);
    });

    testWidgets('it never starts tracking', (tester) async {
      final source = t.FakeSource()..reading = t.fixAt(DateTime(2026));
      await openSos(tester, source: source);
      await holdToSend(tester);
      expect(source.watching, 0);
    });

    testWidgets('a description can be sent instead', (tester) async {
      final (repo, _, _) = await openSos(tester);
      await tester.enterText(find.byType(TextField).first, 'Near gate 3');
      await holdToSend(tester);
      expect(repo.created.single.locationText, 'Near gate 3');
    });

    testWidgets('a dropped request retries with the same id', (tester) async {
      final (repo, _, _) = await openSos(tester, setup: (s) => s.failFirst = 1);
      await holdToSend(tester);
      expect(repo.created, hasLength(2));
      expect(repo.created[0].clientId, repo.created[1].clientId);
      expect(find.text('route:/sosDetail'), findsOneWidget);
    });

    testWidgets('an open SOS is shown rather than a second one', (
      tester,
    ) async {
      await openSos(
        tester,
        setup: (s) => s.createError = const SosAlreadyActive(sosId),
      );
      await holdToSend(tester);
      expect(find.text('route:/sosDetail'), findsOneWidget);
    });
  });

  group('offline', () {
    testWidgets('says plainly that nothing was sent', (tester) async {
      final (_, store, _) = await openSos(
        tester,
        setup: (s) => s.failFirst = 9,
      );
      await holdToSend(tester);
      expect(find.text('Your SOS was not sent'), findsOneWidget);
      expect(find.textContaining('has not been told'), findsOneWidget);
      expect(find.text('Call 112 directly'), findsOneWidget);
      expect(store.values, hasLength(1));
    });

    testWidgets('the retry uses the same id', (tester) async {
      final (repo, _, _) = await openSos(tester, setup: (s) => s.failFirst = 2);
      await holdToSend(tester);
      await tester.tap(find.text('Try again'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.settle(tester);
      expect(repo.created.map((d) => d.clientId).toSet(), hasLength(1));
      expect(find.text('route:/sosDetail'), findsOneWidget);
    });

    testWidgets('a saved SOS is never sent by itself', (tester) async {
      final store = t.MemoryStore();
      await storeWith(store).save(
        SosDraft(clientId: 'c1', category: 'lost', writtenAt: DateTime(2026)),
      );
      final (repo, _, _) = await openSos(tester, store: store);
      expect(find.text('An SOS was not sent'), findsOneWidget);
      expect(find.textContaining('Nobody has been told'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(repo.created, isEmpty);
    });

    testWidgets('sending a saved one needs confirming, and is marked late', (
      tester,
    ) async {
      final store = t.MemoryStore();
      await storeWith(store).save(
        SosDraft(clientId: 'c1', category: 'lost', writtenAt: DateTime(2026)),
      );
      final (repo, _, _) = await openSos(tester, store: store);
      await tester.tap(find.text('Send it now'));
      await t.settle(tester);
      expect(find.text('Is this still an emergency?'), findsOneWidget);
      expect(repo.created, isEmpty);
      await tester.tap(find.text('Send it now').last);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.settle(tester);
      expect(repo.delayed.single, isTrue);
      expect(store.values, isEmpty);
    });

    testWidgets('a saved one can be discarded', (tester) async {
      final store = t.MemoryStore();
      await storeWith(store).save(
        SosDraft(clientId: 'c1', category: 'lost', writtenAt: DateTime(2026)),
      );
      await openSos(tester, store: store);
      await tester.tap(find.text('Discard'));
      await t.settle(tester);
      await tester.tap(find.text('Discard').last);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.settle(tester);
      expect(store.values, isEmpty);
      expect(find.text('An SOS was not sent'), findsNothing);
    });

    test('another account can\'t see it', () async {
      final store = t.MemoryStore();
      await storeWith(store).save(
        SosDraft(clientId: 'c1', category: 'lost', writtenAt: DateTime(2026)),
      );
      expect(await storeWith(store, 'u2').load(), isNull);
      expect(await storeWith(store).load(), isNotNull);
    });

    test('the request only says it was late when it was', () {
      final draft = SosDraft(
        clientId: 'c',
        category: 'lost',
        writtenAt: DateTime(2026),
      );
      expect(draft.toRequest().containsKey('written_at'), isFalse);
      expect(draft.toRequest(delayed: true).containsKey('written_at'), isTrue);
    });
  });

  group('sos screen', () {
    testWidgets('says it doesn\'t call emergency services', (tester) async {
      await openSos(tester);
      expect(find.textContaining('does not call the police'), findsOneWidget);
    });

    testWidgets('112 works with no connection, behind a confirmation', (
      tester,
    ) async {
      await openSos(tester, setup: (s) => s.overviewError = offline);
      await tester.tap(find.text('Call 112 directly'));
      await t.settle(tester);
      expect(find.text('Call 112?'), findsOneWidget);
      expect(
        find.textContaining('separate from a Kumbh Path SOS'),
        findsOneWidget,
      );
    });

    testWidgets('names who will be told', (tester) async {
      await openSos(
        tester,
        overview: const SosOverview(family: ['Suresh More', 'Ravi More']),
      );
      expect(find.text('Suresh More, Ravi More'), findsOneWidget);
    });

    testWidgets('says when nobody would be told', (tester) async {
      await openSos(tester);
      expect(find.textContaining('no relative will be told'), findsOneWidget);
    });

    testWidgets('saved contacts never show the number', (tester) async {
      await openSos(
        tester,
        contacts: const [
          EmergencyContact(id: 'c', name: 'Ravi', mobile: '9000000000'),
        ],
      );
      expect(find.text('Ravi'), findsOneWidget);
      expect(find.textContaining('9000000000'), findsNothing);
    });

    testWidgets('opening it never prompts for location', (tester) async {
      final source = t.FakeSource()..permit = LocationPermit.denied;
      await openSos(tester, source: source);
      expect(source.requests, 0);
      expect(find.textContaining('without it'), findsOneWidget);
    });

    testWidgets('an active SOS replaces the button', (tester) async {
      await openSos(
        tester,
        overview: const SosOverview(
          active: SosRow(
            id: sosId,
            reference: 'SOS-ABCD2345',
            category: 'lost',
            status: 'FAMILY_NOTIFIED',
            isActive: true,
          ),
        ),
      );
      expect(find.byType(SosHoldButton), findsNothing);
      expect(find.text('Active SOS SOS-ABCD2345'), findsOneWidget);
    });
  });

  group('details', () {
    Future<FakeSos> open(
      WidgetTester tester,
      SosDetail detail, {
      t.FakeSource? source,
      Object? error,
    }) async {
      final repo =
          FakeSos()
            ..result = detail
            ..detailError = error;
      await t.pumpApp(
        tester,
        SosDetailScreen(
          id: sosId,
          repository: repo,
          source: source ?? t.FakeSource(),
        ),
        size: const Size(1080, 6000),
      );
      return repo;
    }

    Future<void> leave(WidgetTester tester) =>
        tester.pumpWidget(const SizedBox());

    testWidgets('each stage is its own line', (tester) async {
      await open(
        tester,
        detailOf(
          family: [
            SosRecipient(
              name: 'Suresh',
              notification: 'sent',
              reachedAppAt: DateTime(2026),
              acknowledgedAt: DateTime(2026),
            ),
            const SosRecipient(name: 'Ravi', notification: 'sent'),
            const SosRecipient(name: 'Meera', notification: 'no_device'),
          ],
        ),
      );
      expect(find.text('Your SOS is saved on our server'), findsOneWidget);
      expect(
        find.text('Notification sent to 2 of 3 family members'),
        findsOneWidget,
      );
      expect(find.text('Reached the app of 1 of 3'), findsOneWidget);
      expect(
        find.text('Seen and acknowledged by 1 of 3 family members'),
        findsOneWidget,
      );
      expect(
        find.text('No responder has acknowledged this yet'),
        findsOneWidget,
      );
      expect(find.text('No phone registered'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('family acknowledging is never a responder', (tester) async {
      await open(
        tester,
        detailOf(
          family: [
            SosRecipient(name: 'Suresh', acknowledgedAt: DateTime(2026)),
          ],
        ),
      );
      expect(
        find.text('No responder has acknowledged this yet'),
        findsOneWidget,
      );
      expect(find.textContaining('Acknowledged by a responder'), findsNothing);
      await leave(tester);
    });

    testWidgets('sent is explained as not seen', (tester) async {
      await open(tester, detailOf());
      expect(
        find.textContaining('doesn\'t mean anyone has seen it'),
        findsOneWidget,
      );
      await leave(tester);
    });

    testWidgets('warns no emergency service was contacted', (tester) async {
      await open(tester, detailOf());
      expect(find.textContaining('does not call the police'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('family can acknowledge and call, not manage', (tester) async {
      final repo = await open(tester, detailOf(role: 'family', lat: 19.9));
      expect(find.text('Cancel this SOS'), findsNothing);
      expect(find.text('Add information'), findsNothing);
      await tester.tap(find.text('I\'ve seen this'));
      await t.settle(tester);
      expect(repo.acknowledged, 1);
      await leave(tester);
    });

    testWidgets('the number is only fetched to dial', (tester) async {
      final repo = await open(tester, detailOf(role: 'family'));
      expect(repo.contacts, 0);
      await tester.tap(find.text('Call Asha More'));
      await t.settle(tester);
      expect(repo.contacts, 1);
      expect(find.textContaining('900000'), findsNothing);
      await leave(tester);
    });

    testWidgets('cancelling needs a reason', (tester) async {
      final repo = await open(tester, detailOf());
      await tester.tap(find.text('Cancel this SOS'));
      await t.settle(tester);
      expect(find.text('Why are you cancelling?'), findsOneWidget);
      await tester.tap(find.text('Cancel this SOS').last);
      await t.settle(tester);
      expect(repo.cancelled, isEmpty);
      await leave(tester);
    });

    testWidgets('cancelling with a reason goes through', (tester) async {
      final repo = await open(tester, detailOf());
      await tester.tap(find.text('Cancel this SOS'));
      await t.settle(tester);
      await tester.enterText(find.byType(TextField), 'Pressed by mistake');
      await tester.tap(find.text('Cancel this SOS').last);
      await t.settle(tester);
      expect(repo.cancelled, ['Pressed by mistake']);
      expect(find.text('Cancelled'), findsWidgets);
      await leave(tester);
    });

    testWidgets('sending the location again is one reading', (tester) async {
      final source = t.FakeSource()..reading = t.fixAt(DateTime(2026));
      final repo = await open(tester, detailOf(), source: source);
      await tester.tap(find.text('Send my location again'));
      await t.settle(tester);
      expect(repo.places, hasLength(1));
      expect(source.watching, 0);
      await leave(tester);
    });

    testWidgets('with no GPS it asks for a description', (tester) async {
      final source =
          t.FakeSource()
            ..permit = LocationPermit.blocked
            ..afterRequest = LocationPermit.blocked;
      final repo = await open(tester, detailOf(), source: source);
      await tester.tap(find.text('Send my location again'));
      await t.settle(tester);
      await tester.enterText(find.byType(TextField), 'Near gate 3');
      await tester.tap(find.text('Send'));
      await t.settle(tester);
      expect(repo.places.single, {'location_text': 'Near gate 3'});
      await leave(tester);
    });

    testWidgets('a position is labelled as sent once', (tester) async {
      await open(tester, detailOf(lat: 19.9));
      expect(find.text('Sent once. It isn\'t live.'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('the timeline says who did what', (tester) async {
      await open(tester, detailOf());
      expect(find.textContaining('By the person who sent it'), findsOneWidget);
      expect(find.textContaining('Automatic'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('an ended SOS offers no actions', (tester) async {
      await open(
        tester,
        detailOf(
          status: 'RESOLVED',
          active: false,
          resolution: 'With family at the desk',
        ),
      );
      expect(find.text('Cancel this SOS'), findsNothing);
      expect(find.text('With family at the desk'), findsOneWidget);
    });

    testWidgets('a failed load still offers the call', (tester) async {
      await open(tester, detailOf(), error: offline);
      expect(find.text('Call 112 directly'), findsOneWidget);
    });
  });

  group('history', () {
    testWidgets('empty is said plainly', (tester) async {
      await t.pumpApp(tester, SosHistoryScreen(repository: FakeSos()));
      expect(find.text('Nothing here'), findsOneWidget);
    });
  });

  group('assistance', () {
    Future<void> open(
      WidgetTester tester,
      List<MeetingPoint> points, {
      Object? error,
    }) => t.pumpApp(
      tester,
      AssistanceScreen(
        repository:
            r.FakeReunion()
              ..pointList = points
              ..pointsError = error,
        position: () async => null,
      ),
      size: const Size(1080, 3600),
    );

    testWidgets('shows only verified assistance places', (tester) async {
      await open(tester, [
        r.pointOf(name: 'Camp', category: 'medical'),
        r.tree,
        r.familySpot,
        r.pointOf(
          id: 'x',
          name: 'Unverified desk',
          status: 'community',
          verified: false,
        ),
      ]);
      expect(find.text('Camp'), findsOneWidget);
      expect(find.text('Banyan tree'), findsNothing);
      expect(find.text('Tea stall'), findsNothing);
      expect(find.text('Unverified desk'), findsNothing);
    });

    testWidgets('no data is said plainly, with the call', (tester) async {
      await open(tester, const []);
      expect(find.textContaining('aren\'t available yet'), findsOneWidget);
      expect(find.text('Call 112 directly'), findsOneWidget);
    });

    testWidgets('offline uses the dated copy', (tester) async {
      await const SavedPoints().save([r.pointOf()]);
      await open(tester, const [], error: offline);
      expect(find.text('Ramkund Help Desk'), findsOneWidget);
      expect(find.textContaining('This may be out of date'), findsOneWidget);
    });

    test('reads address and categories', () {
      expect(pointCategories, containsAll(['ambulance', 'fire_rescue']));
      final point = MeetingPoint.fromJson({
        'id': 'p',
        'latitude': 1,
        'longitude': 2,
        'address': 'Main road',
      });
      expect(point.address, 'Main road');
    });
  });

  group('repository', () {
    test('an open SOS comes back as its id', () async {
      final client = HttpEmergencyRepository(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'errors': {
                'non_field_errors': ['x'],
                'active_id': sosId,
              },
            }),
            409,
          ),
        ),
        token: () async => 'token',
        requireHttps: false,
      );
      await expectLater(
        client.create(
          SosDraft(clientId: 'c', category: 'lost', writtenAt: DateTime(2026)),
        ),
        throwsA(isA<SosAlreadyActive>()),
      );
    });

    test('a network failure is reported as one', () async {
      final client = HttpEmergencyRepository(
        client: MockClient((_) async => throw http.ClientException('offline')),
        token: () async => 'token',
        requireHttps: false,
      );
      await expectLater(
        client.overview(),
        throwsA(
          isA<FamilyException>().having(
            (e) => e.kind,
            'kind',
            FamilyFailure.offline,
          ),
        ),
      );
    });

    test('the position goes in the body', () async {
      late http.Request sent;
      final client = HttpEmergencyRepository(
        client: MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'data': {
                'id': sosId,
                'reference': 'SOS-1',
                'category': 'lost',
                'status': 'SUBMITTED',
                'role': 'owner',
              },
            }),
            201,
          );
        }),
        token: () async => 'token',
        requireHttps: false,
      );
      await client.create(
        SosDraft(
          clientId: 'c',
          category: 'lost',
          writtenAt: DateTime(2026),
          latitude: 19.123456,
          longitude: 73.7,
        ),
      );
      expect(sent.url.toString(), isNot(contains('19.12')));
      expect(sent.body, contains('19.123456'));
    });
  });

  group('notification centre', () {
    Future<FakeNotes> open(
      WidgetTester tester, {
      List<AppNote> notes = const [],
      Object? error,
      void Function(Map<String, dynamic>)? onOpen,
    }) async {
      final repo =
          FakeNotes()
            ..notes = notes
            ..error = error;
      await t.pumpApp(
        tester,
        NotificationCentreScreen(repository: repo, onOpen: onOpen ?? (_) {}),
      );
      return repo;
    }

    testWidgets('lists notifications with their category', (tester) async {
      await open(tester, notes: const [note]);
      expect(find.text('Asha More sent an SOS'), findsOneWidget);
      expect(find.textContaining('Emergency SOS'), findsWidgets);
    });

    testWidgets('empty is said plainly', (tester) async {
      await open(tester);
      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    testWidgets('an error offers a retry', (tester) async {
      await open(tester, error: offline);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('opening marks it read and goes to it', (tester) async {
      Map<String, dynamic>? opened;
      final repo = await open(
        tester,
        notes: const [note],
        onOpen: (data) => opened = data,
      );
      expect(find.byIcon(Icons.circle), findsOneWidget);
      await tester.tap(find.text('Asha More sent an SOS'));
      await t.settle(tester);
      expect(repo.read, ['n1']);
      expect(opened!['sos_id'], sosId);
      expect(find.byIcon(Icons.circle), findsNothing);
    });

    testWidgets('mark all as read', (tester) async {
      final repo = await open(tester, notes: const [note]);
      await tester.tap(find.byTooltip('Mark all as read'));
      await t.settle(tester);
      expect(repo.all, [null]);
      expect(find.byIcon(Icons.circle), findsNothing);
      expect(find.byTooltip('Mark all as read'), findsNothing);
    });

    testWidgets('filters by category', (tester) async {
      final repo = await open(tester, notes: const [note]);
      await tester.tap(find.text('Lost & Found').first);
      await t.settle(tester);
      expect(repo.lastCategory, 'lost_found');
      expect(find.text('Asha More sent an SOS'), findsNothing);
    });

    testWidgets('a send that failed says so', (tester) async {
      await open(
        tester,
        notes: const [
          AppNote(
            id: 'n2',
            category: 'emergency',
            title: 'T',
            body: 'B',
            delivery: 'failed',
          ),
        ],
      );
      expect(find.text('Couldn\'t be pushed to your phone'), findsOneWidget);
    });

    testWidgets('the bell shows the unread count', (tester) async {
      await t.pumpApp(
        tester,
        Scaffold(
          appBar: AppBar(
            actions: [NotificationBell(repository: FakeNotes()..unread = 3)],
          ),
        ),
      );
      expect(find.text('3'), findsOneWidget);
      expect(find.byTooltip('3 unread notifications'), findsOneWidget);
    });

    testWidgets('no count shows no badge', (tester) async {
      await t.pumpApp(
        tester,
        Scaffold(
          appBar: AppBar(actions: [NotificationBell(repository: FakeNotes())]),
        ),
      );
      expect(find.text('0'), findsNothing);
    });
  });

  group('preferences', () {
    Future<FakePrefs> open(WidgetTester tester) async {
      final api = FakePrefs();
      await t.pumpApp(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: NotificationPreferencesCard(api: api),
          ),
        ),
        size: const Size(1080, 4800),
      );
      return api;
    }

    testWidgets('emergency alerts have no switch', (tester) async {
      await open(tester);
      expect(find.text('Emergency SOS'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(
        find.widgetWithText(SwitchListTile, 'Emergency SOS'),
        findsNothing,
      );
    });

    testWidgets('turning off safety alerts asks first', (tester) async {
      final api = await open(tester);
      await tester.tap(find.text('Safety alerts'));
      await t.settle(tester);
      expect(find.text('Turn off safety alerts?'), findsOneWidget);
      expect(api.changes, isEmpty);
      await tester.tap(find.text('Turn off'));
      await t.settle(tester);
      expect(api.changes, [NotificationCategory.safetyAlerts]);
    });

    testWidgets('other categories change straight away', (tester) async {
      final api = await open(tester);
      await tester.tap(find.text('Family location'));
      await t.settle(tester);
      expect(api.changes, [NotificationCategory.familyLocation]);
    });
  });

  group('routing and text', () {
    test('an emergency opens its own screen', () {
      final data = {'type': 'emergency_sos', 'sos_id': sosId};
      expect(NotificationRouter.routeFor(data), '/sosDetail');
      expect(NotificationRouter.argumentsFor('/sosDetail', data), sosId);
    });

    test('a bad id opens nothing', () {
      expect(
        NotificationRouter.argumentsFor('/sosDetail', {'sos_id': 'nonsense'}),
        isNull,
      );
    });

    Map<String, dynamic> language(String code) =>
        json.decode(File('assets/translations/$code.json').readAsStringSync())
            as Map<String, dynamic>;

    test('every key exists in all three languages, and none is empty', () {
      bool ours(String k) => k.startsWith('sos_') || k.startsWith('note_');
      final en = language('en').keys.where(ours).toSet();
      for (final code in ['hi', 'mr']) {
        final other = language(code);
        expect(other.keys.where(ours).toSet(), en);
        for (final key in en) {
          expect('${other[key]}'.trim(), isNotEmpty, reason: '$code $key');
        }
      }
    });

    test('every key used in code exists', () {
      final en = language('en');
      final used = <String>{};
      for (final dir in [
        'lib/src/modules/emergency',
        'lib/src/modules/notification_centre',
      ]) {
        for (final file
            in Directory(dir).listSync(recursive: true).whereType<File>()) {
          used.addAll(
            RegExp(
              r"'((?:sos|note)_[a-z_]+)'",
            ).allMatches(file.readAsStringSync()).map((m) => m.group(1)!),
          );
        }
      }
      for (final c in sosCategories) {
        used.add('sos_cat_$c');
      }
      for (final s in [
        'CREATED',
        'SUBMITTED',
        'FAMILY_NOTIFIED',
        'ACKNOWLEDGED',
        'ASSISTANCE_COORDINATED',
        'RESOLVED',
        'CANCELLED',
        'CLOSED',
      ]) {
        used
          ..add('sos_status_$s')
          ..add('sos_status_${s}_means');
      }
      for (final by in ['system', 'person', 'responder']) {
        used.add('sos_by_$by');
      }
      for (final kind in ['person', 'location', 'responder', 'internal']) {
        used.add('sos_note_$kind');
      }
      for (final state in ['pending', 'sent', 'no_device', 'failed']) {
        used.add('sos_person_$state');
      }
      for (final c in noteCategories) {
        used.add('note_cat_$c');
      }
      // A secure-storage key, not text.
      used.remove('sos_unsent');
      expect(used.where((k) => !en.containsKey(k)), isEmpty);
    });

    test('no text claims help was dispatched', () {
      for (final code in ['en']) {
        final en = language(code);
        for (final entry in en.entries.where((e) => e.key.startsWith('sos_'))) {
          final text = '${entry.value}'.toLowerCase();
          expect(text, isNot(contains('help is on the way')));
          expect(text, isNot(contains('dispatched')));
          expect(text, isNot(contains('police have been')));
        }
      }
    });

    test('nothing here prints', () {
      for (final dir in [
        'lib/src/modules/emergency',
        'lib/src/modules/notification_centre',
      ]) {
        for (final file
            in Directory(dir).listSync(recursive: true).whereType<File>()) {
          expect(file.readAsStringSync(), isNot(contains('print(')));
        }
      }
    });
  });
}
