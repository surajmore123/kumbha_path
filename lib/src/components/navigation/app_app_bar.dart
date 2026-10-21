import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

/// Standard top app bar.
///
/// Background, foreground, elevation and title style come from
/// `appBarTheme` in [AppTheme]. Pass it anywhere a [PreferredSizeWidget] is
/// accepted, including `MainLayout(appBar: ...)`.
///
/// Back navigation: by default a back button is shown only when the route
/// can pop, and it calls `Navigator.maybePop` (same as Flutter's default),
/// so system back, `WillPopScope` / `PopScope` and existing routes behave as
/// before. Supply [onBack] to override.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.actions,
    this.showBackButton,
    this.onBack,
    this.leading,
    this.centerTitle,
    this.bottom,
    this.backgroundColor,
  }) : assert(
         title == null || titleWidget == null,
         'Provide either title or titleWidget, not both.',
       );

  final String? title;

  /// Custom title content, e.g. a logo row.
  final Widget? titleWidget;

  /// Secondary line under [title].
  final String? subtitle;
  final List<Widget>? actions;

  /// `null` = automatic (shown when the route can pop).
  final bool? showBackButton;
  final VoidCallback? onBack;

  /// Replaces the back button entirely.
  final Widget? leading;
  final bool? centerTitle;
  final PreferredSizeWidget? bottom;

  /// Override for bars over imagery. Prefer the theme default.
  final Color? backgroundColor;

  static const double _subtitleToolbarHeight = 64;
  static const double _maxSubtitleTextScale = 1.3;

  double get _toolbarHeight =>
      subtitle != null ? _subtitleToolbarHeight : kToolbarHeight;

  @override
  Size get preferredSize =>
      Size.fromHeight(_toolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final text = context.textTheme;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final showBack = showBackButton ?? canPop;

    Widget? leadingWidget = leading;
    if (leadingWidget == null && showBack) {
      leadingWidget = IconButton(
        icon: const BackButtonIcon(),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: onBack ?? () => Navigator.maybePop(context),
      );
    }

    Widget? titleContent = titleWidget;
    if (title != null) {
      final titleText = Text(
        title!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.titleLarge,
      );
      titleContent =
          subtitle == null
              ? titleText
              // The toolbar height is fixed (Scaffold reads preferredSize
              // before build), so the two-line variant caps text growth at
              // 1.3x, like Material's NavigationBar, instead of overflowing.
              // That still covers the Large preset (1.15x).
              : MediaQuery.withClampedTextScaling(
                maxScaleFactor: _maxSubtitleTextScale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      (centerTitle ?? false)
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                  children: [
                    titleText,
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
    }

    return AppBar(
      title: titleContent,
      leading: leadingWidget,
      automaticallyImplyLeading: false,
      actions: actions,
      centerTitle: centerTitle,
      bottom: bottom,
      toolbarHeight: _toolbarHeight,
      backgroundColor: backgroundColor,
      titleSpacing: leadingWidget == null ? AppSpacing.pageGutter : 0,
    );
  }
}
