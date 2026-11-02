import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show formatDate, openExternal;
import 'package:kumbha_path/src/modules/lostfound/data/lf_drafts.dart';
import 'package:kumbha_path/src/modules/lostfound/data/lf_repository.dart';
import 'package:kumbha_path/src/modules/lostfound/models/lf_models.dart';
import 'package:kumbha_path/src/modules/lostfound/widgets/lf_parts.dart';

/// `/lostFound`: the urgent action first, then what to do right now, then the
/// person's own reports. Not a public list: nobody sees anyone else's case.
class LostFoundHomeScreen extends StatefulWidget {
  const LostFoundHomeScreen({super.key, this.repository});

  final LostFoundRepository? repository;

  @override
  State<LostFoundHomeScreen> createState() => _LostFoundHomeScreenState();
}

class _LostFoundHomeScreenState extends State<LostFoundHomeScreen> {
  late final LostFoundRepository _repo =
      widget.repository ?? LostFoundServices.repository;
  final ReportSender _sender = LostFoundDrafts.sender;
  bool _loading = true;
  Object? _error;
  LfCapabilities _me = const LfCapabilities();
  List<CaseSummary> _cases = const [];
  List<ReportDraft> _drafts = const [];

  @override
  void initState() {
    super.initState();
    _sender.addListener(_loadDrafts);
    _load();
  }

  @override
  void dispose() {
    _sender.removeListener(_loadDrafts);
    super.dispose();
  }

