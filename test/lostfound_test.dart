import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:kumbha_path/src/modules/family/offline/contact_store.dart';
import 'package:kumbha_path/src/modules/lostfound/case_screens.dart';
import 'package:kumbha_path/src/modules/lostfound/data/lf_drafts.dart';
import 'package:kumbha_path/src/modules/lostfound/data/lf_repository.dart';
import 'package:kumbha_path/src/modules/lostfound/lostfound_home_screen.dart';
import 'package:kumbha_path/src/modules/lostfound/models/lf_models.dart';
import 'package:kumbha_path/src/modules/lostfound/ops_screens.dart';
import 'package:kumbha_path/src/modules/lostfound/report_screens.dart';
import 'package:kumbha_path/src/services/notification_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    return json.decode(await file.readAsString()) as Map<String, dynamic>;
  }
}

const offline = FamilyException(FamilyFailure.offline);
const caseId = '3f2b8c1e-7a44-4d19-9f0e-6c1d2a7b4e55';

const summary = CaseSummary(
  id: caseId,
  reference: 'LF-ABCD2345',
  caseType: 'lost',
  status: 'SUBMITTED',
  personName: 'Aarav',
);

CaseDetail detailOf({
  String status = 'SUBMITTED',
  bool mine = true,
  List<Sighting> sightings = const [],
  double? lat,
}) => CaseDetail(
  id: caseId,
  reference: 'LF-ABCD2345',
  caseType: 'lost',
  status: status,
  personName: 'Aarav',
  ageMin: 8,
  ageMax: 10,
  clothing: 'Blue kurta',
  locationText: 'Ramkund',
  eventAt: DateTime(2027, 8, 1, 10),
  latitude: lat,
  longitude: lat == null ? null : 73.7,
  isMyReport: mine,
  sightings: sightings,
  timeline: [
    TimelineEvent(kind: 'status', status: status, at: DateTime(2027, 8, 1, 11)),
  ],
);

const side = MatchSide(
  id: caseId,
  reference: 'LF-LOST0001',
  ageMin: 8,
  ageMax: 10,
  clothing: 'Blue kurta',
  locationText: 'Ramkund',
);
const reasons = [
  MatchReason(
    attribute: 'clothing',
    points: 25,
    outOf: 30,
    detail: 'blue, cap',
  ),
  MatchReason(
    attribute: 'age',
    points: 25,
    outOf: 25,
    detail: 'age ranges overlap',
  ),
];
CaseMatch matchOf([String state = 'suggested']) => CaseMatch(
  id: 'm1',
  score: 62,
  state: state,
  lost: side,
  found: side,
  reasons: reasons,
);

OpsCase opsOf({
  String status = 'UNDER_REVIEW',
  bool vulnerable = false,
  List<CaseMatch> matches = const [],
  List<Sighting> sightings = const [],
  bool linked = false,
}) => OpsCase(
  row: OpsCaseRow(
    id: caseId,
    reference: 'LF-ABCD2345',
    caseType: 'lost',
    status: status,
    isVulnerable: vulnerable,
  ),
  detail: detailOf(status: status),
  matches: matches,
  sightings: sightings,
  allowedStatuses: const ['VERIFICATION_REQUIRED', 'CLOSED'],
  linkedToFamily: linked,
);

class FakeLf implements LostFoundRepository {
  CaseAi ai = const CaseAi(available: true);
  FamilyException? aiFailure;
  final aiCalls = <String>[];

  Future<void> _aiCall(String name) async {
    aiCalls.add(name);
    if (aiFailure != null) throw aiFailure!;
  }

  @override
  Future<CaseAi> caseAi(String id) async {
    await _aiCall('load');
    return ai;
  }

  @override
  Future<void> translateCase(String id, String field, String language) =>
      _aiCall('translate:$field:$language');

  @override
  Future<void> reviewTranslation(String translationId, String text) =>
      _aiCall('review:$text');

  @override
  Future<void> extractCase(String id) => _aiCall('extract');

  @override
  Future<void> reviewExtraction(
    String id,
    bool accept, {
    Map<String, Object?> corrections = const {},
  }) => _aiCall('details:$accept:$corrections');

  LfCapabilities me = const LfCapabilities();
  List<CaseSummary> cases = [];
  CaseDetail detail = detailOf();
  OpsCase ops = opsOf();
  FamilyException? failure;
  FamilyException? createFailure;
  bool loseFirstReply = false;
  final made = <String, CaseSummary>{};
  final bodies = <Map<String, dynamic>>[];
  final uploads = <String?>[];
  final calls = <String>[];

