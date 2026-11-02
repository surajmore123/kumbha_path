import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kumbha_path/src/modules/family/offline/encrypted_database.dart';
import 'package:kumbha_path/src/modules/lostfound/data/lf_drafts.dart';
import 'package:kumbha_path/src/modules/lostfound/data/lf_repository.dart';

/// The real client against a real local backend, and the real encrypted draft
/// store. Needs test accounts: see "Testing" in docs/lost_found.md.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const host = String.fromEnvironment('API_HOST');
  const parentToken = String.fromEnvironment('PARENT_TOKEN');
  const helperToken = String.fromEnvironment('HELPER_TOKEN');
  const staffToken = String.fromEnvironment('STAFF_TOKEN');

  // A tiny real JPEG, which the server re-encodes.
  final photo = Uint8List.fromList([
    255,
    216,
    255,
    224,
    0,
    16,
    74,
    70,
    73,
    70,
    0,
    1,
    1,
    0,
    0,
    1,
    0,
    1,
    0,
    0,
    255,
    219,
    0,
    67,
    0,
    8,
    6,
    6,
    7,
    6,
    5,
    8,
    7,
    7,
    7,
    9,
    9,
    8,
    10,
    12,
    20,
    13,
    12,
    11,
    11,
    12,
    25,
    18,
    19,
    15,
    20,
    29,
    26,
    31,
    30,
    29,
    26,
    28,
    28,
    32,
    36,
    46,
    39,
    32,
    34,
    44,
    35,
    28,
    28,
    40,
    55,
    41,
    44,
    48,
    49,
    52,
    52,
    52,
    31,
    39,
    57,
    61,
    56,
    50,
    60,
    46,
    51,
    52,
    50,
    255,
    192,
    0,
    11,
    8,
    0,
    1,
    0,
    1,
    1,
    1,
    17,
    0,
    255,
    196,
    0,
    20,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    9,
    255,
    196,
    0,
    20,
    16,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    255,
    218,
    0,
    8,
    1,
    1,
    0,
    0,
    63,
    0,
    84,
    159,
    255,
    217,
  ]);

  late LostFoundRepository parent;
  late LostFoundRepository helper;
  late LostFoundRepository staff;

  LostFoundRepository as(String token) =>
      HttpLostFoundRepository(token: () async => token, requireHttps: false);

  setUpAll(() {
    dotenv.loadFromString(envString: 'API_PROTOCOL=http\nAPI_HOST=$host');
    parent = as(parentToken);
    helper = as(helperToken);
    staff = as(staffToken);
  });

  Map<String, dynamic> report(String clientId) => {
    'client_id': clientId,
    'relationship': 'Son',
    'age_min': 8,
    'age_max': 10,
    'clothing_description': 'Blue kurta and white cap',
    'physical_description': 'Thin with glasses',
    'location_text': 'Ramkund',
    'event_at': DateTime.now().toUtc().toIso8601String(),
    'latitude': 19.9975,
    'longitude': 73.7898,
    'vulnerabilities': ['child'],
  };

  test('a draft goes through the encrypted store to the server', () async {
    final store = SqlDraftStore(openEncryptedDatabase);
    await store.clear();
    final sender = ReportSender(remote: parent, store: store);
    final draft = await sender.newDraft('lost');
    final filled = draft.copyWith(fields: report(draft.id), photo: photo);
    await sender.save(filled);
    expect((await store.one(draft.id))?.photo, photo);

    final result = await sender.submit(filled);
    expect(result.reference, startsWith('LF-'));
    expect(await store.all(), isEmpty);

    final repeat = await parent.reportLost(report(draft.id));
    expect(repeat.duplicate, isTrue);
    expect(repeat.reference, result.reference);
  });

  test('the family view holds no internals', () async {
    final mine = await parent.myCases();
    final detail = await parent.caseDetail(mine.first.id);
    expect(detail.familyView, isTrue);
    expect(detail.attachmentIds, hasLength(1));
    final image = await parent.attachment(detail.attachmentIds.single);
    expect(image?.sublist(0, 2), [255, 216]);
  });

  test('only helpers file found reports, and only staff operate', () async {
    await expectLater(
      parent.reportFound({}),
      throwsA(
        isA<FamilyException>().having(
          (e) => e.kind,
          'kind',
          FamilyFailure.forbidden,
        ),
      ),
    );
    await expectLater(parent.opsCases(), throwsA(isA<FamilyException>()));
    await expectLater(helper.opsCases(), throwsA(isA<FamilyException>()));
    expect((await parent.capabilities()).canOperate, isFalse);
    expect((await staff.capabilities()).isStaff, isTrue);
  });

  test('match, human check, and reunion', () async {
    final found = await helper.reportFound({
      'client_id': '11111111-2222-4333-8444-555555555555',
      'found_category': 'child_alone',
      'age_min': 7,
      'age_max': 11,
      'clothing_description': 'निळा कुर्ता and white cap',
      'physical_description': 'Thin boy with glasses',
      'location_text': 'Panchavati gate',
      'safe_facility': 'Help desk 3',
      'event_at': DateTime.now().toUtc().toIso8601String(),
      'latitude': 20.006,
      'longitude': 73.791,
    });
    final lost = (await parent.myCases()).first;
    final opened = await staff.opsCase(lost.id);
    expect(opened.matches, isNotEmpty);
    final match = opened.matches.first;
    expect(match.reasons, isNotEmpty);
    expect(match.state, 'suggested');

    await staff.approveMatch(match.id, notifyFamily: true);
    expect((await parent.caseDetail(lost.id)).status, 'POTENTIAL_MATCH_FOUND');

    await expectLater(
      staff.reunite(
        lost.id,
        method: 'id_document',
        remarks: 'Trying before any confirmation',
        identityChecked: true,
        personRecognised: true,
      ),
      throwsA(isA<FamilyException>()),
    );
    await staff.confirmMatch(
      match.id,
      'family_in_person',
      'Father identified him at desk 3',
    );
    final done = await staff.reunite(
      lost.id,
      method: 'id_document',
      remarks: 'Checked ID and the boy knew him',
      identityChecked: true,
      personRecognised: true,
    );
    expect(done.detail.status, 'REUNITED');
    expect((await parent.caseDetail(lost.id)).status, 'REUNITED');
    expect((await staff.opsCase(found.id)).detail.status, 'REUNITED');
  });
}
