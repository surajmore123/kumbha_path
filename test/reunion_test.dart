import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumbha_path/src/components/maps/app_map.dart';
import 'package:kumbha_path/src/modules/family/family_home_screen.dart'
    show FamilyArgs;
import 'package:kumbha_path/src/modules/location/data/location_repository.dart';
import 'package:kumbha_path/src/modules/location/models/location_models.dart';
import 'package:kumbha_path/src/modules/location/widgets/location_parts.dart';
import 'package:kumbha_path/src/modules/lostfound/models/lf_models.dart';
import 'package:kumbha_path/src/modules/reunion/data/reunion_repository.dart';
import 'package:kumbha_path/src/modules/reunion/models/reunion_models.dart';
import 'package:kumbha_path/src/modules/reunion/point_explorer_screen.dart';
import 'package:kumbha_path/src/modules/reunion/reunion_case_screen.dart';
import 'package:kumbha_path/src/modules/reunion/reunion_map_screen.dart';
import 'package:kumbha_path/src/modules/reunion/route_preview_screen.dart';
import 'package:kumbha_path/src/modules/reunion/widgets/reunion_parts.dart';
import 'package:kumbha_path/src/services/notification_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_test.dart' as t;

const offline = FamilyException(FamilyFailure.offline);

MeetingPoint pointOf({
  String id = 'p1',
  String name = 'Ramkund Help Desk',
  String category = 'help_desk',
  String status = 'verified',
  bool verified = true,
  bool official = false,
  bool private = false,
  double lat = 19.9975,
}) => MeetingPoint(
  id: id,
  name: name,
  category: category,
  status: status,
  isVerified: verified,
  isOfficial: official,
  isPrivate: private,
  sourceDetail: verified ? 'Visited 3 Jan' : '',
  latitude: lat,
  longitude: 73.7898,
);

final tree = pointOf(
  id: 'p2',
  name: 'Banyan tree',
  category: 'family_meeting',
  status: 'community',
  verified: false,
);

final familySpot = pointOf(
  id: 'p3',
  name: 'Tea stall',
  category: 'family_meeting',
  status: 'family',
  verified: false,
  private: true,
);

CaseMarker caseOf({
  bool isProtected = false,
  String? memberId,
  List<Sighting> sightings = const [],
  double? lat = 19.99,
}) => CaseMarker(
  id: 'c1',
  reference: 'LF-ABCD2345',
  status: 'SUBMITTED',
  personName: 'Asha More',
  memberId: memberId,
  isProtected: isProtected,
  eventAt: DateTime.now().subtract(const Duration(minutes: 40)),
  locationText: 'Near Ramkund',
  latitude: lat,
  longitude: lat == null ? null : 73.78,
  sightings: sightings,
);

const reported = Sighting(
  id: 's1',
  description: 'Near the steps',
  locationText: 'Ghat',
  latitude: 19.98,
  longitude: 73.78,
  verified: false,
  fromHelper: false,
  review: 'approved',
);

const verifiedSighting = Sighting(
  id: 's2',
  description: 'Seen by staff',
  locationText: 'Gate',
  latitude: 19.97,
  longitude: 73.78,
  verified: true,
  fromHelper: true,
  review: 'approved',
);

ReunionCase viewOf({
  String status = 'SUBMITTED',
  ReunionPlan plan = const ReunionPlan(),
  bool isProtected = false,
  bool operate = false,
  List<Sighting> sightings = const [],
  List<TimelineEvent> timeline = const [],
}) => ReunionCase(
  detail: CaseDetail(
    id: 'c1',
    reference: 'LF-ABCD2345',
    caseType: 'lost',
    status: status,
    personName: 'Asha More',
    locationText: 'Near Ramkund',
    sightings: sightings,
    timeline: timeline,
  ),
  plan: plan,
  isProtected: isProtected,
  canOperate: operate,
);

class FakeReunion implements ReunionRepository {
  List<MeetingPoint> pointList = const [];
  ReunionOverview overviewResult = const ReunionOverview();
  ReunionCase? view;
  List<MeetingPoint> guided = const [];
  Object? pointsError;
  Object? overviewError;
  Object? routeError;
  WalkingRoute? routeResult;
  final chosen = <String>[];
  final notified = <String>[];
  final coordination = <String>[];

