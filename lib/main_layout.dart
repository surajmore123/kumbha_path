import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kumbha_path/src/components/buttons/app_button.dart';
import 'package:kumbha_path/src/components/navigation/app_bottom_navigation.dart';
import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

/// The app shell: a [Scaffold] that adds the primary navigation and system
/// bar styling around a feature screen.
///
/// Constructor is unchanged. `ctx` is the screen's tab (0 Home, 1 AI Chat,
/// 2 Events, 3 Journal, 4 Profile) and is used when the current route has
/// no name; named routes are mapped by [AppNavigation.selectedIndexFor].
///
/// When `showDefaultBottom` is true:
/// * phone widths (< [AppBreakpoints.mobile]) get [AppBottomNavigation];
/// * wider layouts get [AppNavigationRail] beside the content.
class MainLayout extends StatefulWidget {
  final Widget? bottomNavigationBar;
  final Widget? body;
  final bool? showDefaultBottom;
  final bool? showCurvedAppBar;
  final bool? showFloatingActionButton;
  final String? title;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;

  final int ctx;
  const MainLayout({
    super.key,
    this.bottomNavigationBar,
    this.showDefaultBottom = false,
    this.ctx = 0,
    this.showCurvedAppBar = false,
    this.body,
    this.showFloatingActionButton = false,
    this.title,
    this.appBar,
    this.backgroundColor,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final showNav = widget.showDefaultBottom == true;
    final useRail = showNav && !context.isMobile;
    final selectedIndex = AppNavigation.selectedIndexFor(context, widget.ctx);
    final background = widget.backgroundColor ?? theme.scaffoldBackgroundColor;

    Widget? body = widget.body;
    if (useRail && body != null) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            right: false,
            child: AppNavigationRail(currentIndex: selectedIndex),
          ),
          VerticalDivider(width: 1, thickness: 1, color: semantic.divider),
          Expanded(child: body),
        ],
      );
    }

    final Widget? bottomBar =
        !showNav
            ? widget.bottomNavigationBar
            : useRail
            ? null
            : AppBottomNavigation(currentIndex: selectedIndex);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemOverlayStyle(
        theme.brightness,
        navigationBarColor:
            bottomBar != null ? semantic.navigationSurface : background,
      ),
      child: Scaffold(
        backgroundColor: background,
        resizeToAvoidBottomInset: true,
        appBar: widget.appBar,
        body: body,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton:
            (widget.showFloatingActionButton == false)
                ? null
                : Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  child: AppButton(
                    label: widget.title ?? '',
                    // Preserves the original no-op tap.
                    onPressed: () {},
                  ),
                ),
        bottomNavigationBar: bottomBar,
      ),
    );
  }
}
