import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumbha_path/src/modules/operations/data/ops_repository.dart';
import 'package:kumbha_path/src/modules/operations/ops_case_screen.dart';
import 'package:kumbha_path/src/modules/operations/ops_home_screen.dart';
import 'package:kumbha_path/src/modules/operations/ops_sign_in_screen.dart';
import 'package:kumbha_path/src/services/notification_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_test.dart' as t;
import 'sos_test.dart' as sos;

const caseId = '3f2b8c1e-7a44-4d19-9f0e-6c1d2a7b4e55';
const denied = FamilyException(FamilyFailure.signedOut);

const volunteer = OpsMe(
  role: 'VOLUNTEER',
  userId: 'u1',
  status: 'active',
  fullName: 'Asha More',
  zones: [OpsZone(id: 'z1', name: 'Ramkund')],
  canScan: true,
);

const coordinator = OpsMe(
  role: 'SAFETY_COORDINATOR',
  userId: 'u2',
  status: 'active',
  fullName: 'Ravi More',
  canScan: true,
  canManageCases: true,
  canViewSos: true,
  canAssign: true,
  canViewTeam: true,
);

const desk = OpsMe(
  role: 'HELP_DESK_OPERATOR',
  userId: 'u3',
  status: 'active',
  fullName: 'Meera',
  canScan: true,
  canManageCases: true,
  canViewSos: true,
);

OpsCase caseOf({
  String status = 'ASSIGNED',
  String priority = 'normal',
  String volunteerId = 'u1',
  bool assigned = true,
}) => OpsCase(
  id: caseId,
  reference: 'LF-ABCD2345',
  caseType: 'lost',
  status: 'SUBMITTED',
  priority: priority,
  locationText: 'Near Ramkund',
  personName: 'Aarav',
  clothing: 'Green shirt',
  assignment:
      assigned
          ? OpsAssignment(id: 'a1', status: status, volunteerId: volunteerId)
          : null,
);

class FakeOps implements OpsRepository {
  OpsMe meResult = volunteer;
  Object? meError;
  OpsOverview overviewResult = const OpsOverview(active: 2, pending: 1);
  List<OpsCase> cases = const [];
  OpsCase detail = caseOf();
  Object? signInError;
  List<TeamMember> members = const [];
  List<ZoneInfo> zoneList = const [];
  List<OpsSosRow> sos = const [];
  final progressed = <String>[];
  final observations = <String>[];
  final escalated = <String>[];
  final assigned = <String>[];
  final availability = <String>[];
  final sosActions = <String>[];
  int unassignCalls = 0;
  String? setupCode;

  @override
  Future<String> signIn(String phone, String password) async {
    final error = signInError;
    if (error != null) throw error;
    return 'token';
  }

  @override
  Future<String> completeSetup(
    String phone,
    String code,
    String password,
  ) async {
    setupCode = code;
    final error = signInError;
    if (error != null) throw error;
    return 'token';
  }

  @override
  Future<OpsMe> me() async {
    final error = meError;
    if (error != null) throw error;
    return meResult;
  }

  @override
  Future<OpsOverview> overview() async => overviewResult;

  @override
  Future<void> setAvailability(String value) async => availability.add(value);

  @override
  Future<List<OpsCase>> myCases({String status = 'open', String? type}) async =>
      cases;

  @override
  Future<List<OpsCase>> unassigned() async => cases;

  @override
  Future<List<OpsCase>> escalations() async => cases;

  @override
  Future<OpsCase> caseDetail(String id) async => detail;

  @override
  Future<void> progress(String id, String status) async =>
      progressed.add(status);

  @override
  Future<void> addObservation(String id, String body) async =>
      observations.add(body);

  @override
  Future<void> escalate(String id, String reason) async =>
      escalated.add(reason);

  @override
  Future<void> assign(
    String id,
    String volunteerId, {
    String notes = '',
  }) async => assigned.add(volunteerId);

  @override
  Future<void> unassign(String id) async => unassignCalls++;

  @override
  Future<List<OpsAssignment>> history(String id) async => const [];

  @override
  Future<List<TeamMember>> team() async => members;

  @override
  Future<List<ZoneInfo>> zones() async => zoneList;

  @override
  Future<List<OpsSosRow>> sosList() async => sos;

