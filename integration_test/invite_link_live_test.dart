import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/invite_links.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart';

/// The real API client against a real local backend. Needs two test accounts:
/// see "Testing" in docs/family_invite_links.md.
///
///     flutter test integration_test/invite_link_live_test.dart -d <device>
///       --dart-define=API_HOST=10.0.2.2:8000
///       --dart-define=ORGANIZER_TOKEN=... --dart-define=GUEST_TOKEN=...
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const host = String.fromEnvironment('API_HOST');
  const organizerToken = String.fromEnvironment('ORGANIZER_TOKEN');
  const guestToken = String.fromEnvironment('GUEST_TOKEN');

  late FamilyRepository organizer;
  late FamilyRepository guest;
  late String familyId;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'API_PROTOCOL=http\nAPI_HOST=$host');
    organizer = HttpFamilyRepository(token: () async => organizerToken);
    guest = HttpFamilyRepository(token: () async => guestToken);
    familyId = (await organizer.createCircle({'name': 'Link Test Family'})).id;
  });

  Future<(FamilyInvite, String)> invite() async {
    final made = await organizer.createInvitation(
      familyId,
      relationship: 'sibling',
    );
    final link = parseInviteLink(Uri.parse(made.link!));
    return (made, link!.token!);
  }

  Matcher closedAs(String state) => throwsA(
    isA<FamilyException>()
        .having((e) => e.kind, 'kind', FamilyFailure.gone)
        .having((e) => e.invitationState, 'state', state),
  );

  testWidgets('the server\'s link is one the app accepts', (tester) async {
    final (made, token) = await invite();
    expect(made.link, startsWith('https://kumbhapath.in/join/family#t='));
    expect(token.length, greaterThanOrEqualTo(43));
  });

  testWidgets('a declined link stays closed', (tester) async {
    final (_, token) = await invite();
    final preview = await guest.lookupInvitationLink(token);
    expect(preview.familyName, 'Link Test Family');
    expect(preview.alreadyMember, isFalse);
    await guest.declineInvitation(token: token);
    await expectLater(guest.lookupInvitationLink(token), closedAs('declined'));
  });

  testWidgets('a revoked link stops working', (tester) async {
    final (made, token) = await invite();
    await organizer.revokeInvitation(familyId, made.id);
    await expectLater(
      guest.acceptInvitation(token: token),
      closedAs('revoked'),
    );
  });

  testWidgets('an unknown token reveals nothing', (tester) async {
    await expectLater(
      guest.lookupInvitationLink('a' * 43),
      throwsA(
        isA<FamilyException>().having(
          (e) => e.kind,
          'kind',
          FamilyFailure.notFound,
        ),
      ),
    );
  });

  testWidgets('accepting joins once, and only once', (tester) async {
    final (_, token) = await invite();
    final joined = await guest.acceptInvitation(token: token);
    expect(joined, familyId);
    final members = await guest.members(familyId);
    expect(members.length, 2);
    await expectLater(
      guest.acceptInvitation(token: token),
      closedAs('accepted'),
    );
  });

  testWidgets('offline sync behaves the same over real HTTP', (tester) async {
    const id = '3f2b8c1e-7a44-4d19-9f0e-6c1d2a7b4e55';
    final data = {'id': id, 'name': 'Uncle', 'mobile': '9812345678'};
    final first = await organizer.addContact(familyId, data);
    final repeat = await organizer.addContact(familyId, data);
    expect(repeat.id, first.id);
    expect((await organizer.contacts(familyId)).length, 1);

    final changed = await organizer.updateContact(familyId, id, {
      'name': 'Newer',
    }, ifMatch: first.updatedAt);
    await expectLater(
      organizer.updateContact(familyId, id, {
        'name': 'Stale',
      }, ifMatch: first.updatedAt),
      throwsA(
        isA<FamilyException>()
            .having((e) => e.kind, 'kind', FamilyFailure.stale)
            .having((e) => e.serverContact?.name, 'server', 'Newer'),
      ),
    );
    await organizer.deleteContact(familyId, id, ifMatch: changed.updatedAt);
    expect(await organizer.contacts(familyId), isEmpty);
  });

  tearDownAll(() async {
    await guest.leaveCircle(familyId);
    await organizer.deleteCircle(familyId);
  });
}
