import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kumbha_path/src/components/navigation/app_navigation.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/family_home_screen.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:kumbha_path/src/modules/safety/data/safety_repository.dart';
import 'package:kumbha_path/src/modules/safety/models/safety_models.dart';
import 'package:kumbha_path/src/modules/safety/safety_alerts_screen.dart';
import 'package:kumbha_path/src/modules/safety/safety_qr_screen.dart';
import 'package:kumbha_path/src/modules/safety/safety_scan_screen.dart';
import 'package:kumbha_path/src/modules/safety/widgets/safety_card.dart';
import 'package:kumbha_path/src/services/notification_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
const payload = 'https://kumbhapath.in/safety/qr#t=$token';
const circle = FamilyCircle(
  id: 'f1',
  name: 'More Family',
  myRole: 'organizer',
  myMemberId: 'm1',
);
const args = FamilyArgs(circle, memberId: 'm3', memberName: 'Aarav More');

const activeQr = SafetyQr(
  id: 'q1',
  memberName: 'Aarav More',
  status: 'active',
  payload: payload,
);
const childScan = ScanResult(
  scanId: 's1',
  firstName: 'Aarav',
  category: 'child',
  language: 'mr',
);

FamilyAlert alertOf({
  String status = 'open',
  double? lat,
  bool withheld = false,
}) => FamilyAlert(
  id: 'a1',
  reference: 'KP-ABCD2345',
  kind: 'separated',
  status: status,
  familyId: 'f1',
  memberName: 'Aarav More',
  note: 'Help desk at the east gate',
  latitude: lat,
  longitude: lat == null ? null : 73.78,
  locationWithheld: withheld,
);

class FakeSafety implements SafetyRepository {
  SafetyQr? current;
  bool helper = true;
  ScanResult result = childScan;
  FamilyException? failure;
  FamilyException? confirmFailure;
  AlertReceipt? receipt = const AlertReceipt(
    id: 'a1',
    reference: 'KP-ABCD2345',
    delivery: 'sent',
  );
  List<FamilyAlert> theAlerts = [];
  final calls = <String>[];
  Map<String, Object?>? confirmed;

  void _gate() {
    final f = failure;
    if (f != null) throw f;
  }

  @override
  Future<SafetyQr?> qr(String f, String m) async {
    _gate();
    return current;
  }

  @override
  Future<SafetyQr> generate(String f, String m) async {
    _gate();
    calls.add('generate');
    return current = activeQr;
  }

  @override
  Future<SafetyQr> regenerate(String f, String m) async {
    calls.add('regenerate');
    return current = activeQr;
  }

  @override
  Future<void> revoke(String f, String m) async {
    calls.add('revoke');
    current = null;
  }

  @override
  Future<HelperStatus> helperStatus() async {
    _gate();
    return HelperStatus(isHelper: helper, role: helper ? 'volunteer' : null);
  }

  @override
  Future<ScanResult> resolve(String t) async {
    calls.add('resolve:$t');
    _gate();
    return result;
  }

  @override
  Future<AlertReceipt?> confirm(
    String scanId, {
    required String situation,
    String? note,
    double? latitude,
    double? longitude,
  }) async {
    final f = confirmFailure;
    if (f != null) throw f;
    confirmed = {
      'situation': situation,
      'note': note,
      'latitude': latitude,
      'longitude': longitude,
    };
    return situation == 'suspicious' ? null : receipt;
  }

  @override
  Future<AlertReceipt> helperAlert(String alertId) async => const AlertReceipt(
    id: 'a1',
    reference: 'KP-ABCD2345',
    delivery: 'sent',
    familyAcknowledged: true,
  );

  @override
  Future<List<FamilyAlert>> alerts(String familyId) async {
    _gate();
    return theAlerts;
  }

  @override
  Future<void> acknowledge(String f, String a) async {
    calls.add('acknowledge');
    theAlerts = [alertOf(status: 'acknowledged')];
  }

