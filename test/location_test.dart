import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumbha_path/src/components/maps/app_map.dart';
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/family_home_screen.dart'
    show FamilyArgs;
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:kumbha_path/src/modules/location/data/location_repository.dart';
import 'package:kumbha_path/src/modules/location/data/location_tracker.dart';
import 'package:kumbha_path/src/modules/location/family_map_screen.dart';
import 'package:kumbha_path/src/modules/location/location_sharing_screen.dart';
import 'package:kumbha_path/src/modules/location/models/location_models.dart';
import 'package:kumbha_path/src/modules/location/widgets/location_parts.dart';
import 'package:kumbha_path/src/modules/location/widgets/shared_location_note.dart';
import 'package:kumbha_path/src/services/notification_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    return json.decode(await file.readAsString()) as Map<String, dynamic>;
  }
}

const offline = FamilyException(FamilyFailure.offline);

LocationFix fixAt(DateTime at, {double lat = 19.9975}) => LocationFix(
  latitude: lat,
  longitude: 73.7898,
  capturedAt: at,
  accuracyM: 12,
);

SharingSession sessionOf({
  String id = 's1',
  String status = 'active',
  int remaining = 3600,
  bool fromMe = true,
  int seconds = 30,
  List<SharingRecipient> recipients = const [
    SharingRecipient(memberId: 'm2', name: 'Suresh More'),
  ],
}) => SharingSession(
  id: id,
  memberId: 'm1',
  memberName: 'Asha More',
  status: status,
  remainingSeconds: remaining,
  reportsFromMe: fromMe,
  recipients: recipients,
  updateSeconds: seconds,
);

LocationPerson personOf({
  String id = 'm2',
  String name = 'Suresh More',
  String state = 'live',
  int? age = 10,
  int remaining = 3000,
  double? lat = 19.9975,
  DateTime? fetchedAt,
  String? caseId,
}) => LocationPerson(
  memberId: id,
  name: name,
  state: state,
  remainingSeconds: remaining,
  fetchedAt: fetchedAt ?? DateTime.now(),
  ageSeconds: age,
  accuracyM: lat == null ? null : 14,
  latitude: lat,
  longitude: lat == null ? null : 73.7898,
  caseId: caseId,
  caseReference: caseId == null ? null : 'LF-ABCD2345',
);

class FakeSource implements PositionSource {
  LocationPermit permit = LocationPermit.allowed;
  LocationPermit afterRequest = LocationPermit.allowed;
  bool notifications = true;
  int requests = 0;
  int watching = 0;
  LocationFix? reading;
  StreamController<LocationFix>? stream;

  bool get isOn => stream != null;

  @override
  Future<LocationPermit> check() async => permit;

  @override
  Future<LocationPermit> request() async {
    requests++;
    return permit = afterRequest;
  }

  @override
  Future<bool> notificationsAllowed() async => notifications;

  @override
  Stream<LocationFix> watch({
    required int distanceMetres,
    required int seconds,
    required String title,
    required String text,
  }) {
    watching++;
    final controller = StreamController<LocationFix>(
      onCancel: () => stream = null,
    );
    stream = controller;
    return controller.stream;
  }

  @override
  Future<LocationFix?> current() async => reading;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

class MemoryStore implements TrackerStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    value == null ? values.remove(key) : values[key] = value;
  }
}

class FakeRepo implements LocationRepository {
  final sent = <LocationFix>[];
  final stopped = <String>[];
  Object? sendError;
  Object? stopError;
  Object? feedError;
  Object? sessionError;
  SharingSession? current;
  LocationFeed feedResult = const LocationFeed(people: []);
  List<SharingSession> open = [];
  LocationPerson? caseResult;
  int feedCalls = 0;
  Map<String, dynamic>? started;
  List<String>? newRecipients;
  EligibleViewers viewers = const EligibleViewers(
    people: [
      EligibleViewer(memberId: 'm2', name: 'Suresh More'),
      EligibleViewer(memberId: 'm3', name: 'Ravi More'),
    ],
  );

  @override
  Future<bool> sendUpdate(String id, LocationFix fix) async {
    final error = sendError;
    if (error != null) throw error;
    sent.add(fix);
    return true;
  }

  @override
  Future<SharingSession> stop(String id) async {
    final error = stopError;
    if (error != null) throw error;
    stopped.add(id);
    return sessionOf(id: id, status: 'stopped', remaining: 0);
  }

  @override
  Future<SharingSession> pause(String id) async =>
      sessionOf(id: id, status: 'paused');

  @override
  Future<SharingSession> resume(String id) async => sessionOf(id: id);

  @override
  Future<SharingSession> session(String id) async {
    final error = sessionError;
    if (error != null) throw error;
    return current ?? sessionOf(id: id);
  }

