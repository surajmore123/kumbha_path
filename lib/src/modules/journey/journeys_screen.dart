import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/journey/data/journey_repository.dart';
import 'package:kumbha_path/src/modules/journey/journey_controllers.dart';
import 'package:kumbha_path/src/modules/journey/models/journey_models.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart';

/// `/journeys`: the pilgrim's saved plans, by status.
class JourneysScreen extends StatefulWidget {
  const JourneysScreen({super.key, this.repository});

  final JourneyRepository? repository;

  @override
  State<JourneysScreen> createState() => _JourneysScreenState();
}

class _JourneysScreenState extends State<JourneysScreen> {
  late final JourneyRepository _repo =
      widget.repository ?? JourneyServices.repository;
  late final List<JourneyListController> _tabs = [
    JourneyListController(_repo, status: 'planned'),
    JourneyListController(_repo, status: 'draft'),
    JourneyListController(_repo, status: 'completed'),
  ];

  static const _labels = [
    'jp_tab_upcoming',
    'jp_tab_drafts',
    'jp_tab_completed',
  ];

  @override
  void initState() {
    super.initState();
    for (final t in _tabs) {
      t.load();
    }
  }

  @override
  void dispose() {
    for (final t in _tabs) {
      t.dispose();
    }
    super.dispose();
  }

  void _reloadAll() {
    for (final t in _tabs) {
      t.load();
    }
  }

  Future<void> _create() async {
    final created = await Navigator.pushNamed(context, '/journeyForm');
    if (!mounted || created is! JourneyPlan) return;
    _reloadAll();
    await _open(created.id);
  }

  Future<void> _open(String id) async {
    await Navigator.pushNamed(context, '/journeyDetail', arguments: id);
    if (mounted) _reloadAll();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: MainLayout(
        ctx: 0,
        showDefaultBottom: true,
        appBar: AppAppBar(
          title: 'jp_my_journeys'.tr(),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final l in _labels) Tab(text: l.tr())],
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  _JourneyTab(
                    controller: _tabs[i],
                    emptyKey:
                        'jp_empty_${['upcoming', 'drafts', 'completed'][i]}',
                    onCreate: _create,
                    onOpen: _open,
                  ),
              ],
            ),
            Positioned(
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: FloatingActionButton.extended(
                heroTag: 'journey_new',
                onPressed: _create,
                icon: const Icon(Icons.add_rounded),
                label: Text('jp_plan_new'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyTab extends StatelessWidget {
  const _JourneyTab({
    required this.controller,
    required this.emptyKey,
    required this.onCreate,
    required this.onOpen,
  });

  final JourneyListController controller;
  final String emptyKey;
  final VoidCallback onCreate;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        if (c.loading && c.items.isEmpty) return const AppLoading();
        if (c.error != null && c.items.isEmpty) {
          return AppErrorView(
            message: journeyErrorText(c.error),
            onRetry: c.load,
          );
        }
        if (c.items.isEmpty) {
          return AppEmptyState(
            icon: Icons.route_rounded,
            title: emptyKey.tr(),
            message: 'jp_empty_message'.tr(),
            actionLabel: 'jp_plan_my_journey'.tr(),
            onAction: onCreate,
          );
        }
        return RefreshIndicator(
          onRefresh: c.load,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              96, // room for the button
            ),
            itemCount: c.items.length + 1,
            separatorBuilder: (_, __) => AppSpacing.gapMd,
            itemBuilder: (context, i) {
              if (i < c.items.length) {
                final j = c.items[i];
                return JourneySummaryCard(
                  journey: j,
                  onTap: () => onOpen(j.id),
                );
              }
              if (c.loadingMore) return const AppLoading.compact();
              if (c.moreError != null) {
                return AppErrorView(
                  compact: true,
                  message: journeyErrorText(c.moreError),
                  onRetry: c.loadMore,
                );
              }
              if (!c.hasNext) return const SizedBox.shrink();
              return AppButton.outlined(
                label: 'jp_load_more'.tr(),
                onPressed: c.loadMore,
              );
            },
          ),
        );
      },
    );
  }
}

class JourneySummaryCard extends StatelessWidget {
  const JourneySummaryCard({super.key, required this.journey, this.onTap});

  final JourneySummary journey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final muted = context.colorScheme.onSurfaceVariant;
    final j = journey;
    return AppCard(
      onTap: onTap,
      semanticLabel: j.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  j.title,
                  style: text.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.gapSm,
              journeyStatusPill(context, j.status),
            ],
          ),
          AppSpacing.gapSm,
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              _Meta(
                Icons.calendar_month_rounded,
                formatRange(context, j.arrivalDate, j.departureDate),
              ),
              _Meta(
                Icons.group_rounded,
                'jp_travellers_count'.plural(j.travellers),
              ),
              if (j.origin != null) _Meta(Icons.place_outlined, j.origin!),
              if (j.dayCount > 0)
                _Meta(
                  Icons.view_day_outlined,
                  'jp_days_count'.plural(j.dayCount),
                ),
            ],
          ),
          if (j.checklistTotal > 0) ...[
            AppSpacing.gapSm,
            Text(
              'jp_checklist_progress'.tr(
                args: ['${j.checklistDone}', '${j.checklistTotal}'],
              ),
              style: text.bodySmall?.copyWith(color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final muted = context.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: muted),
        AppSpacing.gapXs,
        Flexible(
          child: Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}
