import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:kumbha_path/src/modules/family/offline/contact_sync.dart';

/// [ContactStore] held in memory, for widget tests where real file access
/// can't run. Also lets the same behaviour be checked against the SQL store.
class MemoryContactStore implements ContactStore {
  String? _account;
  final rows = <String, LocalContact>{};
  final infos = <String, ScopeInfo>{};
  List<FamilyCircle> saved = [];

  @override
  Future<String?> account() async => _account;

  @override
  Future<void> setAccount(String account) async => _account = account;

  @override
  Future<List<LocalContact>> contacts(ContactScope scope) async =>
      rows.values.where((r) => r.scope == scope).toList()
        ..sort((a, b) => a.contact.priority.compareTo(b.contact.priority));

  @override
  Future<LocalContact?> contact(String id) async => rows[id];

  @override
  Future<void> save(LocalContact contact) async => rows[contact.id] = contact;

  @override
  Future<void> saveAll(List<LocalContact> contacts) async {
    for (final c in contacts) {
      rows[c.id] = c;
    }
  }

  @override
  Future<void> remove(String id) async => rows.remove(id);

  @override
  Future<List<LocalContact>> queued() async =>
      rows.values.where((r) => r.isQueued).toList()
        ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

  @override
  Future<int> unsyncedCount() async =>
      rows.values.where((r) => r.hasLocalChange).length;

  @override
  Future<ScopeInfo?> scope(ContactScope scope) async => infos[scope.key];

  @override
  Future<void> saveScope(ScopeInfo info) async => infos[info.scope.key] = info;

  @override
  Future<List<ScopeInfo>> scopes() async => infos.values.toList();

  @override
  Future<List<FamilyCircle>> circles() async => saved;

  @override
  Future<void> saveCircles(List<FamilyCircle> circles) async => saved = circles;

  @override
  Future<void> removeScope(ContactScope scope) async {
    rows.removeWhere((_, r) => r.scope == scope);
    infos.remove(scope.key);
  }

  @override
  Future<void> removeFamily(String familyId) async {
    rows.removeWhere((_, r) => r.scope.familyId == familyId);
    infos.removeWhere((_, i) => i.scope.familyId == familyId);
    saved = saved.where((c) => c.id != familyId).toList();
  }

  @override
  Future<void> clear() async {
    rows.clear();
    infos.clear();
    saved = [];
    _account = null;
  }
}

/// Behaves like the Django contact endpoints, with a switch for each way a
/// network or server can fail.
class FakeServer implements FamilyRepository {
  final contactsById = <String, EmergencyContact>{};
  final ownerOf = <String, String?>{};
  int clock = 100;

  /// Thrown by every call while set, as if the network were down.
  FamilyException? down;

  /// Applies the request, then fails as if the response never arrived.
  int loseResponses = 0;

  /// Fails this many requests with a server error.
  int serverErrors = 0;
  FamilyException? refuseWrites;
  int creates = 0;
  int updates = 0;
  int deletes = 0;
  int requests = 0;
  List<String>? order;

  /// A successful create changes nothing the second time, as on the backend.
  String _version() =>
      '2026-10-31T10:00:${(clock++ % 60).toString().padLeft(2, '0')}.${clock}Z';

  void seed(String id, String name, {int priority = 1, String? member}) {
    contactsById[id] = EmergencyContact(
      id: id,
      name: name,
      mobile: '+919812345678',
      priority: priority,
      updatedAt: _version(),
    );
    ownerOf[id] = member;
  }

  /// Someone else changes a contact on another phone.
  void changeElsewhere(String id, String name) {
    contactsById[id] = contactsById[id]!.copyWith(
      name: name,
      updatedAt: _version(),
    );
  }

  void _gate({bool write = false}) {
    requests++;
    final d = down;
    if (d != null) throw d;
    if (serverErrors > 0) {
      serverErrors--;
      throw const FamilyException(FamilyFailure.server);
    }
    if (write && refuseWrites != null) throw refuseWrites!;
  }

  void _maybeLose() {
    if (loseResponses > 0) {
      loseResponses--;
      throw const FamilyException(FamilyFailure.offline);
    }
  }

  void _checkVersion(EmergencyContact current, String? ifMatch) {
    if (ifMatch != null && ifMatch != current.updatedAt) {
      throw FamilyException(FamilyFailure.stale, serverContact: current);
    }
  }

  @override
  Future<List<EmergencyContact>> contacts(
    String familyId, {
    String? memberId,
  }) async {
    _gate();
    return contactsById.values.where((c) => ownerOf[c.id] == memberId).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  @override
  Future<EmergencyContact> addContact(
    String familyId,
    Map<String, dynamic> data, {
    String? memberId,
  }) async {
    _gate(write: true);
    final id = data['id'] as String;
    final existing = contactsById[id];
    if (existing != null) return existing;
    creates++;
    final created = EmergencyContact(
      id: id,
      name: data['name'] as String,
      relationship: data['relationship'] as String? ?? '',
      mobile: data['mobile'] as String,
      method: data['method'] as String? ?? 'call',
      priority:
          contactsById.values
              .where((c) => ownerOf[c.id] == memberId)
              .fold(0, (m, c) => c.priority > m ? c.priority : m) +
          1,
      updatedAt: _version(),
    );
    contactsById[id] = created;
    ownerOf[id] = memberId;
    _maybeLose();
    return created;
  }

  @override
  Future<EmergencyContact> updateContact(
    String familyId,
    String contactId,
    Map<String, dynamic> data, {
    String? ifMatch,
  }) async {
    _gate(write: true);
    final current = contactsById[contactId];
    if (current == null) throw const FamilyException(FamilyFailure.notFound);
    _checkVersion(current, ifMatch);
    updates++;
    final updated = current.copyWith(
      name: data['name'] as String?,
      relationship: data['relationship'] as String?,
      mobile: data['mobile'] as String?,
      method: data['method'] as String?,
      updatedAt: _version(),
    );
    contactsById[contactId] = updated;
    _maybeLose();
    return updated;
  }

  @override
  Future<void> deleteContact(
    String familyId,
    String contactId, {
    String? ifMatch,
  }) async {
    _gate(write: true);
    final current = contactsById[contactId];
    if (current == null) throw const FamilyException(FamilyFailure.notFound);
    _checkVersion(current, ifMatch);
    deletes++;
    contactsById.remove(contactId);
    _maybeLose();
  }

  @override
  Future<List<EmergencyContact>> reorderContacts(
    String familyId,
    List<String> contactIds, {
    String? memberId,
  }) async {
    _gate(write: true);
    final owned =
        contactsById.values
            .where((c) => ownerOf[c.id] == memberId)
            .map((c) => c.id)
            .toSet();
    if (owned.length != contactIds.length || !owned.containsAll(contactIds)) {
      throw const FamilyException(FamilyFailure.invalid);
    }
    order = contactIds;
    for (final (i, id) in contactIds.indexed) {
      contactsById[id] = contactsById[id]!.copyWith(priority: i + 1);
    }
    return contacts(familyId, memberId: memberId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
