import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';

/// Load state of one feed.
enum FeedStatus { loading, ready, failed }

/// One screen section backed by its own [AppDetailsBloc] instance.
///
/// The app-wide AppDetailsBloc keeps a single `status` for every feature, so
/// firing several requests into it would make sections (and other screens
/// listening to that status) see each other's loading / failed states. Each feed therefore uses a private instance of the *same* bloc,
/// with the same events, repository calls and response parsing.
class AppDetailsFeed {
  AppDetailsFeed({
    required AppDetailsEvent Function() request,
    required bool Function(AppDetailsStatus status) isReady,
    required bool Function(AppDetailsStatus status) isFailed,
    Bloc<AppDetailsEvent, AppDetailsState>? bloc,
    this.timeout = const Duration(seconds: 30),
  }) : _request = request,
       _isReady = isReady,
       _isFailed = isFailed,
       bloc = bloc ?? AppDetailsBloc() {
    _subscription = this.bloc.stream.listen(_onState);
  }

  /// A private [AppDetailsBloc] in the app; any bloc of the same types in
  /// tests.
  final Bloc<AppDetailsEvent, AppDetailsState> bloc;
  final AppDetailsEvent Function() _request;
  final bool Function(AppDetailsStatus) _isReady;
  final bool Function(AppDetailsStatus) _isFailed;

  /// A request still loading after this is reported as failed, so a stalled
  /// connection or an unexpected response never leaves a spinner forever.
  final Duration timeout;

  final ValueNotifier<FeedStatus> status = ValueNotifier(FeedStatus.loading);

  /// Device time when data last arrived. Shown as "checked at", never as a
  /// server timestamp.
  DateTime? lastUpdated;

  late final StreamSubscription<AppDetailsState> _subscription;
  Timer? _watchdog;
  Completer<void>? _settled;
  bool _hasRequested = false;

  bool get hasRequested => _hasRequested;

  void _onState(AppDetailsState state) {
    if (_isReady(state.status)) {
      lastUpdated = DateTime.now();
      _finish(FeedStatus.ready);
    } else if (_isFailed(state.status)) {
      _finish(FeedStatus.failed);
    }
  }

  void _finish(FeedStatus result) {
    _watchdog?.cancel();
    status.value = result;
    if (!(_settled?.isCompleted ?? true)) _settled!.complete();
  }

  /// Starts a request. Ignored while one is already in flight, so taps and
  /// pull-to-refresh can't stack duplicate calls.
  Future<void> load() {
    if (_hasRequested && status.value == FeedStatus.loading) {
      return _settled?.future ?? Future.value();
    }
    _hasRequested = true;
    status.value = FeedStatus.loading;
    _settled = Completer<void>();
    _watchdog?.cancel();
    _watchdog = Timer(timeout, () => _finish(FeedStatus.failed));
    bloc.add(_request());
    return _settled!.future;
  }

  void dispose() {
    _watchdog?.cancel();
    _subscription.cancel();
    status.dispose();
    bloc.close();
  }
}
