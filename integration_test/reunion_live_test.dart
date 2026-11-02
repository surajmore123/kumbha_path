import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/family_home_screen.dart'
    show FamilyArgs;
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:kumbha_path/src/modules/location/data/location_repository.dart';
import 'package:kumbha_path/src/modules/location/data/location_tracker.dart';
import 'package:kumbha_path/src/modules/location/models/location_models.dart';
import 'package:kumbha_path/src/modules/reunion/data/reunion_repository.dart';
import 'package:kumbha_path/src/modules/reunion/models/reunion_models.dart';
import 'package:kumbha_path/src/modules/reunion/reunion_map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real clients and map against a local backend holding test records. See
/// "Testing" in docs/family_reunification.md. With no routing key on the
/// server, a route must fail honestly rather than invent anything.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const host = String.fromEnvironment('API_HOST');
  const familyId = String.fromEnvironment('FAMILY_ID');
  const caseId = String.fromEnvironment('CASE_ID');
  const ashaToken = String.fromEnvironment('ASHA_TOKEN');
  const sureshToken = String.fromEnvironment('SURESH_TOKEN');
  const raviToken = String.fromEnvironment('RAVI_TOKEN');

  HttpReunionRepository reunion(String token) =>
      HttpReunionRepository(token: () async => token, requireHttps: false);
  HttpLocationRepository location(String token) =>
      HttpLocationRepository(token: () async => token, requireHttps: false);

  setUpAll(() {
    dotenv.loadFromString(envString: 'API_HOST=$host\nAPI_PROTOCOL=http');
  });

  test('points tell verified from community', () async {
    final points = await reunion(sureshToken).points();
    expect(points.where((p) => p.isVerified), isNotEmpty);
    expect(points.where((p) => !p.isVerified), isNotEmpty);
  });

  test('a child\'s case can\'t use an unverified spot', () async {
    final repo = reunion(sureshToken);
    final points = await repo.points();
    final community = points.firstWhere((p) => !p.isVerified);
    await expectLater(
      repo.choosePoint(caseId, community.id),
      throwsA(isA<UseSafePoint>()),
    );
    final safe = await repo.guidance(caseId);
    expect(safe.every((p) => p.isVerified), isTrue);
    await repo.choosePoint(caseId, safe.first.id);
    final view = await repo.caseView(caseId);
    expect(view.plan.stage, 'point_chosen');
    expect(view.isProtected, isTrue);
    expect(view.detail.status, 'SUBMITTED');
  });

  test('someone unrelated can\'t reach the case', () async {
    await expectLater(
      reunion(raviToken).caseView(caseId),
      throwsA(isA<FamilyException>()),
    );
  });

  test('with no routing provider, a route fails honestly', () async {
    final points = await reunion(sureshToken).points();
    final point = points.first;
    await expectLater(
      reunion(sureshToken).route(
        RouteTarget(
          kind: 'point',
          id: point.id,
          name: point.name,
          latitude: point.latitude,
          longitude: point.longitude,
        ),
        (19.99, 73.78),
      ),
      throwsA(isA<RouteUnavailable>()),
    );
  });

  testWidgets(
    'the map shows every kind of marker',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
      final asha = location(ashaToken);
      final viewers = await asha.eligible(familyId);
      final session = await asha.start(
        familyId,
        consent: true,
        recipientIds: [
          viewers.people.firstWhere((p) => p.name == 'Suresh More').memberId,
        ],
        minutes: 30,
      );
      await asha.sendUpdate(
        session.id,
        LocationFix(
          latitude: 19.9985,
          longitude: 73.7925,
          capturedAt: DateTime.now(),
          accuracyM: 12,
        ),
      );
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
                  home: ReunionMapScreen(
                    args: const FamilyArgs(
                      FamilyCircle(id: familyId, name: 'More Family'),
                    ),
                    repository: reunion(sureshToken),
                    locations: location(sureshToken),
                    familyRepository: _NoFamily(),
                    tracker: LocationTracker(repository: location(sureshToken)),
                  ),
                ),
          ),
        ),
      );
      final end = DateTime.now().add(const Duration(seconds: 50));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.text('Someone here needs staff to help'), findsOneWidget);
      expect(find.text('Asha'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await asha.stop(session.id);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _NoFamily implements FamilyRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