  @override
  Future<void> sosAction(String id, String action, {String? body}) async =>
      sosActions.add(action);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    dotenv.loadFromString(envString: 'API_HOST=example.test');
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<FakeOps> openHome(WidgetTester tester, OpsMe me) async {
    final repo = FakeOps()..meResult = me;
    await t.pumpApp(
      tester,
      VolunteerHomeScreen(repository: repo),
      size: const Size(1080, 3200),
    );
    return repo;
  }

  group('routing by role', () {
    Future<List<String>> after(WidgetTester tester, FakeOps repo) async {
      final pushed = <String>[];
      await t.pumpApp(
        tester,
        Navigator(
          observers: [_Spy(pushed)],
          onGenerateRoute:
              (s) => MaterialPageRoute(
                settings: s,
                builder: (context) {
                  if (s.name == '/') {
                    openOperationsIfAllowed(
                      Navigator.of(context),
                      repository: repo,
                    );
                  }
                  return const SizedBox();
                },
              ),
        ),
      );
      return pushed;
    }

    testWidgets('a pilgrim stays on the normal app', (tester) async {
      final repo = FakeOps()..meResult = const OpsMe(role: 'PILGRIM');
      expect(await after(tester, repo), isEmpty);
    });

    testWidgets('a failure leaves the normal app alone', (tester) async {
      final repo = FakeOps()..meError = denied;
      expect(await after(tester, repo), isEmpty);
    });

    testWidgets('a volunteer goes to their dashboard', (tester) async {
      expect(await after(tester, FakeOps()), ['/ops']);
    });
  });

