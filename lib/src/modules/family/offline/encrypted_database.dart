import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/modules/family/offline/contact_store.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

const _fileName = 'family_contacts.db';
const _keyName = 'family_contacts_db_key';

/// The database key lives in the platform keystore through secure storage. It
/// isn't derived from anything else, and is never written anywhere else.
Future<String> _databaseKey() async {
  String? key;
  try {
    key = await storage.read(key: _keyName);
  } catch (_) {
    // Android can refuse to read after a backup restore. A new key means the
    // old file can't be opened, which is handled when opening it.
    key = null;
  }
  if (key != null && key.isNotEmpty) return key;
  final random = Random.secure();
  final fresh = base64UrlEncode(
    List<int>.generate(32, (_) => random.nextInt(256)),
  );
  await storage.write(key: _keyName, value: fresh);
  return fresh;
}

Future<Database> _openWith(String path, String key) => openDatabase(
  path,
  password: key,
  version: SqlContactStore.schemaVersion,
  onCreate: SqlContactStore.createSchema,
  onUpgrade: SqlContactStore.upgradeSchema,
);

/// Opens the contacts database, encrypted with SQLCipher (AES-256).
///
/// If the file can't be opened with the key, as after a device restore, it's
/// unreadable to everyone. It's replaced, and contacts download again.
Future<Database> openEncryptedDatabase() async {
  final path = p.join(await getDatabasesPath(), _fileName);
  final key = await _databaseKey();
  try {
    return await _openWith(path, key);
  } on DatabaseException {
    await deleteDatabase(path);
    final leftover = File(path);
    if (leftover.existsSync()) leftover.deleteSync();
    return _openWith(path, key);
  }
}