  @override
  Future<ReunionOverview> overview({String? familyId}) async {
    final error = overviewError;
    if (error != null) throw error;
    return overviewResult;
  }

  @override
  Future<List<MeetingPoint>> points({
    String? category,
    bool verifiedOnly = false,
  }) async {
    final error = pointsError;
    if (error != null) throw error;
    return pointList;
  }

  @override
  Future<MeetingPoint> addFamilyPoint(
    String familyId, {
    required String name,
    required double latitude,
    required double longitude,
    String description = '',
  }) async => familySpot;

  @override
  Future<void> suggestPoint(String id) async {}

  @override
  Future<void> removePoint(String id) async {}

  @override
  Future<ReunionCase> caseView(String id) async => view!;

  @override
  Future<List<MeetingPoint>> guidance(
    String caseId, {
    (double, double)? origin,
  }) async => guided;

  @override
  Future<void> choosePoint(String caseId, String pointId) async {
    chosen.add(pointId);
  }

  @override
  Future<void> coordinate(
    String caseId, {
    String? event,
    String? update,
  }) async {
    coordination.add(event ?? update ?? '');
  }

  @override
  Future<WalkingRoute> route(
    RouteTarget target,
    (double, double) origin,
  ) async {
    final error = routeError;
    if (error != null) throw error;
    return routeResult!;
  }

  @override
  Future<int> notifyFamily(
    String familyId,
    String kind, {
    String? pointId,
  }) async {
    notified.add(kind);
    return 2;
  }
}

