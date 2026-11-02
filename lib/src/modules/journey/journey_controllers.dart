import 'package:flutter/foundation.dart';
import 'package:kumbha_path/src/modules/journey/data/journey_repository.dart';
import 'package:kumbha_path/src/modules/journey/models/journey_models.dart';

/// One status tab of `/journeys`: first page, load more, retry.
class JourneyListController extends ChangeNotifier {
  JourneyListController(this.repository, {this.status});

  final JourneyRepository repository;
  final String? status;

  final List<JourneySummary> items = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasNext = false;
  JourneyException? error;
  JourneyException? moreError;
  int _page = 0;
  bool _disposed = false;

  bool get loaded => _page > 0;

  String get _ordering => status == 'completed' ? '-arrival' : 'arrival';

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    _notify();
    try {
      final page = await repository.list(status: status, ordering: _ordering);
      items
        ..clear()
        ..addAll(page.items);
      hasNext = page.hasNext;
      _page = 1;
    } on JourneyException catch (e) {
      error = e;
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasNext) return;
    loadingMore = true;
    moreError = null;
    _notify();
    try {
      final page = await repository.list(
        status: status,
        ordering: _ordering,
        page: _page + 1,
      );
      final known = items.map((i) => i.id).toSet();
      items.addAll(page.items.where((i) => !known.contains(i.id)));
      hasNext = page.hasNext;
      _page++;
    } on JourneyException catch (e) {
      moreError = e;
    } finally {
      loadingMore = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A single plan on `/journeyDetail`. Every change goes to the backend
/// first; the screen shows the backend's copy afterwards, so it never
/// displays an edit that wasn't saved.
class JourneyDetailController extends ChangeNotifier {
  JourneyDetailController(this.repository, this.id);

  final JourneyRepository repository;
  final String id;

  JourneyPlan? plan;
  bool loading = false;
  bool busy = false;
  JourneyException? error;
  bool deleted = false;
  bool _disposed = false;

  Future<void> load() async {
    loading = true;
    error = null;
    _notify();
    try {
      plan = await repository.get(id);
    } on JourneyException catch (e) {
      error = e;
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Runs [action], then shows the fresh plan it returns (or reloads).
  /// Returns the failure, if any, so the screen can say what went wrong.
  Future<JourneyException?> run(Future<Object?> Function() action) async {
    if (busy) return null;
    busy = true;
    _notify();
    try {
      final result = await action();
      plan = result is JourneyPlan ? result : await repository.get(id);
      return null;
    } on JourneyException catch (e) {
      return e;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<JourneyException?> regenerate(String language) =>
      run(() => repository.generate(id, language: language));

  Future<JourneyException?> setStatus(JourneyStatus status) =>
      run(() => repository.update(id, {'status': status.name}));

  Future<JourneyException?> toggleItem(JourneyItem item) =>
      run(() => repository.updateItem(id, item.id, {'is_done': !item.isDone}));

  Future<JourneyException?> saveItem(
    int? itemId,
    int dayNumber,
    Map<String, dynamic> data,
  ) => run(
    () =>
        itemId == null
            ? repository.addItem(id, dayNumber, data)
            : repository.updateItem(id, itemId, {
              ...data,
              'day_number': dayNumber,
            }),
  );

  Future<JourneyException?> deleteItem(int itemId) =>
      run(() => repository.deleteItem(id, itemId));

  /// Moves an item one place up or down within its day.
  Future<JourneyException?> moveItem(JourneyDay day, int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= day.items.length) return Future.value();
    final ids = day.items.map((i) => i.id).toList();
    final moved = ids.removeAt(index);
    ids.insert(target, moved);
    return run(() => repository.reorderDay(id, day.number, ids));
  }

  Future<JourneyException?> toggleChecklist(ChecklistItem item) => run(
    () => repository.updateChecklist(id, item.id, {'is_done': !item.isDone}),
  );

  Future<JourneyException?> addChecklist(String text, String category) => run(
    () => repository.addChecklist(id, {'text': text, 'category': category}),
  );

  Future<JourneyException?> deleteChecklist(int itemId) =>
      run(() => repository.deleteChecklist(id, itemId));

  Future<JourneyException?> saveReference(
    int? refId,
    Map<String, dynamic> data,
  ) => run(
    () =>
        refId == null
            ? repository.addReference(id, data)
            : repository.updateReference(id, refId, data),
  );

  Future<JourneyException?> deleteReference(int refId) =>
      run(() => repository.deleteReference(id, refId));

  Future<JourneyException?> delete() async {
    if (busy) return null;
    busy = true;
    _notify();
    try {
      await repository.delete(id);
      deleted = true;
      return null;
    } on JourneyException catch (e) {
      return e;
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
