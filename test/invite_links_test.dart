import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/family_flows_screens.dart';
import 'package:kumbha_path/src/modules/family/invite_links.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    return json.decode(await file.readAsString()) as Map<String, dynamic>;
  }
}

const token = 'abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQ';
final goodLink = Uri.parse('https://kumbhapath.in/join/family#t=$token');

const preview = InvitePreview(
  id: 'i1',
  familyName: 'Patil Family',
  organizerName: 'Meena Patil',
  memberCount: 4,
  relationship: 'sibling',
);

FamilyException closed(String state) => FamilyException(
  FamilyFailure.gone,
  fieldErrors: {'state': state, 'detail': 'closed'},
);

class FakeLinks implements FamilyRepository {
  FamilyException? failure;
  InvitePreview result = preview;
  final calls = <String>[];

  @override
  Future<InvitePreview> lookupInvitationLink(String t) async {
    calls.add('lookup:$t');
    final f = failure;
    if (f != null) throw f;
    return result;
  }

  @override
  Future<String> acceptInvitation({
    String? code,
    String? invitationId,
    String? token,
  }) async {
    calls.add('accept:$code:$invitationId:$token');
    final f = failure;
    if (f != null) throw f;
    return 'f2';
  }

  @override
  Future<void> declineInvitation({
    String? code,
    String? invitationId,
    String? token,
  }) async {
    calls.add('decline:$code:$invitationId:$token');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> pumpApp(
  WidgetTester tester,
  Widget home, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLinks repo;
  final secure = <String, String>{};

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    repo = FakeLinks();
    secure.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final args = call.arguments as Map;
            final key = args['key'] as String?;
            return switch (call.method) {
              'write' => secure[key!] = args['value'] as String,
              'read' => secure[key],
              'delete' => secure.remove(key),
              _ => null,
            };
          },
        );
    InviteLinkRouter.reset();
  });

  group('Reading links', () {
    test('accepts the real form', () {
      expect(parseInviteLink(goodLink)?.token, token);
      expect(
        parseInviteLink(
          Uri.parse('https://kumbhapath.in/join/family/#t=$token'),
        )?.token,
        token,
      );
    });

    test('ignores every other address', () {
      for (final bad in [
        'http://kumbhapath.in/join/family#t=$token',
        'https://www.kumbhapath.in/join/family#t=$token',
        'https://kumbhapath.in.evil.example/join/family#t=$token',
        'https://evil.example/join/family#t=$token',
        'https://kumbhapath.in:8443/join/family#t=$token',
        'https://kumbhapath.in/join/family/extra#t=$token',
        'https://kumbhapath.in/#t=$token',
        'kumbhapath://join/family#t=$token',
      ]) {
        expect(parseInviteLink(Uri.parse(bad)), isNull, reason: bad);
      }
    });

    test('a damaged link is recognised but carries no token', () {
      for (final bad in [
        'https://kumbhapath.in/join/family',
        'https://kumbhapath.in/join/family#t=short',
        'https://kumbhapath.in/join/family#t=has spaces and more than enough text',
        'https://kumbhapath.in/join/family#x=$token',
        'https://kumbhapath.in/join/family?t=$token',
      ]) {
        final link = parseInviteLink(Uri.parse(bad));
        expect(link, isNotNull, reason: bad);
        expect(link?.token, isNull, reason: bad);
      }
    });

    test('never prints the token', () {
      expect('${parseInviteLink(goodLink)}', isNot(contains(token)));
    });

    test('the module has no logging calls', () {
      final source =
          File('lib/src/modules/family/invite_links.dart').readAsStringSync();
      expect(RegExp(r'\b(print|debugPrint|log)\(').hasMatch(source), isFalse);
    });
  });

  group('Opening links', () {
    late GlobalKey<NavigatorState> key;
    late List<Object?> opened;

    Future<void> pumpRoutes(
      WidgetTester tester, {
      required String first,
    }) async {
      key = GlobalKey<NavigatorState>();
      opened = [];
      InviteLinkRouter.attach(key);
      InviteLinkRouter.shellVisible = () => first == '/dashboardScreen';
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          initialRoute: first,
          onGenerateRoute: (settings) {
            opened.add(settings.name);
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => Text('${settings.name}'),
            );
          },
        ),
      );
      await tester.pump();
      opened.clear();
    }

    Future<void> letStorageFinish(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('signed in: opens straight away', (tester) async {
      await pumpRoutes(tester, first: '/dashboardScreen');
      unawaited(InviteLinkRouter.handle(goodLink));
      await tester.pump();
      await tester.pump();
      expect(opened, ['/familyJoin']);
      expect(secure, isEmpty, reason: 'nothing to keep');
    });

    testWidgets('joining goes on to the family', (tester) async {
      await pumpRoutes(tester, first: '/dashboardScreen');
      unawaited(InviteLinkRouter.handle(goodLink));
      await tester.pump();
      await tester.pump();
      key.currentState!.pop(true);
      await tester.pumpAndSettle();
      expect(opened, ['/familyJoin', '/family']);
    });

    testWidgets('signed out: waits, even if the app is closed', (tester) async {
      await pumpRoutes(tester, first: '/loginScreen');
      await tester.runAsync(() => InviteLinkRouter.handle(goodLink));
      expect(opened, isEmpty);
      expect(InviteLinkRouter.pending?.token, token);
      expect(secure.values, contains(token));

      InviteLinkRouter.reset(); // the phone closed the app during sign-in
      await pumpRoutes(tester, first: '/dashboardScreen');
      unawaited(InviteLinkRouter.consumePending());
      await letStorageFinish(tester);
      expect(opened, ['/familyJoin']);
      expect(secure, isEmpty, reason: 'used once, then removed');
    });

    testWidgets('sign-out drops a waiting link', (tester) async {
      await pumpRoutes(tester, first: '/loginScreen');
      await tester.runAsync(() => InviteLinkRouter.handle(goodLink));
      await tester.runAsync(InviteLinkRouter.clearPending);
      expect(InviteLinkRouter.pending, isNull);
      expect(secure, isEmpty);
    });

    testWidgets('other addresses do nothing', (tester) async {
      await pumpRoutes(tester, first: '/dashboardScreen');
      await InviteLinkRouter.handle(Uri.parse('https://kumbhapath.in/about'));
      await tester.pump();
      expect(opened, isEmpty);
      expect(InviteLinkRouter.pending, isNull);
    });

    testWidgets('links arrive through the stream', (tester) async {
      await pumpRoutes(tester, first: '/loginScreen');
      final links = StreamController<Uri>();
      addTearDown(links.close);
      InviteLinkRouter.listen(links.stream);
      links.add(goodLink);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      expect(InviteLinkRouter.pending?.token, token);
    });
  });

  group('Join screen', () {
    Future<void> open(WidgetTester tester, {String? link = token}) => pumpApp(
      tester,
      JoinFamilyScreen(link: InviteLink(link), repository: repo),
    );

    testWidgets('shows the family and what is shared, then accepts', (
      tester,
    ) async {
      await open(tester);
      expect(repo.calls, ['lookup:$token']);
      expect(find.text('Patil Family'), findsOneWidget);
      expect(find.text('fam_review_cannot_body'.tr()), findsOneWidget);
      final join = find.text('fam_join_confirm'.tr(args: ['Patil Family']));
      await tester.ensureVisible(join);
      await tester.pump();
      await tester.tap(join);
      await settle(tester);
      expect(repo.calls.last, 'accept:null:null:$token');
    });

    testWidgets('can be declined', (tester) async {
      await open(tester);
      final no = find.text('fam_decline'.tr());
      await tester.ensureVisible(no);
      await tester.pump();
      await tester.tap(no);
      await settle(tester);
      expect(repo.calls.last, 'decline:null:null:$token');
    });

    for (final state in const ['expired', 'revoked', 'accepted', 'declined']) {
      testWidgets('explains a link that was $state', (tester) async {
        repo.failure = closed(state);
        await open(tester);
        expect(find.text('fam_link_${state}_title'.tr()), findsOneWidget);
        expect(find.text('fam_join_confirm'), findsNothing);
      });
    }

    testWidgets('an unknown link is simply invalid', (tester) async {
      repo.failure = const FamilyException(FamilyFailure.notFound);
      await open(tester);
      expect(find.text('fam_link_invalid_title'.tr()), findsOneWidget);
    });

    testWidgets('a damaged link never reaches the server', (tester) async {
      await open(tester, link: null);
      expect(find.text('fam_link_invalid_title'.tr()), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('a failure on the network offers a retry', (tester) async {
      repo.failure = const FamilyException(FamilyFailure.offline);
      await open(tester);
      expect(find.text('common_retry'.tr()), findsOneWidget);
      repo.failure = null;
      await tester.tap(find.text('common_retry'.tr()));
      await settle(tester);
      expect(find.text('Patil Family'), findsOneWidget);
    });

    testWidgets('someone already in the family isn\'t asked to join', (
      tester,
    ) async {
      repo.result = const InvitePreview(
        id: 'i1',
        familyName: 'Patil Family',
        organizerName: 'Meena Patil',
        memberCount: 4,
        relationship: 'sibling',
        alreadyMember: true,
      );
      await open(tester);
      expect(find.text('fam_already_member'.tr()), findsOneWidget);
      expect(
        find.text('fam_join_confirm'.tr(args: ['Patil Family'])),
        findsNothing,
      );
    });

    testWidgets('if it ends while being reviewed, says so', (tester) async {
      await open(tester);
      repo.failure = closed('revoked');
      final join = find.text('fam_join_confirm'.tr(args: ['Patil Family']));
      await tester.ensureVisible(join);
      await tester.pump();
      await tester.tap(join);
      await settle(tester);
      expect(find.text('fam_link_revoked_title'.tr()), findsOneWidget);
    });

    for (final (name, locale, brightness, scale) in const [
      ('dark', Locale('en'), Brightness.dark, 1.0),
      ('Hindi large', Locale('hi'), Brightness.light, 1.6),
      ('Marathi dark', Locale('mr'), Brightness.dark, 1.3),
    ]) {
      testWidgets('closed state fits: $name', (tester) async {
        repo.failure = closed('expired');
        await pumpApp(
          tester,
          JoinFamilyScreen(link: const InviteLink(token), repository: repo),
          locale: locale,
          brightness: brightness,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Platform setup', () {
    test('Android verifies only the invitation path', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:autoVerify="true"'));
      expect(manifest, contains('android:host="kumbhapath.in"'));
      expect(manifest, contains('android:path="/join/family"'));
      expect(manifest, isNot(contains('android:scheme="http"')));
      expect(manifest, contains('flutter_deeplinking_enabled'));
    });

    test('iOS is set up for the domain', () {
      expect(
        File('ios/Runner/Runner.entitlements').readAsStringSync(),
        contains('applinks:kumbhapath.in'),
      );
      expect(
        File('ios/Runner/Info.plist').readAsStringSync(),
        contains('FlutterDeepLinkingEnabled'),
      );
      final project =
          File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(
        'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements'
            .allMatches(project)
            .length,
        3,
      );
    });
  });

  group('Repository', () {
    test('tokens travel in the body', () {
      final source =
          File(
            'lib/src/modules/family/data/family_repository.dart',
          ).readAsStringSync();
      expect(source, contains("{'token': token}"));
      expect(source, isNot(contains(r'token=$')));
    });
  });
}
