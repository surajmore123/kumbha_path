import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/emergency/data/emergency_repository.dart';
import 'package:kumbha_path/src/modules/emergency/models/emergency_models.dart';
import 'package:kumbha_path/src/modules/emergency/sos_screen.dart';
import 'package:kumbha_path/src/modules/family/offline/contact_sync.dart'
    show newContactId;
import 'package:kumbha_path/src/modules/notification_centre/notification_centre_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real clients against a local backend with test accounts: see "Testing"
/// in docs/emergency_sos.md. Firebase isn't configured there, so nothing is
/// pushed, and an SOS must stay at SUBMITTED rather than claim otherwise.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const host = String.fromEnvironment('API_HOST');
  const ashaToken = String.fromEnvironment('ASHA_TOKEN');
  const sureshToken = String.fromEnvironment('SURESH_TOKEN');
  const raviToken = String.fromEnvironment('RAVI_TOKEN');

  HttpEmergencyRepository repo(String token) =>
      HttpEmergencyRepository(token: () async => token, requireHttps: false);
  HttpNotificationRepository notes(String token) =>
      HttpNotificationRepository(token: () async => token, requireHttps: false);

  final asha = repo(ashaToken);
  final suresh = repo(sureshToken);

  setUpAll(() {
    dotenv.loadFromString(envString: 'API_HOST=$host\nAPI_PROTOCOL=http');
  });

  SosDraft draft() => SosDraft(
    clientId: newContactId(),
    category: 'medical',
    writtenAt: DateTime.now(),
    locationText: 'Near gate 3',
    latitude: 19.9975,
    longitude: 73.7898,
    accuracyM: 12,
    locationAt: DateTime.now(),
  );

  test('the full path, with every stage kept apart', () async {
    final request = draft();
    final sos = await asha.create(request);
    expect(sos.reference, startsWith('SOS-'));
    expect(sos.status, 'SUBMITTED', reason: 'no provider accepted anything');

    final again = await asha.create(request);
    expect(again.id, sos.id, reason: 'a retry is the same SOS');

    await expectLater(asha.create(draft()), throwsA(isA<SosAlreadyActive>()));

    final seen = await suresh.detail(sos.id);
    expect(seen.role, 'family');
    expect(seen.latitude, 19.9975);

    final acknowledged = await suresh.acknowledgeAsFamily(sos.id);
    expect(acknowledged.iAcknowledged, isTrue);
    expect(acknowledged.status, 'SUBMITTED');
    expect(acknowledged.responderAcknowledgedAt, isNull);

    final inbox = await notes(sureshToken).list(category: 'emergency');
    expect(inbox.notes.first.title, contains('Asha More'));
    await notes(sureshToken).markRead(inbox.notes.first.id);

    final owner = await asha.detail(sos.id);
    expect(owner.family.single.acknowledgedAt, isNotNull);
    expect(owner.family.single.reachedAppAt, isNotNull);

    final updated = await asha.addInfo(sos.id, 'Near the red tent');
    expect(updated.updates, hasLength(1));

    await expectLater(
      repo(raviToken).detail(sos.id),
      throwsA(isA<FamilyException>()),
    );

    final cancelled = await asha.cancel(sos.id, 'Live test finished');
    expect(cancelled.status, 'CANCELLED');
    final after = await suresh.detail(sos.id);
    expect(after.latitude, isNull, reason: 'family lose it when it ends');
  });

  testWidgets('the SOS screen with real data', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        saveLocale: false,
        child: Builder(
          builder:
              (context) => MaterialApp(
                theme: AppTheme.light,
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                home: SosScreen(
                  repository: asha,
                  contacts: () async => const [],
                ),
              ),
        ),
      ),
    );
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Press and hold'), findsOneWidget);
    expect(find.textContaining('does not call the police'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
