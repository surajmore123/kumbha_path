import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:kumbha_path/src/modules/family/offline/contact_sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'family_offline_fakes.dart';

const family = ContactScope('f1');
const person = ContactScope('f1', 'm3');
const offline = FamilyException(FamilyFailure.offline);

const newContact = {
  'name': 'Ramesh Secret',
  'relationship': 'Uncle',
  'mobile': '9812345678',
  'method': 'call',
};

late Directory dir;
late String path;
late FakeServer server;
late StreamController<bool> network;
late List<Duration> retries;
late List<void Function()> scheduled;
var _dbs = <Database>[];

/// The real SQL store on a real file. The app adds SQLCipher underneath; that
/// needs the device library, so `integration_test/` covers encryption.
Future<SqlContactStore> openStore() async {
  final store = SqlContactStore(() async {
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: SqlContactStore.schemaVersion,
        onCreate: SqlContactStore.createSchema,
      ),
    );
    _dbs.add(db);
    return db;
  });
  return store;
}

Future<void> closeAll() async {
  for (final db in _dbs) {
    await db.close();
  }
  _dbs = [];
}

Future<ContactSyncService> service({
  ContactStore? store,
  Future<String?> Function()? account,
}) async => ContactSyncService(
  remote: server,
  store: store ?? await openStore(),
  online: network.stream,
  account: account,
  schedule: (wait, run) {
    retries.add(wait);
    scheduled.add(run);
  },
);

/// Simulates quitting the app: everything in memory goes, only the file stays.
Future<ContactSyncService> restart() async {
  await closeAll();
  return service();
}

Future<List<String>> names(
  ContactSyncService sync, [
  ContactScope scope = family,
]) async {
  final view = await sync.local(scope);
  return [for (final r in view.contacts) r.contact.name];
}

