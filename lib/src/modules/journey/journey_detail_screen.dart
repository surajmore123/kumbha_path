import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/journey/data/journey_repository.dart';
import 'package:kumbha_path/src/modules/journey/journey_controllers.dart';
import 'package:kumbha_path/src/modules/journey/journey_form_screen.dart';
import 'package:kumbha_path/src/modules/journey/models/journey_models.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_detail_tabs.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart';
import 'package:share_plus/share_plus.dart';

enum _Action { edit, regenerate, duplicate, complete, reopen, delete }

/// `/journeyDetail` (argument: the journey id): itinerary, checklist,
/// travel and stay, budget and official information for one plan.
class JourneyDetailScreen extends StatefulWidget {
  const JourneyDetailScreen({
    super.key,
    required this.journeyId,
    this.repository,
    this.share,
  });

  final String journeyId;
  final JourneyRepository? repository;

  /// Injectable for tests; defaults to the system share sheet.
  final Future<void> Function(String text, String subject)? share;

  @override
  State<JourneyDetailScreen> createState() => _JourneyDetailScreenState();
}

class _JourneyDetailScreenState extends State<JourneyDetailScreen> {
  late final JourneyRepository _repo =
      widget.repository ?? JourneyServices.repository;
  late final JourneyDetailController _c = JourneyDetailController(
    _repo,
    widget.journeyId,
  );
  Future<PlanningGuide>? _guide;
  String? _guideLanguage;

  @override
  void initState() {
    super.initState();
    _c.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = journeyLanguage(context);
    if (lang != _guideLanguage) {
      _guideLanguage = lang;
      _guide = _repo.guide(lang);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _reloadGuide() => setState(() => _guide = _repo.guide(_guideLanguage!));

  Future<void> _report(Future<JourneyException?> action, {String? done}) async {
    final error = await action;
    if (!mounted) return;
    if (error != null) {
      showJourneySnack(context, journeyErrorText(error));
    } else if (done != null) {
      showJourneySnack(context, done);
    }
  }

  Future<void> _regenerate({bool ask = true}) async {
    final plan = _c.plan;
    if (plan == null) return;
    if (ask && plan.hasItinerary) {
      final ok = await confirmJourneyAction(
        context,
        title: 'jp_regenerate_title'.tr(),
        message: 'jp_regenerate_message'.tr(),
        confirm: 'jp_regenerate'.tr(),
      );
      if (!ok || !mounted) return;
    }
    await _report(
      _c.regenerate(journeyLanguage(context)),
      done: 'jp_itinerary_updated'.tr(),
    );
  }

  Future<void> _edit() async {
    final plan = _c.plan;
    if (plan == null) return;
    final saved = await Navigator.push<JourneyPlan>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/journeyForm'),
        builder: (_) => JourneyFormScreen(initial: plan, repository: _repo),
      ),
    );
    if (saved == null || !mounted) return;
    _c.plan = saved;
    setState(() {});
    if (saved.hasItinerary) {
      final update = await confirmJourneyAction(
        context,
        title: 'jp_update_after_edit_title'.tr(),
        message: 'jp_regenerate_message'.tr(),
        confirm: 'jp_regenerate'.tr(),
      );
      if (update && mounted) await _regenerate(ask: false);
    }
  }

  Future<void> _share() async {
    final plan = _c.plan;
    if (plan == null) return;
    try {
      final text = await _repo.exportText(plan.id);
      if (!mounted) return;
      final share = widget.share ?? _systemShare;
      await share(text, plan.title);
    } on JourneyException catch (e) {
      if (mounted) showJourneySnack(context, journeyErrorText(e));
    }
  }

  static Future<void> _systemShare(String text, String subject) async {
    await Share.share(text, subject: subject);
  }