  Future<void> _loadDrafts() async {
    try {
      final drafts = await _sender.drafts();
      if (mounted) setState(() => _drafts = drafts);
    } catch (_) {
      // Reports still work without the local list.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = _cases.isEmpty;
      _error = null;
    });
    await _loadDrafts();
    try {
      final me = await _repo.capabilities();
      final cases = await _repo.myCases();
      if (mounted) {
        setState(() {
          _me = me;
          _cases = cases;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _open(String route, {Object? arguments}) async {
    await Navigator.pushNamed(context, route, arguments: arguments);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final colors = context.colorScheme;
    final active = _cases.where((c) => c.isOpen).toList();
    final past = _cases.where((c) => !c.isOpen).toList();
    Widget gap(Widget child, {double top = AppSpacing.xl}) => Padding(
      padding: EdgeInsets.fromLTRB(editorialMargin, top, editorialMargin, 0),
      child: child,
    );

    return MainLayout(
      ctx: 0,
      showDefaultBottom: true,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.huge),
          children: [
            _Header(onReport: () => _open('/lostFoundReport')),
            gap(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('lf_now_title'.tr(), style: e.headline),
                  AppSpacing.gapMd,
                  for (final (i, key)
                      in const ['lf_now_1', 'lf_now_2', 'lf_now_3'].indexed)
                    ThreadStep(
                      marker: '${i + 1}',
                      isLast: i == 2,
                      child: Text(key.tr()),
                    ),
                  AppSpacing.gapMd,
                  AppButton.secondary(
                    label: 'lf_call_112'.tr(),
                    leadingIcon: Icons.call_rounded,
                    onPressed: () => openExternal(context, 'tel:112'),
                  ),
                ],
              ),
            ),
            if (_me.canReportFound || _me.canOperate)
              gap(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('lf_helper_tools'.tr(), style: e.headline),
                    AppSpacing.gapMd,
                    if (_me.canReportFound)
                      AppButton.secondary(
                        label: 'lf_report_found'.tr(),
                        leadingIcon: Icons.person_pin_circle_outlined,
                        onPressed: () => _open('/lostFoundFound'),
                      ),
                    if (_me.canOperate) ...[
                      AppSpacing.gapSm,
                      AppButton.secondary(
                        label: 'lf_ops_title'.tr(),
                        leadingIcon: Icons.dashboard_outlined,
                        onPressed: () => _open('/lostFoundOps'),
                      ),
                    ],
                  ],
                ),
              ),
            for (final draft in _drafts)
              gap(
                _DraftRow(
                  draft: draft,
                  onTap:
                      () => _open(
                        draft.kind == 'found'
                            ? '/lostFoundFound'
                            : '/lostFoundReport',
                        arguments: draft.id,
                      ),
                ),
                top: AppSpacing.md,
              ),
            gap(Text('lf_my_reports'.tr(), style: e.headline)),
            if (_loading)
              gap(
                const Column(
                  children: [SkeletonLine(), SkeletonLine(width: 220)],
                ),
                top: AppSpacing.md,
              )
            else if (_error != null)
              gap(
                AppErrorView(
                  compact: true,
                  message: lfErrorText(_error!),
                  onRetry: _load,
                ),
                top: AppSpacing.md,
              )
            else if (_cases.isEmpty)
              gap(Text('lf_no_reports'.tr(), style: e.dek), top: AppSpacing.sm),
            for (final item in [...active, ...past])
              gap(
                _CaseRow(
                  item: item,
                  onTap: () => _open('/lostFoundCase', arguments: item.id),
                ),
                top: AppSpacing.md,
              ),
            gap(const NotOfficialNote()),
            gap(
              Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  AppSpacing.gapSm,
                  Expanded(child: Text('lf_private_note'.tr(), style: e.meta)),
                ],
              ),
              top: AppSpacing.md,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onReport});

  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final e = context.editorial;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return ClipPath(
      clipper: const GhatEdgeClipper(stepHeight: 8),
      child: ColoredBox(
        color: colors.primary,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.huge + AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canPop)
                  BackButton(color: colors.onPrimary)
                else
                  const SizedBox(height: AppSpacing.minTouchTarget),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: editorialMargin - AppSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'lf_title'.tr(),
                        style: e.kicker.copyWith(color: colors.onPrimary),
                      ),
                      AppSpacing.gapXs,
                      Semantics(
                        header: true,
                        child: Text(
                          'lf_home_title'.tr(),
                          style: e.masthead.copyWith(color: colors.onPrimary),
                        ),
                      ),
                      AppSpacing.gapSm,
                      Text(
                        'lf_home_body'.tr(),
                        style: e.dek.copyWith(color: colors.onPrimary),
                      ),
                      AppSpacing.gapLg,
                      Material(
                        color: colors.surface,
                        borderRadius: AppRadius.lgAll,
                        child: InkWell(
                          borderRadius: AppRadius.lgAll,
                          onTap: onReport,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_search_rounded,
                                  color: colors.primary,
                                ),
                                AppSpacing.gapMd,
                                Expanded(
                                  child: Text(
                                    'lf_report_missing'.tr(),
                                    style: e.title.copyWith(
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: colors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({required this.draft, required this.onTap});

  final ReportDraft draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.semanticColors;
    final (String title, String body) = switch (draft.state) {
      DraftState.editing => ('lf_draft_title', 'lf_draft_body'),
      DraftState.refused => ('lf_draft_refused_title', 'lf_draft_refused_body'),
      _ => ('lf_waiting_title', 'lf_waiting_body'),
    };
    return Pressable(
      onTap: onTap,
      label: title.tr(),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: s.warningContainer,
          borderRadius: AppRadius.lgAll,
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_upload_outlined, color: s.onWarningContainer),
            AppSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.tr(),
                    style: context.editorial.title.copyWith(
                      color: s.onWarningContainer,
                    ),
                  ),
                  Text(
                    body.tr(),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: s.onWarningContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaseRow extends StatelessWidget {
  const _CaseRow({required this.item, required this.onTap});

  final CaseSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final name = item.personName.isEmpty ? 'lf_unnamed'.tr() : item.personName;
    final at = item.createdAt;
    return Pressable(
      onTap: onTap,
      label: '$name, ${statusLabel(item.status)}',
      child: Container(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              width: 3,
              color:
                  item.isOpen
                      ? context.colorScheme.primary
                      : context.colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: e.title),
            StatusTag(item.status),
            MetaLine([item.reference, if (at != null) formatDate(context, at)]),
          ],
        ),
      ),
    );
  }
}

/// On the dashboard, beside Family Safety.
class LostFoundDashboardEntry extends StatelessWidget {
  const LostFoundDashboardEntry({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final label = 'lf_title'.tr();
    final line = 'lf_entry_line'.tr();
    return Pressable(
      onTap: onOpen,
      label: '$label, $line',
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
              Icon(Icons.person_search_outlined, color: colors.primary),
              AppSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: context.textTheme.labelLarge),
                    Text(
                      line,
                      style: context.editorial.meta,
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
