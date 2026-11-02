import 'dart:convert';

import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// Which list a contact belongs to: the family's, or one person's.
class ContactScope {
  const ContactScope(this.familyId, [this.memberId]);

  final String familyId;
  final String? memberId;

  String get key => '$familyId|${memberId ?? ''}';

  @override
  bool operator ==(Object other) => other is ContactScope && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// What the device remembers about a list, so it can be reached offline.
class ScopeInfo {
  const ScopeInfo({
    required this.scope,
    this.label,
    this.canEdit = false,
    this.lastSyncedAt,
    this.orderDirty = false,
  });

  final ContactScope scope;

  /// The person's name, or null for the family's list.
  final String? label;
  final bool canEdit;
  final DateTime? lastSyncedAt;

  /// The order was changed here and hasn't reached the server.
  final bool orderDirty;

  ScopeInfo copyWith({
    String? label,
    bool? canEdit,
    DateTime? lastSyncedAt,
    bool? orderDirty,
  }) => ScopeInfo(
    scope: scope,
    label: label ?? this.label,
    canEdit: canEdit ?? this.canEdit,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    orderDirty: orderDirty ?? this.orderDirty,
  );
}

/// A stored contact and its place in the sync queue.
class LocalContact {
  const LocalContact({
    required this.contact,
    required this.scope,
    this.state = ContactSyncState.synced,
    this.queuedAt = 0,
    this.sent = false,
    this.serverCopy,
    this.goneFromServer = false,
    this.wantsDelete = false,
  });

  final EmergencyContact contact;
  final ContactScope scope;
  final ContactSyncState state;

  /// Queue position: changes go oldest first.
  final int queuedAt;

  /// A create that may have reached the server. Its outcome is unknown, so it
  /// can't simply be cancelled.
  final bool sent;

  /// The server's version, kept while a conflict waits for a decision.
  final EmergencyContact? serverCopy;

  /// The conflict is that the server no longer has this contact.
  final bool goneFromServer;

  /// The conflict or failure is over a delete made here.
  final bool wantsDelete;

  String get id => contact.id;

  bool get isQueued => switch (state) {
    ContactSyncState.pendingCreate ||
    ContactSyncState.pendingUpdate ||
    ContactSyncState.pendingDelete => true,
    _ => false,
  };

  /// Waiting on anything at all, including a decision from the user.
  bool get hasLocalChange => state != ContactSyncState.synced;

  LocalContact copyWith({
    EmergencyContact? contact,
    ContactSyncState? state,
    int? queuedAt,
    bool? sent,
    EmergencyContact? serverCopy,
    bool clearServerCopy = false,
    bool? goneFromServer,
    bool? wantsDelete,
  }) => LocalContact(
    contact: contact ?? this.contact,
    scope: scope,
    state: state ?? this.state,
    queuedAt: queuedAt ?? this.queuedAt,
    sent: sent ?? this.sent,
    serverCopy: clearServerCopy ? null : (serverCopy ?? this.serverCopy),
    goneFromServer: goneFromServer ?? this.goneFromServer,
    wantsDelete: wantsDelete ?? this.wantsDelete,
  );

  /// Contacts are private, so this must never print their details.
  @override
  String toString() => 'LocalContact(${state.name})';
}

/// Everything kept on the device for offline contacts. Implementations hold
/// personal data and must keep it encrypted.
abstract class ContactStore {
  /// The account this data belongs to.
  Future<String?> account();
  Future<void> setAccount(String account);

  Future<List<LocalContact>> contacts(ContactScope scope);
  Future<LocalContact?> contact(String id);
  Future<void> save(LocalContact contact);
  Future<void> saveAll(List<LocalContact> contacts);
  Future<void> remove(String id);

  /// Rows the sync engine should send, oldest first, across every list.
  Future<List<LocalContact>> queued();

  /// Rows needing attention of any kind, across every list.
  Future<int> unsyncedCount();

  Future<ScopeInfo?> scope(ContactScope scope);
  Future<void> saveScope(ScopeInfo info);
  Future<List<ScopeInfo>> scopes();

  Future<List<FamilyCircle>> circles();
  Future<void> saveCircles(List<FamilyCircle> circles);

  /// Removes one list and its contacts.
  Future<void> removeScope(ContactScope scope);

  /// Removes one family and everything in it.
  Future<void> removeFamily(String familyId);