  void _gate() {
    final f = failure;
    if (f != null) throw f;
  }

  Future<CaseSummary> _report(Map<String, dynamic> data) async {
    _gate();
    final f = createFailure;
    if (f != null) throw f;
    bodies.add(data);
    final id = data['client_id'] as String;
    final existing = made[id];
    if (existing != null) {
      return CaseSummary(
        id: existing.id,
        reference: existing.reference,
        caseType: existing.caseType,
        status: existing.status,
        duplicate: true,
      );
    }
    final created = CaseSummary(
      id: 'case-$id',
      reference: 'LF-NEW00001',
      caseType: 'lost',
      status: 'SUBMITTED',
    );
    made[id] = created;
    if (loseFirstReply) {
      loseFirstReply = false;
      throw offline;
    }
    return created;
  }

  @override
  Future<CaseSummary> reportLost(Map<String, dynamic> data) => _report(data);

  @override
  Future<CaseSummary> reportFound(Map<String, dynamic> data) => _report(data);

  @override
  Future<LfCapabilities> capabilities() async {
    _gate();
    return me;
  }

  @override
  Future<List<CaseSummary>> myCases() async {
    _gate();
    return cases;
  }

  @override
  Future<CaseDetail> caseDetail(String id) async {
    _gate();
    return detail;
  }

  @override
  Future<void> addInfo(String id, String body) async => calls.add('info:$body');

  @override
  Future<void> requestCorrection(String id, String body) async =>
      calls.add('correction:$body');

  @override
  Future<void> cancel(String id, String reason) async => calls.add('cancel');

  @override
  Future<void> confirmReunion(String id) async => calls.add('confirm');

  @override
  Future<void> addSighting(String id, Map<String, dynamic> data) async =>
      calls.add('sighting');

  @override
  Future<void> uploadPhoto(
    String id,
    Uint8List bytes, {
    String? clientId,
  }) async {
    _gate();
    uploads.add(clientId);
  }

  @override
  Future<Uint8List?> attachment(String id) async => null;

  @override
  Future<OpsPage> opsCases({
    String? type,
    String? status,
    String? query,
    bool mine = false,
  }) async {
    _gate();
    calls.add('ops:$type:$status:$query:$mine');
    return OpsPage(rows: [ops.row], count: 1);
  }

  @override
  Future<OpsCase> opsCase(String id) async {
    _gate();
    return ops;
  }

  @override
  Future<OpsCase> changeStatus(String id, String status, String reason) async {
    calls.add('status:$status:$reason');
    return ops;
  }

  @override
  Future<OpsCase> assignToMe(String id) async => ops;

  @override
  Future<OpsCase> addNote(String id, String kind, String body) async {
    calls.add('note:$kind');
    return ops;
  }

  @override
  Future<String?> revealContact(String id) async {
    calls.add('reveal');
    return '+919812345678';
  }

  @override
  Future<OpsCase> findMatches(String id) async => ops;

  @override
  Future<OpsCase> verify(String id, String method, String remarks) async => ops;

  @override
  Future<OpsCase> reunite(
    String id, {
    required String method,
    required String remarks,
    required bool identityChecked,
    required bool personRecognised,
  }) async {
    calls.add('reunite:$identityChecked:$personRecognised');
    return ops;
  }

  @override
  Future<OpsCase> reviewSighting(
    String sightingId, {
    required bool approve,
    bool verified = false,
  }) async {
    calls.add('review:$approve:$verified');
    return ops;
  }

  @override
  Future<void> approveMatch(String id, {required bool notifyFamily}) async =>
      calls.add('approve:$notifyFamily');

  @override
  Future<void> dismissMatch(String id, String reason) async =>
      calls.add('dismiss');

  @override
  Future<void> confirmMatch(String id, String method, String remarks) async =>
      calls.add('confirmMatch');
}

class MemoryDrafts implements DraftStore {
  final rows = <String, ReportDraft>{};

  @override
  Future<List<ReportDraft>> all() async => rows.values.toList();

  @override
  Future<ReportDraft?> one(String id) async => rows[id];

  @override
  Future<void> save(ReportDraft draft) async => rows[draft.id] = draft;

  @override
  Future<void> remove(String id) async => rows.remove(id);

  @override
  Future<void> clear() async => rows.clear();
}

class NoFamily implements FamilyRepository {
  @override
  Future<List<FamilyCircle>> circles() async => const [
    FamilyCircle(id: 'f1', name: 'More', myMemberId: 'm1'),
  ];