  @override
  Future<void> resolveAlert(String f, String a) async {
    calls.add('resolveAlert');
    theAlerts = [alertOf(status: 'resolved')];
  }
}

class FakeActions implements SafetyCardActions {
  final done = <String>[];
  bool saveResult = true;
  bool fail = false;
  Uint8List? lastPng;
  Uint8List? lastPdf;

  @override
  Future<bool> save(Uint8List png) async {
    if (fail) throw StateError('no');
    lastPng = png;
    done.add('save');
    return saveResult;
  }

  @override
  Future<bool> printCard(Uint8List pdf) async {
    lastPdf = pdf;
    done.add('print');
    return true;
  }

  @override
  Future<void> share(Uint8List png, Rect? origin) async => done.add('share');
}

class MemoryCache implements QrCache {
  final saved = <String, SafetyQr>{};

  @override
  Future<SafetyQr?> read(String memberId) async => saved[memberId]?.savedCopy();

  @override
  Future<void> write(String memberId, SafetyQr qr) async =>
      saved[memberId] = qr;

  @override
  Future<void> remove(String memberId) async => saved.remove(memberId);

  @override
  Future<void> clear() async => saved.clear();
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

Future<void> tapText(WidgetTester tester, String text) async {
  for (var i = 0; i < 30 && find.text(text).evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 50));
  }
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

/// Stands in for the camera: exposes what the real scanner calls.
late ValueChanged<String> emitCode;
late ValueChanged<ScanProblem> emitProblem;