  Future<void> _onAction(_Action action) async {
    switch (action) {
      case _Action.edit:
        await _edit();
      case _Action.regenerate:
        await _regenerate();
      case _Action.duplicate:
        try {
          final copy = await _repo.duplicate(widget.journeyId);
          if (!mounted) return;
          showJourneySnack(context, 'jp_duplicated'.tr());
          Navigator.pushReplacementNamed(
            context,
            '/journeyDetail',
            arguments: copy.id,
          );
        } on JourneyException catch (e) {
          if (mounted) showJourneySnack(context, journeyErrorText(e));
        }
      case _Action.complete:
        await _report(
          _c.setStatus(JourneyStatus.completed),
          done: 'jp_marked_completed'.tr(),
        );
      case _Action.reopen:
        await _report(_c.setStatus(JourneyStatus.planned));
      case _Action.delete:
        final ok = await confirmJourneyAction(
          context,
          title: 'jp_delete_title'.tr(),
          message: 'jp_delete_message'.tr(),
          confirm: 'jp_delete'.tr(),
          destructive: true,
        );
        if (!ok || !mounted) return;
        final error = await _c.delete();
        if (!mounted) return;
        if (error != null) {
          showJourneySnack(context, journeyErrorText(error));
        } else {
          showJourneySnack(context, 'jp_deleted'.tr());
          Navigator.pop(context, true);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final plan = _c.plan;
        return DefaultTabController(
          length: 5,
          child: MainLayout(
            ctx: 0,
            appBar: AppAppBar(
              title: plan?.title ?? 'jp_journey'.tr(),
              actions: [
                if (plan != null) ...[
                  IconButton(
                    tooltip: 'jp_share'.tr(),
                    onPressed: _c.busy ? null : _share,
                    icon: const Icon(Icons.share_rounded),
                  ),
                  PopupMenuButton<_Action>(
                    tooltip: 'jp_more_actions'.tr(),
                    enabled: !_c.busy,
                    onSelected: _onAction,
                    itemBuilder:
                        (_) => [
                          _menu(
                            _Action.edit,
                            Icons.edit_outlined,
                            'jp_edit_details',
                          ),
                          _menu(
                            _Action.regenerate,
                            Icons.auto_awesome_outlined,
                            'jp_regenerate',
                          ),
                          _menu(
                            _Action.duplicate,
                            Icons.copy_rounded,
                            'jp_duplicate',
                          ),
                          if (plan.status != JourneyStatus.completed)
                            _menu(
                              _Action.complete,
                              Icons.task_alt_rounded,
                              'jp_mark_completed',
                            )
                          else
                            _menu(
                              _Action.reopen,
                              Icons.replay_rounded,
                              'jp_reopen',
                            ),
                          _menu(
                            _Action.delete,
                            Icons.delete_outline_rounded,
                            'jp_delete',
                          ),
                        ],
                  ),
                ],
              ],
              bottom:
                  plan == null
                      ? null
                      : TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: [
                          Tab(text: 'jp_tab_itinerary'.tr()),
                          Tab(text: 'jp_tab_checklist'.tr()),
                          Tab(text: 'jp_tab_travel_stay'.tr()),
                          Tab(text: 'jp_tab_budget'.tr()),
                          Tab(text: 'jp_tab_info'.tr()),
                        ],
                      ),
            ),
            body: _body(plan),
          ),
        );
      },
    );
  }

  PopupMenuItem<_Action> _menu(_Action a, IconData icon, String key) =>
      PopupMenuItem(
        value: a,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(key.tr()),
        ),
      );

  Widget _body(JourneyPlan? plan) {
    if (plan == null) {
      if (_c.loading) return const AppLoading();
      return AppErrorView(
        message: journeyErrorText(_c.error),
        onRetry: _c.load,
      );
    }
    return Column(
      children: [
        // Always present, so the tabs below keep their state when it shows.
        SizedBox(
          height: 2,
          child: _c.busy ? const LinearProgressIndicator(minHeight: 2) : null,
        ),
        Expanded(
          child: TabBarView(
            children: [
              ItineraryTab(
                plan: plan,
                controller: _c,
                onGenerate: () => _regenerate(ask: false),
                header: _Overview(plan: plan),
              ),
              ChecklistTab(plan: plan, controller: _c),
              TravelStayTab(
                plan: plan,
                controller: _c,
                guide: _guide,
                onRetryGuide: _reloadGuide,
              ),
              BudgetTab(plan: plan, onEdit: _edit),
              InfoTab(plan: plan, guide: _guide, onRetryGuide: _reloadGuide),
            ],
          ),
        ),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.plan});

  final JourneyPlan plan;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final muted = context.colorScheme.onSurfaceVariant;
    final origin = [
      plan.originCity,
      plan.originState,
    ].where((s) => s.isNotEmpty).join(', ');
    return AppCard(
      variant: AppCardVariant.filled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              journeyStatusPill(context, plan.status),
              if (plan.dayCount > 0)
                Text(
                  'jp_days_count'.plural(plan.dayCount),
                  style: text.labelLarge,
                ),
            ],
          ),
          AppSpacing.gapSm,
          for (final (icon, value) in [
            (
              Icons.calendar_month_rounded,
              plan.arrivalDate == null && plan.durationDays != null
                  ? 'jp_dates_open'.tr(
                    args: ['jp_days_count'.plural(plan.durationDays!)],
                  )
                  : formatRange(context, plan.arrivalDate, plan.departureDate),
            ),
            (
              Icons.group_rounded,
              'jp_travellers_count'.plural(plan.travellers),
            ),
            if (origin.isNotEmpty)
              (Icons.place_outlined, 'jp_from'.tr(args: [origin])),
            if (plan.transportMode != 'undecided')
              (
                transportIcon(plan.transportMode),
                'jp_transport_${plan.transportMode}'.tr(),
              ),
          ])
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: muted),
                  AppSpacing.gapSm,
                  Expanded(child: Text(value, style: text.bodyMedium)),
                ],
              ),
            ),
          if (plan.recommendedDays > 0 &&
              plan.dayCount > 0 &&
              plan.dayCount < plan.recommendedDays) ...[
            AppSpacing.gapSm,
            SourceNote(
              'jp_recommended_days'.tr(
                args: ['jp_days_count'.plural(plan.recommendedDays)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