  @override
  Future<List<FamilyMember>> members(String familyId) async => const [
    FamilyMember(
      id: 'm3',
      name: 'Aarav More',
      kind: 'dependent_child',
      role: 'member',
      relationship: 'son',
      isDependent: true,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  for (var i = 0; i < 40 && find.text(text).evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 50));
  }
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLf repo;
  late MemoryDrafts store;
  late ReportSender sender;
  late List<String> pushed;

  setUpAll(() async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    dotenv.loadFromString(
      envString: 'API_PROTOCOL=https\nAPI_HOST=api.example.test',
    );
  });

  setUp(() {
    repo = FakeLf();
    store = MemoryDrafts();
    sender = ReportSender(remote: repo, store: store);
    LostFoundServices.repository = repo;
    LostFoundDrafts.sender = sender;
    pushed = [];
  });

  Future<void> pumpApp(
    WidgetTester tester,
    Widget home, {
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.light,
    double textScale = 1,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Route<dynamic> route(RouteSettings settings) {
      pushed.add(settings.name ?? '');
      final args = settings.arguments;
      final Widget page = switch (settings.name) {
        '/lostFoundDone' => ReportDoneScreen(result: args! as SubmitResult),
        '/lostFoundOpsCase' => OpsCaseScreen(id: args! as String),
        '/lostFoundMatch' => MatchReviewScreen(match: args! as CaseMatch),
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

  group('Drafts', () {
    late Directory dir;
    late Database db;
    late SqlDraftStore sql;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('drafts');
      db = await databaseFactoryFfi.openDatabase(
        '${dir.path}/t.db',
        options: OpenDatabaseOptions(
          version: SqlContactStore.schemaVersion,
          onCreate: SqlContactStore.createSchema,
        ),
      );
      sql = SqlDraftStore(() async => db);
    });

    tearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });

    ReportDraft ready(String id) => ReportDraft(
      id: id,
      kind: 'lost',
      fields: const {'person_name': 'Aarav'},
      photo: Uint8List.fromList([1, 2, 3]),
    );

    test('survive being closed and reopened, photo included', () async {
      await sql.save(ready('d1'));
      final loaded = await SqlDraftStore(() async => db).one('d1');
      expect(loaded?.fields['person_name'], 'Aarav');
      expect(loaded?.photo, [1, 2, 3]);
      expect(loaded?.state, DraftState.editing);
    });

    test('an older database gains the table without losing data', () async {
      final path = '${dir.path}/old.db';
      var old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate:
              (d, _) => d.execute(
                'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
              ),
        ),
      );
      await old.insert('meta', {'key': 'account', 'value': 'u1'});
      await old.close();
      old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: SqlContactStore.schemaVersion,
          onUpgrade: SqlContactStore.upgradeSchema,
        ),
      );
      await SqlDraftStore(() async => old).save(ready('d2'));
      expect((await old.query('meta')).single['value'], 'u1');
      expect((await old.query('lf_drafts')).length, 1);
      await old.close();
    });

    test('offline: stays on the phone and claims nothing', () async {
      final send = ReportSender(remote: repo, store: sql);
      repo.failure = offline;
      final result = await send.submit(ready('d1'));
      expect(result.waiting, isTrue);
      expect(result.reference, isNull);
      expect((await sql.one('d1'))?.state, DraftState.waiting);
    });

    test('sends by itself when the connection returns', () async {
      final network = StreamController<bool>.broadcast();
      addTearDown(network.close);
      final send = ReportSender(
        remote: repo,
        store: sql,
        online: network.stream,
      );
      repo.failure = offline;
      await send.submit(ready('d1'));
      send.start();
      await send.sendWaiting();
      repo.failure = null;
      network.add(true);
      await pumpEventQueue();
      await send.sendWaiting();
      expect(repo.made, hasLength(1));
      expect(await sql.all(), isEmpty);
    });

    test('a lost reply can\'t create a second case', () async {
      final send = ReportSender(remote: repo, store: sql);
      repo.loseFirstReply = true;
      final first = await send.submit(ready('d1'));
      expect(first.waiting, isTrue, reason: 'the reply never arrived');
      await send.sendWaiting();
      expect(repo.made, hasLength(1));
      expect(repo.bodies, hasLength(2));
      expect(repo.bodies.first['client_id'], repo.bodies.last['client_id']);
      expect(await sql.all(), isEmpty);
    });

    test('two triggers at once send it once', () async {
      final send = ReportSender(remote: repo, store: sql);
      await sql.save(ready('d1').copyWith(state: DraftState.waiting));
      await Future.wait([send.sendWaiting(), send.sendWaiting()]);
      expect(repo.bodies, hasLength(1));
    });

    test('the photo is retried without resending the report', () async {
      final send = ReportSender(remote: repo, store: sql);
      await sql.save(
        ready(
          'd1',
        ).copyWith(state: DraftState.uploadingPhoto, caseId: 'case-1'),
      );
      await send.sendWaiting();
      expect(repo.bodies, isEmpty);
      expect(repo.uploads, ['d1']);
    });

    test('a refused report goes back for editing', () async {
      final send = ReportSender(remote: repo, store: sql);
      repo.createFailure = const FamilyException(FamilyFailure.invalid);
      final result = await send.submit(ready('d1'));
      expect(result.refused, isNotNull);
      expect((await sql.one('d1'))?.state, DraftState.refused);
    });

    test('sign-out removes drafts', () async {
      await sql.save(ready('d1'));
      await ReportSender(remote: repo, store: sql).wipe();
      expect(await sql.all(), isEmpty);
    });

    test('a different account clears them too', () async {
      await sql.save(ready('d1'));
      await SqlContactStore(() async => db).clear();
      expect(await sql.all(), isEmpty);
    });

    test('text forms hide the contents', () {
      expect('${ready('d1')}', isNot(contains('Aarav')));
    });
  });

  group('Repository', () {
    test('uses the header, keeps details out of URLs', () async {
      late http.Request seen;
      final repo = HttpLostFoundRepository(
        client: MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({
              'status': 'success',
              'data': {'id': 'c', 'reference': 'LF-1'},
            }),
            201,
          );
        }),
        token: () async => 'JWT',
        requireHttps: false,
      );
      await repo.reportLost({'person_name': 'Aarav', 'client_id': 'x'});
      expect(seen.headers['Authorization'], 'Bearer JWT');
      expect(seen.url.toString(), isNot(contains('Aarav')));
    });

    test('maps failures', () async {
      Future<FamilyFailure> failure(int code) async {
        final repo = HttpLostFoundRepository(
          client: MockClient((_) async => http.Response('{}', code)),
          token: () async => 'JWT',
          requireHttps: false,
        );
        try {
          await repo.caseDetail('x');
        } on FamilyException catch (e) {
          return e.kind;
        }
        throw StateError('expected a failure');
      }

      expect(await failure(403), FamilyFailure.forbidden);
      expect(await failure(404), FamilyFailure.notFound);
      expect(await failure(409), FamilyFailure.conflict);
    });

    test('release builds refuse plain HTTP', () {
      final source =
          File(
            'lib/src/modules/lostfound/data/lf_repository.dart',
          ).readAsStringSync();
      expect(source, contains("requireHttps && ApiConst.protocol != 'https'"));
      expect(source, contains('this.requireHttps = kReleaseMode'));
    });
  });

  group('Models', () {
    test('a helper\'s report is recognised as not the family view', () {
      final d = CaseDetail.fromJson(const {
        'id': 'c',
        'reference': 'LF-1',
        'case_type': 'found',
        'status': 'SUBMITTED',
      });
      expect(d.familyView, isFalse);
    });

    test('a confirmed match can\'t be cancelled', () {
      expect(detailOf(status: 'MATCH_CONFIRMED').canCancel, isFalse);
      expect(detailOf().canCancel, isTrue);
      expect(detailOf(mine: false).canCancel, isFalse);
    });
  });

  group('Home', () {
    testWidgets('leads with the urgent action, and is honest', (tester) async {
      await pumpApp(tester, LostFoundHomeScreen(repository: repo));
      expect(find.text('lf_report_missing'.tr()), findsOneWidget);
      expect(find.text('lf_now_title'.tr()), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -800));
      await tester.pump();
      expect(find.text('lf_not_official'.tr()), findsOneWidget);
    });

    testWidgets('an ordinary user sees no helper tools', (tester) async {
      await pumpApp(tester, LostFoundHomeScreen(repository: repo));
      expect(find.text('lf_helper_tools'.tr()), findsNothing);
      expect(find.text('lf_ops_title'.tr()), findsNothing);
    });

    testWidgets('helpers and staff see theirs', (tester) async {
      repo.me = const LfCapabilities(
        role: 'safety_staff',
        canReportFound: true,
        canOperate: true,
        isStaff: true,
      );
      await pumpApp(tester, LostFoundHomeScreen(repository: repo));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pump();
      expect(find.text('lf_report_found'.tr()), findsOneWidget);
      expect(find.text('lf_ops_title'.tr()), findsOneWidget);
    });

    testWidgets('lists reports with reference and status', (tester) async {
      repo.cases = const [summary];
      await pumpApp(tester, LostFoundHomeScreen(repository: repo), width: 390);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pump();
      expect(find.text('Aarav'), findsOneWidget);
      expect(find.textContaining('LF-ABCD2345'), findsOneWidget);
    });

    testWidgets('a waiting report is never shown as submitted', (tester) async {
      await store.save(
        const ReportDraft(
          id: 'd1',
          kind: 'lost',
          fields: {},
          state: DraftState.waiting,
        ),
      );
      await pumpApp(tester, LostFoundHomeScreen(repository: repo));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pump();
      expect(find.text('lf_waiting_title'.tr()), findsOneWidget);
    });

    testWidgets('offline, reporting and advice still work', (tester) async {
      repo.failure = offline;
      await pumpApp(tester, LostFoundHomeScreen(repository: repo));
      expect(find.text('lf_report_missing'.tr()), findsOneWidget);
      expect(find.text('lf_now_title'.tr()), findsOneWidget);
    });

    for (final (name, locale, brightness, scale, width) in const [
      ('dark', Locale('en'), Brightness.dark, 1.0, 390.0),
      ('Hindi large', Locale('hi'), Brightness.light, 1.6, 390.0),
      ('Marathi dark', Locale('mr'), Brightness.dark, 1.3, 390.0),
      ('narrow', Locale('en'), Brightness.light, 1.3, 320.0),
    ]) {
      testWidgets('fits: $name', (tester) async {
        repo.cases = const [summary];
        await pumpApp(
          tester,
          LostFoundHomeScreen(repository: repo),
          locale: locale,
          brightness: brightness,
          textScale: scale,
          width: width,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Report missing', () {
    Future<void> open(WidgetTester tester) async {
      await pumpApp(
        tester,
        ReportLostScreen(
          families: NoFamily(),
          position: () async => (19.99, 73.78),
          photoPicker: () async => Uint8List.fromList([1]),
        ),
      );
    }

    Future<void> fill(WidgetTester tester) async {
      await tester.enterText(find.byType(TextFormField).at(3), 'Son');
      await tapText(tester, 'fam_continue'.tr());
      await tester.enterText(find.byType(TextFormField).at(1), 'Blue kurta');
      await tapText(tester, 'fam_continue'.tr());
      final state = tester.state(find.byType(ReportLostScreen)) as dynamic;
      state.when = DateTime(2026, 10, 1, 10);
      await tester.enterText(find.byType(TextFormField).first, 'Ramkund');
      await tapText(tester, 'fam_continue'.tr());
    }

    testWidgets('each step checks what it needs', (tester) async {
      await open(tester);
      await tapText(tester, 'fam_continue'.tr());
      expect(find.text('lf_need_relationship'.tr()), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(3), 'Son');
      await tapText(tester, 'fam_continue'.tr());
      await tapText(tester, 'fam_continue'.tr());
      expect(find.text('lf_need_description'.tr()), findsOneWidget);
    });

    testWidgets('can use someone from the family', (tester) async {
      await open(tester);
      expect(find.text('Aarav More'), findsOneWidget);
      await tapText(tester, 'Aarav More');
      await tester.enterText(find.byType(TextFormField).at(3), 'Son');
      await tapText(tester, 'fam_continue'.tr());
      expect(store.rows.values.single.fields['member_id'], 'm3');
    });

    testWidgets('every step is saved as it goes', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextFormField).at(3), 'Son');
      await tapText(tester, 'fam_continue'.tr());
      expect(store.rows.values.single.fields['relationship'], 'Son');
      expect(store.rows.values.single.state, DraftState.editing);
    });

    testWidgets('sending shows the reference, once the server has it', (
      tester,
    ) async {
      await open(tester);
      await fill(tester);
      await tapText(tester, 'lf_submit'.tr());
      expect(find.text('lf_done_title'.tr()), findsOneWidget);
      expect(find.text('LF-NEW00001'), findsOneWidget);
      expect(store.rows, isEmpty);
    });

    testWidgets('offline, it never says it was submitted', (tester) async {
      await open(tester);
      await fill(tester);
      repo.failure = offline;
      await tapText(tester, 'lf_submit'.tr());
      expect(find.text('lf_done_waiting_title'.tr()), findsOneWidget);
      expect(find.text('lf_done_title'.tr()), findsNothing);
      expect(find.text('LF-NEW00001'), findsNothing);
      expect(store.rows.values.single.state, DraftState.waiting);
    });

    testWidgets('a draft can be continued', (tester) async {
      await store.save(
        const ReportDraft(
          id: 'd1',
          kind: 'lost',
          fields: {'relationship': 'Father', 'person_name': 'Suresh'},
        ),
      );
      await pumpApp(
        tester,
        ReportLostScreen(draftId: 'd1', families: NoFamily()),
      );
      expect(find.text('Suresh'), findsOneWidget);
      expect(find.text('Father'), findsOneWidget);
    });

    testWidgets('a duplicate says so', (tester) async {
      await pumpApp(
        tester,
        const ReportDoneScreen(
          result: SubmitResult.sent('LF-ABCD2345', duplicate: true),
        ),
      );
      expect(find.text('lf_done_duplicate_title'.tr()), findsOneWidget);
    });
  });

  group('Report found', () {
    testWidgets('a child prompts the safety rules', (tester) async {
      await pumpApp(tester, const ReportFoundScreen());
      await tapText(tester, 'lf_found_child_alone'.tr());
      expect(find.text('lf_child_rules_body'.tr()), findsOneWidget);
    });

    testWidgets('a child can\'t be submitted without a safe place', (
      tester,
    ) async {
      await pumpApp(tester, const ReportFoundScreen());
      await tapText(tester, 'lf_found_child_alone'.tr());
      await tapText(tester, 'fam_continue'.tr());
      await tester.enterText(find.byType(TextFormField).at(3), 'Red shirt');
      await tapText(tester, 'fam_continue'.tr());
      final state = tester.state(find.byType(ReportFoundScreen)) as dynamic;
      state.when = DateTime(2026, 10, 1, 10);
      await tester.enterText(find.byType(TextFormField).first, 'Gate 2');
      await tapText(tester, 'lf_submit'.tr());
      expect(find.text('lf_need_facility'.tr()), findsOneWidget);
      expect(repo.bodies, isEmpty);
    });

    testWidgets('a category is required', (tester) async {
      await pumpApp(tester, const ReportFoundScreen());
      await tapText(tester, 'fam_continue'.tr());
      expect(find.text('lf_need_category'.tr()), findsOneWidget);
    });
  });

  group('Case details', () {
    Future<void> open(WidgetTester tester) =>
        pumpApp(tester, CaseDetailScreen(id: caseId, repository: repo));

    testWidgets('shows status, meaning and the note it is not official', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Aarav'), findsOneWidget);
      expect(find.text(statusMeaningEn('SUBMITTED')), findsOneWidget);
    });

    testWidgets('marks reported and verified apart', (tester) async {
      repo.detail = detailOf(
        sightings: const [
          Sighting(id: 's1', description: 'Near the gate'),
          Sighting(id: 's2', description: 'At desk 3', verified: true),
        ],
      );
      await open(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pump();
      expect(find.text('lf_reported_community'.tr()), findsOneWidget);
      expect(find.text('lf_verified'.tr()), findsOneWidget);
    });

    testWidgets('a location says it is not live tracking', (tester) async {
      repo.detail = detailOf(lat: 19.99);
      await open(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pump();
      expect(find.text('lf_not_live'.tr()), findsOneWidget);
    });

    testWidgets('confirmed shows the handover warning', (tester) async {
      repo.detail = detailOf(status: 'MATCH_CONFIRMED');
      await open(tester);
      expect(find.text('lf_handover_body'.tr()), findsOneWidget);
    });

    testWidgets('a family saying they\'re together asks first', (tester) async {
      await open(tester);
      await tapText(tester, 'lf_confirm_open'.tr());
      expect(repo.calls, isEmpty);
      await tester.tap(find.text('lf_confirm'.tr()));
      await settle(tester);
      expect(repo.calls, ['confirm']);
    });

    testWidgets('cancelling asks first', (tester) async {
      await open(tester);
      await tapText(tester, 'lf_cancel'.tr());
      expect(repo.calls, isEmpty);
      await tester.tap(find.text('lf_cancel'.tr()).last);
      await settle(tester);
      expect(repo.calls, ['cancel']);
    });

    testWidgets('adding information reaches staff', (tester) async {
      await open(tester);
      await tapText(tester, 'lf_add_info'.tr());
      await tester.enterText(find.byType(TextFormField), 'Red bag');
      await tester.tap(find.text('lf_send'.tr()));
      await settle(tester);
      expect(repo.calls, ['info:Red bag']);
    });

    testWidgets('a closed case offers no actions', (tester) async {
      repo.detail = detailOf(status: 'CLOSED');
      await open(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await tester.pump();
      expect(find.text('lf_add_info'.tr()), findsNothing);
      expect(find.text('lf_cancel'.tr()), findsNothing);
    });

    testWidgets('someone without access just sees an error', (tester) async {
      repo.failure = const FamilyException(FamilyFailure.notFound);
      await open(tester);
      expect(find.text('fam_error_not_found'.tr()), findsOneWidget);
      expect(find.text('Aarav'), findsNothing);
    });
  });

  group('Sightings', () {
    testWidgets('need a description, place and time', (tester) async {
      await pumpApp(
        tester,
        AddSightingScreen(caseId: caseId, repository: repo),
      );
      await tapText(tester, 'lf_send'.tr());
      expect(find.text('lf_need_description'.tr()), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('are sent for review', (tester) async {
      await pumpApp(
        tester,
        AddSightingScreen(caseId: caseId, repository: repo),
      );
      await tester.enterText(find.byType(TextFormField).first, 'Near a gate');
      await tester.enterText(find.byType(TextFormField).last, 'Gate 2');
      final state = tester.state(find.byType(AddSightingScreen)) as dynamic;
      state.pickWhen(DateTime(2026, 10, 1));
      await tapText(tester, 'lf_send'.tr());
      expect(repo.calls, ['sighting']);
    });
  });

  group('Operations', () {
    testWidgets('filters reach the server', (tester) async {
      await pumpApp(tester, OpsHomeScreen(repository: repo));
      await tester.tap(find.widgetWithText(FilterChip, 'lf_type_lost'.tr()));
      await settle(tester);
      expect(repo.calls.last, 'ops:lost:null::false');
      await tester.tap(find.widgetWithText(FilterChip, 'lf_ops_mine'.tr()));
      await settle(tester);
      expect(repo.calls.last, 'ops:lost:null::true');
    });

    testWidgets('someone without the role sees a refusal', (tester) async {
      repo.failure = const FamilyException(FamilyFailure.forbidden);
      await pumpApp(tester, OpsHomeScreen(repository: repo));
      expect(find.text('fam_error_forbidden'.tr()), findsOneWidget);
      expect(find.text('LF-ABCD2345'), findsNothing);
    });

    testWidgets('a phone number needs a deliberate, recorded step', (
      tester,
    ) async {
      await pumpApp(tester, OpsCaseScreen(id: caseId, repository: repo));
      expect(find.textContaining('+91'), findsNothing);
      await tapText(tester, 'lf_ops_reveal'.tr());
      expect(repo.calls, ['reveal']);
      expect(find.text('+919812345678'), findsOneWidget);
    });

    testWidgets('statuses are offered, not reunited or confirmed', (
      tester,
    ) async {
      await pumpApp(tester, OpsCaseScreen(id: caseId, repository: repo));
      expect(
        find.widgetWithText(ActionChip, statusLabelEn('CLOSED')),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ActionChip, statusLabelEn('REUNITED')),
        findsNothing,
      );
    });

    testWidgets('changing status asks for a reason', (tester) async {
      await pumpApp(tester, OpsCaseScreen(id: caseId, repository: repo));
      await tapText(tester, statusLabelEn('CLOSED'));
      await tester.enterText(
        find.byType(TextFormField).last,
        'Family found him',
      );
      await tester.tap(find.text('fam_save'.tr()));
      await settle(tester);
      expect(repo.calls, ['status:CLOSED:Family found him']);
    });

    testWidgets('sightings can be shared, verified or rejected', (
      tester,
    ) async {
      repo.ops = opsOf(
        sightings: const [
          Sighting(id: 's1', description: 'At the gate', review: 'pending'),
        ],
      );
      await pumpApp(tester, OpsCaseScreen(id: caseId, repository: repo));
      await tapText(tester, 'lf_ops_share_verified'.tr());
      expect(repo.calls, ['review:true:true']);
    });

    testWidgets('a reunion can\'t be saved until the checks are ticked', (
      tester,
    ) async {
      repo.ops = opsOf(status: 'MATCH_CONFIRMED', vulnerable: true);
      await pumpApp(tester, OpsCaseScreen(id: caseId, repository: repo));
      await tapText(tester, 'lf_ops_reunite'.tr());
      await tapText(tester, 'lf_method_id_document'.tr());
      await tester.enterText(find.byType(TextFormField), 'Checked his Aadhaar');
      await tester.pump();
      AppButton save() => tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'fam_save'.tr()),
      );
      expect(save().onPressed, isNull);
      await tapText(tester, 'lf_check_identity'.tr());
      expect(save().onPressed, isNull, reason: 'a child must recognise them');
      await tapText(tester, 'lf_check_recognised'.tr());
      expect(save().onPressed, isNotNull);
      await tapText(tester, 'fam_save'.tr());
      expect(repo.calls, ['reunite:true:true']);
    });
  });

  group('Match review', () {
    Future<void> open(WidgetTester tester, [String state = 'suggested']) =>
        pumpApp(
          tester,
          MatchReviewScreen(match: matchOf(state), repository: repo),
        );

    testWidgets('explains itself, and warns it proves nothing', (tester) async {
      await open(tester);
      expect(find.text('lf_match_warning_body'.tr()), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pump();
      expect(find.text('blue, cap'), findsOneWidget);
      expect(find.text('25/30'), findsOneWidget);
    });

    testWidgets('telling the family is opt-in', (tester) async {
      await open(tester);
      await tapText(tester, 'lf_match_approve'.tr());
      expect(repo.calls, ['approve:false']);
    });

    testWidgets('a suggestion can\'t be confirmed directly', (tester) async {
      await open(tester);
      expect(find.text('lf_match_confirm'.tr()), findsNothing);
    });

    testWidgets('confirming needs a recorded check', (tester) async {
      await open(tester, 'approved');
      await tapText(tester, 'lf_match_confirm'.tr());
      expect(repo.calls, isEmpty);
      await tapText(tester, 'lf_method_family_in_person'.tr());
      await tester.enterText(
        find.byType(TextFormField),
        'Father identified him',
      );
      await tester.pump();
      await tapText(tester, 'fam_save'.tr());
      expect(repo.calls, ['confirmMatch']);
    });
  });

  group('App wiring', () {
    test('a push opens the case, and only with a real id', () {
      expect(
        NotificationRouter.routeFor(const {'type': 'lostfound_case'}),
        '/lostFoundCase',
      );
      expect(
        NotificationRouter.argumentsFor('/lostFoundCase', const {
          'case_id': caseId,
        }),
        caseId,
      );
      expect(
        NotificationRouter.argumentsFor('/lostFoundCase', const {
          'case_id': '../../etc',
        }),
        isNull,
      );
      expect(
        NotificationRouter.argumentsFor('/shahiEvents', const {
          'case_id': caseId,
        }),
        isNull,
      );
    });

    test('routes keep Home highlighted', () {
      for (final route in const [
        '/lostFound',
        '/lostFoundReport',
        '/lostFoundFound',
        '/lostFoundCase',
        '/lostFoundSighting',
        '/lostFoundOps',
        '/lostFoundOpsCase',
        '/lostFoundMatch',
      ]) {
        expect(AppNavigation.indexOfRoute(route), AppNavigation.homeIndex);
      }
    });

    test('every key exists in all three languages', () {
      Map<String, dynamic> load(String lang) =>
          json.decode(File('assets/translations/$lang.json').readAsStringSync())
              as Map<String, dynamic>;
      final en = load('en');
      final keys = en.keys.where((k) => k.startsWith('lf_')).toSet();
      expect(keys.length, greaterThan(200));
      for (final lang in const ['hi', 'mr']) {
        expect(keys.difference(load(lang).keys.toSet()), isEmpty, reason: lang);
      }
      final source =
          Directory('lib/src/modules/lostfound')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              .map((f) => f.readAsStringSync())
              .join();
      for (final m in RegExp(
        r"'(lf_[a-z0-9_]+)'\s*\.(?:tr|plural)",
      ).allMatches(source)) {
        expect(en.containsKey(m.group(1)), isTrue, reason: m.group(1));
      }
    });

    test('nothing in the module logs', () {
      final files = Directory('lib/src/modules/lostfound')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in files) {
        expect(
          RegExp(
            r'\b(print|debugPrint|log)\(',
          ).hasMatch(file.readAsStringSync()),
          isFalse,
          reason: file.path,
        );
      }
    });

    test('nothing personal goes in shared preferences', () {
      final files = Directory('lib/src/modules/lostfound')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in files) {
        expect(
          file.readAsStringSync(),
          isNot(contains('SharedPreferences')),
          reason: file.path,
        );
      }
    });
  });
}

String statusMeaningEn(String status) => 'lf_status_${status}_means'.tr();
String statusLabelEn(String status) => 'lf_status_$status'.tr();