Widget fakeScanner(
  BuildContext context,
  ValueChanged<String> onCode,
  ValueChanged<ScanProblem> onProblem,
) {
  emitCode = onCode;
  emitProblem = onProblem;
  return const SizedBox.expand(key: ValueKey('camera'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSafety repo;
  late FakeActions actions;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    dotenv.loadFromString(
      envString: 'API_PROTOCOL=https\nAPI_HOST=api.example.test',
    );
  });

  setUp(() {
    repo = FakeSafety();
    actions = FakeActions();
    SafetyServices.repository = repo;
    SafetyCardServices.actions = actions;
  });

  group('Reading a scanned code', () {
    test('accepts only our form', () {
      expect(safetyTokenFrom(payload), token);
      expect(safetyTokenFrom(' $payload\n'), token);
      for (final bad in [
        'http://kumbhapath.in/safety/qr#t=$token',
        'https://evil.example/safety/qr#t=$token',
        'https://kumbhapath.in.evil.example/safety/qr#t=$token',
        'https://www.kumbhapath.in/safety/qr#t=$token',
        'https://kumbhapath.in:8443/safety/qr#t=$token',
        'https://kumbhapath.in/safety/qr',
        'https://kumbhapath.in/safety/qr#t=short',
        'https://kumbhapath.in/join/family#t=$token',
        token,
        'hello',
        '',
      ]) {
        expect(safetyTokenFrom(bad), isNull, reason: bad);
      }
    });
  });

  group('Models', () {
    test('never print a token', () {
      expect('$activeQr', isNot(contains(token)));
    });

    test('only a sent push counts as the family being notified', () {
      AlertReceipt of(String d) =>
          AlertReceipt(id: 'a', reference: 'r', delivery: d);
      expect(of('sent').familyNotified, isTrue);
      for (final d in const ['no_devices', 'unavailable', 'pending']) {
        expect(of(d).familyNotified, isFalse);
      }
    });

    test('a helper result can\'t carry a phone number', () {
      final scan = ScanResult.fromJson(const {
        'scan_id': 's',
        'first_name': 'Aarav',
        'category': 'child',
        'language': 'hi',
        'open_alerts': [
          {'kind': 'separated', 'reference': 'KP-1'},
        ],
        'phone': '+919812345678',
      });
      expect(scan.openAlerts, ['KP-1']);
    });
  });

  group('Repository', () {
    HttpSafetyRepository client(
      Future<http.Response> Function(http.Request) handler, {
      QrCache? cache,
      bool https = false,
    }) => HttpSafetyRepository(
      client: MockClient(handler),
      token: () async => 'JWT',
      cache: cache ?? MemoryCache(),
      requireHttps: https,
    );

    http.Response ok(Object? data, [int code = 200]) =>
        http.Response(jsonEncode({'status': 'success', 'data': data}), code);

    Map<String, Object?> qrJson() => {
      'id': 'q1',
      'member_name': 'Aarav',
      'status': 'active',
      'payload': payload,
    };

    test('sends the token in the body, with auth in the header', () async {
      late http.Request seen;
      final repo = client((request) async {
        seen = request;
        return ok({'scan_id': 's', 'category': 'child'});
      });
      await repo.resolve(token);
      expect(seen.url.toString(), isNot(contains(token)));
      expect(jsonDecode(seen.body), {'token': token});
      expect(seen.headers['Authorization'], 'Bearer JWT');
    });

    test('maps every failure', () async {
      Future<FamilyFailure> failure(int code) async {
        try {
          await client((_) async => http.Response('{}', code)).resolve(token);
        } on FamilyException catch (e) {
          return e.kind;
        }
        throw StateError('expected a failure');
      }

      expect(await failure(403), FamilyFailure.forbidden);
      expect(await failure(404), FamilyFailure.notFound);
      expect(await failure(410), FamilyFailure.gone);
      expect(await failure(429), FamilyFailure.server);
    });

    test('release builds refuse plain HTTP', () async {
      dotenv.loadFromString(
        envString: 'API_PROTOCOL=https\nAPI_HOST=api.example.test',
      );
      final repo = client((_) async => ok(null), https: false);
      await expectLater(repo.helperStatus(), throwsA(isA<FamilyException>()));
      final source =
          File(
            'lib/src/modules/safety/data/safety_repository.dart',
          ).readAsStringSync();
      expect(source, contains("requireHttps && ApiConst.protocol != 'https'"));
      expect(source, contains('this.requireHttps = kReleaseMode'));
    });

    test('offline shows the saved card, and marks it as such', () async {
      final cache = MemoryCache();
      var online = true;
      final repo = client((_) async {
        if (!online) throw http.ClientException('down');
        return ok(qrJson());
      }, cache: cache);
      expect((await repo.qr('f', 'm'))?.fromDevice, isFalse);
      online = false;
      final saved = await repo.qr('f', 'm');
      expect(saved?.fromDevice, isTrue);
      expect(saved?.payload, payload);
    });

    test('losing access removes the saved card', () async {
      final cache = MemoryCache()..saved['m'] = activeQr;
      final repo = client((_) async => http.Response('{}', 403), cache: cache);
      await expectLater(repo.qr('f', 'm'), throwsA(isA<FamilyException>()));
      expect(cache.saved, isEmpty);
    });

    test('revoking removes the saved card', () async {
      final cache = MemoryCache()..saved['m'] = activeQr;
      await client((_) async => ok({}), cache: cache).revoke('f', 'm');
      expect(cache.saved, isEmpty);
    });

    test('a report needs the helper\'s confirmation flag', () async {
      late Map<String, dynamic> body;
      final repo = client((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return ok({'id': 'a', 'reference': 'KP-1', 'delivery': 'sent'});
      });
      await repo.confirm('s', situation: 'medical');
      expect(body['confirmed'], isTrue);
      expect(body.containsKey('latitude'), isFalse);
    });
  });

  group('Safety QR screen', () {
    Future<void> open(WidgetTester tester, {double textScale = 1}) => pumpApp(
      tester,
      SafetyQrScreen(args: args, repository: repo),
      textScale: textScale,
    );

    testWidgets('with no card, explains and offers one', (tester) async {
      await open(tester);
      expect(
        find.text('qr_none_title'.tr(args: ['Aarav More'])),
        findsOneWidget,
      );
      await tapText(tester, 'qr_create'.tr());
      expect(repo.calls, ['generate']);
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('shows the name, the code and the status', (tester) async {
      repo.current = activeQr;
      await open(tester);
      expect(find.text('Aarav More'), findsOneWidget);
      expect(find.text('qr_status_active'.tr()), findsOneWidget);
      final view = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(view.backgroundColor, Colors.white);
    });

    testWidgets('the printed card names nobody', (tester) async {
      repo.current = activeQr;
      await open(tester);
      final card = find.byType(SafetyCard);
      expect(tester.widget<SafetyCard>(card).initial, 'A.');
      final words = tester
          .widgetList<Text>(
            find.descendant(of: card, matching: find.byType(Text)),
          )
          .map((t) => t.data ?? '')
          .join(' ');
      expect(words, isNot(contains('Aarav')));
      expect(words, isNot(contains('More Family')));
      expect(RegExp(r'\d{10}').hasMatch(words), isFalse);
    });

    testWidgets('replacing asks first', (tester) async {
      repo.current = activeQr;
      await open(tester);
      await tapText(tester, 'qr_regenerate'.tr());
      expect(repo.calls, isEmpty);
      await tester.tap(find.text('qr_regenerate'.tr()).last);
      await settle(tester);
      expect(repo.calls, ['regenerate']);
    });

    testWidgets('turning off asks first, then shows revoked', (tester) async {
      repo.current = activeQr;
      await open(tester);
      await tapText(tester, 'qr_revoke'.tr());
      await tester.tap(find.text('qr_revoke'.tr()).last);
      await settle(tester);
      expect(repo.calls, ['revoke']);
      expect(find.text('qr_status_revoked'.tr()), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('a saved copy is labelled, and can\'t be changed', (
      tester,
    ) async {
      repo.current = activeQr.savedCopy();
      await open(tester);
      expect(find.text('qr_offline_saved'.tr()), findsOneWidget);
    });

    testWidgets('offline with nothing saved explains', (tester) async {
      repo.failure = const FamilyException(FamilyFailure.offline);
      await open(tester);
      expect(find.text('qr_offline_none'.tr()), findsOneWidget);
      repo.failure = null;
      await tapText(tester, 'common_retry'.tr());
      expect(find.text('qr_create'.tr()), findsOneWidget);
    });

    testWidgets('being refused says so', (tester) async {
      repo.failure = const FamilyException(FamilyFailure.forbidden);
      await open(tester);
      expect(find.text('fam_error_forbidden'.tr()), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    for (final (name, locale, brightness, scale, width) in const [
      ('dark', Locale('en'), Brightness.dark, 1.0, 390.0),
      ('Hindi large', Locale('hi'), Brightness.light, 1.6, 390.0),
      ('Marathi dark', Locale('mr'), Brightness.dark, 1.3, 390.0),
      ('narrow', Locale('en'), Brightness.light, 1.3, 320.0),
    ]) {
      testWidgets('fits: $name', (tester) async {
        repo.current = activeQr;
        await pumpApp(
          tester,
          SafetyQrScreen(args: args, repository: repo),
          locale: locale,
          brightness: brightness,
          textScale: scale,
          width: width,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Card image and printing', () {
    testWidgets('the card renders to a PNG, and the PDF holds it', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: const SafetyCard(payload: payload, initial: 'A.'),
            ),
          ),
        ),
      );
      await tester.pump();
      final png = await tester.runAsync(() => captureCard(key));
      expect(png, isNotNull);
      expect(png!.sublist(1, 4), utf8.encode('PNG'));
      expect(png.length, greaterThan(2000));
      final pdf = await tester.runAsync(() => buildCardPdf(png));
      expect(utf8.decode(pdf!.sublist(0, 4)), '%PDF');
      expect(pdf.length, greaterThan(png.length ~/ 4));
    });

    testWidgets('the code matches the payload exactly', (tester) async {
      final qr = QrImage(
        QrCode.fromData(
          data: payload,
          errorCorrectLevel: QrErrorCorrectLevel.Q,
        ),
      );
      expect(qr.moduleCount, greaterThan(20));
      expect(payload, isNot(contains('Aarav')));
    });

    Future<void> runAction(WidgetTester tester, String label) async {
      repo.current = activeQr;
      await pumpApp(tester, SafetyQrScreen(args: args, repository: repo));
      final target = find.text(label.tr());
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(target);
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await settle(tester);
    }

    testWidgets('saving hands over the image and says so', (tester) async {
      await runAction(tester, 'qr_save');
      expect(actions.done, ['save']);
      expect(actions.lastPng, isNotNull);
      expect(find.text('qr_saved'.tr()), findsOneWidget);
    });

    testWidgets('printing hands over a PDF', (tester) async {
      await runAction(tester, 'qr_print');
      expect(actions.done, ['print']);
      expect(utf8.decode(actions.lastPdf!.sublist(0, 4)), '%PDF');
    });

    testWidgets('sharing hands over the card', (tester) async {
      await runAction(tester, 'qr_share');
      expect(actions.done, ['share']);
    });

    testWidgets('a failure is reported', (tester) async {
      actions.fail = true;
      await runAction(tester, 'qr_save');
      expect(find.text('qr_card_failed'.tr()), findsOneWidget);
    });

    testWidgets('cancelling a save says nothing', (tester) async {
      actions.saveResult = false;
      await runAction(tester, 'qr_save');
      expect(find.text('qr_saved'.tr()), findsNothing);
    });
  });

  group('Scanner', () {
    Future<void> open(WidgetTester tester, {LocationReader? location}) =>
        pumpApp(
          tester,
          SafetyScanScreen(
            repository: repo,
            scanner: fakeScanner,
            location: location ?? () async => null,
          ),
        );

    Future<void> scan(WidgetTester tester, [String code = payload]) async {
      emitCode(code);
      await settle(tester);
    }

    testWidgets('an ordinary user gets no camera at all', (tester) async {
      repo.helper = false;
      await open(tester);
      expect(find.text('scan_not_helper_title'.tr()), findsOneWidget);
      expect(find.byKey(const ValueKey('camera')), findsNothing);
    });

    testWidgets('losing helper status mid-scan closes it', (tester) async {
      await open(tester);
      repo.failure = const FamilyException(FamilyFailure.forbidden);
      await scan(tester);
      expect(find.text('scan_not_helper_title'.tr()), findsOneWidget);
    });

    testWidgets('camera permission denied explains and offers settings', (
      tester,
    ) async {
      await open(tester);
      emitProblem(ScanProblem.permissionDenied);
      await settle(tester);
      expect(find.text('scan_camera_denied_title'.tr()), findsOneWidget);
      expect(find.text('scan_open_settings'.tr()), findsOneWidget);
    });

    testWidgets('a camera failure can be retried', (tester) async {
      await open(tester);
      emitProblem(ScanProblem.unavailable);
      await settle(tester);
      expect(find.text('scan_camera_failed_title'.tr()), findsOneWidget);
      await tapText(tester, 'common_retry'.tr());
      expect(find.text('scan_hint'.tr()), findsOneWidget);
    });

    testWidgets('a foreign code never reaches the server', (tester) async {
      await open(tester);
      await scan(tester, 'https://example.org/promo');
      expect(repo.calls, isEmpty);
      expect(find.text('scan_not_ours'.tr()), findsOneWidget);
    });

    testWidgets('an unknown or revoked code keeps scanning', (tester) async {
      await open(tester);
      repo.failure = const FamilyException(FamilyFailure.notFound);
      await scan(tester);
      expect(find.text('scan_unknown'.tr()), findsOneWidget);
      repo.failure = const FamilyException(FamilyFailure.gone);
      await scan(tester);
      expect(find.text('scan_revoked'.tr()), findsOneWidget);
    });

    testWidgets('shows the minimum, and warns about identity', (tester) async {
      await open(tester);
      await scan(tester);
      expect(repo.calls, ['resolve:$token']);
      expect(find.text('Aarav'), findsOneWidget);
      expect(find.text('scan_verify_child'.tr()), findsOneWidget);
      expect(find.textContaining('+91'), findsNothing);
    });

    testWidgets('nothing is reported without choosing and confirming', (
      tester,
    ) async {
      await open(tester);
      await scan(tester);
      expect(repo.confirmed, isNull);
      await tapText(tester, 'scan_sit_separated'.tr());
      await tapText(tester, 'scan_notify'.tr());
      expect(repo.confirmed, isNull, reason: 'the dialog must come first');
      expect(find.text('scan_confirm_alert'.tr()), findsOneWidget);
      await tester.tap(find.text('scan_confirm'.tr()));
      await settle(tester);
      expect(repo.confirmed?['situation'], 'separated');
      expect(find.text('KP-ABCD2345'), findsOneWidget);
      expect(find.text('scan_handover_body'.tr()), findsOneWidget);
    });

    Future<void> report(WidgetTester tester, [String sit = 'separated']) async {
      await tapText(tester, 'scan_sit_$sit'.tr());
      await tapText(
        tester,
        sit == 'suspicious' ? 'scan_record'.tr() : 'scan_notify'.tr(),
      );
      await tester.tap(find.text('scan_confirm'.tr()));
      await settle(tester);
    }

    testWidgets('location is sent only if the helper turns it on', (
      tester,
    ) async {
      var asked = 0;
      await open(
        tester,
        location: () async {
          asked++;
          return (19.99, 73.78);
        },
      );
      await scan(tester);
      await report(tester);
      expect(asked, 0);
      expect(repo.confirmed?['latitude'], isNull);
    });

    testWidgets('location is added when allowed', (tester) async {
      await open(tester, location: () async => (19.99, 73.78));
      await scan(tester);
      await tapText(tester, 'scan_sit_separated'.tr());
      await tapText(tester, 'scan_share_location'.tr());
      await tapText(tester, 'scan_notify'.tr());
      await tester.tap(find.text('scan_confirm'.tr()));
      await settle(tester);
      expect(repo.confirmed?['latitude'], 19.99);
    });

    testWidgets('a refused location permission still reports', (tester) async {
      await open(tester, location: () async => null);
      await scan(tester);
      await tapText(tester, 'scan_sit_medical'.tr());
      await tapText(tester, 'scan_share_location'.tr());
      await tapText(tester, 'scan_notify'.tr());
      await tester.tap(find.text('scan_confirm'.tr()));
      await settle(tester);
      expect(repo.confirmed?['situation'], 'medical');
      expect(repo.confirmed?['latitude'], isNull);
    });

    for (final (delivery, key) in const [
      ('sent', 'scan_delivered'),
      ('no_devices', 'scan_no_devices'),
      ('unavailable', 'scan_undelivered'),
    ]) {
      testWidgets('tells the truth when delivery is $delivery', (tester) async {
        repo.receipt = AlertReceipt(
          id: 'a1',
          reference: 'KP-ABCD2345',
          delivery: delivery,
        );
        await open(tester);
        await scan(tester);
        await report(tester);
        expect(find.text(key.tr()), findsOneWidget);
      });
    }

    testWidgets('a duplicate says the family wasn\'t alerted again', (
      tester,
    ) async {
      repo.receipt = const AlertReceipt(
        id: 'a1',
        reference: 'KP-ABCD2345',
        delivery: 'sent',
        duplicate: true,
      );
      await open(tester);
      await scan(tester);
      await report(tester);
      expect(find.text('scan_duplicate'.tr()), findsOneWidget);
    });

    testWidgets('a suspicious scan tells no family', (tester) async {
      await open(tester);
      await scan(tester);
      await report(tester, 'suspicious');
      expect(find.text('scan_flagged_title'.tr()), findsOneWidget);
      expect(repo.confirmed?['situation'], 'suspicious');
    });

    testWidgets('an expired scan goes back to scanning', (tester) async {
      await open(tester);
      await scan(tester);
      repo.confirmFailure = const FamilyException(FamilyFailure.gone);
      await report(tester);
      expect(find.text('scan_expired'.tr()), findsOneWidget);
    });

    testWidgets('the helper can see when the family has seen it', (
      tester,
    ) async {
      await open(tester);
      await scan(tester);
      await report(tester);
      expect(find.text('scan_family_waiting'.tr()), findsOneWidget);
      await tester.tap(find.byTooltip('scan_refresh'.tr()));
      await settle(tester);
      expect(find.text('scan_family_seen'.tr()), findsOneWidget);
    });
  });

  group('Family alerts', () {
    Future<void> open(WidgetTester tester) =>
        pumpApp(tester, SafetyAlertsScreen(args: args, repository: repo));

    testWidgets('empty', (tester) async {
      await open(tester);
      expect(find.text('alert_none_title'.tr()), findsOneWidget);
    });

    testWidgets('shows what happened, and warns about handover', (
      tester,
    ) async {
      repo.theAlerts = [alertOf(lat: 19.99)];
      await open(tester);
      expect(find.text('Aarav More'), findsOneWidget);
      expect(find.text('Help desk at the east gate'), findsOneWidget);
      expect(find.text('alert_handover_family'.tr()), findsOneWidget);
      expect(find.text('alert_open_map'.tr()), findsOneWidget);
    });

    testWidgets('an adult\'s withheld location says so', (tester) async {
      repo.theAlerts = [alertOf(withheld: true)];
      await open(tester);
      expect(find.text('alert_location_withheld'.tr()), findsOneWidget);
      expect(find.text('alert_open_map'.tr()), findsNothing);
    });

    testWidgets('acknowledging and resolving', (tester) async {
      repo.theAlerts = [alertOf()];
      await open(tester);
      await tapText(tester, 'alert_acknowledge'.tr());
      expect(repo.calls, ['acknowledge']);
      expect(find.text('alert_acknowledge'.tr()), findsNothing);
      await tapText(tester, 'alert_resolve'.tr());
      await tester.tap(find.text('alert_resolve'.tr()).last);
      await settle(tester);
      expect(repo.calls, ['acknowledge', 'resolveAlert']);
      expect(find.text('alert_resolve'.tr()), findsNothing);
    });

    testWidgets('an error can be retried', (tester) async {
      repo.failure = const FamilyException(FamilyFailure.offline);
      await open(tester);
      repo.failure = null;
      await tapText(tester, 'common_retry'.tr());
      expect(find.text('alert_none_title'.tr()), findsOneWidget);
    });
  });

  group('App wiring', () {
    test('routes keep Home highlighted, and notifications can open alerts', () {
      for (final route in const ['/safetyQr', '/safetyScan', '/safetyAlerts']) {
        expect(AppNavigation.indexOfRoute(route), AppNavigation.homeIndex);
      }
      expect(
        NotificationRouter.routeFor(const {'type': 'family_safety_alert'}),
        '/safetyAlerts',
      );
    });

    test('every translation key exists in all three languages', () {
      Map<String, dynamic> load(String lang) =>
          json.decode(File('assets/translations/$lang.json').readAsStringSync())
              as Map<String, dynamic>;
      final en = load('en');
      final keys =
          en.keys
              .where((k) => RegExp(r'^(qr|scan|alert)_').hasMatch(k))
              .toSet();
      expect(keys.length, greaterThan(90));
      for (final lang in const ['hi', 'mr']) {
        expect(keys.difference(load(lang).keys.toSet()), isEmpty, reason: lang);
      }
    });

    test('the camera permission is declared on both platforms', () {
      expect(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        contains('android.permission.CAMERA'),
      );
      expect(
        File('ios/Runner/Info.plist').readAsStringSync(),
        contains('NSCameraUsageDescription'),
      );
    });

    test('nothing in the module logs', () {
      final files = Directory('lib/src/modules/safety')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in files) {
        expect(
          RegExp(
            r'\b(debugPrint|log)\(|[^.]\bprint\(',
          ).hasMatch(file.readAsStringSync()),
          isFalse,
          reason: file.path,
        );
      }
    });
  });
}
