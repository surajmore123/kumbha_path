import 'package:flutter/widgets.dart';
import 'package:kumbha_path/src/components/navigation/app_navigation.dart';

/// Opens the screen a tapped notification points to, in every app state:
///
/// - app open: tap on the notification shown by [NotificationService];
/// - app in background: `FirebaseMessaging.onMessageOpenedApp`;
/// - app closed: `FirebaseMessaging.getInitialMessage()` at start-up.
///
/// The backend sends `data.route` (and `data.type`). Only known screens
/// are opened. Until the signed-in app (the dashboard) is on screen — for
/// example while the launch screen decides between login and dashboard —
/// the request is kept and opened by [consumePending].
class NotificationRouter {
  NotificationRouter._();

  static GlobalKey<NavigatorState>? _navigatorKey;
  static String? _pending;
  static Object? _pendingArguments;

  static const String _shell = '/dashboardScreen';

  /// Screens a notification may open.
  static const Set<String> allowedRoutes = {
    '/shahiEvents',
    '/liveCroud',
    '/notifications',
    '/safetyAlerts',
    '/lostFoundCase',
    '/lostFoundOpsCase',
    '/familyMap',
    '/reunionMap',
    '/sosDetail',
    '/notificationCentre',
    '/opsCase',
  };

  static const Map<String, String> _routesByType = {
    'event_reminder': '/shahiEvents',
    'event_update': '/shahiEvents',
    'new_event': '/shahiEvents',
    'crowd_alert': '/liveCroud',
    'safety_alert': '/notifications',
    'family_safety_alert': '/safetyAlerts',
    'lostfound_case': '/lostFoundCase',
    'family_location': '/familyMap',
    'family_reunion': '/reunionMap',
    'emergency_sos': '/sosDetail',
    'operations_case': '/opsCase',
  };

  static void attach(GlobalKey<NavigatorState> key) => _navigatorKey = key;

  /// The screen for a notification's data, or null.
  static String? routeFor(Map<String, dynamic>? data) {
    if (data == null) return null;
    final route = data['route'];
    if (route is String && allowedRoutes.contains(route)) return route;
    final type = data['type'];
    return type is String ? _routesByType[type] : null;
  }

  /// What a screen needs to open. A case id only: the server decides whether
  /// this person may see that case when the screen asks for it.
  static Object? argumentsFor(String route, Map<String, dynamic>? data) {
    if (route == '/sosDetail') {
      final id = data?['sos_id'];
      return id is String && _uuid.hasMatch(id) ? id : null;
    }
    if (route == '/reunionMap') {
      String? id(String key) {
        final value = data?[key];
        return value is String && _uuid.hasMatch(value) ? value : null;
      }

      return <String, String>{
        if (id('family_id') != null) 'family_id': id('family_id')!,
        if (id('point_id') != null) 'point_id': id('point_id')!,
      };
    }
    if (route == '/familyMap') {
      final family = data?['family_id'];
      return family is String && _uuid.hasMatch(family) ? family : null;
    }
    if (route != '/lostFoundCase' &&
        route != '/lostFoundOpsCase' &&
        route != '/opsCase') {
      return null;
    }
    final id = data?['case_id'];
    return id is String && _uuid.hasMatch(id) ? id : null;
  }

  static final _uuid = RegExp(r'^[0-9a-fA-F-]{36}$');

  static void open(Map<String, dynamic>? data) {
    final route = routeFor(data);
    if (route == null) return;
    final arguments = argumentsFor(route, data);
    if ((route == '/lostFoundCase' ||
            route == '/lostFoundOpsCase' ||
            route == '/opsCase' ||
            route == '/sosDetail') &&
        arguments == null) {
      return;
    }
    final navigator = _navigatorKey?.currentState;
    if (navigator == null || !AppNavigation.observer.contains(_shell)) {
      _pending = route;
      _pendingArguments = arguments;
      return;
    }
    _pending = null;
    _pendingArguments = null;
    navigator.pushNamed(route, arguments: arguments);
  }

  /// Called once the dashboard is visible.
  static void consumePending() {
    final route = _pending;
    if (route == null) return;
    final arguments = _pendingArguments;
    _pending = null;
    _pendingArguments = null;
    _navigatorKey?.currentState?.pushNamed(route, arguments: arguments);
  }

  @visibleForTesting
  static String? get pendingRoute => _pending;

  @visibleForTesting
  static void reset() {
    _pending = null;
    _pendingArguments = null;
    _navigatorKey = null;
  }
}
