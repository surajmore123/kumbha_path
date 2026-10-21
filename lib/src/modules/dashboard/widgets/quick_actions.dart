import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

@immutable
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.labelKey,
    required this.onTap,
  });

  final IconData icon;
  final String labelKey;
  final VoidCallback onTap;
}

/// Four equal shortcuts: 2×2 on phones, one row of 4 when there is room.
/// AI Explorer and Journal have their own richer sections (and tabs), so
/// they are not repeated here.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key, required this.actions});

  final List<QuickAction> actions;

  static const double _fourColumnMinWidth = 520;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= _fourColumnMinWidth ? actions.length : 2;
        final rows = <Widget>[];
        for (var i = 0; i < actions.length; i += columns) {
          final slice = actions.skip(i).take(columns).toList();
          if (rows.isNotEmpty) rows.add(AppSpacing.gapMd);
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < columns; j++) ...[
                    if (j > 0) AppSpacing.gapMd,
                    Expanded(
                      child:
                          j < slice.length
                              ? _QuickActionTile(action: slice[j])
                              : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final label = action.labelKey.tr();
    return AppCard(
      onTap: action.onTap,
      semanticLabel: label,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: AppSpacing.minTouchTarget,
            height: AppSpacing.minTouchTarget,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(action.icon, color: colors.onPrimaryContainer),
          ),
          AppSpacing.gapSm,
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