const target = RouteTarget(
  kind: 'point',
  id: 'p1',
  name: 'Ramkund Help Desk',
  latitude: 19.9975,
  longitude: 73.7898,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppMapConfig? shown;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'API_HOST=example.test');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    LocationMarkers.debugPlain = true;
    ReunionMarkers.debugPlain = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    shown = null;
    LocationServices.lastFeed.clear();
    ReunionServices.lastOverview = null;
    ReunionServices.lastRoutes.clear();
    AppMap.debugBuilder = (context, config) {
      shown = config;
      return const ColoredBox(color: Colors.green);
    };
  });

  tearDown(() => AppMap.debugBuilder = null);

  Future<(FakeReunion, t.FakeRepo)> openMap(
    WidgetTester tester, {
    List<MeetingPoint> points = const [],
    ReunionOverview overview = const ReunionOverview(),
    LocationFeed feed = const LocationFeed(people: []),
  }) async {
    final repo =
        FakeReunion()
          ..pointList = points
          ..overviewResult = overview;
    final locations = t.FakeRepo()..feedResult = feed;
    await t.pumpApp(
      tester,
      ReunionMapScreen(
        args: const FamilyArgs(t.circle),
        repository: repo,
        locations: locations,
        familyRepository: t.FakeFamily(),
        tracker: t.makeTracker().tracker,
      ),
    );
    return (repo, locations);
  }

  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  Set<String> ids() => {for (final m in shown!.markers) m.markerId.value};

  group('helpers', () {
    test('decodes a Google polyline', () {
      final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(points, hasLength(3));
      expect(points[0].latitude, closeTo(38.5, 0.00001));
      expect(points[2].longitude, closeTo(-126.453, 0.00001));
    });

    test('a broken polyline gives no line rather than a crash', () {
      expect(decodePolyline(''), isEmpty);
    });

    test('straight-line distance is about right', () {
      expect(straightLineKm((19.99, 73.78), 20.08, 73.78), closeTo(10, 0.1));
    });

    test('walking links ask for walking', () {
      expect(googleMapsWalkingUrl(1, 2), contains('travelmode=walking'));
    });

    test('points read from the server', () {
      final point = MeetingPoint.fromJson({
        'id': 'p',
        'name': 'Desk',
        'category': 'police',
        'status': 'verified',
        'is_verified': true,
        'is_official': true,
        'latitude': 19.9,
        'longitude': 73.7,
      });
      expect(point.isOfficial, isTrue);
      expect(point.isFamilySpot, isFalse);
    });
  });

  group('saved points', () {
    test('keeps public points with the date', () async {
      await const SavedPoints().save([pointOf(), tree]);
      final page = await const SavedPoints().load();
      expect(page!.points, hasLength(2));
      expect(page.savedAt, isNotNull);
    });

    test('never writes a private family spot to the phone', () async {
      await const SavedPoints().save([pointOf(), familySpot]);
      final page = await const SavedPoints().load();
      expect(page!.points.map((p) => p.name), ['Ramkund Help Desk']);
    });

    test('wiping removes everything', () async {
      await const SavedPoints().save([pointOf()]);
      ReunionServices.lastRoutes['x'] = WalkingRoute(
        name: 'n',
        distanceM: 1,
        durationS: 1,
        polyline: '',
      );
      await ReunionServices.wipe();
      expect(await const SavedPoints().load(), isNull);
      expect(ReunionServices.lastRoutes, isEmpty);
    });
  });

  group('repository', () {
    HttpReunionRepository repo(MockClientHandler handler) =>
        HttpReunionRepository(
          client: MockClient(handler),
          token: () async => 'token',
          requireHttps: false,
        );

    test('a provider failure is its own error', () async {
      final client = repo(
        (_) async => http.Response(
          jsonEncode({
            'errors': {'detail': 'x', 'code': 'routing_unavailable'},
          }),
          503,
        ),
      );
      await expectLater(
        client.route(target, (19.9, 73.7)),
        throwsA(isA<RouteUnavailable>()),
      );
    });

    test('a safety refusal is its own error', () async {
      final client = repo(
        (_) async => http.Response(
          jsonEncode({
            'errors': {
              'non_field_errors': ['x'],
              'code': 'use_safe_point',
            },
          }),
          409,
        ),
      );
      await expectLater(
        client.route(target, (19.9, 73.7)),
        throwsA(isA<UseSafePoint>()),
      );
    });

    test('the origin goes in the body, never the address', () async {
      late http.Request sent;
      final client = repo((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'data': {
              'name': 'n',
              'distance_m': 1,
              'duration_s': 1,
              'polyline': '',
            },
          }),
          200,
        );
      });
      await client.route(target, (19.123456, 73.7));
      expect(sent.url.toString(), isNot(contains('19.12')));
      expect(sent.body, contains('19.123456'));
    });
  });

  group('map', () {
    testWidgets('each kind of thing gets its own marker', (tester) async {
      await openMap(
        tester,
        points: [pointOf(), tree],
        overview: ReunionOverview(
          cases: [
            caseOf(sightings: const [reported, verifiedSighting]),
          ],
        ),
        feed: LocationFeed(people: [t.personOf()]),
      );
      expect(ids(), {
        'person:m2',
        'point:p1',
        'point:p2',
        'case:c1',
        'sighting:s1',
        'sighting:s2',
      });
      await unmount(tester);
    });

    testWidgets('filters hide a layer', (tester) async {
      await openMap(tester, points: [pointOf(), tree]);
      await tester.ensureVisible(find.text('Help points'));
      await t.settle(tester);
      await tester.tap(find.text('Help points'));
      await t.settle(tester);
      expect(ids(), {'point:p2'});
      await unmount(tester);
    });

    testWidgets('a case without permission has no marker', (tester) async {
      await openMap(
        tester,
        points: [pointOf()],
        overview: ReunionOverview(cases: [caseOf(lat: null)]),
      );
      expect(ids(), {'point:p1'});
      await unmount(tester);
    });

    testWidgets('paused and expired people have no marker', (tester) async {
      await openMap(
        tester,
        points: [pointOf()],
        feed: LocationFeed(
          people: [
            t.personOf(state: 'paused', age: null, lat: null),
            t.personOf(
              id: 'm3',
              remaining: 5,
              fetchedAt: DateTime.now().subtract(const Duration(minutes: 1)),
            ),
          ],
        ),
      );
      expect(ids(), {'point:p1'});
      await unmount(tester);
    });

    testWidgets('nothing at all is an honest empty state', (tester) async {
      await openMap(tester);
      expect(shown, isNull);
      expect(find.text('Nothing to show yet'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the key explains the markers', (tester) async {
      await openMap(tester, points: [pointOf()]);
      await tester.tap(find.byTooltip('Map key'));
      await t.settle(tester);
      expect(find.textContaining('Verified help point'), findsOneWidget);
      expect(find.textContaining('hollow triangle'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a stale person is labelled and warned about', (tester) async {
      await openMap(
        tester,
        points: [pointOf()],
        feed: LocationFeed(people: [t.personOf(age: 1800)]),
      );
      await tester.tap(find.text('Suresh'));
      await t.settle(tester);
      expect(find.text('Last known location'), findsOneWidget);
      expect(find.text('They may have moved since then.'), findsOneWidget);
      expect(find.text('Live'), findsNothing);
      await unmount(tester);
    });

    testWidgets('a protected person gets help points, not family routes', (
      tester,
    ) async {
      await openMap(
        tester,
        points: [pointOf()],
        overview: const ReunionOverview(selfProtected: true),
        feed: LocationFeed(people: [t.personOf()]),
      );
      expect(find.text('Go to staff, not across the crowd'), findsOneWidget);
      await tester.tap(find.text('Suresh'));
      await t.settle(tester);
      expect(find.text('Get walking route'), findsNothing);
      expect(find.text('Find a help point'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('reaching a vulnerable relative comes with a caution', (
      tester,
    ) async {
      await openMap(
        tester,
        points: [pointOf()],
        overview: ReunionOverview(
          cases: [caseOf(isProtected: true, memberId: 'm2')],
        ),
        feed: LocationFeed(people: [t.personOf()]),
      );
      expect(find.text('Someone here needs staff to help'), findsOneWidget);
      await tester.tap(find.text('Suresh'));
      await t.settle(tester);
      expect(find.textContaining("Don't ask them to walk"), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('losing the connection keeps what was known, labelled', (
      tester,
    ) async {
      final (repo, locations) = await openMap(
        tester,
        points: [pointOf()],
        feed: LocationFeed(people: [t.personOf()]),
      );
      locations.feedError = offline;
      repo.overviewError = offline;
      await tester.pump(const Duration(seconds: 21));
      await t.settle(tester);
      expect(ids(), contains('person:m2'));
      expect(find.textContaining('No connection'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('one failing source leaves the rest working', (tester) async {
      final repo =
          FakeReunion()
            ..pointList = [pointOf()]
            ..overviewError = offline;
      await t.pumpApp(
        tester,
        ReunionMapScreen(
          args: const FamilyArgs(t.circle),
          repository: repo,
          locations: t.FakeRepo()..feedError = offline,
          familyRepository: t.FakeFamily(),
          tracker: t.makeTracker().tracker,
        ),
      );
      expect(ids(), {'point:p1'});
      await unmount(tester);
    });

    testWidgets('help points come back offline with their date', (
      tester,
    ) async {
      await const SavedPoints().save([pointOf()]);
      final repo = FakeReunion()..pointsError = offline;
      await t.pumpApp(
        tester,
        ReunionMapScreen(
          args: const FamilyArgs(t.circle),
          repository: repo,
          locations: t.FakeRepo(),
          familyRepository: t.FakeFamily(),
          tracker: t.makeTracker().tracker,
        ),
      );
      expect(ids(), {'point:p1'});
      expect(find.textContaining('This may be out of date'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a shared point opens straight away', (tester) async {
      await t.pumpApp(
        tester,
        ReunionMapScreen(
          args: const FamilyArgs(t.circle),
          pointId: 'p1',
          repository: FakeReunion()..pointList = [pointOf()],
          locations: t.FakeRepo(),
          familyRepository: t.FakeFamily(),
          tracker: t.makeTracker().tracker,
        ),
      );
      expect(find.text('Ramkund Help Desk'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('notifying the family asks first', (tester) async {
      final (repo, _) = await openMap(tester, points: [pointOf()]);
      await tester.tap(find.byTooltip('Notify your family'));
      await t.settle(tester);
      expect(repo.notified, isEmpty);
      await tester.tap(find.text('Send'));
      await t.settle(tester);
      expect(repo.notified, ['check_map']);
      await unmount(tester);
    });
  });

  group('point explorer', () {
    Future<FakeReunion> open(
      WidgetTester tester, {
      List<MeetingPoint> points = const [],
      PointExplorerArgs args = const PointExplorerArgs(),
      Object? error,
      (double, double)? me,
    }) async {
      final repo =
          FakeReunion()
            ..pointList = points
            ..pointsError = error;
      await t.pumpApp(
        tester,
        PointExplorerScreen(
          args: args,
          repository: repo,
          position: () async => me,
        ),
        size: const Size(1080, 3600),
      );
      return repo;
    }

    testWidgets('tells official, verified and community apart', (tester) async {
      await open(
        tester,
        points: [
          pointOf(name: 'Official', official: true),
          pointOf(id: 'x', name: 'Checked'),
          tree,
        ],
      );
      expect(find.text('Verified, official source'), findsOneWidget);
      expect(find.text('Verified by Kumbh Path staff'), findsOneWidget);
      expect(find.text('Community suggestion, not verified'), findsOneWidget);
    });

    testWidgets('verified only hides suggestions', (tester) async {
      await open(tester, points: [pointOf(), tree]);
      await tester.tap(find.text('Verified only'));
      await t.settle(tester);
      expect(find.text('Banyan tree'), findsNothing);
      expect(find.text('Ramkund Help Desk'), findsOneWidget);
    });

    testWidgets('category filters', (tester) async {
      await open(
        tester,
        points: [
          pointOf(),
          pointOf(id: 'c', name: 'Camp', category: 'medical'),
        ],
      );
      await tester.tap(find.text('Medical camp').first);
      await t.settle(tester);
      expect(find.text('Ramkund Help Desk'), findsNothing);
      expect(find.text('Camp'), findsOneWidget);
    });

    testWidgets('safe mode shows only verified, staffed places', (
      tester,
    ) async {
      await open(
        tester,
        points: [
          pointOf(),
          tree,
          pointOf(
            id: 'fv',
            name: 'Verified family spot',
            category: 'family_meeting',
          ),
        ],
        args: const PointExplorerArgs(safeOnly: true),
      );
      expect(find.text('Ramkund Help Desk'), findsOneWidget);
      expect(find.text('Banyan tree'), findsNothing);
      expect(find.text('Verified family spot'), findsNothing);
      expect(find.text('Verified only'), findsNothing);
    });

    testWidgets('distance filter works, and says what it measures', (
      tester,
    ) async {
      await open(
        tester,
        me: (19.9975, 73.7898),
        points: [
          pointOf(name: 'Here'),
          pointOf(id: 'far', name: 'Far', lat: 20.2),
        ],
      );
      await tester.tap(find.text('Sort by distance from me'));
      await t.settle(tester);
      expect(find.textContaining('straight line'), findsWidgets);
      await tester.tap(find.text('3 km'));
      await t.settle(tester);
      expect(find.text('Far'), findsNothing);
      expect(find.text('Here'), findsOneWidget);
    });

    testWidgets('no data is said plainly, and nothing is made up', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('No meeting points yet'), findsOneWidget);
    });

    testWidgets('offline uses the saved copy, dated', (tester) async {
      await const SavedPoints().save([pointOf()]);
      await open(tester, error: offline);
      expect(find.text('Ramkund Help Desk'), findsOneWidget);
      expect(find.textContaining('This may be out of date'), findsOneWidget);
    });

    testWidgets('offline with nothing saved offers a retry', (tester) async {
      await open(tester, error: offline);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('choosing asks first', (tester) async {
      final repo = await open(
        tester,
        points: [pointOf()],
        args: const PointExplorerArgs(caseId: 'c1', picking: true),
      );
      await tester.tap(find.text('Ramkund Help Desk'));
      await t.settle(tester);
      await tester.tap(find.text('Set as meeting point'));
      await t.settle(tester);
      expect(repo.chosen, isEmpty);
      await tester.tap(find.text('Set as meeting point').last);
      await t.settle(tester);
      expect(repo.chosen, ['p1']);
    });

    testWidgets('a community point says nobody confirmed it', (tester) async {
      await open(tester, points: [tree]);
      await tester.tap(find.text('Banyan tree'));
      await t.settle(tester);
      expect(find.textContaining('nobody has confirmed it'), findsOneWidget);
    });
  });

  group('route preview', () {
    Future<void> open(
      WidgetTester tester,
      FakeReunion repo, {
      (double, double)? origin = (19.99, 73.78),
    }) => t.pumpApp(
      tester,
      RoutePreviewScreen(
        target: target,
        repository: repo,
        position: () async => origin,
      ),
    );

    testWidgets('shows only the provider\'s figures', (tester) async {
      await open(
        tester,
        FakeReunion()
          ..routeResult = WalkingRoute(
            name: 'Desk',
            distanceM: 1240,
            durationS: 900,
            polyline: '_p~iF~ps|U_ulLnnqC',
          ),
      );
      expect(find.textContaining('1.2 km'), findsOneWidget);
      expect(find.textContaining('15 min'), findsOneWidget);
      expect(shown!.polylines.single.points, hasLength(2));
      expect(find.text('Open in Google Maps'), findsOneWidget);
    });

    testWidgets('no provider means no numbers, and Google Maps', (
      tester,
    ) async {
      await open(tester, FakeReunion()..routeError = const RouteUnavailable());
      expect(find.textContaining('preview isn\'t available'), findsOneWidget);
      expect(find.textContaining(' km'), findsNothing);
      expect(find.textContaining(' min'), findsNothing);
      expect(shown!.polylines, isEmpty);
      expect(find.text('Open in Google Maps'), findsOneWidget);
    });

    testWidgets('no GPS is explained', (tester) async {
      await open(tester, FakeReunion(), origin: null);
      expect(find.textContaining("can't read your location"), findsOneWidget);
      expect(find.text('Open in Google Maps'), findsOneWidget);
    });

    testWidgets('an old route is marked and never called current', (
      tester,
    ) async {
      ReunionServices.lastRoutes[target.key] = WalkingRoute(
        name: 'Desk',
        distanceM: 500,
        durationS: 360,
        polyline: '_p~iF~ps|U_ulLnnqC',
      );
      await open(tester, FakeReunion()..routeError = offline);
      expect(find.textContaining("can't be refreshed"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('offline with no earlier route says so', (tester) async {
      await open(tester, FakeReunion()..routeError = offline);
      expect(find.textContaining('No connection'), findsOneWidget);
    });

    testWidgets('lost access clears an old route', (tester) async {
      ReunionServices.lastRoutes[target.key] = WalkingRoute(
        name: 'Desk',
        distanceM: 500,
        durationS: 360,
        polyline: '',
      );
      await open(
        tester,
        FakeReunion()
          ..routeError = const FamilyException(FamilyFailure.notFound),
      );
      expect(ReunionServices.lastRoutes, isEmpty);
      expect(find.textContaining('500'), findsNothing);
    });

    testWidgets('a safety refusal gives instructions, not a route', (
      tester,
    ) async {
      await open(tester, FakeReunion()..routeError = const UseSafePoint());
      expect(find.text('Go to staff, not across the crowd'), findsOneWidget);
      expect(find.text('Open in Google Maps'), findsNothing);
      expect(find.text('Find a help point'), findsOneWidget);
    });

    testWidgets('a stale destination is labelled', (tester) async {
      await open(
        tester,
        FakeReunion()
          ..routeResult = WalkingRoute(
            name: 'Asha',
            distanceM: 500,
            durationS: 360,
            polyline: '',
            state: 'last_known',
            capturedAt: DateTime.now().subtract(const Duration(minutes: 30)),
            caution: 'stay_put',
          ),
      );
      expect(find.text('Last known location'), findsOneWidget);
      expect(find.text('They may have moved since then.'), findsOneWidget);
      expect(find.textContaining("Don't ask them to walk"), findsOneWidget);
    });
  });

  group('reunification case', () {
    Future<FakeReunion> open(
      WidgetTester tester,
      ReunionCase view, {
      List<MeetingPoint> guided = const [],
    }) async {
      final repo =
          FakeReunion()
            ..view = view
            ..guided = guided;
      await t.pumpApp(
        tester,
        ReunionCaseScreen(
          id: 'c1',
          repository: repo,
          showSharedLocation: false,
        ),
        size: const Size(1080, 4800),
      );
      return repo;
    }

    testWidgets('shows where the workflow stands', (tester) async {
      await open(
        tester,
        viewOf(
          plan: ReunionPlan(stage: 'point_chosen', meetingPoint: pointOf()),
        ),
      );
      expect(find.text('Meeting point chosen'), findsOneWidget);
      expect(find.text('Ramkund Help Desk'), findsOneWidget);
    });

    testWidgets('a protected case shows the safety steps', (tester) async {
      await open(tester, viewOf(isProtected: true), guided: [pointOf()]);
      expect(find.text('Someone here needs staff to help'), findsOneWidget);
      expect(find.textContaining('safest places'), findsOneWidget);
      expect(find.textContaining('prove who anyone is'), findsOneWidget);
    });

    testWidgets('being there is never shown as confirmed', (tester) async {
      await open(
        tester,
        viewOf(
          plan: ReunionPlan(
            stage: 'at_point',
            meetingPoint: pointOf(),
            familyArrivedAt: DateTime.now(),
          ),
        ),
      );
      expect(find.textContaining("isn't confirmation"), findsOneWidget);
      expect(find.text('Reunited'), findsNothing);
    });

    testWidgets('sightings say who stands behind them', (tester) async {
      await open(tester, viewOf(sightings: const [reported, verifiedSighting]));
      expect(find.text('Reported sighting'), findsOneWidget);
      expect(find.text('Verified by staff'), findsOneWidget);
    });

    testWidgets('family can say they arrived, but not verify', (tester) async {
      final repo = await open(
        tester,
        viewOf(
          plan: ReunionPlan(stage: 'point_chosen', meetingPoint: pointOf()),
        ),
      );
      expect(find.text('Verify and record handover'), findsNothing);
      expect(find.text('Person has arrived'), findsNothing);
      await tester.tap(find.text("We've arrived"));
      await t.settle(tester);
      await tester.tap(find.text('Confirm'));
      await t.settle(tester);
      expect(repo.coordination, ['family_arrived']);
    });

    testWidgets('staff get the coordination tools', (tester) async {
      await open(
        tester,
        viewOf(
          operate: true,
          plan: ReunionPlan(stage: 'point_chosen', meetingPoint: pointOf()),
        ),
      );
      expect(find.text('Person has arrived'), findsOneWidget);
      expect(find.text('Send update to family'), findsOneWidget);
      expect(find.text('Verify and record handover'), findsOneWidget);
      expect(find.textContaining('proves nothing'), findsOneWidget);
    });

    testWidgets('a reunited case offers no more actions', (tester) async {
      await open(
        tester,
        viewOf(status: 'REUNITED', plan: const ReunionPlan(stage: 'reunited')),
      );
      expect(find.text('Reunited'), findsOneWidget);
      expect(find.text('Choose a meeting point'), findsNothing);
    });

    testWidgets('no verified points is said plainly', (tester) async {
      await open(tester, viewOf(isProtected: true));
      expect(find.textContaining('once staff have checked'), findsOneWidget);
    });
  });

  group('routing and text', () {
    const family = '3f2b8c1e-7a44-4d19-9f0e-6c1d2a7b4e55';

    test('notifications open the map', () {
      expect(
        NotificationRouter.routeFor({'type': 'family_reunion'}),
        '/reunionMap',
      );
    });

    test('only real ids are passed on', () {
      expect(
        NotificationRouter.argumentsFor('/reunionMap', {
          'family_id': family,
          'point_id': 'nonsense',
        }),
        {'family_id': family},
      );
    });

    test('every key exists in all three languages', () {
      Set<String> keys(String lang) =>
          (json.decode(
                    File('assets/translations/$lang.json').readAsStringSync(),
                  )
                  as Map<String, dynamic>)
              .keys
              .where((k) => k.startsWith('re_'))
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
            'lib/src/modules/reunion',
          ).listSync(recursive: true).whereType<File>()) {
        used.addAll(
          RegExp(
            r"'(re_[a-z_]+)'",
          ).allMatches(file.readAsStringSync()).map((m) => m.group(1)!),
        );
      }
      for (final category in pointCategories) {
        used.add('re_cat_$category');
      }
      for (final stage in [...reunionStages, 'closed']) {
        used
          ..add('re_stage_$stage')
          ..add('re_stage_${stage}_means');
      }
      for (final layer in MapLayer.values) {
        used.add('re_layer_${layer.name}');
      }
      expect(used.where((k) => !en.containsKey(k)), isEmpty);
    });

    test('nothing here prints', () {
      for (final file
          in Directory(
            'lib/src/modules/reunion',
          ).listSync(recursive: true).whereType<File>()) {
        final text = file.readAsStringSync();
        expect(text, isNot(contains('print(')), reason: file.path);
      }
    });
  });

  testWidgets('every marker shape draws', (tester) async {
    for (final shape in MarkerShape.values) {
      final bytes = await tester.runAsync(
        () => ReunionMarkers.draw(
          shape: shape,
          glyph: Icons.support_agent_rounded,
          color: Colors.green,
          onColor: Colors.white,
        ),
      );
      expect(bytes!.length, greaterThan(300));
    }
  });
}
