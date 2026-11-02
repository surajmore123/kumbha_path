import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kumbha_path/src/modules/family/offline/contact_sync.dart';
import 'package:kumbha_path/src/modules/family/offline/encrypted_database.dart';
import 'package:kumbha_path/src/modules/lostfound/data/lf_repository.dart';
import 'package:kumbha_path/src/modules/lostfound/models/lf_models.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// Reports on this phone. They hold private details, so implementations must
/// keep them encrypted.
abstract class DraftStore {
  Future<List<ReportDraft>> all();
  Future<ReportDraft?> one(String id);
  Future<void> save(ReportDraft draft);
  Future<void> remove(String id);
  Future<void> clear();
}

/// [DraftStore] in the same encrypted SQLCipher database as emergency contacts.
class SqlDraftStore implements DraftStore {
  SqlDraftStore(this._open);

  final Future<Database> Function() _open;
  Future<Database>? _database;

  Future<Database> get _db => _database ??= _open();

  @override
  Future<List<ReportDraft>> all() async {
    final rows = await (await _db).query(
      'lf_drafts',
      orderBy: 'updated_at DESC',
    );
    return rows.map(ReportDraft.fromRow).toList();
  }

  @override
  Future<ReportDraft?> one(String id) async {
    final rows = await (await _db).query(
      'lf_drafts',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : ReportDraft.fromRow(rows.first);
  }

  @override
  Future<void> save(ReportDraft draft) async {
    await (await _db).insert('lf_drafts', {
      'id': draft.id,
      'kind': draft.kind,
      'fields': jsonEncode(draft.fields),
      'photo': draft.photo,
      'state': draft.state.name,
      'case_id': draft.caseId,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> remove(String id) async {
    await (await _db).delete('lf_drafts', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clear() async {
    await (await _db).delete('lf_drafts');
  }
}

/// What happened when a report was sent.
class SubmitResult {
  const SubmitResult.sent(this.reference, {this.duplicate = false})
    : waiting = false,
      refused = null;
  const SubmitResult.waiting()
    : reference = null,
      duplicate = false,
      waiting = true,
      refused = null;
  const SubmitResult.refused(this.refused)
    : reference = null,
      duplicate = false,
      waiting = false;

  /// Set only once the server has confirmed the report.
  final String? reference;
  final bool duplicate;

  /// Saved on the phone, and not yet with anyone.
  final bool waiting;
  final Object? refused;
}

/// Sends finished reports. Only a confirmed server reply counts as submitted,
/// and the draft's id is its `client_id`, so a retry after a lost reply can't
/// create a second case.
class ReportSender extends ChangeNotifier {
  ReportSender({
    required LostFoundRepository remote,
    required DraftStore store,
    Stream<bool>? online,
  }) : _remote = remote,
       _store = store,
       _online = online;

  final LostFoundRepository _remote;
  final DraftStore _store;
  final Stream<bool>? _online;
  StreamSubscription<bool>? _sub;
  Future<void>? _running;

  void start() {
    _sub = _online?.listen((online) {
      if (online) unawaited(sendWaiting());
    });
    unawaited(sendWaiting());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<List<ReportDraft>> drafts() => _store.all();

  Future<ReportDraft?> draft(String id) => _store.one(id);

  Future<ReportDraft> newDraft(String kind) async {
    final draft = ReportDraft(id: newContactId(), kind: kind, fields: const {});
    await _store.save(draft);
    notifyListeners();
    return draft;
  }

  Future<void> save(ReportDraft draft) async {
    await _store.save(draft);
    notifyListeners();
  }

  Future<void> discard(String id) async {
    await _store.remove(id);
    notifyListeners();
  }

  Future<void> wipe() async {
    try {
      await _store.clear();
    } catch (_) {
      // A storage fault mustn't stop someone signing out.
    }
  }

  Future<CaseSummary> _create(ReportDraft draft) {
    final body = {...draft.fields, 'client_id': draft.id};
    return draft.kind == 'found'
        ? _remote.reportFound(body)
        : _remote.reportLost(body);
  }

  /// Marks it finished and tries now. Whatever happens, it's safe on the phone.
  Future<SubmitResult> submit(ReportDraft draft) async {
    final waiting = draft.copyWith(state: DraftState.waiting);
    await save(waiting);
    final result = await _send(waiting);
    notifyListeners();
    return result;
  }

  Future<SubmitResult> _send(ReportDraft draft) async {
    try {
      var caseId = draft.caseId;
      String? reference;
      var duplicate = false;
      if (caseId == null) {
        final made = await _create(draft);
        caseId = made.id;
        reference = made.reference;
        duplicate = made.duplicate;
      }
      final photo = draft.photo;
      if (photo != null) {
        await _store.save(
          draft.copyWith(state: DraftState.uploadingPhoto, caseId: caseId),
        );
        await _remote.uploadPhoto(caseId, photo, clientId: draft.id);
      }
      await _store.remove(draft.id);
      return SubmitResult.sent(reference ?? '', duplicate: duplicate);
    } on FamilyException catch (e) {
      if (e.kind == FamilyFailure.invalid ||
          e.kind == FamilyFailure.forbidden ||
          e.kind == FamilyFailure.conflict) {
        if (draft.caseId == null) {
          await _store.save(draft.copyWith(state: DraftState.refused));
          return SubmitResult.refused(e);
        }
        // The report is in; only its photo was refused.
        await _store.remove(draft.id);
        return const SubmitResult.sent('');
      }
      return const SubmitResult.waiting();
    }
  }

  /// One run at a time, so two triggers can't send the same report at once.
  Future<void> sendWaiting() {
    return _running ??= _sendAll().whenComplete(() => _running = null);
  }

  Future<void> _sendAll() async {
    try {
      for (final draft in await _store.all()) {
        if (draft.state != DraftState.waiting &&
            draft.state != DraftState.uploadingPhoto) {
          continue;
        }
        final result = await _send(draft);
        if (result.waiting) break;
      }
    } catch (_) {
      // A storage fault. The next trigger tries again.
    }
    notifyListeners();
  }
}

/// Swappable in tests.
class LostFoundDrafts {
  LostFoundDrafts._();

  static ReportSender? _sender;

  static ReportSender get sender =>
      _sender ??= ReportSender(
        remote: LostFoundServices.repository,
        store: SqlDraftStore(openEncryptedDatabase),
        online: connectivityChanges(),
      );

  static set sender(ReportSender value) => _sender = value;
}
