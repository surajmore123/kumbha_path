import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/family_flows_screens.dart';
import 'package:kumbha_path/src/modules/family/family_home_screen.dart';
import 'package:kumbha_path/src/modules/family/invite_links.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:kumbha_path/src/modules/family/widgets/invite_share_sheet.dart';
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
const link = 'https://kumbhapath.in/join/family#t=$token';
const circle = FamilyCircle(
  id: 'f1',
  name: 'More Family',
  myRole: 'organizer',
  myMemberId: 'm1',
);

class FakeSharer implements InviteSharer {
  bool opens = true;
  InviteShareResult result = InviteShareResult.shared;
  bool systemFails = false;
  bool copyFails = false;
  final opened = <Uri>[];
  final shared = <String>[];
  final copied = <String>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return opens;
  }

  @override
  Future<InviteShareResult> system(String text, Rect? origin) async {
    shared.add(text);
    if (systemFails) throw StateError('no share sheet');
    return result;
  }

  @override
  Future<void> copy(String text) async {
    if (copyFails) throw StateError('no clipboard');
    copied.add(text);
  }
}

class FakeInvites implements FamilyRepository {
  DateTime? expires = DateTime(2030, 8, 3);
  String madeLink = link;
  String stateNow = 'pending';
  bool listFails = false;
  bool created = false;

  FamilyInvite get _invite => FamilyInvite(
    id: 'i9',
    relationship: 'sibling',
    state: stateNow,
    code: 'ABCD2345WXYZ',
    link: madeLink,
    expiresAt: expires,
  );

  @override
  Future<List<FamilyInvite>> invitations(String f) async {
    if (listFails && created) {
      throw const FamilyException(FamilyFailure.offline);
    }
    return created ? [_invite] : [];
  }

