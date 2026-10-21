import 'package:flutter/material.dart';

/// A primary destination in the app shell's navigation.
@immutable
class AppNavDestination {
  const AppNavDestination({
    required this.route,
    required this.labelKey,
    required this.icon,
    required this.selectedIcon,
  });

  /// Named route from `AppRouter`.
  final String route;

  /// easy_localization key in assets/translations.
  final String labelKey;
  final IconData icon;
  final IconData selectedIcon;
}

/// Destinations and tab-switching behavior shared by the bottom bar and the
/// wide-screen rail.
///
/// Built on the existing Navigator 1.0 named routes (`AppRouter`); it only
/// decides *how* to reach a tab:
///
/// * Already on that tab's screen: nothing happens (as before).
/// * The tab's screen is already in the back stack: pop back to it, so its
///   state, scroll position and loaded data are kept and the stack doesn't
///   fill with duplicates.
/// * Otherwise: `Navigator.pushNamed`, exactly as before.
abstract final class AppNavigation {
  /// Order matches the `ctx` index screens pass to `MainLayout`.
  static const List<AppNavDestination> destinations = [
    AppNavDestination(
      route: '/dashboardScreen',
      labelKey: 'nav_home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    AppNavDestination(
      route: '/aichat',
      labelKey: 'nav_ai_chat',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
    ),
    AppNavDestination(
      route: '/shahiEvents',
      labelKey: 'nav_events',
      icon: Icons.event_outlined,
      selectedIcon: Icons.event_rounded,
    ),
    AppNavDestination(
      route: '/journal',
      labelKey: 'nav_journal',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book_rounded,
    ),
    AppNavDestination(
      route: '/setting',
      labelKey: 'nav_profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  static const int homeIndex = 0;

  /// Non-tab screens and the tab section they belong to. These are all
  /// opened from Home, so Home stays highlighted and tapping it returns there.
  static const Map<String, int> sectionOfRoute = {
    '/notifications': homeIndex,
    '/liveCroud': homeIndex,
    '/nearTemples': homeIndex,
    '/templeDetail': homeIndex,
  };

  /// Register in `MaterialApp.navigatorObservers`.
  static final AppRouteObserver observer = AppRouteObserver();

  static int? indexOfRoute(String? route) {
    if (route == null) return null;
    final index = destinations.indexWhere((d) => d.route == route);
    return index >= 0 ? index : sectionOfRoute[route];
  }

  /// Tab to highlight for the screen at [context]. Uses the current route
  /// name when known; falls back to the screen's own `ctx` for routes pushed
  /// without a name.
  static int selectedIndexFor(BuildContext context, int fallback) {
    final name = ModalRoute.of(context)?.settings.name;
    return indexOfRoute(name) ?? fallback;
  }

  /// Navigates to tab [index] from the screen at [context], whose own
  /// highlighted tab is [currentIndex].
  static void select(BuildContext context, int index, int currentIndex) {
    final target = destinations[index].route;
    final currentName = ModalRoute.of(context)?.settings.name;

    // Screens on an unmapped (or unnamed) route keep the original rule:
    // tapping their own `ctx` tab is a no-op.
    final onTarget =
        currentName == target ||
        (indexOfRoute(currentName) == null && index == currentIndex);
    if (onTarget) return;

    final navigator = Navigator.of(context);
    if (observer.navigator == navigator && observer.contains(target)) {
      // isFirst guards against ever popping the last route.
      navigator.popUntil(
        (route) => route.settings.name == target || route.isFirst,
      );
    } else {
      navigator.pushNamed(target);
    }
  }
}

/// Tracks the route names on the root navigator's stack so tab switches can
/// return to an existing screen instead of pushing a duplicate. Observes
/// only; never navigates.
class AppRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> _stack = [];

  bool contains(String routeName) =>
      _stack.any((route) => route.settings.name == routeName);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _stack.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (newRoute is! PageRoute) {
      if (index >= 0) _stack.removeAt(index);
      return;
    }
    if (index >= 0) {
      _stack[index] = newRoute;
    } else {
      _stack.add(newRoute);
    }
  }
}
