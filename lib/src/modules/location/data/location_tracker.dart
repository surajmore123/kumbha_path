import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/modules/family/offline/contact_sync.dart'
    show connectivityChanges;
import 'package:kumbha_path/src/modules/location/data/location_repository.dart';
import 'package:kumbha_path/src/modules/location/models/location_models.dart';
import 'package:permission_handler/permission_handler.dart' as handler;

/// Whether this phone can give a position, and why not.
enum LocationPermit { allowed, approximate, denied, blocked, servicesOff }

/// The phone's location, kept behind an interface so sharing can be tested
/// without GPS.
abstract class PositionSource {
  Future<LocationPermit> check();

  /// Shows the system prompt. Only called after the app has explained why.
  Future<LocationPermit> request();

  /// Android needs a visible notification to keep going in the background.
  Future<bool> notificationsAllowed();

  Stream<LocationFix> watch({
    required int distanceMetres,
    required int seconds,
    required String title,
    required String text,
  });

  Future<LocationFix?> current();
  Future<void> openLocationSettings();
  Future<void> openAppSettings();
}

class GeolocatorSource implements PositionSource {
  const GeolocatorSource();

  Future<LocationPermit> _permit(LocationPermission permission) async {
    switch (permission) {
      case LocationPermission.deniedForever:
        return LocationPermit.blocked;
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        final accuracy = await Geolocator.getLocationAccuracy();
        return accuracy == LocationAccuracyStatus.reduced
            ? LocationPermit.approximate
            : LocationPermit.allowed;
      default:
        return LocationPermit.denied;
    }
  }

