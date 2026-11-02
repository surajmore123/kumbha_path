import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/safety/data/safety_repository.dart';
import 'package:kumbha_path/src/modules/safety/models/safety_models.dart';
import 'package:kumbha_path/src/modules/safety/widgets/safety_card.dart';
import 'package:path_provider/path_provider.dart';

class _NoCache implements QrCache {
  @override
  Future<SafetyQr?> read(String memberId) async => null;

  @override
  Future<void> write(String memberId, SafetyQr qr) async {}

  @override
  Future<void> remove(String memberId) async {}

  @override
  Future<void> clear() async {}
}

/// The real client against a real local backend, and a real card on a device.
/// Needs test accounts: see "Testing" in docs/safety_qr.md.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const host = String.fromEnvironment('API_HOST');
  const organizerToken = String.fromEnvironment('ORGANIZER_TOKEN');
  const helperToken = String.fromEnvironment('HELPER_TOKEN');

  late FamilyRepository family;
  late SafetyRepository organizer;
  late SafetyRepository helper;
  late String familyId;
  late String childId;
  late SafetyQr qr;

  SafetyRepository as(String token) => HttpSafetyRepository(
    token: () async => token,
    cache: _NoCache(),
    requireHttps: false,
  );

  setUpAll(() async {
    dotenv.loadFromString(envString: 'API_PROTOCOL=http\nAPI_HOST=$host');
    family = HttpFamilyRepository(token: () async => organizerToken);
    organizer = as(organizerToken);
    helper = as(helperToken);
    familyId = (await family.createCircle({'name': 'QR Test Family'})).id;
    final child = await family.addDependent(familyId, {
      'full_name': 'Test Child',
      'kind': 'dependent_child',
      'relationship': 'son',
      'age_group': '6_12',
    });
    childId = child.id;
  });

  tearDownAll(() => family.deleteCircle(familyId));

  testWidgets('a guardian generates a card, the same each time', (
    tester,
  ) async {
    expect(await organizer.qr(familyId, childId), isNull);
    qr = await organizer.generate(familyId, childId);
    expect(safetyTokenFrom(qr.payload), isNotNull);
    expect((await organizer.generate(familyId, childId)).payload, qr.payload);
    expect(qr.payload, isNot(contains('Test')));
  });

  testWidgets('the card renders on a device with real fonts', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: FittedBox(
              child: RepaintBoundary(
                key: key,
                child: SafetyCard(payload: qr.payload, initial: 'T.'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final png = await captureCard(key);
    final pdf = await buildCardPdf(png);
    final dir = await getTemporaryDirectory();
    await File('${dir.path}/safety_card.png').writeAsBytes(png);
    await File('${dir.path}/safety_card.pdf').writeAsBytes(pdf);
    expect(png.length, greaterThan(5000));
  });

  testWidgets('a family member can\'t scan', (tester) async {
    await expectLater(
      organizer.resolve(safetyTokenFrom(qr.payload)!),
      throwsA(
        isA<FamilyException>().having(
          (e) => e.kind,
          'kind',
          FamilyFailure.forbidden,
        ),
      ),
    );
    expect((await organizer.helperStatus()).isHelper, isFalse);
  });

  testWidgets('scan, report, and the family acknowledges', (tester) async {
    expect((await helper.helperStatus()).isHelper, isTrue);
    final token = safetyTokenFrom(qr.payload)!;
    final scan = await helper.resolve(token);
    expect(scan.firstName, 'Test');
    expect(scan.category, 'child');
    expect(await organizer.alerts(familyId), isEmpty);

    final receipt = await helper.confirm(
      scan.scanId,
      situation: 'separated',
      note: 'Help desk',
    );
    expect(receipt, isNotNull);
    expect(receipt!.reference, startsWith('KP-'));
    expect(receipt.familyNotified, isFalse, reason: 'no device is registered');
    expect(receipt.delivery, 'no_devices');

    final again = await helper.resolve(token);
    final repeat = await helper.confirm(again.scanId, situation: 'separated');
    expect(repeat!.duplicate, isTrue);
    expect(repeat.reference, receipt.reference);

    final alerts = await organizer.alerts(familyId);
    expect(alerts.single.reference, receipt.reference);
    expect(alerts.single.note, 'Help desk');
    await organizer.acknowledge(familyId, alerts.single.id);
    expect((await helper.helperAlert(receipt.id)).familyAcknowledged, isTrue);
    await organizer.resolveAlert(familyId, alerts.single.id);
  });

  testWidgets('a suspicious scan tells nobody', (tester) async {
    final token = safetyTokenFrom(qr.payload)!;
    final scan = await helper.resolve(token);
    expect(await helper.confirm(scan.scanId, situation: 'suspicious'), isNull);
    final open = await organizer.alerts(familyId);
    expect(open.where((a) => !a.isResolved), isEmpty);
  });

  testWidgets('replacing kills the old card', (tester) async {
    final old = safetyTokenFrom(qr.payload)!;
    final fresh = await organizer.regenerate(familyId, childId);
    expect(fresh.payload, isNot(qr.payload));
    await expectLater(
      helper.resolve(old),
      throwsA(
        isA<FamilyException>().having(
          (e) => e.kind,
          'kind',
          FamilyFailure.gone,
        ),
      ),
    );
    await organizer.revoke(familyId, childId);
    expect(await organizer.qr(familyId, childId), isNull);
  });
}