  group('dashboards', () {
    testWidgets('a volunteer sees the volunteer dashboard', (tester) async {
      await openHome(tester, volunteer);
      expect(find.text('Volunteer Dashboard'), findsOneWidget);
      expect(find.text('Scan a Safety QR'), findsOneWidget);
      expect(find.text('Register a found person'), findsOneWidget);
    });

    testWidgets('a volunteer has no coordinator tools', (tester) async {
      await openHome(tester, volunteer);
      expect(find.text('SOS alerts'), findsNothing);
      expect(find.text('Manage cases'), findsNothing);
      expect(find.text('Volunteers and workload'), findsNothing);
    });

    testWidgets('a help desk sees case and SOS tools', (tester) async {
      await openHome(tester, desk);
      expect(find.text('Help Desk Dashboard'), findsOneWidget);
      expect(find.text('Register a missing person'), findsOneWidget);
      expect(find.text('SOS alerts'), findsOneWidget);
      expect(find.text('Volunteers and workload'), findsNothing);
    });

    testWidgets('a coordinator sees the operations view', (tester) async {
      final repo =
          FakeOps()
            ..overviewResult = const OpsOverview(
              openSos: 2,
              escalations: 1,
              unassigned: 3,
            );
      repo.meResult = coordinator;
      await t.pumpApp(
        tester,
        VolunteerHomeScreen(repository: repo),
        size: const Size(1080, 3200),
      );
      expect(find.text('Safety Operations'), findsOneWidget);
      expect(find.text('Open SOS'), findsOneWidget);
      expect(find.text('Escalations'), findsOneWidget);
      expect(find.text('Volunteers and workload'), findsOneWidget);
    });

    testWidgets('pending shows no tools', (tester) async {
      await openHome(tester, const OpsMe(role: 'VOLUNTEER', status: 'pending'));
      expect(find.text('Waiting for approval'), findsOneWidget);
      expect(find.text('Scan a Safety QR'), findsNothing);
    });

    testWidgets('suspended shows no tools', (tester) async {
      await openHome(
        tester,
        const OpsMe(role: 'VOLUNTEER', status: 'suspended'),
      );
      expect(find.text('Your account is suspended'), findsOneWidget);
    });

    testWidgets('a failed load offers a retry', (tester) async {
      final repo =
          FakeOps()..meError = const FamilyException(FamilyFailure.offline);
      await t.pumpApp(tester, VolunteerHomeScreen(repository: repo));
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('the profile can change availability only', (tester) async {
      final repo = await openHome(tester, volunteer);
      await tester.tap(find.text('Profile'));
      await t.settle(tester);
      expect(find.textContaining('Only an administrator'), findsOneWidget);
      await tester.tap(find.text('Busy'));
      await t.settle(tester);
      expect(repo.availability, ['BUSY']);
    });

    testWidgets('cases show priority in words', (tester) async {
      final repo = FakeOps()..cases = [caseOf(priority: 'high')];
      await t.pumpApp(tester, VolunteerHomeScreen(repository: repo));
      await tester.tap(find.text('Cases'));
      await t.settle(tester);
      expect(find.text('High priority'), findsOneWidget);
      expect(find.text('LF-ABCD2345'), findsOneWidget);
    });

    testWidgets('no cases is said plainly', (tester) async {
      await openHome(tester, volunteer);
      await tester.tap(find.text('Cases'));
      await t.settle(tester);
      expect(find.text('No cases here'), findsOneWidget);
    });

    testWidgets('only coordinators get the unassigned view', (tester) async {
      await openHome(tester, volunteer);
      await tester.tap(find.text('Cases'));
      await t.settle(tester);
      expect(find.text('Unassigned'), findsNothing);
    });

    testWidgets('zones show verified places only', (tester) async {
      final repo =
          FakeOps()
            ..zoneList = const [
              ZoneInfo(
                zone: OpsZone(id: 'z', name: 'Ramkund'),
                points: [ZonePoint(name: 'Desk', category: 'help_desk')],
              ),
            ];
      await t.pumpApp(tester, VolunteerHomeScreen(repository: repo));
      await tester.tap(find.text('Zones'));
      await t.settle(tester);
      expect(find.text('Desk'), findsOneWidget);
      expect(
        find.textContaining('Verified by Kumbh Path staff'),
        findsOneWidget,
      );
    });
  });

  group('case work', () {
    Future<FakeOps> open(
      WidgetTester tester,
      OpsCase detail, {
      OpsMe me = volunteer,
      List<TeamMember> members = const [],
    }) async {
      final repo =
          FakeOps()
            ..detail = detail
            ..meResult = me
            ..members = members;
      await t.pumpApp(
        tester,
        AssignedCaseScreen(id: caseId, repository: repo),
        size: const Size(1080, 3600),
      );
      return repo;
    }

    testWidgets('the next step moves the work on', (tester) async {
      final repo = await open(tester, caseOf());
      await tester.tap(find.text('Accept this case'));
      await t.settle(tester);
      expect(repo.progressed, ['ACCEPTED']);
    });

    testWidgets('finishing is explained as your task only', (tester) async {
      await open(tester, caseOf(status: 'IN_PROGRESS'));
      expect(find.text('Mark my task complete'), findsOneWidget);
      expect(find.textContaining('doesn\'t mark anyone'), findsOneWidget);
    });

    testWidgets('someone else\'s assignment offers no steps', (tester) async {
      await open(tester, caseOf(volunteerId: 'other'));
      expect(find.text('Accept this case'), findsNothing);
    });

    testWidgets('a volunteer has no assign controls', (tester) async {
      await open(tester, caseOf());
      expect(find.text('Reassign'), findsNothing);
      expect(find.text('Open the full case'), findsNothing);
    });

    testWidgets('a child\'s case warns and asks for staff', (tester) async {
      await open(tester, caseOf(priority: 'high'));
      expect(
        find.textContaining('exact position isn\'t shown'),
        findsOneWidget,
      );
    });

    testWidgets('an observation stays with staff', (tester) async {
      final repo = await open(tester, caseOf());
      await tester.tap(find.text('Add an observation'));
      await t.settle(tester);
      await tester.enterText(find.byType(TextField), 'Near the gate');
      await tester.tap(find.text('Send'));
      await t.settle(tester);
      expect(repo.observations, ['Near the gate']);
    });

    testWidgets('escalating asks why', (tester) async {
      final repo = await open(tester, caseOf());
      await tester.tap(find.text('Escalate to a coordinator'));
      await t.settle(tester);
      await tester.enterText(find.byType(TextField), 'Needs a coordinator');
      await tester.tap(find.text('Escalate to a coordinator').last);
      await t.settle(tester);
      expect(repo.escalated, ['Needs a coordinator']);
    });

    testWidgets('a coordinator can assign someone available', (tester) async {
      final repo = await open(
        tester,
        caseOf(assigned: false),
        me: coordinator,
        members: const [
          TeamMember(userId: 'v1', name: 'Asha', role: 'VOLUNTEER'),
          TeamMember(
            userId: 'v2',
            name: 'Off Duty',
            role: 'VOLUNTEER',
            availability: 'OFF_DUTY',
          ),
        ],
      );
      await tester.tap(find.text('Assign a volunteer'));
      await t.settle(tester);
      await tester.tap(find.text('Off Duty'), warnIfMissed: false);
      await t.settle(tester);
      expect(repo.assigned, isEmpty);
      await tester.tap(find.text('Asha'));
      await t.settle(tester);
      expect(repo.assigned, ['v1']);
    });

    testWidgets('removing an assignment asks first', (tester) async {
      final repo = await open(tester, caseOf(), me: coordinator);
      await tester.tap(find.text('Remove assignment'));
      await t.settle(tester);
      expect(repo.unassignCalls, 0);
      await tester.tap(find.text('Remove assignment').last);
      await t.settle(tester);
      expect(repo.unassignCalls, 1);
    });
  });

  group('sos responder', () {
    Future<FakeOps> open(
      WidgetTester tester,
      String status, {
      bool active = true,
    }) async {
      final repo = FakeOps();
      await t.pumpApp(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: SosResponderPanel(
              sos: sos.detailOf(role: 'ops', status: status, active: active),
              onChanged: () async {},
              repository: repo,
            ),
          ),
        ),
        size: const Size(1080, 2400),
      );
      return repo;
    }

    testWidgets('says nothing here contacts emergency services', (
      tester,
    ) async {
      await open(tester, 'SUBMITTED');
      expect(find.textContaining('don\'t contact police'), findsOneWidget);
    });

    testWidgets('acknowledging is deliberate', (tester) async {
      final repo = await open(tester, 'FAMILY_NOTIFIED');
      await tester.tap(find.text('Acknowledge as responder'));
      await t.settle(tester);
      expect(repo.sosActions, isEmpty);
      await tester.tap(find.text('Acknowledge as responder').last);
      await t.settle(tester);
      expect(repo.sosActions, ['acknowledge']);
    });

    testWidgets('it can\'t be resolved before acknowledging', (tester) async {
      await open(tester, 'SUBMITTED');
      expect(find.text('Mark resolved'), findsNothing);
    });

    testWidgets('resolving needs a note', (tester) async {
      final repo = await open(tester, 'ACKNOWLEDGED');
      await tester.tap(find.text('Mark resolved'));
      await t.settle(tester);
      await tester.tap(find.text('Send'));
      await t.settle(tester);
      expect(repo.sosActions, isEmpty);
    });

    testWidgets('a resolved SOS can only be closed', (tester) async {
      await open(tester, 'RESOLVED', active: false);
      expect(find.text('Close this case'), findsOneWidget);
      expect(find.text('Escalate to a coordinator'), findsNothing);
    });
  });

