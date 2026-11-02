import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

/// One tab of the [ExploreHub].
@immutable
class ExploreTab {
  const ExploreTab({
    required this.icon,
    required this.labelKey,
    required this.builder,
    this.actionLabelKey,
    this.onAction,
  });

  final IconData icon;
  final String labelKey;

  /// The preview shown when the tab is selected (built only then).
  final WidgetBuilder builder;

  /// Link to the full screen, under the preview ("See all", "Open map").
  final String? actionLabelKey;
  final VoidCallback? onAction;
}

/// The dashboard's feature previews in one place: a row of tabs (all
/// features visible at once where they fit) and the selected preview below. Instead of
/// stacking every section, which made the page long, only one preview takes
/// space. Tap a tab, or swipe the preview sideways, to switch.
class ExploreHub extends StatefulWidget {
  const ExploreHub({super.key, required this.tabs, this.initialIndex = 0});

  final List<ExploreTab> tabs;
  final int initialIndex;

  @override
  State<ExploreHub> createState() => _ExploreHubState();
}

class _ExploreHubState extends State<ExploreHub> {
  late int _index = widget.initialIndex.clamp(0, widget.tabs.length - 1);

  void _select(int index) {
    if (index == _index || index < 0 || index >= widget.tabs.length) return;
    setState(() => _index = index);
  }

  void _onSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 300) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final forward = (velocity < 0) != rtl;
    _select(_index + (forward ? 1 : -1));
  }

  @override
  Widget build(BuildContext context) {
    final tab = widget.tabs[_index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TabStrip(tabs: widget.tabs, selected: _index, onSelect: _select),
        AppSpacing.gapMd,
        GestureDetector(
          onHorizontalDragEnd: _onSwipe,
          behavior: HitTestBehavior.translucent,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            curve: Curves.easeOut,
            child: KeyedSubtree(
              key: ValueKey(_index),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tab.builder(context),
                  if (tab.actionLabelKey != null && tab.onAction != null)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: tab.onAction,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: Text(tab.actionLabelKey!.tr()),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  final List<ExploreTab> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  /// Narrowest a tab can be before its label is cut off (at 1x text).
  static const double _minTabWidth = 56;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: AppRadius.lgAll,
      ),
      // Tabs share the width equally; on a narrow screen or with large
      // text, where labels would be cut off, the strip scrolls instead.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minTab = MediaQuery.textScalerOf(context).scale(_minTabWidth);
          Widget button(int i) => _TabButton(
            tab: tabs[i],
            selected: i == selected,
            onTap: () => onSelect(i),
          );
          if (constraints.maxWidth >= minTab * tabs.length) {
            return Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(child: button(i)),
              ],
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  SizedBox(width: minTab, child: button(i)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final ExploreTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final fg = selected ? colors.onPrimaryContainer : colors.onSurfaceVariant;
    final label = tab.labelKey.tr();
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.primaryContainer : Colors.transparent,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxs,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tab.icon, size: 20, color: fg),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
