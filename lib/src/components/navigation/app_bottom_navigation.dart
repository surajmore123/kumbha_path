import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/navigation/app_navigation.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

export 'package:kumbha_path/src/components/navigation/app_navigation.dart'
    show AppNavDestination, AppNavigation;

/// The app's bottom navigation bar for phone-width layouts. `MainLayout`
/// shows it when `showDefaultBottom` is true (wide layouts use
/// [AppNavigationRail] instead).
///
/// Uses Material 3 [NavigationBar] rather than [BottomNavigationBar] because
/// the latter clamps label text scaling to 1.0, which would ignore the
/// user's font-size preference. Colors, label styles, height and the
/// indicator come from `navigationBarTheme` in [AppTheme]. NavigationBar
/// pads itself for the gesture / system navigation area.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    this.onDestinationSelected,
  });

  /// Index into [destinations]. Out-of-range values select nothing.
  final int currentIndex;

  /// Overrides the default [AppNavigation.select] behavior. Mainly for tests.
  final ValueChanged<int>? onDestinationSelected;

  static List<AppNavDestination> get destinations => AppNavigation.destinations;

  @override
  Widget build(BuildContext context) {
    final count = AppNavigation.destinations.length;
    final inRange = currentIndex >= 0 && currentIndex < count;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.semanticColors.divider)),
      ),
      child: NavigationBar(
        selectedIndex: inRange ? currentIndex : 0,
        // No false highlight when the screen isn't part of any tab.
        indicatorColor: inRange ? null : Colors.transparent,
        onDestinationSelected:
            onDestinationSelected ??
            (index) => AppNavigation.select(context, index, currentIndex),
        destinations: [
          for (final d in AppNavigation.destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(inRange ? d.selectedIcon : d.icon),
              label: d.labelKey.tr(),
            ),
        ],
      ),
    );
  }
}

/// Side navigation for tablet / desktop widths, with the same destinations
/// and behavior as [AppBottomNavigation].
class AppNavigationRail extends StatelessWidget {
  const AppNavigationRail({
    super.key,
    required this.currentIndex,
    this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int>? onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final count = AppNavigation.destinations.length;
    final inRange = currentIndex >= 0 && currentIndex < count;

    return NavigationRail(
      selectedIndex: inRange ? currentIndex : null,
      labelType: NavigationRailLabelType.all,
      groupAlignment: -1,
      onDestinationSelected:
          onDestinationSelected ??
          (index) => AppNavigation.select(context, index, currentIndex),
      destinations: [
        for (final d in AppNavigation.destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.labelKey.tr(), textAlign: TextAlign.center),
          ),
      ],
    );
  }
}