Future<void> settle(ContactSyncService sync) async {
  await sync.sync();
  await sync.sync();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('contacts');
    path = '${dir.path}/test.db';
    server = FakeServer();
    network = StreamController<bool>.broadcast();
    retries = [];
    scheduled = [];
  });

  tearDown(() async {
    await closeAll();
    await network.close();
    await dir.delete(recursive: true);
  });

  group('Loading', () {
    test('1. contacts load without internet', () async {
      server.seed('a', 'Uncle');
      final sync = await service();
      await sync.refresh(family);
      server.down = offline;
      final view = await sync.refresh(family);
      expect(view.contacts.single.contact.name, 'Uncle');
      expect(sync.phase, SyncPhase.offline);
    });

    test('local reads never touch the network', () async {
      server.seed('a', 'Uncle');
      final sync = await service();
      await sync.refresh(family);
      final before = server.requests;
      await sync.local(family);
      expect(server.requests, before);
    });

    test('records when it last synced, and keeps it offline', () async {
      final sync = await service();
      await sync.refresh(family);
      final at = (await sync.local(family)).info?.lastSyncedAt;
      expect(at, isNotNull);
      server.down = offline;
      await sync.refresh(family);
      expect((await sync.local(family)).info?.lastSyncedAt, at);
    });

    test('the circle and lists can be reached with no connection', () async {
      final sync = await service();
      await sync.rememberCircles(const [
        FamilyCircle(
          id: 'f1',
          name: 'More',
          myRole: 'organizer',
          myMemberId: 'm1',
        ),
      ]);
      await sync.remember(person, label: 'Aarav', canEdit: true);
      final again = await restart();
      final circle = (await again.savedCircles()).single;
      expect((circle.name, circle.isOrganizer), ('More', true));
      final list = (await again.savedLists('f1')).single;
      expect((list.label, list.canEdit), ('Aarav', true));
    });
  });

  group('Offline changes', () {
    late ContactSyncService sync;

    setUp(() async {
      server
        ..seed('a', 'Uncle')
        ..seed('b', 'Aunt', priority: 2);
      sync = await service();
      await sync.refresh(family);
      server.down = offline;
    });

    Future<LocalContact> row(String id) async =>
        (await sync.local(family)).contacts.firstWhere((r) => r.id == id);

    test('2. adding offline saves here and queues it', () async {
      await sync.add(family, newContact);
      await sync.sync();
      expect(await names(sync), ['Uncle', 'Aunt', 'Ramesh Secret']);
      expect(sync.unsynced, 1);
      expect(server.creates, 0);
      final added = (await sync.local(family)).contacts.last;
      expect(added.state, ContactSyncState.pendingCreate);
      expect(added.contact.mobile, '+919812345678');
      expect(added.id, hasLength(36));
    });

    test('3. editing offline saves here and queues it', () async {
      await sync.edit(await row('a'), {'name': 'Uncle Ji'});
      await sync.sync();
      expect((await names(sync)).first, 'Uncle Ji');
      expect((await row('a')).state, ContactSyncState.pendingUpdate);
      expect(server.contactsById['a']!.name, 'Uncle');
    });

    test('4. deleting offline hides it and queues it', () async {
      await sync.delete(await row('a'));
      await sync.sync();
      expect(await names(sync), ['Aunt']);
      expect(sync.unsynced, 1);
      expect(server.contactsById, contains('a'));
    });

    test('a contact added and deleted offline leaves nothing behind', () async {
      await sync.add(family, newContact);
      await sync.sync();
      final added = (await sync.local(family)).contacts.last;
      await sync.delete(added);
      await sync.sync();
      server.down = null;
      await settle(sync);
      expect(server.contactsById, hasLength(2));
      expect(sync.unsynced, 0);
      expect(await names(sync), ['Uncle', 'Aunt']);
    });

    test('many edits become one request', () async {
      for (final name in ['One', 'Two', 'Three']) {
        await sync.edit(await row('a'), {'name': name});
      }
      await sync.sync();
      server.down = null;
      await settle(sync);
      expect(server.updates, 1);
      expect(server.contactsById['a']!.name, 'Three');
    });

    test('5. changes survive closing and reopening the app', () async {
      await sync.add(family, newContact);
      await sync.edit(await row('a'), {'name': 'Uncle Ji'});
      await sync.delete(await row('b'));
      await sync.sync();
      final reopened = await restart();
      expect(await names(reopened), ['Uncle Ji', 'Ramesh Secret']);
      expect(reopened.unsynced, 3);
      server.down = null;
      await settle(reopened);
      expect(reopened.unsynced, 0);
      expect(server.contactsById['a']!.name, 'Uncle Ji');
      expect(server.contactsById, isNot(contains('b')));
      expect(server.creates, 1);
    });

    test('reordering offline waits, then reaches the server', () async {
      await sync.reorder(family, ['b', 'a']);
      await sync.sync();
      expect(await names(sync), ['Aunt', 'Uncle']);
      expect(sync.unsynced, 1);
      final reopened = await restart();
      server.down = null;
      await settle(reopened);
      expect(server.order, ['b', 'a']);
      expect(reopened.unsynced, 0);
      expect(await names(reopened), ['Aunt', 'Uncle']);
    });

    test('a new contact can be reordered before it is on the server', () async {
      await sync.add(family, newContact);
      await sync.sync();
      final id = (await sync.local(family)).contacts.last.id;
      await sync.reorder(family, [id, 'a', 'b']);
      server.down = null;
      await settle(sync);
      expect(server.order, [id, 'a', 'b']);
      expect(await names(sync), ['Ramesh Secret', 'Uncle', 'Aunt']);
    });
  });

  group('Sync', () {
    test('6. runs by itself when the connection returns', () async {
      final sync = await service();
      sync.start();
      addTearDown(sync.dispose);
      await sync.sync();
      server.down = offline;
      await sync.add(family, newContact);
      await sync.sync();
      expect(server.creates, 0);
      server.down = null;
      network.add(true);
      await pumpEventQueue();
      await sync.sync();
      expect(server.creates, 1);
      expect(sync.unsynced, 0);
      expect(sync.phase, SyncPhase.idle);
    });

    test('losing the connection shows offline at once', () async {
      final sync = await service();
      sync.start();
      addTearDown(sync.dispose);
      await sync.sync();
      network.add(false);
      await pumpEventQueue();
      expect(sync.phase, SyncPhase.offline);
    });

    test('brings in what changed on the server', () async {
      server.seed('a', 'Uncle');
      final sync = await service();
      await sync.refresh(family);
      server
        ..changeElsewhere('a', 'Uncle Ji')
        ..seed('b', 'Aunt', priority: 2);
      await sync.refresh(family);
      expect(await names(sync), ['Uncle Ji', 'Aunt']);
      server.contactsById.remove('a');
      await sync.refresh(family);
      expect(await names(sync), ['Aunt']);
    });

    test('leaving a family removes everything saved for it', () async {
      server.seed('a', 'Uncle');
      final sync = await service();
      await sync.rememberCircles(const [FamilyCircle(id: 'f1', name: 'More')]);
      await sync.refresh(family);
      await sync.rememberCircles(const []);
      expect((await sync.local(family)).contacts, isEmpty);
      expect(await sync.savedCircles(), isEmpty);
    });

    test('losing access to a list removes its saved copy', () async {
      server.seed('a', 'Sister', member: 'm3');
      final sync = await service();
      await sync.refresh(person);
      expect(await names(sync, person), ['Sister']);
      final blocked = _Blocked(server);
      final after = ContactSyncService(
        remote: blocked,
        store: await openStore(),
        schedule: (_, __) {},
      );
      await after.sync();
      expect((await after.local(person)).contacts, isEmpty);
    });
  });

  group('Failure and retry', () {
    test('7. failed sync keeps the change and retries with backoff', () async {
      final sync = await service();
      await sync.sync();
      server.serverErrors = 2;
      await sync.add(family, newContact);
      await pumpEventQueue();
      await sync.sync();
      expect(sync.phase, SyncPhase.retrying);
      expect(sync.unsynced, 1);
      expect(retries, isNotEmpty);
      for (var i = 0; i < 4; i++) {
        await sync.sync();
      }
      expect(server.creates, 1);
      expect(sync.unsynced, 0);
      expect(sync.phase, SyncPhase.idle);
    });

    test('backoff grows and is capped', () {
      expect(ContactSyncService.backoff(1), const Duration(seconds: 5));
      expect(ContactSyncService.backoff(2), const Duration(seconds: 10));
      expect(ContactSyncService.backoff(3), const Duration(seconds: 20));
      expect(ContactSyncService.backoff(20), const Duration(minutes: 5));
    });

    test('a retry timer really sends the change', () async {
      final sync = await service();
      await sync.refresh(family);
      server.down = const FamilyException(FamilyFailure.server);
      await sync.add(family, newContact);
      await sync.sync();
      expect(scheduled, isNotEmpty);
      server.down = null;
      scheduled.last();
      await sync.sync();
      expect(sync.unsynced, 0);
      expect(server.creates, 1);
    });

    test('a refused change is parked, and the rest still go', () async {
      final sync = await service();
      await sync.sync();
      server.down = offline;
      await sync.add(family, newContact);
      await sync.add(family, {...newContact, 'name': 'Second'});
      await sync.sync();
      server.down = null;
      server.refuseWrites = const FamilyException(FamilyFailure.invalid);
      await sync.sync();
      final rows = (await sync.local(family)).contacts;
      expect(rows.every((r) => r.state == ContactSyncState.failed), isTrue);
      server.refuseWrites = null;
      await sync.edit(rows.first, {'name': 'Fixed'});
      await settle(sync);
      expect(server.contactsById.values.single.name, 'Fixed');
      await sync.discard((await sync.local(family)).contacts.last);
      await settle(sync);
      expect(sync.unsynced, 0);
      expect(await names(sync), ['Fixed']);
    });

    test('discarding a failed edit brings back the server copy', () async {
      server.seed('a', 'Uncle');
      final sync = await service();
      await sync.refresh(family);
      server.refuseWrites = const FamilyException(FamilyFailure.forbidden);
      final row = (await sync.local(family)).contacts.single;
      await sync.edit(row, {'name': 'Mine'});
      await settle(sync);
      final failed = (await sync.local(family)).contacts.single;
      expect(failed.state, ContactSyncState.failed);
      await sync.discard(failed);
      server.refuseWrites = null;
      await settle(sync);
      expect(await names(sync), ['Uncle']);
    });

    test('an expired session keeps changes and stops retrying', () async {
      final sync = await service();
      await sync.sync();
      server.down = const FamilyException(FamilyFailure.signedOut);
      await sync.add(family, newContact);
      retries.clear();
      await settle(sync);
      expect(sync.phase, SyncPhase.signedOut);
      expect(sync.unsynced, 1);
      expect(retries, isEmpty);
    });

    test('a storage fault is contained, not thrown', () async {
      final broken = ContactSyncService(
        remote: server,
        store: _BrokenStore(),
        schedule: (_, __) {},
      );
      await broken.sync();
      expect(broken.phase, SyncPhase.retrying);
      await broken.wipe();
    });
  });

  group('Duplicates', () {
    test('8. a retry after a lost response creates one contact', () async {
      final sync = await service();
      await sync.sync();
      server.loseResponses = 1;
      await sync.add(family, newContact);
      await settle(sync);
      await sync.sync();
      await sync.sync();
      expect(server.contactsById, hasLength(1));
      expect(server.creates, 1);
      expect(await names(sync), ['Ramesh Secret']);
      expect(sync.unsynced, 0);
    });

    test('repeated runs at once send each change only once', () async {
      final sync = await service();
      await sync.sync();
      server.down = offline;
      await sync.add(family, newContact);
      await sync.sync();
      server.down = null;
      await Future.wait([sync.sync(), sync.sync(), sync.sync()]);
      await sync.sync();
      expect(server.creates, 1);
    });

    test('a lost update response doesn\'t cause a false conflict', () async {
      server.seed('a', 'Uncle');
      final sync = await service();
      await sync.refresh(family);
      server.loseResponses = 1;
      final row = (await sync.local(family)).contacts.single;
      await sync.edit(row, {'name': 'Mine'});
      await settle(sync);
      final after = (await sync.local(family)).contacts.single;
      expect(after.state, ContactSyncState.synced);
      expect(after.contact.name, 'Mine');
      expect(server.contactsById['a']!.name, 'Mine');
      expect(sync.unsynced, 0);
    });

    test('a create whose outcome is unknown can still be deleted', () async {
      final sync = await service();
      await sync.sync();
      server.loseResponses = 1;
      await sync.add(family, newContact);
      await settle(sync);
      final rows = (await sync.local(family)).contacts;
      if (rows.isNotEmpty) {
        await sync.delete(rows.single);
        await settle(sync);
      }
      expect(server.contactsById, isEmpty);
      expect(await names(sync), isEmpty);
    });

    test('a contact saved here isn\'t duplicated by the next pull', () async {
      final sync = await service();
      await sync.add(family, newContact);
      await settle(sync);
      await sync.refresh(family);
      expect(await names(sync), ['Ramesh Secret']);
    });
  });

  group('Conflicts', () {
    late ContactSyncService sync;

    setUp(() async {
      server.seed('a', 'Uncle');
      sync = await service();
      await sync.refresh(family);
      server.down = offline;
    });

    Future<LocalContact> row() async =>
        (await sync.local(family)).contacts.single;

    Future<LocalContact> conflict(
      Future<void> Function() local,
      void Function() remote,
    ) async {
      await local();
      await sync.sync();
      remote();
      server.down = null;
      await settle(sync);
      return (await sync.local(family)).contacts.single;
    }

    test('9. stale edits never overwrite newer server data', () async {
      final seen = await conflict(
        () async => sync.edit(await row(), {'name': 'Mine'}),
        () => server.changeElsewhere('a', 'Theirs'),
      );
      expect(server.contactsById['a']!.name, 'Theirs');
      expect(seen.state, ContactSyncState.conflict);
      expect(seen.contact.name, 'Mine');
      expect(seen.serverCopy?.name, 'Theirs');
      expect(sync.unsynced, 1);
    });

    test('a pull leaves a queued change alone', () async {
      await sync.edit(await row(), {'name': 'Mine'});
      await sync.sync();
      server.changeElsewhere('a', 'Theirs');
      server.down = null;
      server.refuseWrites = const FamilyException(FamilyFailure.server);
      await sync.sync();
      expect((await row()).contact.name, 'Mine');
    });

    test('keep mine replaces the server copy on purpose', () async {
      final seen = await conflict(
        () async => sync.edit(await row(), {'name': 'Mine'}),
        () => server.changeElsewhere('a', 'Theirs'),
      );
      await sync.keepMine(seen);
      await settle(sync);
      expect(server.contactsById['a']!.name, 'Mine');
      expect(sync.unsynced, 0);
    });

    test('use theirs takes the server copy', () async {
      final seen = await conflict(
        () async => sync.edit(await row(), {'name': 'Mine'}),
        () => server.changeElsewhere('a', 'Theirs'),
      );
      await sync.useTheirs(seen);
      await settle(sync);
      expect(await names(sync), ['Theirs']);
      expect(server.contactsById['a']!.name, 'Theirs');
      expect(sync.unsynced, 0);
    });

    test('a conflict survives a restart', () async {
      await conflict(
        () async => sync.edit(await row(), {'name': 'Mine'}),
        () => server.changeElsewhere('a', 'Theirs'),
      );
      final reopened = await restart();
      final seen = (await reopened.local(family)).contacts.single;
      expect(seen.state, ContactSyncState.conflict);
      expect(seen.serverCopy?.name, 'Theirs');
    });

    test('edited here, deleted there: asks, then can bring it back', () async {
      final seen = await conflict(
        () async => sync.edit(await row(), {'name': 'Mine'}),
        () => server.contactsById.remove('a'),
      );
      expect(seen.goneFromServer, isTrue);
      expect(seen.state, ContactSyncState.conflict);
      await sync.keepMine(seen);
      await settle(sync);
      expect(server.contactsById['a']!.name, 'Mine');
      expect(sync.unsynced, 0);
    });

    test('edited here, deleted there: can accept the deletion', () async {
      final seen = await conflict(
        () async => sync.edit(await row(), {'name': 'Mine'}),
        () => server.contactsById.remove('a'),
      );
      await sync.useTheirs(seen);
      await settle(sync);
      expect(await names(sync), isEmpty);
    });

    test('deleted here, edited there: asks first', () async {
      await sync.delete(await row());
      await sync.sync();
      server.changeElsewhere('a', 'Theirs');
      server.down = null;
      await settle(sync);
      expect(server.contactsById, contains('a'));
      final seen = (await sync.local(family)).contacts.single;
      expect((seen.state, seen.wantsDelete), (ContactSyncState.conflict, true));
      await sync.keepMine(seen);
      await settle(sync);
      expect(server.contactsById, isEmpty);
    });

    test('deleted on both sides simply finishes', () async {
      await sync.delete(await row());
      await sync.sync();
      server.contactsById.remove('a');
      server.down = null;
      await settle(sync);
      expect(sync.unsynced, 0);
      expect(await names(sync), isEmpty);
    });

    test('a contact added elsewhere doesn\'t lose a local reorder', () async {
      server.down = null;
      server.seed('b', 'Aunt', priority: 2);
      await sync.refresh(family);
      server.down = offline;
      await sync.reorder(family, ['b', 'a']);
      await sync.sync();
      server.down = null;
      server.seed('c', 'Cousin', priority: 3);
      await settle(sync);
      expect(server.order, ['b', 'a', 'c']);
      expect(await names(sync), ['Aunt', 'Uncle', 'Cousin']);
    });
  });

  group('Accounts', () {
    test('signing out removes everything, including the queue', () async {
      final sync = await service();
      server.down = offline;
      await sync.add(family, newContact);
      await sync.sync();
      await sync.wipe();
      expect(sync.unsynced, 0);
      expect((await sync.local(family)).contacts, isEmpty);
      expect(await sync.savedCircles(), isEmpty);
    });

    test('another account on this phone sees nothing', () async {
      var user = 'user-a';
      final store = await openStore();
      final sync = await service(store: store, account: () async => user);
      server.down = offline;
      await sync.add(family, newContact);
      await sync.sync();
      expect(await names(sync), ['Ramesh Secret']);
      user = 'user-b';
      expect(await names(sync), isEmpty);
      server.down = null;
      await sync.sync();
      expect(server.creates, 0, reason: 'never sent as the wrong account');
    });

    test('the same account keeps its data with no token offline', () async {
      String? user = 'user-a';
      final store = await openStore();
      final sync = await service(store: store, account: () async => user);
      server.down = offline;
      await sync.add(family, newContact);
      user = null;
      expect(await names(sync), ['Ramesh Secret']);
      await sync.sync();
    });

    test('reads the account from the token without verifying it', () {
      String part(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final token = '${part({'alg': 'x'})}.${part({'user_id': 'u1'})}.sig';
      expect(accountFromToken(token), 'u1');
      expect(accountFromToken('rubbish'), isNull);
      expect(accountFromToken(null), isNull);
    });
  });

  group('10. No data leaks into logs', () {
    const name = 'Ramesh Secret';
    const number = '9812345678';

    test('text forms of these objects carry no details', () {
      const contact = EmergencyContact(
        id: 'a',
        name: name,
        mobile: '+91$number',
      );
      const local = LocalContact(contact: contact, scope: family);
      final failure = FamilyException(
        FamilyFailure.stale,
        fieldErrors: const {'mobile': number},
        serverContact: contact,
      );
      for (final text in ['$contact', '$local', '$failure']) {
        expect(text, isNot(contains(name)));
        expect(text, isNot(contains(number)));
      }
    });

    test('nothing is printed through a full sync, failing or not', () async {
      final printed = <String>[];
      await runZoned(
        () async {
          final previous = debugPrint;
          debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
          addTearDown(() => debugPrint = previous);
          final sync = await service();
          server.down = offline;
          await sync.add(family, newContact);
          await sync.sync();
          server.down = null;
          server.refuseWrites = const FamilyException(FamilyFailure.invalid);
          await sync.sync();
          server.refuseWrites = null;
          server.serverErrors = 1;
          await sync.sync();
          await settle(sync);
        },
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, line) => printed.add(line),
        ),
      );
      expect(printed, isEmpty);
    });

    test('the offline code has no logging calls at all', () {
      final files = Directory('lib/src/modules/family')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      final logging = RegExp(r'\b(print|debugPrint|log)\(|developer\.log');
      for (final file in files) {
        expect(
          logging.hasMatch(file.readAsStringSync()),
          isFalse,
          reason: file.path,
        );
      }
    });

    test('personal details never go in shared preferences', () {
      final files = Directory('lib/src/modules/family')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in files) {
        expect(
          file.readAsStringSync(),
          isNot(contains('SharedPreferences')),
          reason: file.path,
        );
      }
    });
  });
}

/// The person stopped sharing this list.
class _Blocked extends FakeServer {
  _Blocked(this.inner);

  final FakeServer inner;

  @override
  Future<List<EmergencyContact>> contacts(
    String familyId, {
    String? memberId,
  }) async => throw const FamilyException(FamilyFailure.forbidden);
}

class _BrokenStore extends MemoryContactStore {
  @override
  Future<String?> account() async => throw StateError('broken');

  @override
  Future<void> clear() async => throw StateError('broken');
}
