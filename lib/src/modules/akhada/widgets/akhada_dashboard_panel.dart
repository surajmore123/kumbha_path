import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/akhada/akhadas_screens.dart';

/// Dashboard "Akhadas" tab: shortcuts into the module. It loads nothing, so
/// it can't slow the dashboard or fail on it.
class AkhadaDashboardPanel extends StatelessWidget {
  const AkhadaDashboardPanel({super.key, required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.filled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ak_title'.tr(), style: context.textTheme.titleMedium),
          AppSpacing.gapXs,
          Text('ak_pitch'.tr(), style: context.textTheme.bodyMedium),
          AppSpacing.gapMd,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final s in AkhadaSection.all)
                ActionChip(
                  avatar: Icon(s.icon, size: 18),
                  label: Text(s.titleKey.tr()),
                  onPressed: () => onOpen(s.route),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
