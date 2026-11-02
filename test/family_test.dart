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
import 'package:kumbha_path/src/modules/family/family_flows_screens.dart';
import 'package:kumbha_path/src/modules/family/family_home_screen.dart';
import 'package:kumbha_path/src/modules/family/family_member_screens.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:kumbha_path/src/modules/family/offline/contact_sync.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'family_offline_fakes.dart';

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    return json.decode(await file.readAsString()) as Map<String, dynamic>;
  }
}

const circle = FamilyCircle(
  id: 'f1',
  name: 'More Family',
  memberCount: 3,
  myRole: 'organizer',
  myMemberId: 'm1',
);
const asMember = FamilyCircle(
  id: 'f1',
  name: 'More Family',
  memberCount: 3,
  myRole: 'member',
  myMemberId: 'm2',
);

const organizer = FamilyMember(
  id: 'm1',
  name: 'Suresh More',
  kind: 'account_holder',
  role: 'organizer',
  relationship: 'self',
  isDependent: false,
  permissions: MemberPermissions(viewContacts: true, editContacts: true),
  privacy: MemberPrivacy(),
);
const adult = FamilyMember(
  id: 'm2',
  name: 'Asha More',
  kind: 'independent_adult',
  role: 'member',
  relationship: 'spouse',
  isDependent: false,
  permissions: MemberPermissions(remove: true, makeOrganizer: true),
);
const child = FamilyMember(
  id: 'm3',
  name: 'Aarav More',
  kind: 'dependent_child',
  role: 'member',
  relationship: 'son',
  isDependent: true,
  ageGroup: '6_12',
  phone: '+919876543210',
  guardians: [GuardianRef(id: 'm1', name: 'Suresh More')],
  permissions: MemberPermissions(
    editProfile: true,
    remove: true,
    manageGuardians: true,
    viewContacts: true,
    editContacts: true,
  ),
);

const contactA = EmergencyContact(
  id: 'c1',
  name: 'Uncle Ramesh',
  mobile: '+919812345678',
  relationship: 'Uncle',
  updatedAt: '2026-10-30T10:00:00Z',
);
const contactB = EmergencyContact(
  id: 'c2',
  name: 'Aunt Sunita',
  mobile: '+919812345679',
  priority: 2,
  method: 'whatsapp',
  updatedAt: '2026-10-30T10:00:01Z',
);

const preview = InvitePreview(
  id: 'i1',
  familyName: 'Patil Family',
  organizerName: 'Meena Patil',
  memberCount: 4,
  relationship: 'sibling',
);

class FakeFamily implements FamilyRepository {
  List<FamilyCircle> theCircles = [];
  List<FamilyMember> theMembers = [organizer, adult, child];
  List<EmergencyContact> theContacts = [];
  List<InvitePreview> mine = [];
  List<FamilyInvite> invites = [];
  Object? failWith;
  final calls = <String>[];
  Map<String, dynamic>? lastBody;
  List<String>? lastOrder;

