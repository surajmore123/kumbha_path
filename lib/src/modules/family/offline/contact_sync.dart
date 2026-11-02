import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:kumbha_path/src/modules/family/offline/contact_store.dart';
import 'package:kumbha_path/src/modules/family/offline/encrypted_database.dart';

export 'package:kumbha_path/src/modules/family/offline/contact_store.dart';

enum SyncPhase {
  /// Nothing is waiting, and the last attempt worked.
  idle,
  syncing,

  /// No connection. Changes are safe on the phone.
  offline,

  /// The server failed. Retrying on a timer.
  retrying,

  /// The session ended. Nothing can sync until sign-in.
  signedOut,
}

/// The screen's view of one list.
class ContactListView {
  const ContactListView({required this.contacts, required this.info});

  /// Visible contacts, in order. Pending deletes aren't included.
  final List<LocalContact> contacts;
  final ScopeInfo? info;
}

/// The ID in the access token, read locally so it works offline. The token is
/// not trusted for anything here: the server still checks every request.
String? accountFromToken(String? token) {
  final parts = token?.split('.');
  if (parts == null || parts.length != 3) return null;
  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final claims = jsonDecode(payload);
    final id = claims is Map ? claims['user_id'] : null;
    return id?.toString();
  } catch (_) {
    return null;
  }
}

/// A random UUID (v4), so a contact made offline already has its final ID and
/// any number of retries can only ever create it once.
String newContactId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Offline-first emergency contacts. Screens read and write the local store
/// through this; only [sync] talks to the server, which stays the source of
/// truth. It runs while the app is open and starts no background work.
///
/// The queue is the rows themselves: each contact has one state, so any number
/// of edits to it becomes a single request.
class ContactSyncService extends ChangeNotifier with WidgetsBindingObserver {
  ContactSyncService({
    required FamilyRepository remote,
    required ContactStore store,
    Stream<bool>? online,
    Future<String?> Function()? account,
    DateTime Function()? now,
    void Function(Duration, void Function())? schedule,
  }) : _remote = remote,
       _store = store,
       _online = online,
       _account = account ?? (() async => null),
       _now = now ?? DateTime.now,
       _schedule = schedule;

  final FamilyRepository _remote;
  final ContactStore _store;
  final Stream<bool>? _online;
  final Future<String?> Function() _account;
  final DateTime Function() _now;
  final void Function(Duration, void Function())? _schedule;

  StreamSubscription<bool>? _onlineSub;
  Timer? _retry;
  int _failures = 0;
  Future<void>? _running;
  bool _again = false;
  bool _ready = false;
  int _lastQueuedAt = 0;

  SyncPhase phase = SyncPhase.idle;

  /// Changes not yet on the server, including those needing a decision.
  int unsynced = 0;

  static const _maxBackoff = Duration(minutes: 5);

  /// How long to wait after [failures] failed attempts: 5s, 10s, 20s ... 5m.
  static Duration backoff(int failures) {
    final seconds = 5 * pow(2, max(0, failures - 1)).toInt();
    return seconds >= _maxBackoff.inSeconds
        ? _maxBackoff
        : Duration(seconds: seconds);
  }

  /// Begins watching for the network and the app returning to the foreground.
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _onlineSub = _online?.listen((online) {
      if (online) {
        unawaited(sync());
      } else {
        _set(SyncPhase.offline);
      }
    });
    unawaited(sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onlineSub?.cancel();
    _retry?.cancel();
    super.dispose();
  }

  void _set(SyncPhase value) {
    phase = value;
    notifyListeners();
  }

  /// Data from one account must never reach another on a shared phone.
  Future<void> _prepare() async {
    final current = await _account();
    if (!_ready || current != null) {
      final saved = await _store.account();
      if (current != null && saved != null && saved != current) {
        await _store.clear();
      }
      if (current != null && saved != current) {
        await _store.setAccount(current);
      }
      _ready = true;
    }
  }

  Future<void> _count() async {
    final rows = await _store.unsyncedCount();
    final orders = (await _store.scopes()).where((s) => s.orderDirty).length;
    if (rows + orders == unsynced) return;
    unsynced = rows + orders;
    notifyListeners();
  }

  int _nextQueuedAt() {
    final at = max(_now().millisecondsSinceEpoch, _lastQueuedAt + 1);
    _lastQueuedAt = at;
    return at;
  }