  @override
  Future<LocationFeed> feed(String familyId) async {
    feedCalls++;
    final error = feedError;
    if (error != null) throw error;
    return feedResult;
  }

  @override
  Future<List<SharingSession>> sessions(String familyId) async => open;

  @override
  Future<EligibleViewers> eligible(String familyId, {String? memberId}) async =>
      viewers;

  @override
  Future<SharingSession> start(
    String familyId, {
    required bool consent,
    required List<String> recipientIds,
    String? memberId,
    int? minutes,
    bool untilStopped = false,
  }) async {
    started = {
      'consent': consent,
      'recipients': recipientIds,
      'member': memberId,
      'minutes': minutes,
      'until': untilStopped,
    };
    return sessionOf();
  }

  @override
  Future<SharingSession> setRecipients(String id, List<String> ids) async {
    newRecipients = ids;
    return sessionOf(id: id);
  }

  @override
  Future<SharingSession> changeDuration(
    String id, {
    int? minutes,
    bool untilStopped = false,
  }) async => sessionOf(id: id, remaining: (minutes ?? 720) * 60);

  @override
  Future<LocationPerson?> caseLocation(String caseId) async => caseResult;
}

class FakeFamily implements FamilyRepository {
  FakeFamily({this.memberList = const [], this.circleList});

  final List<FamilyMember> memberList;
  final List<FamilyCircle>? circleList;

  @override
  Future<List<FamilyCircle>> circles() async => circleList ?? const [];