  void _maybeFail() {
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  Future<List<FamilyCircle>> circles() async {
    _maybeFail();
    return theCircles;
  }

  @override
  Future<FamilyCircle> createCircle(Map<String, dynamic> data) async {
    calls.add('createCircle');
    lastBody = data;
    return circle;
  }

  @override
  Future<FamilyCircle> updateCircle(String id, Map<String, dynamic> d) async {
    calls.add('updateCircle');
    return circle;
  }

  @override
  Future<void> deleteCircle(String id) async => calls.add('deleteCircle');

  @override
  Future<void> leaveCircle(String id) async => calls.add('leaveCircle');

  @override
  Future<void> offerOrganizer(String f, String m) async =>
      calls.add('offerOrganizer');

  @override
  Future<void> acceptOrganizer(String f) async => calls.add('acceptOrganizer');

  @override
  Future<List<FamilyMember>> members(String familyId) async {
    _maybeFail();
    return theMembers;
  }

  @override
  Future<FamilyMember> member(String f, String m) async {
    _maybeFail();
    return theMembers.firstWhere((x) => x.id == m);
  }

  @override
  Future<FamilyMember> addDependent(String f, Map<String, dynamic> data) async {
    calls.add('addDependent');
    lastBody = data;
    return child;
  }

  @override
  Future<FamilyMember> updateMember(
    String f,
    String m,
    Map<String, dynamic> data,
  ) async {
    calls.add('updateMember');
    lastBody = data;
    return theMembers.firstWhere((x) => x.id == m);
  }

  @override
  Future<void> removeMember(String f, String m) async =>
      calls.add('removeMember');

  @override
  Future<Uint8List?> photo(String f, String m) async => null;

  @override
  Future<void> uploadPhoto(String f, String m, Uint8List b) async {}

  @override
  Future<void> removePhoto(String f, String m) async {}

  @override
  Future<FamilyMember> addGuardian(String f, String m, String g) async {
    calls.add('addGuardian');
    return child;
  }

  @override
  Future<void> removeGuardian(String f, String m, String g) async =>
      calls.add('removeGuardian');

  @override
  Future<List<EmergencyContact>> contacts(String f, {String? memberId}) async {
    _maybeFail();
    return theContacts;
  }

  @override
  Future<EmergencyContact> addContact(
    String f,
    Map<String, dynamic> data, {
    String? memberId,
  }) async {
    _maybeFail();
    calls.add('addContact');
    lastBody = data;
    final added = EmergencyContact(
      id: data['id'] as String? ?? 'c9',
      name: data['name'] as String,
      mobile: '+91${data['mobile']}',
    );
    theContacts = [...theContacts, added];
    return added;
  }

  @override
  Future<EmergencyContact> updateContact(
    String f,
    String c,
    Map<String, dynamic> d, {
    String? ifMatch,
  }) async {
    final current = theContacts.firstWhere((x) => x.id == c);
    return current.copyWith(name: d['name'] as String?);
  }

  @override
  Future<void> deleteContact(String f, String c, {String? ifMatch}) async {
    _maybeFail();
    calls.add('deleteContact');
    theContacts = theContacts.where((x) => x.id != c).toList();
  }

  @override
  Future<List<EmergencyContact>> reorderContacts(
    String f,
    List<String> ids, {
    String? memberId,
  }) async {
    lastOrder = ids;
    return [for (final id in ids) theContacts.firstWhere((c) => c.id == id)];
  }

  @override
  Future<List<FamilyInvite>> invitations(String f) async => invites;

  @override
  Future<FamilyInvite> createInvitation(
    String f, {
    required String relationship,
    String? phone,
  }) async {
    calls.add('createInvitation');
    return FamilyInvite(
      id: 'i9',
      relationship: relationship,
      state: 'pending',
      code: 'ABCD2345WXYZ',
      expiresAt: DateTime(2027, 8, 3),
    );
  }

  @override
  Future<void> revokeInvitation(String f, String i) async {
    calls.add('revoke');
    invites = [];
  }

  @override
  Future<List<InvitePreview>> myInvitations() async => mine;

  @override
  Future<InvitePreview> lookupInvitation(String code) async {
    calls.add('lookup');
    if (code != 'GOODCODE') {
      throw const FamilyException(FamilyFailure.notFound);
    }
    return preview;
  }

  @override
  Future<InvitePreview> lookupInvitationLink(String token) async => preview;

  @override
  Future<String> acceptInvitation({
    String? code,
    String? invitationId,
    String? token,
  }) async {
    calls.add('accept:${code ?? invitationId}');
    return 'f2';
  }

  @override
  Future<void> declineInvitation({
    String? code,
    String? invitationId,
    String? token,
  }) async => calls.add('decline:${code ?? invitationId}');
}

late FakeFamily repo;
late MemoryContactStore store;
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
      '/familyMember' => MemberProfileScreen(
        args: args! as FamilyArgs,
        repository: repo,
      ),
      '/familyContacts' => EmergencyContactsScreen(args: args! as FamilyArgs),
      '/familyJoin' => JoinFamilyScreen(
        invite: args is InvitePreview ? args : null,
        repository: repo,
      ),
      '/familyCreate' => CreateFamilyScreen(repository: repo),
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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    dotenv.loadFromString(
      envString: 'API_PROTOCOL=https\nAPI_HOST=api.example.test',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = FakeFamily();
    FamilyServices.repository = repo;
    store = MemoryContactStore();
    FamilyContacts.service = ContactSyncService(
      remote: repo,
      store: store,
      schedule: (_, __) {},
    );
    FamilyPhotos.clear();
    pushed = [];
  });

  group('Translations', () {
    Map<String, dynamic> load(String lang) =>
        json.decode(File('assets/translations/$lang.json').readAsStringSync())
            as Map<String, dynamic>;

    test('every family key exists in all three languages', () {
      final en = load('en');
      final keys = en.keys.where((k) => k.startsWith('fam_')).toSet();
      expect(keys.length, greaterThan(200));
      for (final lang in const ['hi', 'mr']) {
        final other = load(lang);
        expect(keys.difference(other.keys.toSet()), isEmpty, reason: lang);
      }
    });

    test('every key the module uses is defined', () {
      final en = load('en');
      final source =
          Directory('lib/src/modules/family')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              .map((f) => f.readAsStringSync())
              .join();
      for (final match in RegExp(
        r"'(fam_[a-z0-9_]+)'\s*\.(?:tr|plural)",
      ).allMatches(source)) {
        expect(en.containsKey(match.group(1)), isTrue, reason: match.group(1));
      }
      for (final kind in const [
        'account_holder',
        'independent_adult',
        ...dependentKinds,
      ]) {
        expect(en.containsKey('fam_kind_$kind'), isTrue, reason: kind);
      }
      for (final value in familyRelationships) {
        expect(en.containsKey('fam_rel_$value'), isTrue, reason: value);
      }
      for (final value in familyAgeGroups) {
        expect(en.containsKey('fam_age_$value'), isTrue, reason: value);
      }
      for (final value in contactMethods) {
        expect(en.containsKey('fam_method_$value'), isTrue, reason: value);
      }
    });
  });

  group('Models', () {
    test('withheld fields stay null, and phone rules match the app', () {
      final member = FamilyMember.fromJson({
        'id': 'm2',
        'name': 'Asha',
        'kind': 'independent_adult',
        'role': 'member',
        'relationship': 'spouse',
        'is_dependent': false,
        'phone': null,
        'date_of_birth': null,
        'guardians': <Object>[],
        'permissions': {'remove': true},
        'privacy': null,
      });
      expect(member.phone, isNull);
      expect(member.privacy, isNull);
      expect(member.permissions.remove, isTrue);
      expect(member.permissions.editProfile, isFalse);
      expect(isValidMobile('9876543210'), isTrue);
      expect(isValidMobile('1234567890'), isFalse);
      expect(isValidMobile('98765'), isFalse);
      expect(localMobile('+919876543210'), '9876543210');
    });
  });

  group('Repository', () {
    HttpFamilyRepository client(
      Future<http.Response> Function(http.Request) handler,
    ) => HttpFamilyRepository(
      client: MockClient(handler),
      token: () async => 'TOKEN',
    );

    test('sends the token in the header, never the URL', () async {
      late http.Request seen;
      final repo = client((request) async {
        seen = request;
        return http.Response(
          jsonEncode({'status': 'success', 'data': <Object>[]}),
          200,
        );
      });
      await repo.circles();
      expect(seen.headers['Authorization'], 'Bearer TOKEN');
      expect(seen.url.toString(), isNot(contains('TOKEN')));
      expect(seen.url.path, '/api/family/circles/');
    });

    test('keeps invitation codes out of URLs', () async {
      late http.Request seen;
      final repo = client((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {'id': 'i1'},
          }),
          200,
        );
      });
      await repo.lookupInvitation('SECRETCODE');
      expect(seen.url.toString(), isNot(contains('SECRETCODE')));
      expect(jsonDecode(seen.body), {'code': 'SECRETCODE'});
    });

    test('sends the version, and reads a stale reply', () async {
      late http.Request seen;
      final repo = client((request) async {
        seen = request;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'status': 'error',
              'errors': {'detail': 'Changed'},
              'data': {
                'id': 'c1',
                'name': 'Theirs',
                'mobile': '+919812345678',
                'updated_at': '2026-10-31T10:00:00Z',
              },
            }),
          ),
          412,
        );
      });
      await expectLater(
        repo.updateContact('f1', 'c1', {'name': 'Mine'}, ifMatch: 'v1'),
        throwsA(
          isA<FamilyException>()
              .having((e) => e.kind, 'kind', FamilyFailure.stale)
              .having((e) => e.serverContact?.name, 'server', 'Theirs')
              .having(
                (e) => e.serverContact?.updatedAt,
                'version',
                '2026-10-31T10:00:00Z',
              ),
        ),
      );
      expect(seen.headers['If-Match'], 'v1');
      await expectLater(
        repo.deleteContact('f1', 'c1', ifMatch: 'v2'),
        throwsA(isA<FamilyException>()),
      );
      expect(seen.headers['If-Match'], 'v2');
      expect(seen.method, 'DELETE');
    });

    test('maps failures', () async {
      Future<FamilyFailure> failure(int code) async {
        final repo = client(
          (_) async => http.Response(
            jsonEncode({
              'status': 'error',
              'errors': {
                'non_field_errors': ['No'],
              },
            }),
            code,
          ),
        );
        try {
          await repo.circles();
        } on FamilyException catch (e) {
          return e.kind;
        }
        throw StateError('expected a failure');
      }

      expect(await failure(400), FamilyFailure.invalid);
      expect(await failure(401), FamilyFailure.signedOut);
      expect(await failure(403), FamilyFailure.forbidden);
      expect(await failure(404), FamilyFailure.notFound);
      expect(await failure(409), FamilyFailure.conflict);
      expect(await failure(500), FamilyFailure.server);
    });

    test('no token means signed out, without any request', () async {
      var requests = 0;
      final repo = HttpFamilyRepository(
        client: MockClient((_) async {
          requests++;
          return http.Response('', 200);
        }),
        token: () async => null,
      );
      await expectLater(repo.circles(), throwsA(isA<FamilyException>()));
      expect(requests, 0);
    });

    test('no connection reports offline', () async {
      final repo = client((_) async => throw http.ClientException('down'));
      await expectLater(
        repo.circles(),
        throwsA(
          isA<FamilyException>().having(
            (e) => e.kind,
            'kind',
            FamilyFailure.offline,
          ),
        ),
      );
    });
  });

  group('Home', () {
    testWidgets('without a family shows onboarding with both ways in', (
      tester,
    ) async {
      await pumpApp(tester, FamilyHomeScreen(repository: repo));
      expect(find.text('fam_onboard_title'.tr()), findsOneWidget);
      expect(find.text('fam_create'.tr()), findsOneWidget);
      expect(find.text('fam_join'.tr()), findsOneWidget);
      expect(find.byType(FamilyMap), findsNothing);
    });

    testWidgets('onboarding opens creation and joining', (tester) async {
      await pumpApp(tester, FamilyHomeScreen(repository: repo));
      await tapText(tester, 'fam_create'.tr());
      expect(pushed, contains('/familyCreate'));
    });

    testWidgets('a waiting in-app invitation is shown', (tester) async {
      repo.mine = [preview];
      await pumpApp(tester, FamilyHomeScreen(repository: repo));
      final label = 'fam_invited_to'.tr(args: ['Patil Family']);
      expect(find.text(label), findsOneWidget);
      await tapText(tester, label);
      expect(pushed, contains('/familyJoin'));
    });

    testWidgets('with a family shows the circle, not a list of cards', (
      tester,
    ) async {
      repo
        ..theCircles = [circle]
        ..theContacts = [contactA];
      await pumpApp(tester, FamilyHomeScreen(repository: repo));
      expect(find.text('More Family'), findsOneWidget);
      expect(find.byType(FamilyMap), findsOneWidget);
      expect(find.byType(FamilyAvatar), findsNWidgets(3));
      expect(find.textContaining('fam_member_count'.plural(3)), findsOneWidget);
      expect(
        find.textContaining('fam_in_care_count'.plural(1)),
        findsOneWidget,
      );
      expect(find.text('fam_add_member'.tr()), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pump();
      expect(find.text('Uncle Ramesh'), findsOneWidget);
    });

    testWidgets('dependents sit below adults, joined to their guardian', (
      tester,
    ) async {
      repo.theCircles = [circle];
      await pumpApp(tester, FamilyHomeScreen(repository: repo));
      final parent = tester.getTopLeft(find.text('Suresh'));
      final dependent = tester.getTopLeft(find.text('Aarav'));
      expect(dependent.dy, greaterThan(parent.dy));
    });

    testWidgets('a member can\'t see organizer actions', (tester) async {
      repo.theCircles = [asMember];
      await pumpApp(tester, FamilyHomeScreen(repository: repo));
      expect(find.text('fam_add_member'.tr()), findsNothing);
      expect(find.text('fam_invitations'.tr()), findsNothing);
      expect(find.text('fam_emergency_contacts'.tr()), findsOneWidget);
    });

    testWidgets('opens a member and the contacts', (tester) async {
      repo.theCircles = [circle];
      await pumpApp(tester, FamilyHomeScreen(repository: repo));
      await tester.tap(find.text('Aarav'));
      await settle(tester);
      expect(pushed, contains('/familyMember'));
      expect(find.text('Aarav More'), findsOneWidget);
    });

    testWidgets('an adult can be invited but not added directly', (
      tester,
    ) async {
      repo.theCircles = [circle];
      await pumpApp(tester, FamilyHomeScreen(repository: repo));
      await tapText(tester, 'fam_add_member'.tr());
      expect(find.text('fam_add_dependent'.tr()), findsOneWidget);
      expect(find.text('fam_add_adult_hint'.tr()), findsOneWidget);
    });

    testWidgets('an offered organizer role needs accepting', (tester) async {
      repo.theCircles = [
        const FamilyCircle(
          id: 'f1',
          name: 'More Family',
          myRole: 'member',
          myMemberId: 'm2',
          organizerOfferForMe: true,
        ),
      ];
      await pumpApp(tester, FamilyHomeScreen(repository: repo));
      await tapText(tester, 'fam_offer_accept'.tr());
      expect(repo.calls, contains('acceptOrganizer'));
    });

    testWidgets('offline with nothing loaded explains why', (tester) async {
      repo.failWith = const FamilyException(FamilyFailure.offline);
      await pumpApp(tester, FamilyHomeScreen(repository: repo));
      expect(find.textContaining('fam_offline_note'.tr()), findsOneWidget);
      repo.failWith = null;
      await tapText(tester, 'common_retry'.tr());
      expect(find.text('fam_onboard_title'.tr()), findsOneWidget);
    });

    testWidgets('offline after a restart still reaches the contacts', (
      tester,
    ) async {
      await store.saveCircles(const [circle]);
      await store.saveScope(const ScopeInfo(scope: ContactScope('f1')));
      await store.save(
        const LocalContact(contact: contactA, scope: ContactScope('f1')),
      );
      await store.saveScope(
        const ScopeInfo(scope: ContactScope('f1', 'm3'), label: 'Aarav More'),
      );
      repo.failWith = const FamilyException(FamilyFailure.offline);
      await pumpApp(tester, FamilyHomeScreen(repository: repo));
      expect(find.text('More Family'), findsOneWidget);
      expect(find.text('fam_offline_title'.tr()), findsOneWidget);
      expect(find.text('Uncle Ramesh'), findsOneWidget);
      expect(
        find.text('fam_contacts_of'.tr(args: ['Aarav More'])),
        findsOneWidget,
      );
      await tapText(tester, 'fam_emergency_contacts'.tr());
      expect(pushed, contains('/familyContacts'));
    });

    testWidgets('a failed refresh keeps what is on screen', (tester) async {
      repo.theCircles = [circle];
      await pumpApp(tester, FamilyHomeScreen(repository: repo));
      repo.failWith = const FamilyException(FamilyFailure.offline);
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 400),
        1000,
      );
      await settle(tester);
      expect(find.byType(FamilyMap), findsOneWidget);
      expect(find.text('fam_stale_note'.tr()), findsOneWidget);
    });

    for (final (name, locale, brightness, scale, width) in const [
      ('dark', Locale('en'), Brightness.dark, 1.0, 390.0),
      ('Hindi at large text', Locale('hi'), Brightness.light, 1.6, 390.0),
      ('Marathi dark', Locale('mr'), Brightness.dark, 1.3, 390.0),
      ('narrow', Locale('en'), Brightness.light, 1.3, 320.0),
    ]) {
      testWidgets('renders without overflow: $name', (tester) async {
        repo
          ..theCircles = [circle]
          ..theContacts = [contactA]
          ..theMembers = [
            organizer,
            adult,
            child,
            for (var i = 0; i < 6; i++)
              FamilyMember(
                id: 'x$i',
                name: 'Child Number$i',
                kind: 'dependent_child',
                role: 'member',
                relationship: 'daughter',
                isDependent: true,
                guardians: const [GuardianRef(id: 'm1', name: 'Suresh')],
              ),
          ];
        await pumpApp(
          tester,
          FamilyHomeScreen(repository: repo),
          locale: locale,
          brightness: brightness,
          textScale: scale,
          size: Size(width, 800),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(FamilyMap), findsOneWidget);
      });
    }
  });

  group('Create family', () {
    Future<void> toReview(WidgetTester tester, {String? contact}) async {
      await tester.enterText(find.byType(TextFormField).first, 'More Family');
      await tapText(tester, 'fam_continue'.tr());
      await tapText(tester, 'fam_continue'.tr());
      if (contact != null) {
        await tester.enterText(find.byType(TextFormField).first, 'Ramesh');
        await tester.enterText(find.byType(TextFormField).last, contact);
        await tester.pump();
        await tapText(tester, 'fam_continue'.tr());
      } else {
        await tapText(tester, 'fam_skip'.tr());
      }
    }

    testWidgets('a name is required', (tester) async {
      await pumpApp(tester, CreateFamilyScreen(repository: repo));
      await tapText(tester, 'fam_continue'.tr());
      expect(find.text('fam_name_required'.tr()), findsOneWidget);
    });

    testWidgets('explains the organizer can\'t see other adults\' details', (
      tester,
    ) async {
      await pumpApp(tester, CreateFamilyScreen(repository: repo));
      await tester.enterText(find.byType(TextFormField).first, 'More');
      await tapText(tester, 'fam_continue'.tr());
      expect(find.text('fam_role_cannot'.tr()), findsOneWidget);
    });

    testWidgets('creates only at the end, and the contact is optional', (
      tester,
    ) async {
      await pumpApp(tester, CreateFamilyScreen(repository: repo));
      await toReview(tester);
      expect(repo.calls, isEmpty);
      expect(find.text('fam_create_no_messages'.tr()), findsOneWidget);
      await tapText(tester, 'fam_create_confirm'.tr());
      expect(repo.calls, ['createCircle']);
      expect(repo.lastBody?['name'], 'More Family');
    });

    testWidgets('saves an emergency contact, and checks its number', (
      tester,
    ) async {
      await pumpApp(tester, CreateFamilyScreen(repository: repo));
      await tester.enterText(find.byType(TextFormField).first, 'More Family');
      await tapText(tester, 'fam_continue'.tr());
      await tapText(tester, 'fam_continue'.tr());
      await tester.enterText(find.byType(TextFormField).first, 'Ramesh');
      await tester.enterText(find.byType(TextFormField).last, '12345');
      await tester.pump();
      await tapText(tester, 'fam_continue'.tr());
      expect(find.text('auth_phone_invalid'.tr()), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, '9812345678');
      await tester.pump();
      await tapText(tester, 'fam_continue'.tr());
      await tapText(tester, 'fam_create_confirm'.tr());
      expect(repo.calls, ['createCircle', 'addContact']);
    });
  });

  group('Add a dependent', () {
    Future<void> open(WidgetTester tester) => pumpApp(
      tester,
      MemberFormScreen(args: const FamilyArgs(circle), repository: repo),
    );

    testWidgets('a child needs no consent step and no account', (tester) async {
      await open(tester);
      await tapText(tester, relationshipLabel('son'));
      await tapText(tester, 'fam_continue'.tr());
      await tester.enterText(find.byType(TextFormField).first, 'Aarav');
      await tapText(tester, 'fam_age_6_12'.tr());
      await tapText(tester, 'fam_dep_add'.tr());
      expect(repo.calls, ['addDependent']);
      expect(repo.lastBody?['kind'], 'dependent_child');
      expect(repo.lastBody?['age_group'], '6_12');
      expect(repo.lastBody!.containsKey('user'), isFalse);
      expect(repo.lastBody!.containsKey('gender'), isFalse);
    });

    testWidgets('age is required', (tester) async {
      await open(tester);
      await tapText(tester, relationshipLabel('son'));
      await tapText(tester, 'fam_continue'.tr());
      await tester.enterText(find.byType(TextFormField).first, 'Aarav');
      await tapText(tester, 'fam_dep_add'.tr());
      expect(find.text('fam_age_required'.tr()), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('an elder can\'t be added without saying they know', (
      tester,
    ) async {
      await open(tester);
      await tapText(tester, 'fam_kind_dependent_elderly'.tr());
      await tapText(tester, relationshipLabel('grandmother'));
      await tapText(tester, 'fam_continue'.tr());
      await tester.enterText(find.byType(TextFormField).first, 'Aji');
      await tapText(tester, 'fam_age_senior'.tr());
      await tapText(tester, 'fam_continue'.tr());
      expect(find.text('fam_consent_title'.tr()), findsOneWidget);
      await tapText(tester, 'fam_dep_add'.tr());
      expect(repo.calls, isEmpty, reason: 'disabled until a choice is made');
      await tapText(tester, 'fam_consent_agreed'.tr());
      await tapText(tester, 'fam_dep_add'.tr());
      expect(repo.lastBody?['consent_basis'], 'agreed');
    });
  });

  group('Member profile', () {
    Future<void> open(
      WidgetTester tester,
      String id, {
      FamilyCircle at = circle,
    }) => pumpApp(
      tester,
      MemberProfileScreen(args: FamilyArgs(at, memberId: id), repository: repo),
    );

    testWidgets('a dependent shows guardians and permitted actions', (
      tester,
    ) async {
      await open(tester, 'm3');
      expect(find.text('Aarav More'), findsOneWidget);
      expect(find.text('Suresh More'), findsOneWidget);
      expect(find.text('+91 9876543210'), findsOneWidget);
      await scrollTo(tester, find.text('fam_add_guardian'.tr()));
      expect(find.text('fam_add_guardian'.tr()), findsOneWidget);
    });

    testWidgets('another adult shows nothing private and no edit', (
      tester,
    ) async {
      await open(tester, 'm2');
      expect(find.text('Asha More'), findsOneWidget);
      expect(find.text('fam_field_mobile'.tr()), findsNothing);
      expect(find.text('fam_privacy_title'.tr()), findsNothing);
      expect(find.text('fam_their_contacts'.tr()), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.text('fam_change_photo'.tr()), findsNothing);
      expect(
        find.text('fam_adult_note'.tr(args: ['Asha More'])),
        findsOneWidget,
      );
    });

    testWidgets('your own profile has your privacy, all off', (tester) async {
      await open(tester, 'm1');
      await scrollTo(tester, find.byType(SwitchListTile));
      final switches = tester.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switches.every((s) => !s.value), isTrue);
      await tester.tap(find.byType(SwitchListTile).first);
      await settle(tester);
      expect(repo.lastBody, {'share_phone': true});
    });

    testWidgets('removing asks first', (tester) async {
      await open(tester, 'm3');
      await tapText(tester, 'fam_remove'.tr());
      expect(repo.calls, isEmpty);
      await tester.tap(find.text('fam_remove'.tr()).last);
      await settle(tester);
      expect(repo.calls, ['removeMember']);
    });

    testWidgets('a removed member shows an error, not a blank', (tester) async {
      repo.failWith = const FamilyException(FamilyFailure.notFound);
      await open(tester, 'm3');
      expect(find.text('fam_error_not_found'.tr()), findsOneWidget);
    });
  });

  group('Invitations', () {
    Future<void> open(WidgetTester tester) => pumpApp(
      tester,
      InviteScreen(args: const FamilyArgs(circle), repository: repo),
    );

    testWidgets('never claims a message was sent', (tester) async {
      await open(tester);
      await tapText(tester, relationshipLabel('sibling'));
      await tapText(tester, 'fam_invite_create'.tr());
      expect(repo.calls, ['createInvitation']);
      expect(find.text('ABCD-2345-WXYZ'), findsOneWidget);
      expect(find.text('fam_code_not_sent'.tr()), findsOneWidget);
    });

    testWidgets('checks the number and needs a relationship', (tester) async {
      await open(tester);
      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'fam_invite_create'.tr()),
      );
      expect(button.onPressed, isNull);
      await tapText(tester, relationshipLabel('sibling'));
      await tester.enterText(find.byType(TextFormField), '123');
      await tapText(tester, 'fam_invite_create'.tr());
      expect(find.text('auth_phone_invalid'.tr()), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('an open invitation can be revoked', (tester) async {
      repo.invites = [
        FamilyInvite(
          id: 'i1',
          relationship: 'spouse',
          state: 'pending',
          expiresAt: DateTime(2027, 8, 3),
        ),
        const FamilyInvite(id: 'i2', relationship: 'son', state: 'expired'),
      ];
      await open(tester);
      await scrollTo(tester, find.text('fam_revoke'.tr()));
      expect(find.text('fam_revoke'.tr()), findsOneWidget);
      await tapText(tester, 'fam_revoke'.tr());
      expect(repo.calls, ['revoke']);
    });

    testWidgets('joining: review what is shared, then accept', (tester) async {
      await pumpApp(tester, JoinFamilyScreen(repository: repo));
      await tester.enterText(find.byType(TextFormField), 'WRONG');
      await tapText(tester, 'fam_continue'.tr());
      expect(find.text('fam_code_invalid'.tr()), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'GOODCODE');
      await tapText(tester, 'fam_continue'.tr());
      expect(find.text('Patil Family'), findsOneWidget);
      expect(find.text('fam_review_cannot_body'.tr()), findsOneWidget);
      expect(repo.calls.where((c) => c.startsWith('accept')), isEmpty);
      await tapText(tester, 'fam_join_confirm'.tr(args: ['Patil Family']));
      expect(repo.calls, contains('accept:GOODCODE'));
    });

    testWidgets('an in-app invitation can be declined by id', (tester) async {
      await pumpApp(
        tester,
        JoinFamilyScreen(invite: preview, repository: repo),
      );
      await tapText(tester, 'fam_decline'.tr());
      expect(repo.calls, ['decline:i1']);
    });
  });

  group('Emergency contacts', () {
    Future<void> open(WidgetTester tester, {FamilyCircle at = circle}) =>
        pumpApp(tester, EmergencyContactsScreen(args: FamilyArgs(at)));

    testWidgets('empty state offers to add, for those who can', (tester) async {
      await open(tester);
      expect(find.text('fam_no_contacts_title'.tr()), findsOneWidget);
      expect(find.text('fam_contact_add'.tr()), findsOneWidget);
    });

    testWidgets('members can read but not change them', (tester) async {
      repo.theContacts = [contactA];
      await open(tester, at: asMember);
      expect(find.text('Uncle Ramesh'), findsOneWidget);
      expect(find.text('fam_contact_add'.tr()), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });

    testWidgets('are in priority order and can be moved', (tester) async {
      repo.theContacts = [contactA, contactB];
      await open(tester);
      final first = tester.getTopLeft(find.text('Uncle Ramesh'));
      final second = tester.getTopLeft(find.text('Aunt Sunita'));
      expect(first.dy, lessThan(second.dy));
      await tester.tap(find.byTooltip('fam_move_up'.tr(args: ['Aunt Sunita'])));
      await settle(tester);
      expect(repo.lastOrder, ['c2', 'c1']);
    });

    testWidgets('adding checks the number', (tester) async {
      await open(tester);
      await tapText(tester, 'fam_contact_add'.tr());
      await tester.enterText(find.byType(TextFormField).first, 'Ramesh');
      await tester.enterText(find.byType(TextFormField).last, '123');
      await tapText(tester, 'fam_save'.tr());
      expect(find.text('auth_phone_invalid'.tr()), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, '9812345678');
      await tapText(tester, 'fam_save'.tr());
      expect(repo.calls, ['addContact']);
      expect(find.text('Ramesh'), findsOneWidget);
    });

    testWidgets('shows saved contacts straight away when offline', (
      tester,
    ) async {
      repo.theContacts = [contactA];
      await FamilyContacts.service.refresh(const ContactScope('f1'));
      repo.failWith = const FamilyException(FamilyFailure.offline);
      await open(tester);
      expect(find.text('Uncle Ramesh'), findsOneWidget);
      expect(find.text('fam_sync_offline'.tr()), findsOneWidget);
    });

    testWidgets('shows when it last synced', (tester) async {
      await open(tester);
      expect(find.textContaining('Last synced'), findsOneWidget);
      expect(find.text('fam_sync_done'.tr()), findsOneWidget);
    });

    testWidgets('adding offline says it is saved, and marks it waiting', (
      tester,
    ) async {
      repo.failWith = const FamilyException(FamilyFailure.offline);
      await open(tester);
      await tapText(tester, 'fam_contact_add'.tr());
      await tester.enterText(find.byType(TextFormField).first, 'Ramesh');
      await tester.enterText(find.byType(TextFormField).last, '9812345678');
      await tapText(tester, 'fam_save'.tr());
      expect(find.text('Ramesh'), findsOneWidget);
      expect(find.text('fam_saved_offline'.tr()), findsOneWidget);
      expect(find.text('fam_row_waiting'.tr()), findsOneWidget);
      expect(find.textContaining('fam_sync_waiting'.plural(1)), findsOneWidget);
    });

    testWidgets('when it connects again it says everything synced', (
      tester,
    ) async {
      repo.failWith = const FamilyException(FamilyFailure.offline);
      await open(tester);
      await FamilyContacts.service.add(const ContactScope('f1'), {
        'name': 'Ramesh',
        'mobile': '9812345678',
      });
      await settle(tester);
      repo.failWith = null;
      await tapText(tester, 'fam_sync_now'.tr());
      expect(find.text('fam_synced_toast'.tr()), findsOneWidget);
      expect(find.text('fam_row_waiting'.tr()), findsNothing);
    });

    testWidgets('a conflict shows both versions and asks', (tester) async {
      await store.save(
        LocalContact(
          scope: const ContactScope('f1'),
          state: ContactSyncState.conflict,
          contact: contactA,
          serverCopy: contactA.copyWith(name: 'Aunt Sunita'),
        ),
      );
      await store.saveScope(const ScopeInfo(scope: ContactScope('f1')));
      await open(tester);
      expect(find.text('Uncle Ramesh'), findsOneWidget);
      expect(find.textContaining('Aunt Sunita'), findsOneWidget);
      expect(find.byTooltip('fam_delete'.tr()), findsNothing);
      await tapText(tester, 'fam_use_theirs'.tr());
      expect(find.text('Uncle Ramesh'), findsNothing);
    });

    testWidgets('a refused change can be discarded', (tester) async {
      await store.save(
        const LocalContact(
          scope: ContactScope('f1'),
          state: ContactSyncState.failed,
          contact: contactB,
        ),
      );
      await store.saveScope(const ScopeInfo(scope: ContactScope('f1')));
      await open(tester);
      expect(find.text('fam_row_failed'.tr()), findsOneWidget);
      await tapText(tester, 'fam_discard'.tr());
      expect(find.text('Aunt Sunita'), findsNothing);
    });

    testWidgets('with nothing saved, offline explains why', (tester) async {
      repo.failWith = const FamilyException(FamilyFailure.offline);
      await open(tester, at: asMember);
      expect(find.text('fam_no_saved_contacts_title'.tr()), findsOneWidget);
    });

    for (final (name, locale, brightness, scale) in const [
      ('dark', Locale('en'), Brightness.dark, 1.0),
      ('Hindi at large text', Locale('hi'), Brightness.light, 1.6),
      ('Marathi dark', Locale('mr'), Brightness.dark, 1.3),
    ]) {
      testWidgets('status and conflicts fit: $name', (tester) async {
        await store.save(
          LocalContact(
            scope: const ContactScope('f1'),
            state: ContactSyncState.conflict,
            contact: contactA,
            serverCopy: contactA.copyWith(name: 'Aunt Sunita'),
          ),
        );
        await store.saveScope(const ScopeInfo(scope: ContactScope('f1')));
        repo.failWith = const FamilyException(FamilyFailure.offline);
        await pumpApp(
          tester,
          const EmergencyContactsScreen(args: FamilyArgs(circle)),
          locale: locale,
          brightness: brightness,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('deleting asks first', (tester) async {
      repo.theContacts = [contactA];
      await open(tester);
      await tester.tap(find.byTooltip('fam_delete'.tr()));
      await settle(tester);
      expect(repo.calls, isEmpty);
      await tester.tap(find.text('fam_delete'.tr()).last);
      await settle(tester);
      expect(repo.calls, ['deleteContact']);
    });
  });

  group('Settings', () {
    testWidgets('the organizer can hand over, only with acceptance', (
      tester,
    ) async {
      await pumpApp(
        tester,
        FamilySettingsScreen(args: const FamilyArgs(circle), repository: repo),
      );
      expect(find.text('fam_leave'.tr()), findsNothing);
      await tapText(tester, 'fam_handover_confirm'.tr());
      await tester.tap(find.text('fam_handover_confirm'.tr()).last);
      await settle(tester);
      expect(repo.calls, ['offerOrganizer']);
    });

    testWidgets('a member can only leave', (tester) async {
      await pumpApp(
        tester,
        FamilySettingsScreen(
          args: const FamilyArgs(asMember),
          repository: repo,
        ),
      );
      expect(find.text('fam_delete_family'.tr()), findsNothing);
      await tapText(tester, 'fam_leave'.tr());
      await tester.tap(find.text('fam_leave'.tr()).last);
      await settle(tester);
      expect(repo.calls, ['leaveCircle']);
    });
  });

  group('Navigation', () {
    test('every family route keeps Home highlighted', () {
      for (final route in const [
        '/family',
        '/familyCreate',
        '/familyJoin',
        '/familyMember',
        '/familyMemberForm',
        '/familyInvite',
        '/familyContacts',
        '/familySettings',
      ]) {
        expect(AppNavigation.indexOfRoute(route), AppNavigation.homeIndex);
      }
    });
  });
}