  group('sign-in', () {
    Future<(FakeOps, List<String>)> open(
      WidgetTester tester, {
      Object? error,
    }) async {
      final repo = FakeOps()..signInError = error;
      final saved = <String>[];
      await t.pumpApp(
        tester,
        OpsSignInScreen(repository: repo, saveToken: (v) async => saved.add(v)),
      );
      return (repo, saved);
    }

    Future<void> fill(WidgetTester tester, List<String> values) async {
      final fields = find.byType(TextField);
      for (final (i, value) in values.indexed) {
        await tester.enterText(fields.at(i), value);
      }
      await t.settle(tester);
    }

    testWidgets('signs in and stores the token', (tester) async {
      final (_, saved) = await open(tester);
      await fill(tester, ['9000000000', 'password']);
      await tester.tap(find.text('Sign in').last);
      await t.settle(tester);
      expect(saved, ['token']);
      expect(find.text('route:/dashboardScreen'), findsOneWidget);
    });

    testWidgets('a wrong password says only that', (tester) async {
      final (_, saved) = await open(tester, error: denied);
      await fill(tester, ['9000000000', 'wrong']);
      await tester.tap(find.text('Sign in').last);
      await t.settle(tester);
      expect(find.text('Those details don\'t match.'), findsOneWidget);
      expect(saved, isEmpty);
    });

    testWidgets('first time uses the one-time code', (tester) async {
      final (repo, saved) = await open(tester);
      await tester.tap(find.text('First time? Use your one-time code'));
      await t.settle(tester);
      await fill(tester, ['9000000000', 'ABCD234567', 'long password']);
      await tester.tap(find.text('Set password and sign in'));
      await t.settle(tester);
      expect(repo.setupCode, 'ABCD234567');
      expect(saved, ['token']);
    });

    testWidgets('empty fields are caught', (tester) async {
      await open(tester);
      await tester.tap(find.text('Sign in').last);
      await t.settle(tester);
      expect(find.text('Fill in every field.'), findsOneWidget);
    });

    testWidgets('the password is hidden by default', (tester) async {
      await open(tester);
      final field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.obscureText, isTrue);
    });
  });

  group('repository', () {
    test('sign-in sends no token', () async {
      late http.Request sent;
      final client = HttpOpsRepository(
        client: MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'data': {'access_token': 'abc'},
            }),
            200,
          );
        }),
        token: () async => 'stale',
        requireHttps: false,
      );
      expect(await client.signIn('9000000000', 'x'), 'abc');
      expect(sent.headers.containsKey('Authorization'), isFalse);
    });

    test('a role is read as the server sent it', () {
      final me = OpsMe.fromJson({
        'role': 'VOLUNTEER',
        'status': 'active',
        'can': {'scan': true, 'assign_cases': false},
      });
      expect(me.canScan, isTrue);
      expect(me.canAssign, isFalse);
      expect(me.isPilgrim, isFalse);
    });

    test('an unknown answer means pilgrim', () {
      expect(OpsMe.fromJson(const {}).isPilgrim, isTrue);
    });

    test('nothing role-related is stored on the phone', () {
      for (final file
          in Directory(
            'lib/src/modules/operations',
          ).listSync(recursive: true).whereType<File>()) {
        final text = file.readAsStringSync();
        expect(text, isNot(contains('SharedPreferences')));
        if (!file.path.contains('sign_in')) {
          expect(text, isNot(contains('storage.write')));
        }
        expect(text, isNot(contains('print(')));
      }
    });
  });

  group('routing and text', () {
    test('an assignment opens its case', () {
      final data = {'type': 'operations_case', 'case_id': caseId};
      expect(NotificationRouter.routeFor(data), '/opsCase');
      expect(NotificationRouter.argumentsFor('/opsCase', data), caseId);
    });

    Map<String, dynamic> language(String code) =>
        json.decode(File('assets/translations/$code.json').readAsStringSync())
            as Map<String, dynamic>;

    test('every key exists in all three languages', () {
      bool ours(String k) => k.startsWith('ops_');
      final en = language('en').keys.where(ours).toSet();
      expect(language('hi').keys.where(ours).toSet(), en);
      expect(language('mr').keys.where(ours).toSet(), en);
    });

    test('every key used in code exists', () {
      final en = language('en');
      final used = <String>{};
      for (final file
          in Directory(
            'lib/src/modules/operations',
          ).listSync(recursive: true).whereType<File>()) {
        used.addAll(
          RegExp(
            r"'(ops_[a-z_]+)'",
          ).allMatches(file.readAsStringSync()).map((m) => m.group(1)!),
        );
      }
      for (final role in [
        'VOLUNTEER',
        'HELP_DESK_OPERATOR',
        'SAFETY_COORDINATOR',
        'ADMIN',
      ]) {
        used
          ..add('ops_role_$role')
          ..add('ops_title_$role');
      }
      for (final s in availabilityStates) {
        used.add('ops_avail_$s');
      }
      for (final s in [
        'ASSIGNED',
        'ACCEPTED',
        'IN_PROGRESS',
        'ESCALATED',
        'COMPLETED',
        'REASSIGNED',
      ]) {
        used.add('ops_assign_$s');
      }
      for (final s in ['pending', 'active', 'suspended', 'deactivated']) {
        used.add('ops_status_$s');
      }
      expect(used.where((k) => !en.containsKey(k)), isEmpty);
    });
  });
}

class _Spy extends NavigatorObserver {
  _Spy(this.pushed);

  final List<String> pushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null && name != '/') pushed.add(name);
  }
}