  @override
  Future<List<FamilyMember>> members(String familyId) async => memberList;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const circle = FamilyCircle(id: 'f1', name: 'More Family', myMemberId: 'm1');

const me = FamilyMember(
  id: 'm1',
  name: 'Asha More',
  kind: 'adult_member',
  role: 'member',
  relationship: 'self',
  isDependent: false,
);

const otherAdult = FamilyMember(
  id: 'm3',
  name: 'Ravi More',
  kind: 'adult_member',
  role: 'member',
  relationship: 'sibling',
  isDependent: false,
  permissions: MemberPermissions(editProfile: true),
);

const child = FamilyMember(
  id: 'm4',
  name: 'Aarav More',
  kind: 'dependent_child',
  role: 'member',
  relationship: 'son',
  isDependent: true,
  permissions: MemberPermissions(editProfile: true),
);

({
  LocationTracker tracker,
  FakeSource source,
  FakeRepo repo,
  MemoryStore store,
  StreamController<bool> online,
})
makeTracker({DateTime Function()? clock}) {
  final source = FakeSource();
  final repo = FakeRepo();
  final store = MemoryStore();
  final online = StreamController<bool>.broadcast();
  final tracker = LocationTracker(
    repository: repo,
    source: source,
    store: store,
    online: online.stream,
    clock: clock,
  );
  return (
    tracker: tracker,
    source: source,
    repo: repo,
    store: store,
    online: online,
  );
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> pumpApp(WidgetTester tester, Widget child, {Size? size}) async {
  tester.view.physicalSize = size ?? const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        saveLocale: false,
        assetLoader: const _FileAssetLoader(),
        child: Builder(
          builder:
              (context) => MaterialApp(
                theme: AppTheme.light,
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                onGenerateRoute:
                    (s) => MaterialPageRoute(
                      settings: s,
                      builder: (_) => Scaffold(body: Text('route:${s.name}')),
                    ),
                home: child,
              ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
  });
  // Translations load from disk, which takes longer on a busy machine, so
  // wait for the screen itself as well as a fixed time.
  for (var i = 0; i < 200 && find.byWidget(child).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
  await settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    dotenv.loadFromString(envString: 'API_HOST=example.test');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    LocationMarkers.debugPlain = true;
  });

  group('freshness', () {
    final at = DateTime(2026, 11, 1, 10);

    test('follows the age of the fix', () {
      expect(personOf(age: 10, fetchedAt: at).freshnessAt(at), Freshness.live);
      expect(
        personOf(age: 300, fetchedAt: at).freshnessAt(at),
        Freshness.recent,
      );
      expect(
        personOf(age: 900, fetchedAt: at).freshnessAt(at),
        Freshness.lastKnown,
      );
    });

    test('live goes stale by itself with no new data', () {
      final person = personOf(age: 10, fetchedAt: at);
      final later = at.add(const Duration(minutes: 5));
      expect(person.freshnessAt(later), Freshness.recent);
      expect(
        person.freshnessAt(at.add(const Duration(minutes: 20))),
        Freshness.lastKnown,
      );
    });

    test('no position is unavailable, never a guess', () {
      expect(
        personOf(age: null, lat: null, fetchedAt: at).freshnessAt(at),
        Freshness.unavailable,
      );
    });

    test('paused stays paused', () {
      expect(
        personOf(
          state: 'paused',
          age: null,
          lat: null,
          fetchedAt: at,
        ).freshnessAt(at),
        Freshness.paused,
      );
    });

    test('an expired person leaves the screen even offline', () {
      final feed = LocationFeed(
        people: [personOf(remaining: 60, fetchedAt: at)],
      );
      expect(feed.visibleAt(at), hasLength(1));
      expect(feed.visibleAt(at.add(const Duration(minutes: 2))), isEmpty);
    });

    test('a fix sends its real time', () {
      final body = fixAt(DateTime.utc(2026, 11, 1, 10)).toJson();
      expect(body['captured_at'], startsWith('2026-11-01T10:00:00'));
      expect(body['latitude'], '19.997500');
    });
  });

  group('tracker', () {
    test('collects nothing until a session begins', () async {
      final t = makeTracker();
      await t.tracker.start();
      expect(t.source.isOn, isFalse);
      expect(t.tracker.state, TrackerState.idle);
      t.tracker.dispose();
    });

    test('collects during a session and stops with it', () async {
      final t = makeTracker();
      await t.tracker.start();
      await t.tracker.begin(sessionOf());
      expect(t.source.isOn, isTrue);
      expect(t.tracker.state, TrackerState.sharing);
      expect(await t.tracker.stop('s1'), isTrue);
      expect(t.source.isOn, isFalse);
      expect(t.repo.stopped, ['s1']);
      expect(t.store.values, isEmpty);
      t.tracker.dispose();
    });

    test('sends a position with the time it was taken', () async {
      final t = makeTracker();
      await t.tracker.begin(sessionOf());
      final taken = DateTime.utc(2026, 11, 1, 9, 30);
      t.source.stream!.add(fixAt(taken));
      await pumpEventQueue();
      expect(t.repo.sent.single.capturedAt, taken);
      t.tracker.dispose();
    });

    test('respects the interval between sends', () async {
      final now = DateTime(2026, 11, 1, 10);
      final t = makeTracker(clock: () => now);
      await t.tracker.begin(sessionOf());
      t.source.stream!.add(fixAt(now));
      await pumpEventQueue();
      t.source.stream!.add(fixAt(now.add(const Duration(seconds: 2))));
      await pumpEventQueue();
      expect(t.repo.sent, hasLength(1));
      expect(t.tracker.hasUnsent, isTrue);
      t.tracker.dispose();
    });

    test('offline keeps only the newest position', () async {
      final now = DateTime(2026, 11, 1, 10);
      var clock = now;
      final t = makeTracker(clock: () => clock);
      await t.tracker.start();
      await t.tracker.begin(sessionOf());
      t.online.add(false);
      await pumpEventQueue();
      expect(t.tracker.offline, isTrue);
      for (var i = 1; i <= 20; i++) {
        t.source.stream!.add(
          fixAt(now.add(Duration(minutes: i)), lat: 19 + i / 100),
        );
      }
      await pumpEventQueue();
      expect(t.repo.sent, isEmpty);
      clock = now.add(const Duration(minutes: 30));
      t.online.add(true);
      await pumpEventQueue();
      expect(t.repo.sent, hasLength(1), reason: 'no backlog');
      expect(t.repo.sent.single.latitude, closeTo(19.2, 0.0001));
      expect(
        t.repo.sent.single.capturedAt,
        now.add(const Duration(minutes: 20)),
        reason: 'keeps its original time',
      );
      t.tracker.dispose();
    });

    test('a failed upload is held for the next try', () async {
      final t = makeTracker();
      await t.tracker.begin(sessionOf());
      t.repo.sendError = offline;
      t.source.stream!.add(fixAt(DateTime(2026, 11, 1, 10)));
      await pumpEventQueue();
      expect(t.tracker.hasUnsent, isTrue);
      expect(t.tracker.offline, isTrue);
      t.tracker.dispose();
    });

    test('an older reading never replaces a newer held one', () async {
      final now = DateTime(2026, 11, 1, 10);
      final t = makeTracker(clock: () => now);
      await t.tracker.start();
      await t.tracker.begin(sessionOf());
      t.online.add(false);
      await pumpEventQueue();
      t.source.stream!
        ..add(fixAt(now, lat: 19.5))
        ..add(fixAt(now.subtract(const Duration(minutes: 5)), lat: 19.1));
      await pumpEventQueue();
      t.online.add(true);
      await pumpEventQueue();
      expect(t.repo.sent.single.latitude, 19.5);
      t.tracker.dispose();
    });

    test('the server ending it stops collection', () async {
      final t = makeTracker();
      await t.tracker.begin(sessionOf());
      t.repo.sendError = const SharingClosed('expired');
      t.source.stream!.add(fixAt(DateTime(2026, 11, 1, 10)));
      await pumpEventQueue();
      expect(t.source.isOn, isFalse);
      expect(t.tracker.state, TrackerState.idle);
      expect(t.tracker.endedStatus, 'expired');
      expect(t.store.values, isEmpty);
      t.tracker.dispose();
    });

    test('revoked access stops collection', () async {
      final t = makeTracker();
      await t.tracker.begin(sessionOf());
      t.repo.sendError = const FamilyException(FamilyFailure.notFound);
      t.source.stream!.add(fixAt(DateTime(2026, 11, 1, 10)));
      await pumpEventQueue();
      expect(t.source.isOn, isFalse);
      t.tracker.dispose();
    });

    test('paused elsewhere stops collection but keeps the session', () async {
      final t = makeTracker();
      await t.tracker.begin(sessionOf());
      t.repo.sendError = const SharingClosed('paused');
      t.source.stream!.add(fixAt(DateTime(2026, 11, 1, 10)));
      await pumpEventQueue();
      expect(t.source.isOn, isFalse);
      expect(t.tracker.state, TrackerState.paused);
      expect(t.tracker.sessionId, 's1');
      t.tracker.dispose();
    });

    test('pausing collects nothing, and resuming starts again', () async {
      final t = makeTracker();
      await t.tracker.begin(sessionOf());
      await t.tracker.sync(sessionOf(status: 'paused'));
      expect(t.source.isOn, isFalse);
      expect(t.tracker.state, TrackerState.paused);
      await t.tracker.sync(sessionOf());
      expect(t.source.isOn, isTrue);
      expect(t.tracker.state, TrackerState.sharing);
      t.tracker.dispose();
    });

    testWidgets('its own clock ends the session with no server', (
      tester,
    ) async {
      final t = makeTracker();
      await t.tracker.begin(sessionOf(remaining: 60));
      await tester.pump(const Duration(seconds: 61));
      expect(t.source.isOn, isFalse);
      expect(t.tracker.endedStatus, 'expired');
      t.tracker.dispose();
    });

    test('GPS off interrupts rather than pretending', () async {
      final t = makeTracker();
      t.source.permit = LocationPermit.servicesOff;
      await t.tracker.begin(sessionOf());
      expect(t.source.isOn, isFalse);
      expect(t.tracker.state, TrackerState.interrupted);
      t.tracker.dispose();
    });

    test('losing permission mid-session interrupts', () async {
      final t = makeTracker();
      await t.tracker.begin(sessionOf());
      t.source.stream!.addError('denied');
      await pumpEventQueue();
      expect(t.source.isOn, isFalse);
      expect(t.tracker.state, TrackerState.interrupted);
      t.tracker.dispose();
    });

    test('notifications off is reported', () async {
      final t = makeTracker();
      t.source.notifications = false;
      await t.tracker.checkAccess();
      expect(t.tracker.notificationsAllowed, isFalse);
      t.tracker.dispose();
    });

    test('checking never prompts', () async {
      final t = makeTracker();
      await t.tracker.checkAccess();
      expect(t.source.requests, 0);
      t.tracker.dispose();
    });

    test('a restart carries on an open session', () async {
      final t = makeTracker();
      t.store.values['location_session_id'] = 's1';
      t.store.values['location_session_ends'] =
          DateTime.now()
              .add(const Duration(hours: 1))
              .toUtc()
              .toIso8601String();
      await t.tracker.start();
      expect(t.source.isOn, isTrue);
      t.tracker.dispose();
    });

    test('a restart doesn\'t revive a session past its time', () async {
      final t = makeTracker();
      t.store.values['location_session_id'] = 's1';
      t.store.values['location_session_ends'] =
          DateTime.now()
              .subtract(const Duration(minutes: 1))
              .toUtc()
              .toIso8601String();
      await t.tracker.start();
      expect(t.source.isOn, isFalse);
      expect(t.store.values, isEmpty);
      t.tracker.dispose();
    });

    test('a restart drops a session stopped elsewhere', () async {
      final t = makeTracker();
      t.store.values['location_session_id'] = 's1';
      t.store.values['location_session_ends'] =
          DateTime.now()
              .add(const Duration(hours: 1))
              .toUtc()
              .toIso8601String();
      t.repo.current = sessionOf(status: 'stopped', remaining: 0);
      await t.tracker.start();
      expect(t.source.isOn, isFalse);
      t.tracker.dispose();
    });

    test('stopping offline stops here and tells the server later', () async {
      final t = makeTracker();
      await t.tracker.start();
      await t.tracker.begin(sessionOf());
      t.repo.stopError = offline;
      expect(await t.tracker.stop('s1'), isFalse);
      expect(t.source.isOn, isFalse, reason: 'stops at once');
      t.repo.stopError = null;
      t.online.add(true);
      await pumpEventQueue();
      expect(t.repo.stopped, ['s1']);
      expect(t.store.values, isEmpty);
      t.tracker.dispose();
    });

    test('signing out stops sharing', () async {
      final t = makeTracker();
      await t.tracker.begin(sessionOf());
      LocationServices.lastFeed['f1'] = const LocationFeed(people: []);
      await t.tracker.signOut();
      expect(t.source.isOn, isFalse);
      expect(t.repo.stopped, ['s1']);
      expect(LocationServices.lastFeed, isEmpty);
      t.tracker.dispose();
    });

    test('nothing about a position is ever stored', () async {
      final t = makeTracker();
      await t.tracker.begin(sessionOf());
      t.repo.sendError = offline;
      t.source.stream!.add(fixAt(DateTime(2026, 11, 1, 10)));
      await pumpEventQueue();
      expect(t.store.values.toString(), isNot(contains('19.99')));
      t.tracker.dispose();
    });
  });

  group('repository', () {
    HttpLocationRepository repo(MockClientHandler handler) =>
        HttpLocationRepository(
          client: MockClient(handler),
          token: () async => 'token',
          requireHttps: false,
        );

    test('410 tells the tracker why it stopped', () async {
      final client = repo(
        (_) async => http.Response(
          jsonEncode({
            'errors': {'detail': 'x', 'status': 'expired'},
          }),
          410,
        ),
      );
      await expectLater(
        client.sendUpdate('s1', fixAt(DateTime(2026))),
        throwsA(
          isA<SharingClosed>().having((e) => e.status, 'status', 'expired'),
        ),
      );
    });

    test('the case endpoint says when nothing is shared', () async {
      final client = repo(
        (_) async => http.Response(
          jsonEncode({
            'data': {'state': 'not_shared'},
          }),
          200,
        ),
      );
      expect(await client.caseLocation('c1'), isNull);
    });

    test('a signed-out phone sends nothing', () async {
      final client = HttpLocationRepository(
        client: MockClient((_) async => fail('no request expected')),
        token: () async => null,
        requireHttps: false,
      );
      await expectLater(
        client.feed('f1'),
        throwsA(
          isA<FamilyException>().having(
            (e) => e.kind,
            'kind',
            FamilyFailure.signedOut,
          ),
        ),
      );
    });

    test('plain http is refused when https is required', () async {
      final client = HttpLocationRepository(
        client: MockClient((_) async => fail('no request expected')),
        token: () async => 'token',
        requireHttps: true,
      );
      if (ApiConst.protocol == 'https') return;
      await expectLater(client.feed('f1'), throwsA(isA<FamilyException>()));
    });
  });

  group('map', () {
    late AppMapConfig? shown;

    setUp(() {
      shown = null;
      LocationServices.lastFeed.clear();
      AppMap.debugBuilder = (context, config) {
        shown = config;
        return const ColoredBox(color: Colors.green);
      };
    });

    tearDown(() => AppMap.debugBuilder = null);

    Future<FakeRepo> open(
      WidgetTester tester,
      LocationFeed feed, {
      LocationTracker? tracker,
    }) async {
      final repo = FakeRepo()..feedResult = feed;
      await pumpApp(
        tester,
        FamilyMapScreen(
          args: const FamilyArgs(circle),
          repository: repo,
          familyRepository: FakeFamily(),
          tracker: tracker ?? makeTracker().tracker,
        ),
      );
      return repo;
    }

    testWidgets('nobody sharing is an empty state, not an empty map', (
      tester,
    ) async {
      LocationServices.lastFeed.clear();
      await open(tester, const LocationFeed(people: []));
      expect(find.text('No one is sharing with you'), findsOneWidget);
      expect(shown, isNull);
    });

    testWidgets('shows a pin for each person with a position', (tester) async {
      await open(
        tester,
        LocationFeed(
          people: [personOf(), personOf(id: 'm3', name: 'Ravi More', age: 900)],
        ),
      );
      expect(shown!.markers, hasLength(2));
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Last known location'), findsOneWidget);
    });

    testWidgets('paused people have no pin', (tester) async {
      await open(
        tester,
        LocationFeed(
          people: [
            personOf(),
            personOf(
              id: 'm3',
              name: 'Ravi More',
              state: 'paused',
              age: null,
              lat: null,
            ),
          ],
        ),
      );
      expect(shown!.markers, hasLength(1));
      expect(find.text('Sharing paused'), findsOneWidget);
    });

    testWidgets('only positionless people means no map', (tester) async {
      await open(
        tester,
        LocationFeed(
          people: [personOf(state: 'unavailable', age: null, lat: null)],
        ),
      );
      expect(shown, isNull);
      expect(find.text('Location unavailable'), findsOneWidget);
    });

    testWidgets('never claims to be real time', (tester) async {
      await open(tester, LocationFeed(people: [personOf()]));
      expect(find.text('Updates can be delayed'), findsOneWidget);
    });

    testWidgets('tapping a person opens the panel', (tester) async {
      await open(tester, LocationFeed(people: [personOf(age: 300)]));
      await tester.tap(find.text('Suresh'));
      await settle(tester);
      expect(find.textContaining('Updated 5 min ago'), findsOneWidget);
      expect(find.textContaining('Accurate to about 14 m'), findsOneWidget);
      expect(find.text('Directions'), findsOneWidget);
      expect(shown!.circles, hasLength(1));
    });

    testWidgets('a stale position warns they may have moved', (tester) async {
      await open(tester, LocationFeed(people: [personOf(age: 900)]));
      await tester.tap(find.text('Suresh'));
      await settle(tester);
      expect(find.text('They may have moved since then.'), findsOneWidget);
    });

    testWidgets('a person with a case links to it', (tester) async {
      await open(tester, LocationFeed(people: [personOf(caseId: 'c1')]));
      await tester.tap(find.text('Suresh'));
      await settle(tester);
      expect(find.text('Open case LF-ABCD2345'), findsOneWidget);
    });

    testWidgets('polls while open, and stops when closed', (tester) async {
      final repo = await open(
        tester,
        LocationFeed(people: [personOf()], pollSeconds: 20),
      );
      final first = repo.feedCalls;
      await tester.pump(const Duration(seconds: 21));
      await settle(tester);
      expect(repo.feedCalls, first + 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 2));
      expect(repo.feedCalls, first + 1);
    });

    testWidgets('losing connection keeps the last update, labelled', (
      tester,
    ) async {
      final repo = await open(tester, LocationFeed(people: [personOf()]));
      repo.feedError = offline;
      await tester.pump(const Duration(seconds: 21));
      await settle(tester);
      expect(shown!.markers, hasLength(1));
      expect(
        find.text('No connection. Showing the last update.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('your own sharing can be stopped from the map', (tester) async {
      final t = makeTracker();
      await tester.runAsync(() => t.tracker.begin(sessionOf()));
      await open(
        tester,
        LocationFeed(people: [personOf()]),
        tracker: t.tracker,
      );
      expect(find.text("You're sharing your location"), findsOneWidget);
      expect(find.byTooltip('Stop sharing'), findsOneWidget);
      expect(find.byTooltip('Pause sharing'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      t.tracker.dispose();
    });

    testWidgets('no blue dot unless sharing', (tester) async {
      await open(tester, LocationFeed(people: [personOf()]));
      expect(shown!.showMyLocation, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no family means joining one first', (tester) async {
      await pumpApp(
        tester,
        FamilyMapScreen(
          repository: FakeRepo(),
          familyRepository: FakeFamily(),
          tracker: makeTracker().tracker,
        ),
      );
      expect(find.text('Join a family first'), findsOneWidget);
    });

    testWidgets('a notification opens the right family', (tester) async {
      final repo = FakeRepo()..feedResult = LocationFeed(people: [personOf()]);
      await pumpApp(
        tester,
        FamilyMapScreen(
          familyId: 'f2',
          repository: repo,
          familyRepository: FakeFamily(
            circleList: const [circle, FamilyCircle(id: 'f2', name: 'Second')],
          ),
          tracker: makeTracker().tracker,
        ),
      );
      expect(repo.feedCalls, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('sharing screen', () {
    Future<({FakeRepo repo, FakeSource source, LocationTracker tracker})> open(
      WidgetTester tester, {
      List<SharingSession> sessions = const [],
      List<FamilyMember> members = const [me, otherAdult],
      void Function(FakeSource)? setup,
      Size? size,
    }) async {
      final t = makeTracker();
      setup?.call(t.source);
      t.repo.open = sessions;
      await pumpApp(
        tester,
        LocationSharingScreen(
          args: const FamilyArgs(circle),
          repository: t.repo,
          familyRepository: FakeFamily(memberList: members),
          tracker: t.tracker,
        ),
        size: size ?? const Size(1080, 4200),
      );
      return (repo: t.repo, source: t.source, tracker: t.tracker);
    }

    testWidgets('needs someone chosen', (tester) async {
      final t = await open(tester);
      await tester.tap(find.text('Start sharing'));
      await settle(tester);
      expect(find.text('Choose at least one person.'), findsOneWidget);
      expect(t.repo.started, isNull);
    });

    testWidgets('needs explicit agreement', (tester) async {
      final t = await open(tester);
      await tester.tap(find.text('Suresh More'));
      await settle(tester);
      await tester.tap(find.text('Start sharing'));
      await settle(tester);
      expect(
        find.text('Tick the box to agree before you start.'),
        findsOneWidget,
      );
      expect(t.repo.started, isNull);
      expect(t.source.requests, 0, reason: 'no prompt before agreeing');
    });

    testWidgets('starts with what was chosen', (tester) async {
      final t = await open(tester);
      await tester.tap(find.text('Suresh More'));
      await settle(tester);
      await tester.tap(find.text('3 h'));
      await settle(tester);
      await tester.tap(find.textContaining('I agree to share'));
      await settle(tester);
      await tester.tap(find.text('Start sharing'));
      await tester.runAsync(() => pumpEventQueue());
      await settle(tester);
      expect(t.repo.started, {
        'consent': true,
        'recipients': ['m2'],
        'member': null,
        'minutes': 180,
        'until': false,
      });
      expect(t.tracker.collecting, isTrue);
      expect(find.text('Pause sharing'), findsOneWidget);
      t.tracker.dispose();
    });

    testWidgets('until stopped says it still ends', (tester) async {
      await open(tester);
      await tester.tap(find.text('Until I stop'));
      await settle(tester);
      expect(
        find.text('It still ends by itself after 12 hours.'),
        findsOneWidget,
      );
    });

    testWidgets('another adult can never be chosen as the subject', (
      tester,
    ) async {
      await open(tester, members: const [me, otherAdult, child]);
      expect(find.text('Whose location'), findsOneWidget);
      expect(find.text('Aarav More'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Ravi More'), findsNothing);
    });

    testWidgets('a dependent asks for the guardian\'s agreement', (
      tester,
    ) async {
      await open(tester, members: const [me, child]);
      await tester.tap(find.text('Aarav More'));
      await settle(tester);
      expect(
        find.textContaining('Keep this phone with Aarav More'),
        findsOneWidget,
      );
      expect(
        find.textContaining('I am responsible for Aarav More'),
        findsOneWidget,
      );
    });

    testWidgets('denied permission starts nothing', (tester) async {
      final t = await open(
        tester,
        setup: (s) {
          s.permit = LocationPermit.denied;
          s.afterRequest = LocationPermit.denied;
        },
      );
      expect(find.text('Your phone will ask for permission'), findsOneWidget);
      await tester.tap(find.text('Suresh More'));
      await settle(tester);
      await tester.tap(find.textContaining('I agree to share'));
      await settle(tester);
      await tester.tap(find.text('Start sharing'));
      await settle(tester);
      expect(t.source.requests, 1);
      expect(t.repo.started, isNull);
      expect(t.source.isOn, isFalse);
    });

    testWidgets('explains each blocked state', (tester) async {
      await open(tester, setup: (s) => s.permit = LocationPermit.servicesOff);
      expect(find.text('Location is turned off'), findsOneWidget);
    });

    testWidgets('explains approximate location', (tester) async {
      await open(tester, setup: (s) => s.permit = LocationPermit.approximate);
      expect(find.text('Only approximate location is allowed'), findsOneWidget);
    });

    testWidgets('explains blocked location', (tester) async {
      await open(tester, setup: (s) => s.permit = LocationPermit.blocked);
      expect(find.text('Location access is blocked'), findsOneWidget);
    });

    testWidgets('warns when background sharing can\'t show itself', (
      tester,
    ) async {
      await open(tester, setup: (s) => s.notifications = false);
      expect(find.text('Notifications are off'), findsOneWidget);
    });

    testWidgets('states the background limits', (tester) async {
      await open(tester);
      expect(find.textContaining('If you close the app fully'), findsOneWidget);
    });

    testWidgets('an open session shows its controls', (tester) async {
      await open(
        tester,
        sessions: [
          sessionOf(
            remaining: 4800,
            recipients: [
              SharingRecipient(
                memberId: 'm2',
                name: 'Suresh More',
                lastViewedAt: DateTime.now().subtract(
                  const Duration(minutes: 3),
                ),
              ),
            ],
          ),
        ],
      );
      expect(find.text('Pause sharing'), findsOneWidget);
      expect(find.text('Stop sharing'), findsOneWidget);
      expect(find.text('Change people'), findsOneWidget);
      expect(find.text('Change time'), findsOneWidget);
      expect(find.text('1 h 19 min left'), findsOneWidget);
      expect(find.text('Viewed 3 min ago'), findsOneWidget);
      expect(find.text('Start sharing'), findsNothing);
    });

    testWidgets('an open session never claims to be live', (tester) async {
      await open(tester, sessions: [sessionOf()]);
      expect(find.text('Live'), findsNothing);
      expect(find.text('Waiting for the first update'), findsOneWidget);
    });

    testWidgets('stopping asks first', (tester) async {
      final t = makeTracker();
      await tester.runAsync(() => t.tracker.begin(sessionOf()));
      t.repo.open = [sessionOf()];
      await pumpApp(
        tester,
        LocationSharingScreen(
          args: const FamilyArgs(circle),
          repository: t.repo,
          familyRepository: FakeFamily(memberList: const [me]),
          tracker: t.tracker,
        ),
        size: const Size(1080, 4200),
      );
      await tester.tap(find.text('Stop sharing'));
      await settle(tester);
      expect(find.text('Stop sharing your location?'), findsOneWidget);
      expect(t.repo.stopped, isEmpty);
      await tester.tap(find.text('Stop sharing').last);
      await tester.runAsync(() => pumpEventQueue());
      await settle(tester);
      expect(t.repo.stopped, ['s1']);
      expect(t.source.isOn, isFalse);
      expect(find.text('Start sharing'), findsOneWidget);
      t.tracker.dispose();
    });

    testWidgets('a session on another phone says so', (tester) async {
      await open(tester, sessions: [sessionOf(fromMe: false)]);
      expect(
        find.text('This sharing is running on another phone.'),
        findsOneWidget,
      );
    });

    testWidgets('fits a phone at large text', (tester) async {
      await open(tester, size: const Size(1080, 2000));
      expect(tester.takeException(), isNull);
    });
  });

  group('lost and found', () {
    testWidgets('says plainly when nothing is shared', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: SharedLocationNote(caseId: 'c1', repository: FakeRepo()),
        ),
      );
      expect(
        find.textContaining("A report doesn't change that"),
        findsOneWidget,
      );
    });

    testWidgets('a stale position is never called current', (tester) async {
      final repo = FakeRepo()..caseResult = personOf(age: 3600);
      await pumpApp(
        tester,
        Scaffold(body: SharedLocationNote(caseId: 'c1', repository: repo)),
      );
      expect(find.text('Last known location'), findsOneWidget);
      expect(
        find.textContaining('not a confirmed current location'),
        findsOneWidget,
      );
      expect(find.text('Live'), findsNothing);
    });
  });

  group('routing and text', () {
    test('notifications open the map', () {
      final data = {'type': 'family_location', 'route': '/familyMap'};
      expect(NotificationRouter.routeFor(data), '/familyMap');
    });

    test('only a real family id is passed on', () {
      expect(
        NotificationRouter.argumentsFor('/familyMap', {'family_id': 'x'}),
        isNull,
      );
      const id = '3f2b8c1e-7a44-4d19-9f0e-6c1d2a7b4e55';
      expect(
        NotificationRouter.argumentsFor('/familyMap', {'family_id': id}),
        id,
      );
    });

    test('every key exists in all three languages', () {
      Set<String> keys(String lang) =>
          (json.decode(
                    File('assets/translations/$lang.json').readAsStringSync(),
                  )
                  as Map<String, dynamic>)
              .keys
              .where((k) => k.startsWith('loc_'))
              .toSet();
      expect(keys('hi'), keys('en'));
      expect(keys('mr'), keys('en'));
    });

    test('every key used in code exists', () {
      final en =
          json.decode(File('assets/translations/en.json').readAsStringSync())
              as Map<String, dynamic>;
      final used = <String>{};
      for (final file
          in Directory(
            'lib/src/modules/location',
          ).listSync(recursive: true).whereType<File>()) {
        used.addAll(
          RegExp(
            r"'(loc_[a-z_]+)'",
          ).allMatches(file.readAsStringSync()).map((m) => m.group(1)!),
        );
      }
      expect(used.where((k) => !en.containsKey(k)), isEmpty);
    });

    test('location code never prints', () {
      for (final file
          in Directory(
            'lib/src/modules/location',
          ).listSync(recursive: true).whereType<File>()) {
        final text = file.readAsStringSync();
        expect(text, isNot(contains('print(')), reason: file.path);
        expect(text, isNot(contains('debugPrint')), reason: file.path);
      }
    });
  });

  testWidgets('pins are drawn with a real image', (tester) async {
    final bytes = await tester.runAsync(
      () => LocationMarkers.drawPin(
        initials: 'AM',
        ring: Colors.green,
        fill: Colors.deepOrange,
        text: Colors.white,
        current: false,
      ),
    );
    expect(bytes!.length, greaterThan(500));
    expect(bytes.sublist(1, 4), [0x50, 0x4E, 0x47]);
  });
}