  // ---------------- reading ----------------

  /// What's saved on the phone, at once and without touching the network.
  Future<ContactListView> local(ContactScope scope) async {
    await _prepare();
    await _count();
    return _view(scope);
  }

  Future<ContactListView> _view(ContactScope scope) async {
    final rows = await _store.contacts(scope);
    return ContactListView(
      contacts:
          rows.where((r) => r.state != ContactSyncState.pendingDelete).toList(),
      info: await _store.scope(scope),
    );
  }

  /// Remembers how a list can be reached and edited.
  Future<void> remember(
    ContactScope scope, {
    String? label,
    required bool canEdit,
  }) async {
    await _prepare();
    final info = await _store.scope(scope) ?? ScopeInfo(scope: scope);
    await _store.saveScope(info.copyWith(label: label, canEdit: canEdit));
  }

  /// The circles this person belonged to when last online.
  Future<List<FamilyCircle>> savedCircles() async {
    await _prepare();
    return _store.circles();
  }

  Future<List<ScopeInfo>> savedLists(String familyId) async {
    await _prepare();
    final all = await _store.scopes();
    return all.where((s) => s.scope.familyId == familyId).toList();
  }

  /// Keeps the saved circles matching the server, and drops any the person
  /// has left, including anything still queued there.
  Future<void> rememberCircles(List<FamilyCircle> circles) async {
    await _prepare();
    final ids = circles.map((c) => c.id).toSet();
    for (final old in await _store.circles()) {
      if (!ids.contains(old.id)) await _store.removeFamily(old.id);
    }
    await _store.saveCircles(circles);
    await _count();
  }

  /// Sign-out: nothing stays on the phone.
  Future<void> wipe() async {
    _retry?.cancel();
    try {
      await _store.clear();
    } catch (_) {
      // A storage fault mustn't stop someone signing out. The account check
      // still clears this data before anyone else can reach it.
    }
    _ready = false;
    unsynced = 0;
    _failures = 0;
    _set(SyncPhase.idle);
  }

  // ---------------- writing ----------------

  /// Saves here first, then tries the server. Returns once it's safe on the
  /// phone, whether or not the server has it yet.
  Future<void> add(ContactScope scope, Map<String, dynamic> data) async {
    await _prepare();
    final rows = await _store.contacts(scope);
    final last = rows.fold<int>(0, (m, r) => max(m, r.contact.priority));
    await _store.save(
      LocalContact(
        scope: scope,
        state: ContactSyncState.pendingCreate,
        queuedAt: _nextQueuedAt(),
        contact: EmergencyContact(
          id: newContactId(),
          name: data['name'] as String,
          relationship: data['relationship'] as String? ?? '',
          mobile: _stored(data['mobile'] as String),
          priority: last + 1,
          method: data['method'] as String? ?? 'call',
        ),
      ),
    );
    await _afterChange();
  }

  static String _stored(String mobile) =>
      mobile.startsWith('+91') ? mobile : '+91$mobile';

  Future<void> edit(LocalContact row, Map<String, dynamic> data) async {
    await _prepare();
    final latest = await _store.contact(row.id) ?? row;
    // Fixing a failed row or editing a conflict's local side keeps its state.
    final state = switch (latest.state) {
      ContactSyncState.pendingCreate => ContactSyncState.pendingCreate,
      ContactSyncState.conflict => ContactSyncState.conflict,
      ContactSyncState.failed =>
        latest.contact.updatedAt == null
            ? ContactSyncState.pendingCreate
            : ContactSyncState.pendingUpdate,
      _ => ContactSyncState.pendingUpdate,
    };
    await _store.save(
      latest.copyWith(
        state: state,
        queuedAt: latest.isQueued ? latest.queuedAt : _nextQueuedAt(),
        wantsDelete: false,
        contact: latest.contact.copyWith(
          name: data['name'] as String?,
          relationship: data['relationship'] as String?,
          mobile:
              data['mobile'] == null ? null : _stored(data['mobile'] as String),
          method: data['method'] as String?,
        ),
      ),
    );
    await _afterChange();
  }

  Future<void> delete(LocalContact row) async {
    await _prepare();
    final latest = await _store.contact(row.id);
    if (latest == null) return;
    final notOnServer =
        latest.contact.updatedAt == null &&
        (latest.state == ContactSyncState.failed ||
            (latest.state == ContactSyncState.pendingCreate && !latest.sent));
    if (notOnServer) {
      await _store.remove(row.id);
    } else {
      await _store.save(
        latest.copyWith(
          state: ContactSyncState.pendingDelete,
          queuedAt: _nextQueuedAt(),
        ),
      );
    }
    await _afterChange();
  }