  /// Removes everything.
  Future<void> clear();
}

Map<String, Object?> _contactJson(EmergencyContact c) => {
  'id': c.id,
  'name': c.name,
  'relationship': c.relationship,
  'mobile': c.mobile,
  'priority': c.priority,
  'method': c.method,
  'updated_at': c.updatedAt,
};

/// [ContactStore] over SQLite. Opened through `openEncryptedDatabase` in the
/// app, so every byte on disk is encrypted. Only ordinary SQL lives here.
class SqlContactStore implements ContactStore {
  SqlContactStore(this._open);

  final Future<Database> Function() _open;
  Future<Database>? _database;

  Future<Database> get _db => _database ??= _open();

  static const schemaVersion = 2;

  /// Creates the tables. Passed to whichever factory opens the database.
  static Future<void> createSchema(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        family_id TEXT NOT NULL,
        member_id TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        relationship TEXT NOT NULL DEFAULT '',
        mobile TEXT NOT NULL,
        priority INTEGER NOT NULL,
        method TEXT NOT NULL,
        updated_at TEXT,
        state TEXT NOT NULL,
        queued_at INTEGER NOT NULL DEFAULT 0,
        sent INTEGER NOT NULL DEFAULT 0,
        server_copy TEXT,
        gone INTEGER NOT NULL DEFAULT 0,
        wants_delete INTEGER NOT NULL DEFAULT 0
      )''');
    batch.execute(
      'CREATE INDEX contacts_scope ON contacts (family_id, member_id, priority)',
    );
    batch.execute('CREATE INDEX contacts_state ON contacts (state, queued_at)');
    batch.execute('''
      CREATE TABLE scopes (
        family_id TEXT NOT NULL,
        member_id TEXT NOT NULL DEFAULT '',
        label TEXT,
        can_edit INTEGER NOT NULL DEFAULT 0,
        last_synced_at INTEGER,
        order_dirty INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (family_id, member_id)
      )''');
    batch.execute('''
      CREATE TABLE circles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        language TEXT NOT NULL,
        my_role TEXT,
        my_member_id TEXT
      )''');
    batch.execute(
      'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    batch.execute(_draftsTable);
    await batch.commit(noResult: true);
  }

  /// Lost & Found reports not yet with the server. In this same encrypted file,
  /// so they're wiped with everything else on sign-out or a change of account.
  static const _draftsTable = '''
      CREATE TABLE lf_drafts (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        fields TEXT NOT NULL,
        photo BLOB,
        state TEXT NOT NULL,
        case_id TEXT,
        updated_at INTEGER NOT NULL
      )''';

  static Future<void> upgradeSchema(Database db, int from, int to) async {
    if (from < 2) await db.execute(_draftsTable);
  }

  static Map<String, Object?> _row(LocalContact local) {
    final c = local.contact;
    return {
      'id': c.id,
      'family_id': local.scope.familyId,
      'member_id': local.scope.memberId ?? '',
      'name': c.name,
      'relationship': c.relationship,
      'mobile': c.mobile,
      'priority': c.priority,
      'method': c.method,
      'updated_at': c.updatedAt,
      'state': local.state.name,
      'queued_at': local.queuedAt,
      'sent': local.sent ? 1 : 0,
      'server_copy':
          local.serverCopy == null
              ? null
              : jsonEncode(_contactJson(local.serverCopy!)),
      'gone': local.goneFromServer ? 1 : 0,
      'wants_delete': local.wantsDelete ? 1 : 0,
    };
  }

  static LocalContact _fromRow(Map<String, Object?> row) {
    final member = row['member_id']! as String;
    final copy = row['server_copy'] as String?;
    return LocalContact(
      contact: EmergencyContact(
        id: row['id']! as String,
        name: row['name']! as String,
        relationship: row['relationship']! as String,
        mobile: row['mobile']! as String,
        priority: row['priority']! as int,
        method: row['method']! as String,
        updatedAt: row['updated_at'] as String?,
      ),
      scope: ContactScope(
        row['family_id']! as String,
        member.isEmpty ? null : member,
      ),
      state: ContactSyncState.values.byName(row['state']! as String),
      queuedAt: row['queued_at']! as int,
      sent: row['sent'] == 1,
      serverCopy:
          copy == null
              ? null
              : EmergencyContact.fromJson(
                jsonDecode(copy) as Map<String, dynamic>,
              ),
      goneFromServer: row['gone'] == 1,
      wantsDelete: row['wants_delete'] == 1,
    );
  }

  @override
  Future<String?> account() async {
    final rows = await (await _db).query(
      'meta',
      where: 'key = ?',
      whereArgs: ['account'],
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> setAccount(String account) async {
    await (await _db).insert('meta', {
      'key': 'account',
      'value': account,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<LocalContact>> contacts(ContactScope scope) async {
    final rows = await (await _db).query(
      'contacts',
      where: 'family_id = ? AND member_id = ?',
      whereArgs: [scope.familyId, scope.memberId ?? ''],
      orderBy: 'priority, queued_at',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<LocalContact?> contact(String id) async {
    final rows = await (await _db).query(
      'contacts',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<void> save(LocalContact contact) async {
    await (await _db).insert(
      'contacts',
      _row(contact),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveAll(List<LocalContact> contacts) async {
    final batch = (await _db).batch();
    for (final contact in contacts) {
      batch.insert(
        'contacts',
        _row(contact),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> remove(String id) async {
    await (await _db).delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<LocalContact>> queued() async {
    final rows = await (await _db).query(
      'contacts',
      where: 'state IN (?, ?, ?)',
      whereArgs: [
        ContactSyncState.pendingCreate.name,
        ContactSyncState.pendingUpdate.name,
        ContactSyncState.pendingDelete.name,
      ],
      orderBy: 'queued_at',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<int> unsyncedCount() async {
    final rows = await (await _db).rawQuery(
      'SELECT COUNT(*) AS n FROM contacts WHERE state != ?',
      [ContactSyncState.synced.name],
    );
    return rows.first['n']! as int;
  }

  static ScopeInfo _scopeFromRow(Map<String, Object?> row) {
    final member = row['member_id']! as String;
    final synced = row['last_synced_at'] as int?;
    return ScopeInfo(
      scope: ContactScope(
        row['family_id']! as String,
        member.isEmpty ? null : member,
      ),
      label: row['label'] as String?,
      canEdit: row['can_edit'] == 1,
      lastSyncedAt:
          synced == null ? null : DateTime.fromMillisecondsSinceEpoch(synced),
      orderDirty: row['order_dirty'] == 1,
    );
  }

  @override
  Future<ScopeInfo?> scope(ContactScope scope) async {
    final rows = await (await _db).query(
      'scopes',
      where: 'family_id = ? AND member_id = ?',
      whereArgs: [scope.familyId, scope.memberId ?? ''],
    );
    return rows.isEmpty ? null : _scopeFromRow(rows.first);
  }

  @override
  Future<void> saveScope(ScopeInfo info) async {
    await (await _db).insert('scopes', {
      'family_id': info.scope.familyId,
      'member_id': info.scope.memberId ?? '',
      'label': info.label,
      'can_edit': info.canEdit ? 1 : 0,
      'last_synced_at': info.lastSyncedAt?.millisecondsSinceEpoch,
      'order_dirty': info.orderDirty ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<ScopeInfo>> scopes() async {
    final rows = await (await _db).query('scopes');
    return rows.map(_scopeFromRow).toList();
  }

  @override
  Future<List<FamilyCircle>> circles() async {
    final rows = await (await _db).query('circles', orderBy: 'rowid');
    return [
      for (final row in rows)
        FamilyCircle(
          id: row['id']! as String,
          name: row['name']! as String,
          language: row['language']! as String,
          myRole: row['my_role'] as String?,
          myMemberId: row['my_member_id'] as String?,
        ),
    ];
  }

  @override
  Future<void> saveCircles(List<FamilyCircle> circles) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('circles');
      for (final c in circles) {
        await txn.insert('circles', {
          'id': c.id,
          'name': c.name,
          'language': c.language,
          'my_role': c.myRole,
          'my_member_id': c.myMemberId,
        });
      }
    });
  }

  @override
  Future<void> removeScope(ContactScope scope) async {
    final db = await _db;
    await db.transaction((txn) async {
      const where = 'family_id = ? AND member_id = ?';
      final args = [scope.familyId, scope.memberId ?? ''];
      await txn.delete('contacts', where: where, whereArgs: args);
      await txn.delete('scopes', where: where, whereArgs: args);
    });
  }

  @override
  Future<void> removeFamily(String familyId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'contacts',
        where: 'family_id = ?',
        whereArgs: [familyId],
      );
      await txn.delete('scopes', where: 'family_id = ?', whereArgs: [familyId]);
      await txn.delete('circles', where: 'id = ?', whereArgs: [familyId]);
    });
  }

  @override
  Future<void> clear() async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('contacts');
      await txn.delete('scopes');
      await txn.delete('circles');
      await txn.delete('meta');
      await txn.delete('lf_drafts');
    });
  }
}
