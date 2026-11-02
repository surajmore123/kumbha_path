import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/operations/data/ops_repository.dart';
import 'package:kumbha_path/src/modules/operations/ops_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real sign-in, real tokens and a real local server: see "Testing" in
/// docs/volunteer_operations.md. Nothing here is forced past authentication.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const host = String.fromEnvironment('API_HOST');
  const volunteerPhone = String.fromEnvironment('VOLUNTEER_PHONE');
  const volunteerCode = String.fromEnvironment('VOLUNTEER_CODE');
  const coordinatorPhone = String.fromEnvironment('COORDINATOR_PHONE');
  const coordinatorCode = String.fromEnvironment('COORDINATOR_CODE');
  const pilgrimToken = String.fromEnvironment('PILGRIM_TOKEN');
  const caseId = String.fromEnvironment('CASE_ID');
  const password = 'Ramkund-Ghat-2027!';

  HttpOpsRepository client([String? token]) =>
      HttpOpsRepository(token: () async => token, requireHttps: false);

  late String volunteerToken;
  late String coordinatorToken;

  setUpAll(() {
    dotenv.loadFromString(envString: 'API_HOST=$host\nAPI_PROTOCOL=http');
  });

  test('a wrong code and a wrong password are refused', () async {
    await expectLater(
      client().completeSetup(volunteerPhone, 'WRONGCODE1', password),
      throwsA(isA<FamilyException>()),
    );
    await expectLater(
      client().signIn(volunteerPhone, 'not-the-password'),
      throwsA(isA<FamilyException>()),
    );
  });

  test('setup gives a real session, once', () async {
    volunteerToken = await client().completeSetup(
      volunteerPhone,
      volunteerCode,
      password,
    );
    coordinatorToken = await client().completeSetup(
      coordinatorPhone,
      coordinatorCode,
      password,
    );
    final me = await client(volunteerToken).me();
    expect(me.role, 'VOLUNTEER');
    expect(me.canAssign, isFalse);
    await expectLater(
      client().completeSetup(volunteerPhone, volunteerCode, password),
      throwsA(isA<FamilyException>()),
    );
    expect(await client().signIn(volunteerPhone, password), isNotEmpty);
  });

  test('a pilgrim gets nothing operational', () async {
    final pilgrim = client(pilgrimToken);
    expect((await pilgrim.me()).isPilgrim, isTrue);
    await expectLater(pilgrim.myCases(), throwsA(isA<FamilyException>()));
    await expectLater(
      pilgrim.caseDetail(caseId),
      throwsA(isA<FamilyException>()),
    );
  });

  test('a coordinator assigns, and the volunteer works the case', () async {
    final coordinator = client(coordinatorToken);
    final volunteer = client(volunteerToken);
    final team = await coordinator.team();
    final person = team.firstWhere((m) => m.role == 'VOLUNTEER');
    await coordinator.assign(caseId, person.userId);

    final mine = await volunteer.myCases();
    expect(mine.single.id, caseId);
    final detail = await volunteer.caseDetail(caseId);
    expect(detail.isHighPriority, isTrue);
    expect(detail.latitude, isNull, reason: 'a child\'s position is withheld');

    await volunteer.progress(caseId, 'ACCEPTED');
    await volunteer.addObservation(caseId, 'Live test observation');
    await volunteer.escalate(caseId, 'Live test escalation');
    final escalated = await coordinator.escalations();
    expect(escalated.single.id, caseId);
    expect(await coordinator.history(caseId), hasLength(1));
  });

  testWidgets('the dashboard, with real data', (tester) async {
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
                home: VolunteerHomeScreen(repository: client(coordinatorToken)),
              ),
        ),
      ),
    );
    final end = DateTime.now().add(const Duration(seconds: 25));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Safety Operations'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