  /// Saves a new order. It reaches the server after any queued contacts.
  Future<void> reorder(ContactScope scope, List<String> ids) async {
    await _prepare();
    final rows = {for (final r in await _store.contacts(scope)) r.id: r};
    final changed = <LocalContact>[
      for (final (i, id) in ids.indexed)
        if (rows[id] != null)
          rows[id]!.copyWith(
            contact: rows[id]!.contact.copyWith(priority: i + 1),
          ),
    ];
    await _store.saveAll(changed);
    final info = await _store.scope(scope) ?? ScopeInfo(scope: scope);
    await _store.saveScope(info.copyWith(orderDirty: true));
    await _afterChange();
  }

  /// Conflict: send this phone's version, on top of the server's current one.
  Future<void> keepMine(LocalContact row) async {
    final latest = await _store.contact(row.id);
    if (latest == null) return;
    final server = latest.serverCopy;
    final recreate = latest.goneFromServer && !latest.wantsDelete;
    if (latest.goneFromServer && latest.wantsDelete) {
      await _store.remove(row.id);
      await _afterChange();
      return;
    }
    await _store.save(
      latest.copyWith(
        state:
            latest.wantsDelete
                ? ContactSyncState.pendingDelete
                : recreate
                ? ContactSyncState.pendingCreate
                : ContactSyncState.pendingUpdate,
        queuedAt: _nextQueuedAt(),
        clearServerCopy: true,
        goneFromServer: false,
        wantsDelete: false,
        sent: false,
        contact: latest.contact.copyWith(
          updatedAt: server?.updatedAt,
          clearUpdatedAt: recreate,
        ),
      ),
    );
    await _afterChange();
  }

  /// Conflict: take the server's version, or its deletion.
  Future<void> useTheirs(LocalContact row) async {
    final latest = await _store.contact(row.id);
    if (latest == null) return;
    final server = latest.serverCopy;
    if (server == null) {
      await _store.remove(row.id);
    } else {
      await _store.save(LocalContact(contact: server, scope: latest.scope));
    }
    await _afterChange();
  }

  /// Gives up on a failed change. The next sync restores the server's copy.
  Future<void> discard(LocalContact row) async {
    final latest = await _store.contact(row.id);
    if (latest == null) return;
    if (latest.contact.updatedAt == null) {
      await _store.remove(row.id);
    } else {
      await _store.save(
        LocalContact(contact: latest.contact, scope: latest.scope),
      );
    }
    await _afterChange();
  }

  Future<void> _afterChange() async {
    await _count();
    unawaited(sync());
  }

  // ---------------- syncing ----------------

