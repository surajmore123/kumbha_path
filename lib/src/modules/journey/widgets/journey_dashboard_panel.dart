import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/journey/data/journey_repository.dart';
import 'package:kumbha_path/src/modules/journey/journeys_screen.dart';
import 'package:kumbha_path/src/modules/journey/models/journey_models.dart';

/// Dashboard "Plan" tab: the next planned journey, or an invitation to
/// plan one. Failures fall back to the invitation; the journeys screen
/// shows the actual error.
class JourneyDashboardPanel extends StatefulWidget {
  const JourneyDashboardPanel({
    super.key,
    required this.onOpenList,
    required this.onOpen,
    required this.onCreate,
    this.repository,
  });

  final VoidCallback onOpenList;
  final ValueChanged<String> onOpen;
  final VoidCallback onCreate;
  final JourneyRepository? repository;

  @override
  State<JourneyDashboardPanel> createState() => _JourneyDashboardPanelState();
}

class _JourneyDashboardPanelState extends State<JourneyDashboardPanel> {
  late final Future<JourneySummary?> _next = _load();

  Future<JourneySummary?> _load() async {
    try {
      final repo = widget.repository ?? JourneyServices.repository;
      final page = await repo.list(status: 'planned', ordering: 'arrival');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      for (final j in page.items) {
        if (j.departureDate == null || !j.departureDate!.isBefore(today)) {
          return j;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<JourneySummary?>(
      future: _next,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 120, child: AppLoading.compact());
        }
        final next = snap.data;
        if (next != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              JourneySummaryCard(
                journey: next,
                onTap: () => widget.onOpen(next.id),
              ),
              AppSpacing.gapSm,
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/booking'),
                    icon: const Icon(Icons.luggage_outlined, size: 18),
                    label: Text('bk_title'.tr()),
                  ),
                  TextButton.icon(
                    onPressed: widget.onCreate,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text('jp_plan_new'.tr()),
                  ),
                  TextButton.icon(
                    onPressed: widget.onOpenList,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text('jp_my_journeys'.tr()),
                  ),
                ],
              ),
            ],
          );
        }
        final text = context.textTheme;
        return AppCard(
          variant: AppCardVariant.filled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.route_rounded, color: context.colorScheme.primary),
                  AppSpacing.gapSm,
                  Expanded(
                    child: Text('jp_plan_title'.tr(), style: text.titleMedium),
                  ),
                ],
              ),
              AppSpacing.gapSm,
              Text('jp_plan_pitch'.tr(), style: text.bodyMedium),
              AppSpacing.gapMd,
              AppButton(
                label: 'jp_plan_my_journey'.tr(),
                leadingIcon: Icons.add_rounded,
                onPressed: widget.onCreate,
              ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/booking'),
                    icon: const Icon(Icons.luggage_outlined, size: 18),
                    label: Text('bk_title'.tr()),
                  ),
                  TextButton(
                    onPressed: widget.onOpenList,
                    child: Text('jp_my_journeys'.tr()),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
