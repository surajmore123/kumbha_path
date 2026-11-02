import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:kumbha_path/src/modules/family/offline/contact_store.dart';
import 'package:kumbha_path/src/modules/family/offline/encrypted_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;

/// Runs on a device: encryption needs the native SQLCipher library.
///
///     flutter test integration_test/contact_encryption_test.dart -d <device>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scope = ContactScope('f1');
  const secretName = 'Ramesh Findable Secret';
  const secretNumber = '+919812345678';
  const local = LocalContact(
    scope: scope,
    state: ContactSyncState.pendingCreate,
    contact: EmergencyContact(id: 'c1', name: secretName, mobile: secretNumber),
  );

  late String path;

  setUp(() async {
    path = p.join(await cipher.getDatabasesPath(), 'family_contacts.db');
    await cipher.deleteDatabase(path);
  });

  testWidgets('contacts are encrypted on disk and survive reopening', (
    tester,
  ) async {
    final first = await openEncryptedDatabase();
    await SqlContactStore(() async => first).save(local);
    await first.close();

    // The whole file: no SQLite header, and no readable details anywhere.
    final bytes = await File(path).readAsBytes();
    final text = latin1.decode(bytes);
    expect(bytes.length, greaterThan(0));
    expect(text.startsWith('SQLite format 3'), isFalse);
    expect(text.contains('Findable'), isFalse);
    expect(text.contains('9812345678'), isFalse);
    expect(text.contains('CREATE TABLE'), isFalse);

    final second = await openEncryptedDatabase();
    final store = SqlContactStore(() async => second);
    final saved = await store.contact('c1');
    expect(saved?.contact.name, secretName);
    expect(saved?.state, ContactSyncState.pendingCreate);
    await second.close();
  });

  testWidgets('the file can\'t be opened with any other key', (tester) async {
    final db = await openEncryptedDatabase();
    await SqlContactStore(() async => db).save(local);
    await db.close();

    Object? failure;
    try {
      final wrong = await cipher.openDatabase(path, password: 'not-the-key');
      await wrong.rawQuery('SELECT * FROM contacts');
      await wrong.close();
    } catch (e) {
      failure = e;
    }
    expect(failure, isNotNull);
  });

  testWidgets('losing the key replaces the file and keeps working', (
    tester,
  ) async {
    final db = await openEncryptedDatabase();
    await SqlContactStore(() async => db).save(local);
    await db.close();

    await storage.delete(key: 'family_contacts_db_key');
    final fresh = await openEncryptedDatabase();
    final store = SqlContactStore(() async => fresh);
    expect(await store.contact('c1'), isNull);
    await store.save(local);
    expect((await store.contact('c1'))?.contact.name, secretName);
    await fresh.close();
  });
}