  /// Sends what's queued, then refreshes the saved lists. Only one run happens
  /// at a time; a request during a run causes one more straight after it, and
  /// the returned future covers both.
  Future<void> sync() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _runUntilCaughtUp().whenComplete(() => _running = null);
  }

  Future<void> _runUntilCaughtUp() async {
    do {
      _again = false;
      await _run();
    } while (_again);
  }

  Future<void> _run() async {
    _retry?.cancel();
    _set(SyncPhase.syncing);
    try {
      await _prepare();
      await _push();
      for (final info in await _store.scopes()) {
        await _pushOrder(info.scope);
        await _pull(info.scope);
      }
      _failures = 0;
      await _count();
      _set(SyncPhase.idle);
    } on FamilyException catch (e) {
      await _count();
      _stopFor(e);
    } catch (_) {
      // A local storage fault. Nothing is logged: this data is private.
      _failures++;
      _set(SyncPhase.retrying);
      _later();
    }
  }

  void _stopFor(FamilyException e) {
    switch (e.kind) {
      case FamilyFailure.signedOut:
        _set(SyncPhase.signedOut);
      case FamilyFailure.offline:
        _failures++;
        _set(SyncPhase.offline);
        _later();
      default:
        _failures++;
        _set(SyncPhase.retrying);
        _later();
    }
  }

  void _later() {
    final wait = backoff(_failures);
    final schedule = _schedule;
    if (schedule != null) {
      schedule(wait, () => unawaited(sync()));
    } else {
      _retry = Timer(wait, () => unawaited(sync()));
    }
  }

  /// Oldest first. A failure that could pass later stops the run with the
  /// queue intact; one that can't is parked on its row and the rest continue.
  Future<void> _push() async {
    for (final queued in await _store.queued()) {
      // It may have changed while earlier ones were sent.
      final row = await _store.contact(queued.id);
      if (row == null || !row.isQueued) continue;
      try {
        await switch (row.state) {
          ContactSyncState.pendingCreate => _create(row),
          ContactSyncState.pendingUpdate => _update(row),
          _ => _deleteRemote(row),
        };
      } on FamilyException catch (e) {
        switch (e.kind) {
          case FamilyFailure.invalid || FamilyFailure.forbidden:
            await _store.save(
              row.copyWith(
                state: ContactSyncState.failed,
                wantsDelete: row.state == ContactSyncState.pendingDelete,
              ),
            );
          case FamilyFailure.stale:
            await _conflict(row, e.serverContact);
          case FamilyFailure.notFound:
            await _missing(row);
          default:
            rethrow;
        }
      }
    }
  }

  Map<String, dynamic> _fields(EmergencyContact c) => {
    'name': c.name,
    'relationship': c.relationship,
    'mobile': c.mobile,
    'method': c.method,
  };

  Future<void> _create(LocalContact row) async {
    // Marked before sending: from here its fate may be unknown.
    await _store.save(row.copyWith(sent: true));
    final saved = await _remote.addContact(row.scope.familyId, {
      'id': row.id,
      ..._fields(row.contact),
    }, memberId: row.scope.memberId);
    await _settled(row, saved);
  }

  Future<void> _update(LocalContact row) async {
    final saved = await _remote.updateContact(
      row.scope.familyId,
      row.id,
      _fields(row.contact),
      ifMatch: row.contact.updatedAt,
    );
    await _settled(row, saved);
  }

  /// The local row may have been edited while the request was out.
  Future<void> _settled(LocalContact sent, EmergencyContact saved) async {
    final now = await _store.contact(sent.id);
    if (now == null) return;
    final changedMeanwhile =
        now.isQueued &&
        (now.state != sent.state || !_same(now.contact, sent.contact));
    if (changedMeanwhile) {
      await _store.save(
        now.copyWith(
          sent: false,
          contact: now.contact.copyWith(updatedAt: saved.updatedAt),
          state:
              now.state == ContactSyncState.pendingCreate
                  ? ContactSyncState.pendingUpdate
                  : now.state,
        ),
      );
      return;
    }
    final info = await _store.scope(sent.scope);
    final keepOrder = info?.orderDirty ?? false;
    await _store.save(
      LocalContact(
        scope: sent.scope,
        contact: saved.copyWith(
          priority: keepOrder ? now.contact.priority : saved.priority,
        ),
      ),
    );
  }

  static bool _same(EmergencyContact a, EmergencyContact b) =>
      a.name == b.name &&
      a.relationship == b.relationship &&
      a.mobile == b.mobile &&
      a.method == b.method;

  Future<void> _deleteRemote(LocalContact row) async {
    // Sending a delete for a create whose outcome is unknown: settle the
    // create first, which is safe to repeat, so the delete has a version.
    var version = row.contact.updatedAt;
    if (version == null) {
      final saved = await _remote.addContact(row.scope.familyId, {
        'id': row.id,
        ..._fields(row.contact),
      }, memberId: row.scope.memberId);
      version = saved.updatedAt;
    }
    await _remote.deleteContact(row.scope.familyId, row.id, ifMatch: version);
    await _store.remove(row.id);
  }

  Future<void> _conflict(LocalContact row, EmergencyContact? server) async {
    // An update whose response was lost: the server already has this exact
    // version, so there's nothing to choose between.
    if (server != null &&
        row.state == ContactSyncState.pendingUpdate &&
        _same(server, row.contact)) {
      await _store.save(LocalContact(contact: server, scope: row.scope));
      return;
    }
    await _store.save(
      row.copyWith(
        state: ContactSyncState.conflict,
        serverCopy: server,
        wantsDelete: row.state == ContactSyncState.pendingDelete,
      ),
    );
  }

  /// A 404: the contact is gone, or this person lost the list.
  Future<void> _missing(LocalContact row) async {
    if (row.state == ContactSyncState.pendingDelete) {
      await _store.remove(row.id); // already gone: the delete succeeded
    } else {
      await _store.save(
        row.copyWith(
          state: ContactSyncState.conflict,
          goneFromServer: true,
          clearServerCopy: true,
        ),
      );
    }
  }

  Future<void> _pushOrder(ContactScope scope) async {
    final info = await _store.scope(scope);
    if (info == null || !info.orderDirty) return;
    final rows = await _store.contacts(scope);
    // Unsettled rows have no place on the server yet; try again next run.
    if (rows.any((r) => r.hasLocalChange)) return;
    var ids = [for (final r in rows) r.id];
    try {
      await _sendOrder(scope, ids);
    } on FamilyException catch (e) {
      if (e.kind == FamilyFailure.forbidden ||
          e.kind == FamilyFailure.notFound) {
        // Can't edit this list any more: take the server's order.
        await _store.saveScope(info.copyWith(orderDirty: false));
        return;
      }
      if (e.kind != FamilyFailure.invalid) rethrow;
      // The server's set differs: someone added or removed one elsewhere.
      // Keep this order for those both sides know, and add the rest after.
      final server = await _remote.contacts(
        scope.familyId,
        memberId: scope.memberId,
      );
      final known = server.map((c) => c.id).toSet();
      ids = [
        ...ids.where(known.contains),
        ...server.map((c) => c.id).where((id) => !ids.contains(id)),
      ];
      await _sendOrder(scope, ids);
    }
    await _store.saveScope(info.copyWith(orderDirty: false));
  }

  Future<void> _sendOrder(ContactScope scope, List<String> ids) =>
      _remote.reorderContacts(scope.familyId, ids, memberId: scope.memberId);

  /// Brings in the server's list. A row with any local change is left alone:
  /// [_push] is what decides those, so stale local data never wins silently
  /// and newer server data is never lost.
  Future<void> _pull(ContactScope scope) async {
    final List<EmergencyContact> server;
    try {
      server = await _remote.contacts(scope.familyId, memberId: scope.memberId);
    } on FamilyException catch (e) {
      // Removed from the family, the person is gone, or they've stopped
      // sharing. Either way this phone must not keep their contacts.
      if (e.kind == FamilyFailure.notFound && scope.memberId == null) {
        await _store.removeFamily(scope.familyId);
        return;
      }
      if (e.kind == FamilyFailure.notFound ||
          e.kind == FamilyFailure.forbidden) {
        await _store.removeScope(scope);
        return;
      }
      rethrow;
    }
    final local = {for (final r in await _store.contacts(scope)) r.id: r};
    final info = await _store.scope(scope) ?? ScopeInfo(scope: scope);
    final fresh = <LocalContact>[];
    for (final contact in server) {
      final row = local.remove(contact.id);
      if (row != null && row.hasLocalChange) continue;
      fresh.add(
        LocalContact(
          scope: scope,
          contact:
              info.orderDirty && row != null
                  ? contact.copyWith(priority: row.contact.priority)
                  : contact,
        ),
      );
    }
    await _store.saveAll(fresh);
    for (final gone in local.values) {
      if (!gone.hasLocalChange) await _store.remove(gone.id);
    }
    await _store.saveScope(info.copyWith(lastSyncedAt: _now()));
  }

  /// Syncs, then returns the list. Works the same with no connection.
  Future<ContactListView> refresh(ContactScope scope) async {
    await _prepare();
    final known = await _store.scope(scope);
    if (known == null) await _store.saveScope(ScopeInfo(scope: scope));
    await sync();
    return _view(scope);
  }
}

/// True when any network is attached. It can't promise the internet works, so
/// a failed sync still backs off and retries.
Stream<bool> connectivityChanges() => Connectivity().onConnectivityChanged.map(
  (results) => results.any((r) => r != ConnectivityResult.none),
);

Future<String?> _currentAccount() async {
  try {
    return accountFromToken(await storage.read(key: 'access_token'));
  } catch (_) {
    return null;
  }
}

/// Swappable in tests.
class FamilyContacts {
  FamilyContacts._();

  static ContactSyncService? _service;

  static ContactSyncService get service =>
      _service ??= ContactSyncService(
        remote: FamilyServices.repository,
        store: SqlContactStore(openEncryptedDatabase),
        online: connectivityChanges(),
        account: _currentAccount,
      );

  static set service(ContactSyncService value) => _service = value;
}