  @override
  Future<LocationPermit> check() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationPermit.servicesOff;
      }
      return _permit(await Geolocator.checkPermission());
    } catch (_) {
      return LocationPermit.denied;
    }
  }

  @override
  Future<LocationPermit> request() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationPermit.servicesOff;
      }
      final permit = await _permit(await Geolocator.requestPermission());
      if (Platform.isAndroid &&
          (permit == LocationPermit.allowed ||
              permit == LocationPermit.approximate)) {
        // Without this, Android hides the notification that shows sharing is on.
        await handler.Permission.notification.request();
      }
      return permit;
    } catch (_) {
      return LocationPermit.denied;
    }
  }

  @override
  Future<bool> notificationsAllowed() async {
    if (!Platform.isAndroid) return true;
    try {
      return await handler.Permission.notification.isGranted;
    } catch (_) {
      return true;
    }
  }

  static LocationFix _fix(Position p) => LocationFix(
    latitude: p.latitude,
    longitude: p.longitude,
    capturedAt: p.timestamp,
    accuracyM: p.accuracy >= 0 ? p.accuracy : null,
    // iOS reports -1 when it doesn't know.
    speedMps: p.speed >= 0 ? p.speed : null,
    heading: p.heading >= 0 && p.heading <= 360 ? p.heading : null,
  );

  @override
  Stream<LocationFix> watch({
    required int distanceMetres,
    required int seconds,
    required String title,
    required String text,
  }) {
    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceMetres,
        intervalDuration: Duration(seconds: seconds),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: title,
          notificationText: text,
          setOngoing: true,
        ),
      );
    } else if (Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.other,
        distanceFilter: distanceMetres,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      settings = LocationSettings(distanceFilter: distanceMetres);
    }
    return Geolocator.getPositionStream(locationSettings: settings).map(_fix);
  }

  @override
  Future<LocationFix?> current() async {
    try {
      return _fix(
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}

/// What's remembered between runs: the session this phone reports, and any
/// stop that hasn't reached the server. Never a position.
abstract class TrackerStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class SecureTrackerStore implements TrackerStore {
  const SecureTrackerStore();

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> write(String key, String? value) =>
      value == null
          ? storage.delete(key: key)
          : storage.write(key: key, value: value);
}

enum TrackerState {
  /// Not sharing, and collecting nothing.
  idle,

  /// Collecting and sending.
  sharing,

  /// On purpose: nothing is collected.
  paused,

  /// Sharing is on, but this phone can't give a position.
  interrupted,
}

/// Collects this phone's position while a sharing session is open, and at no
/// other time. Starts only from [begin] (the person just agreed) or [start]
/// (a session they agreed to is still open), and every way out stops the GPS.
///
/// Holds at most one unsent position. While offline a newer one replaces it,
/// so returning online sends the latest with its real time, not a backlog.
class LocationTracker extends ChangeNotifier with WidgetsBindingObserver {
  LocationTracker({
    required this.repository,
    PositionSource source = const GeolocatorSource(),
    TrackerStore store = const SecureTrackerStore(),
    Stream<bool>? online,
    DateTime Function()? clock,
    this.notificationTitle = '',
    this.notificationText = '',
  }) : _source = source,
       _store = store,
       _online = online,
       _clock = clock ?? DateTime.now;

  static const _sessionKey = 'location_session_id';
  static const _endsKey = 'location_session_ends';
  static const _stopKey = 'location_pending_stop';

  final LocationRepository repository;
  final PositionSource _source;
  final TrackerStore _store;
  final Stream<bool>? _online;
  final DateTime Function() _clock;

  String notificationTitle;
  String notificationText;

  TrackerState _state = TrackerState.idle;
  TrackerState get state => _state;

  LocationPermit _permit = LocationPermit.allowed;
  LocationPermit get permit => _permit;

  bool _notifications = true;

  /// False on Android when the sharing notification can't be shown.
  bool get notificationsAllowed => _notifications;

  String? _sessionId;
  String? get sessionId => _sessionId;

  DateTime? _lastSentAt;
  DateTime? get lastSentAt => _lastSentAt;

  LocationFix? _pending;
  bool get hasUnsent => _pending != null;

  bool _noNetwork = false;
  bool _sendFailed = false;

  /// Positions can't reach the server right now.
  bool get offline => _noNetwork || _sendFailed;

  /// The session ended on its own, for the screen to say so once.
  String? _endedStatus;
  String? get endedStatus => _endedStatus;

  DateTime? _endsAt;
  int _updateSeconds = 30;
  int _distance = 25;
  bool _sending = false;
  bool _started = false;

  StreamSubscription<LocationFix>? _watch;
  StreamSubscription<bool>? _connection;
  Timer? _expiry;
  Timer? _heartbeat;
  Timer? _flushLater;

  bool get collecting => _watch != null;

  void _set(TrackerState state) {
    _state = state;
    notifyListeners();
  }

  /// Once, at app start. Carries on a session that's still open, and retries
  /// a stop that couldn't be delivered.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // No binding in plain unit tests.
    }
    _connection = (_online ?? connectivityChanges()).listen(_onConnection);
    await _sendPendingStop();
    final id = await _read(_sessionKey);
    final ends = DateTime.tryParse(await _read(_endsKey) ?? '');
    if (id == null || ends == null) return;
    if (!ends.isAfter(_clock())) {
      await _forget();
      return;
    }
    try {
      final session = await repository.session(id);
      if (!session.isOpen || !session.reportsFromMe) {
        await _forget();
      } else {
        await _follow(session);
      }
    } on FamilyException catch (e) {
      if (e.kind == FamilyFailure.offline || e.kind == FamilyFailure.server) {
        // Can't check, and the agreed time hasn't passed: carry on, and let
        // the server have the final word when it's reachable.
        _sessionId = id;
        _endsAt = ends;
        await _beginCollecting();
      } else {
        await _forget();
      }
    }
  }

  Future<String?> _read(String key) async {
    try {
      return await _store.read(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, String? value) async {
    try {
      await _store.write(key, value);
    } catch (_) {
      // Sharing still ends by itself on the server.
    }
  }

  Future<LocationPermit> checkAccess() async {
    _permit = await _source.check();
    _notifications = await _source.notificationsAllowed();
    notifyListeners();
    return _permit;
  }

  Future<LocationPermit> requestAccess() async {
    _permit = await _source.request();
    _notifications = await _source.notificationsAllowed();
    notifyListeners();
    return _permit;
  }

  Future<void> openLocationSettings() => _source.openLocationSettings();
  Future<void> openAppSettings() => _source.openAppSettings();

  bool get _usable =>
      _permit == LocationPermit.allowed ||
      _permit == LocationPermit.approximate;

  /// The person just agreed and the server has the session.
  Future<void> begin(SharingSession session) async {
    _endedStatus = null;
    await _follow(session);
  }

  /// Matches this phone to the server's view of a session.
  Future<void> _follow(SharingSession session) async {
    _sessionId = session.id;
    _endsAt = session.endsAt;
    _updateSeconds = session.updateSeconds;
    _distance = session.distanceMetres;
    await _write(_sessionKey, session.id);
    await _write(_endsKey, session.endsAt.toUtc().toIso8601String());
    _armExpiry();
    if (session.isPaused) {
      _stopCollecting();
      _set(TrackerState.paused);
    } else if (!collecting) {
      await _beginCollecting();
    }
  }

  /// Keeps the phone in step after a change made on the management screen.
  Future<void> sync(SharingSession session) async {
    if (!session.reportsFromMe) return;
    if (!session.isOpen) {
      await _finish(session.status);
    } else {
      await _follow(session);
    }
  }

  void _armExpiry() {
    _expiry?.cancel();
    final ends = _endsAt;
    if (ends == null) return;
    final left = ends.difference(_clock());
    _expiry = Timer(left.isNegative ? Duration.zero : left, () {
      _finish('expired');
    });
  }

  Future<void> _beginCollecting() async {
    _armExpiry();
    await checkAccess();
    if (!_usable) {
      _stopCollecting();
      _set(TrackerState.interrupted);
      return;
    }
    _stopCollecting();
    _watch = _source
        .watch(
          distanceMetres: _distance,
          seconds: _updateSeconds,
          title: notificationTitle,
          text: notificationText,
        )
        .listen(
          _onFix,
          onError: (_) {
            _stopCollecting();
            _set(TrackerState.interrupted);
          },
        );
    // The stream only speaks when the phone moves. Someone standing still is
    // still sharing, so a real reading is taken now and then to prove it.
    _heartbeat = Timer.periodic(
      Duration(seconds: _updateSeconds * 3),
      (_) => unawaited(_beat()),
    );
    _set(TrackerState.sharing);
    unawaited(_beat());
  }

  Future<void> _beat() async {
    if (!collecting) return;
    final fix = await _source.current();
    if (fix != null && collecting) _onFix(fix);
  }

  void _stopCollecting() {
    _watch?.cancel();
    _watch = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _flushLater?.cancel();
    _flushLater = null;
  }

  void _onFix(LocationFix fix) {
    final held = _pending;
    if (held != null && !fix.capturedAt.isAfter(held.capturedAt)) return;
    _pending = fix;
    if (_state == TrackerState.interrupted) _set(TrackerState.sharing);
    _flush();
  }

  /// Sends the newest position, no more often than the session allows.
  Future<void> _flush() async {
    final id = _sessionId;
    if (id == null || _sending || _pending == null || _noNetwork) return;
    if (_state == TrackerState.paused) return;
    final last = _lastSentAt;
    if (last != null) {
      final wait = last
          .add(Duration(seconds: _updateSeconds))
          .difference(_clock());
      if (wait > Duration.zero) {
        _flushLater ??= Timer(wait, () {
          _flushLater = null;
          _flush();
        });
        return;
      }
    }
    final fix = _pending!;
    _sending = true;
    try {
      await repository.sendUpdate(id, fix);
      if (identical(_pending, fix)) _pending = null;
      _lastSentAt = _clock();
      _sendFailed = false;
      notifyListeners();
    } on SharingClosed catch (closed) {
      if (closed.status == 'paused') {
        _pending = null;
        _stopCollecting();
        _set(TrackerState.paused);
      } else {
        await _finish(closed.status);
      }
    } on FamilyException catch (e) {
      if (e.kind == FamilyFailure.notFound ||
          e.kind == FamilyFailure.forbidden ||
          e.kind == FamilyFailure.signedOut) {
        await _finish('stopped');
      } else if (e.kind == FamilyFailure.offline) {
        _sendFailed = true;
        notifyListeners();
      }
      // Anything else: the newest position stays held for the next try.
    } catch (_) {
      // Held for the next try.
    } finally {
      _sending = false;
    }
    if (_pending != null && !identical(_pending, fix)) unawaited(_flush());
  }

  void _onConnection(bool connected) {
    final was = offline;
    _noNetwork = !connected;
    if (connected) _sendFailed = false;
    if (was != offline) notifyListeners();
    if (connected) {
      unawaited(_sendPendingStop());
      unawaited(_flush());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_sessionId == null) return;
    // GPS or permission may have changed in Settings.
    unawaited(_recheck());
  }

  Future<void> _recheck() async {
    if (_state == TrackerState.paused || _sessionId == null) return;
    await checkAccess();
    if (_usable && !collecting) {
      await _beginCollecting();
    } else if (!_usable && collecting) {
      _stopCollecting();
      _set(TrackerState.interrupted);
    }
    unawaited(_flush());
  }

  /// Local pause, once the server has agreed.
  void markPaused() {
    _pending = null;
    _stopCollecting();
    _set(TrackerState.paused);
  }

  /// Stops at once on this phone, even with no connection. Returns false if
  /// the server hasn't heard yet, in which case it's retried.
  Future<bool> stop(String id) async {
    final mine = id == _sessionId;
    if (mine) await _clear(TrackerState.idle);
    try {
      await repository.stop(id);
      return true;
    } on FamilyException catch (e) {
      if (e.kind == FamilyFailure.offline || e.kind == FamilyFailure.server) {
        await _write(_stopKey, id);
        return false;
      }
      return true;
    }
  }

  Future<void> _sendPendingStop() async {
    final id = await _read(_stopKey);
    if (id == null) return;
    try {
      await repository.stop(id);
      await _write(_stopKey, null);
    } on FamilyException catch (e) {
      if (e.kind != FamilyFailure.offline && e.kind != FamilyFailure.server) {
        await _write(_stopKey, null);
      }
    }
  }

  Future<void> _finish(String status) async {
    _endedStatus = status;
    await _clear(TrackerState.idle);
  }

  void clearEnded() => _endedStatus = null;

  Future<void> _clear(TrackerState next) async {
    _stopCollecting();
    _expiry?.cancel();
    _expiry = null;
    _pending = null;
    _sessionId = null;
    _endsAt = null;
    _lastSentAt = null;
    await _forget();
    _set(next);
  }

  Future<void> _forget() async {
    await _write(_sessionKey, null);
    await _write(_endsKey, null);
  }

  /// Before the sign-in token goes, so the server can be told too.
  Future<void> signOut() async {
    final id = _sessionId;
    if (id != null) {
      try {
        await stop(id);
      } catch (_) {
        // It ends by itself at its expiry.
      }
    }
    await _clear(TrackerState.idle);
    _endedStatus = null;
    await _write(_stopKey, null);
    LocationServices.lastFeed.clear();
  }

  @override
  void dispose() {
    _stopCollecting();
    _expiry?.cancel();
    _connection?.cancel();
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {
      // No binding in plain unit tests.
    }
    super.dispose();
  }
}

class LocationSharing {
  LocationSharing._();

  static LocationTracker? _tracker;

  static LocationTracker get tracker =>
      _tracker ??= LocationTracker(repository: LocationServices.repository);

  @visibleForTesting
  static set tracker(LocationTracker value) => _tracker = value;
}
