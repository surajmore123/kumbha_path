import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart';

/// One line on the dashboard, in the Quick Access spot above the panels. It
/// names the family, or says a family hasn't been set up.
class FamilyDashboardEntry extends StatefulWidget {
  const FamilyDashboardEntry({super.key, required this.onOpen});

  final Future<void> Function() onOpen;

  @override
  State<FamilyDashboardEntry> createState() => _FamilyDashboardEntryState();
}

class _FamilyDashboardEntryState extends State<FamilyDashboardEntry> {
  FamilyCircle? _circle;
  int _invites = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = FamilyServices.repository;
      final circles = await repo.circles();
      final invites = await repo.myInvitations();
      if (!mounted) return;
      setState(() {
        _circle = circles.firstOrNull;
        _invites = invites.length;
      });
    } catch (_) {
      // Signed out or offline: the entry still opens the feature.
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final colors = context.colorScheme;
    final circle = _circle;
    final line =
        _invites > 0
            ? 'fam_entry_invites'.plural(_invites)
            : circle == null
            ? 'fam_entry_empty'.tr()
            : '${circle.name}  ·  ${'fam_member_count'.plural(circle.memberCount)}';
    return Pressable(
      onTap: () async {
        await widget.onOpen();
        if (mounted) await _load();
      },
      label: '${'fam_title'.tr()}, $line',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: AppRadius.lgAll,
          ),
          child: Row(
            children: [
              Icon(Icons.diversity_1_outlined, color: colors.primary),
              AppSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('fam_title'.tr(), style: context.textTheme.labelLarge),
                    Text(
                      line,
                      style: e.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