  @override
  Future<FamilyInvite> createInvitation(
    String f, {
    required String relationship,
    String? phone,
  }) async {
    created = true;
    return _invite;
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

Future<void> tapText(WidgetTester tester, String text) async {
  final scrollables = find.byType(Scrollable);
  // The ticket appears above where the form was left scrolled to.
  for (final step in const [Offset(0, 300), Offset(0, -300)]) {
    for (var i = 0; i < 12 && find.text(text).evaluate().isEmpty; i++) {
      await tester.drag(scrollables.first, step);
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSharer sharer;
  late FakeInvites repo;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    sharer = FakeSharer();
    repo = FakeInvites();
    InviteSharing.sharer = sharer;
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.light,
    double textScale = 1,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 844) * 3;
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
                home: InviteScreen(
                  args: const FamilyArgs(circle),
                  repository: repo,
                ),
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

  Future<void> createInvite(WidgetTester tester, {String? phone}) async {
    await tapText(tester, 'fam_rel_sibling'.tr());
    if (phone != null) {
      await tester.enterText(find.byType(TextFormField), phone);
    }
    await tapText(tester, 'fam_invite_create'.tr());
  }

  Future<void> openSheet(WidgetTester tester, {String? phone}) async {
    await pumpScreen(tester);
    await createInvite(tester, phone: phone);
    await tapText(tester, 'fam_share_invitation'.tr());
  }

  group('Addresses', () {
    const text = 'Join us: $link\n\nThanks & see you';

    test('WhatsApp keeps the whole message, including the token', () {
      final uri = whatsAppUri(text);
      expect(uri.scheme, 'whatsapp');
      expect(uri.host, 'send');
      expect(uri.fragment, isEmpty, reason: 'the "#" must be encoded');
      expect(uri.queryParameters['text'], text);
    });

    test('WhatsApp can go straight to a chosen number', () {
      expect(
        whatsAppUri(text, phone: '9812345678').queryParameters['phone'],
        '919812345678',
      );
    });

    test('SMS keeps the whole message on each platform', () {
      final android = smsUri(text, ios: false);
      expect(android.toString(), startsWith('sms:?body='));
      expect(android.queryParameters['body'], text);
      expect(android.fragment, isEmpty);
      final ios = smsUri(text, phone: '9812345678', ios: true).toString();
      expect(ios, startsWith('sms:+919812345678&body='));
      expect(Uri.decodeComponent(ios), contains(link));
    });
  });

  group('Message', () {
    testWidgets('has the family, the link and the expiry', (tester) async {
      await openSheet(tester);
      final text = find.textContaining('More Family').last;
      final message = tester.widget<Text>(text).data!;
      expect(message, contains('More Family'));
      expect(message, contains(link));
      expect(message, contains('3 Aug 2030'));
      expect(message, isNot(contains('ABCD2345WXYZ')));
      expect(parseInviteLink(Uri.parse(link))?.token, token);
    });

    testWidgets('works when there is no expiry', (tester) async {
      repo.expires = null;
      await openSheet(tester);
      await tapText(tester, 'fam_way_more'.tr());
      expect(sharer.shared.single, contains(link));
      expect(sharer.shared.single, contains('works once'));
      expect(sharer.shared.single, isNot(contains('expires')));
    });

    test('every language has the placeholders in place', () {
      for (final lang in const ['en', 'hi', 'mr']) {
        final file = File('assets/translations/$lang.json').readAsStringSync();
        final map = json.decode(file) as Map<String, dynamic>;
        expect('{}'.allMatches(map['fam_invite_msg'] as String).length, 3);
        expect('{}'.allMatches(map['fam_invite_msg_open'] as String).length, 2);
        expect('{}'.allMatches(map['fam_share_note'] as String).length, 1);
      }
    });
  });

  group('Sharing', () {
    testWidgets(
      'WhatsApp opens with the message, and claims nothing was sent',
      (tester) async {
        await openSheet(tester);
        await tapText(tester, 'fam_way_whatsapp'.tr());
        final uri = sharer.opened.single;
        expect(uri.scheme, 'whatsapp');
        expect(uri.queryParameters['text'], contains(link));
        expect(find.text('fam_share_opened_whatsapp'.tr()), findsOneWidget);
        expect(sharer.shared, isEmpty);
      },
    );

    testWidgets('a number typed for the invitation is used', (tester) async {
      await openSheet(tester, phone: '9812345678');
      await tapText(tester, 'fam_way_whatsapp'.tr());
      expect(sharer.opened.single.queryParameters['phone'], '919812345678');
    });

    testWidgets('SMS opens with the message', (tester) async {
      await openSheet(tester);
      await tapText(tester, 'fam_way_sms'.tr());
      expect(sharer.opened.single.scheme, 'sms');
      expect(sharer.opened.single.queryParameters['body'], contains(link));
      expect(find.text('fam_share_opened_sms'.tr()), findsOneWidget);
    });

    testWidgets('other apps use the system sheet', (tester) async {
      await openSheet(tester);
      await tapText(tester, 'fam_way_more'.tr());
      expect(sharer.shared.single, contains(link));
      expect(find.text('fam_share_opened'.tr()), findsOneWidget);
    });

    testWidgets('copying takes just the link, and says so', (tester) async {
      await openSheet(tester);
      await tapText(tester, 'fam_way_copy'.tr());
      expect(sharer.copied, [link]);
      expect(find.text('fam_link_copied'.tr()), findsOneWidget);
    });

    testWidgets('the code can still be copied', (tester) async {
      await pumpScreen(tester);
      await createInvite(tester);
      expect(find.text('ABCD-2345-WXYZ'), findsOneWidget);
      expect(find.text('fam_copy'.tr()), findsOneWidget);
    });
  });

  group('When things go wrong', () {
    testWidgets('closing the sheet does nothing', (tester) async {
      await openSheet(tester);
      await tester.tapAt(const Offset(20, 20));
      await settle(tester);
      expect(sharer.opened, isEmpty);
      expect(sharer.shared, isEmpty);
      expect(find.text('fam_share_invitation'.tr()), findsOneWidget);
    });

    testWidgets('cancelling the system sheet says the invitation stays open', (
      tester,
    ) async {
      sharer.result = InviteShareResult.cancelled;
      await openSheet(tester);
      await tapText(tester, 'fam_way_more'.tr());
      expect(find.text('fam_share_cancelled'.tr()), findsOneWidget);
      expect(find.text('fam_share_invitation'.tr()), findsOneWidget);
    });

    testWidgets('without WhatsApp, offers the other apps', (tester) async {
      sharer.opens = false;
      await openSheet(tester);
      await tapText(tester, 'fam_way_whatsapp'.tr());
      expect(find.text('fam_whatsapp_missing'.tr()), findsOneWidget);
      expect(sharer.shared.single, contains(link));
    });

    testWidgets('without a messages app, offers the other apps', (
      tester,
    ) async {
      sharer.opens = false;
      await openSheet(tester);
      await tapText(tester, 'fam_way_sms'.tr());
      expect(find.text('fam_sms_missing'.tr()), findsOneWidget);
      expect(sharer.shared, hasLength(1));
    });

    testWidgets('if nothing can share, the link is copied', (tester) async {
      sharer
        ..opens = false
        ..systemFails = true;
      await openSheet(tester);
      await tapText(tester, 'fam_way_whatsapp'.tr());
      expect(sharer.copied, [link]);
      expect(find.text('fam_share_failed_copied'.tr()), findsOneWidget);
    });

    testWidgets('a clipboard failure is reported, not hidden', (tester) async {
      sharer.copyFails = true;
      await openSheet(tester);
      await tapText(tester, 'fam_way_copy'.tr());
      expect(find.text('fam_share_failed'.tr()), findsOneWidget);
    });

    testWidgets('an expired invitation can\'t be shared', (tester) async {
      repo.expires = DateTime(2020);
      await pumpScreen(tester);
      await createInvite(tester);
      await tapText(tester, 'fam_share_invitation'.tr());
      expect(find.text('fam_link_expired_title'.tr()), findsOneWidget);
      expect(find.text('fam_way_whatsapp'.tr()), findsNothing);
      expect(find.text('ABCD-2345-WXYZ'), findsNothing);
    });

    for (final state in const ['revoked', 'accepted', 'declined']) {
      testWidgets('a $state invitation can\'t be shared', (tester) async {
        await pumpScreen(tester);
        await createInvite(tester);
        repo.stateNow = state;
        await tapText(tester, 'fam_share_invitation'.tr());
        expect(find.text('fam_link_${state}_title'.tr()), findsOneWidget);
        expect(find.text('fam_way_whatsapp'.tr()), findsNothing);
      });
    }

    testWidgets('a malformed link can\'t be shared', (tester) async {
      repo.madeLink = 'https://evil.example/join/family#t=$token';
      await pumpScreen(tester);
      await createInvite(tester);
      await tapText(tester, 'fam_share_invitation'.tr());
      expect(find.text('fam_link_invalid_title'.tr()), findsOneWidget);
      expect(find.text('fam_way_whatsapp'.tr()), findsNothing);
    });

    testWidgets('offline, it can still be shared', (tester) async {
      repo.listFails = true;
      await pumpScreen(tester);
      await createInvite(tester);
      await tapText(tester, 'fam_share_invitation'.tr());
      expect(find.text('fam_way_whatsapp'.tr()), findsOneWidget);
    });
  });

  group('Appearance', () {
    for (final (name, locale, brightness, scale, width) in const [
      ('dark', Locale('en'), Brightness.dark, 1.0, 390.0),
      ('Hindi large text', Locale('hi'), Brightness.light, 1.6, 390.0),
      ('Marathi dark', Locale('mr'), Brightness.dark, 1.3, 390.0),
      ('narrow screen', Locale('en'), Brightness.light, 1.3, 320.0),
    ]) {
      testWidgets('sheet fits: $name', (tester) async {
        await pumpScreen(
          tester,
          locale: locale,
          brightness: brightness,
          textScale: scale,
          width: width,
        );
        await createInvite(tester);
        await tapText(tester, 'fam_share_invitation'.tr());
        expect(find.text('fam_way_whatsapp'.tr()), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Logs', () {
    test('text forms hide the link', () {
      const share = InviteShare(familyName: 'More', link: link);
      expect('$share', isNot(contains(token)));
    });

    test('sharing code never logs, or asks url_launcher to', () {
      final source =
          File(
            'lib/src/modules/family/widgets/invite_share_sheet.dart',
          ).readAsStringSync();
      final code = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('///'))
          .join('\n');
      expect(RegExp(r'\b(print|debugPrint|log)\(').hasMatch(code), isFalse);
      expect(code, isNot(contains('canLaunchUrl')));
    });

    testWidgets('nothing prints the token while sharing', (tester) async {
      final printed = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
      sharer
        ..opens = false
        ..systemFails = true;
      await openSheet(tester);
      await tapText(tester, 'fam_way_whatsapp'.tr());
      debugPrint = previous;
      expect(printed.where((line) => line.contains(token)), isEmpty);
    });

    test('release builds strip verbose, debug and info logs', () {
      final rules = File('android/app/proguard-rules.pro').readAsStringSync();
      for (final level in const ['v', 'd', 'i']) {
        expect(rules, contains('public static int $level(...);'));
      }
    });
  });
}
