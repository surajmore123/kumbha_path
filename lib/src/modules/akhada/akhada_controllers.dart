import 'package:flutter/foundation.dart';
import 'package:kumbha_path/src/modules/akhada/data/akhada_repository.dart';
import 'package:kumbha_path/src/modules/akhada/models/akhada_models.dart';

typedef PageLoader<T> = Future<ContentPage<T>> Function(int page);

/// A paged list that can be searched or filtered. When the query changes
/// mid-request, the older response is ignored.
class ContentListController<T> extends ChangeNotifier {
  ContentListController(this.loader);

  /// Reads the current search and filters; set before calling [load].
  PageLoader<T> loader;

  final List<T> items = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasNext = false;
  bool isSavedCopy = false;
  AkhadaException? error;
  AkhadaException? moreError;
  int _page = 0;
  int _request = 0;
  bool _disposed = false;

  bool get loaded => _page > 0;

  Future<void> load() async {
    final request = ++_request;
    loading = true;
    loadingMore = false;
    error = null;
    moreError = null;
    _notify();
    try {
      final page = await loader(1);
      if (request != _request) return;
      items
        ..clear()
        ..addAll(page.items);
      hasNext = page.hasNext;
      isSavedCopy = page.isSavedCopy;
      _page = 1;
    } on AkhadaException catch (e) {
      if (request != _request) return;
      items.clear();
      hasNext = false;
      error = e;
    } finally {
      if (request == _request) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasNext) return;
    final request = _request;
    loadingMore = true;
    moreError = null;
    _notify();
    try {
      final page = await loader(_page + 1);
      if (request != _request) return;
      items.addAll(page.items);
      hasNext = page.hasNext;
      _page++;
    } on AkhadaException catch (e) {
      if (request != _request) return;
      moreError = e;
    } finally {
      if (request == _request) {
        loadingMore = false;
        _notify();
      }
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
