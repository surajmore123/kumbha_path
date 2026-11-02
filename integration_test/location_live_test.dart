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
import 'package:kumbha_path/src/modules/location/family_map_screen.dart';
import 'package:kumbha_path/src/modules/location/models/location_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real tracker and GPS against a real local backend. The phone's position
/// comes from the emulator, and a driver on the host sends the app to the
/// background part way through: see "Testing" in docs/family_location.md.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const host = String.fromEnvironment('API_HOST');
  const familyId = String.fromEnvironment('FAMILY_ID');
  const ashaToken = String.fromEnvironment('ASHA_TOKEN');
  const sureshToken = String.fromEnvironment('SURESH_TOKEN');
  const raviToken = String.fromEnvironment('RAVI_TOKEN');
  const meeraToken = String.fromEnvironment('MEERA_TOKEN');

  HttpLocationRepository as_(String token) =>
      HttpLocationRepository(token: () async => token, requireHttps: false);

  final asha = as_(ashaToken);
  final suresh = as_(sureshToken);
  final ravi = as_(raviToken);

  setUpAll(() {
    dotenv.loadFromString(envString: 'API_HOST=$host\nAPI_PROTOCOL=http');
  });

  Future<String> memberNamed(String name) async {
    final viewers = await asha.eligible(familyId);
    return viewers.people.firstWhere((p) => p.name == name).memberId;
  }

  Future<LocationPerson?> ashaOn(HttpLocationRepository viewer) async {
    final feed = await viewer.feed(familyId);
    return feed.people.where((p) => p.name == 'Asha More').firstOrNull;
  }

  Future<LocationPerson> waitFor(
    bool Function(LocationPerson person) ready,
    String what, {
    String Function()? status,
  }) async {
    final end = DateTime.now().add(const Duration(seconds: 150));
    while (DateTime.now().isBefore(end)) {
      final person = await ashaOn(suresh);
      if (person != null && ready(person)) return person;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    fail('Timed out waiting for $what (${status?.call() ?? ''})');
  }

  test(
    'real GPS reaches the chosen viewer, in the background too',
    () async {
      final tracker = LocationTracker(
        repository: asha,
        notificationTitle: 'Sharing your location',
        notificationText: 'Open Kumbh Path to stop.',
      );
      final permit = await tracker.requestAccess();
      expect(permit, LocationPermit.allowed);

      final session = await asha.start(
        familyId,
        consent: true,
        recipientIds: [await memberNamed('Suresh More')],
        minutes: 30,
      );
      await tracker.begin(session);
      expect(tracker.state, TrackerState.sharing);
      expect(tracker.collecting, isTrue);

      String state() =>
          '${tracker.state} collecting=${tracker.collecting} '
          'unsent=${tracker.hasUnsent} offline=${tracker.offline} '
          'sent=${tracker.lastSentAt}';

      final first = await waitFor(
        (p) => p.hasPosition,
        'the first position',
        status: state,
      );
      expect(first.freshnessAt(DateTime.now()), Freshness.live);
      expect(first.accuracyM, isNotNull);

      // Nobody else was chosen, and being in the family isn't enough.
      expect(await ashaOn(ravi), isNull);

      // The host presses Home once the first position has arrived, and the
      // emulator keeps moving. A later position proves the app kept collecting.
      final moved = await waitFor(
        (p) =>
            p.hasPosition &&
            p.capturedAt!.isAfter(first.capturedAt!) &&
            p.latitude != first.latitude,
        'a position taken in the background',
        status: state,
      );
      expect(moved.freshnessAt(DateTime.now()), isNot(Freshness.lastKnown));

      // Time for the host to read Android's own record of the running service.
      await Future<void>.delayed(const Duration(seconds: 40));

      // Pausing stops the GPS and hides the position straight away.
      await tracker.sync(await asha.pause(session.id));
      expect(tracker.collecting, isFalse);
      final paused = await ashaOn(suresh);
      expect(paused!.state, 'paused');
      expect(paused.hasPosition, isFalse);
      await expectLater(
        asha.sendUpdate(session.id, _fix()),
        throwsA(isA<SharingClosed>()),
      );

      await tracker.sync(await asha.resume(session.id));
      expect(tracker.collecting, isTrue);

      // Stopping ends collection, removes the position and refuses late data.
      expect(await tracker.stop(session.id), isTrue);
      expect(tracker.collecting, isFalse);
      expect(tracker.state, TrackerState.idle);
      expect(await ashaOn(suresh), isNull);
      await expectLater(
        asha.sendUpdate(session.id, _fix()),
        throwsA(isA<SharingClosed>()),
      );
      tracker.dispose();
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );

  test('an organizer can\'t start an adult\'s sharing', () async {
    final family = await suresh.eligible(familyId);
    final ashaMember =
        family.people.firstWhere((p) => p.name == 'Asha More').memberId;
    await expectLater(
      suresh.start(
        familyId,
        consent: true,
        recipientIds: [await memberNamed('Suresh More')],
        memberId: ashaMember,
        minutes: 30,
      ),
      throwsA(
        isA<FamilyException>().having(
          (e) => e.kind,
          'kind',
          FamilyFailure.forbidden,
        ),
      ),
    );
  });

  testWidgets('the map shows a shared position', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final session = await asha.start(
      familyId,
      consent: true,
      recipientIds: [await memberNamed('Meera More')],
      minutes: 30,
    );
    await asha.sendUpdate(
      session.id,
      LocationFix(
        latitude: 19.9975,
        longitude: 73.7898,
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
                home: FamilyMapScreen(
                  args: const FamilyArgs(
                    FamilyCircle(id: familyId, name: 'More Family'),
                  ),
                  repository: as_(meeraToken),
                  familyRepository: _NoFamily(),
                  tracker: LocationTracker(repository: as_(meeraToken)),
                ),
              ),
        ),
      ),
    );
    final end = DateTime.now().add(const Duration(seconds: 45));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Live'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await asha.stop(session.id);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

LocationFix _fix() => LocationFix(
  latitude: 19.9975,
  longitude: 73.7898,
  capturedAt: DateTime.now(),
);

class _NoFamily implements FamilyRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
