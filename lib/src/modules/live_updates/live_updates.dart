import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_feed.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/display_format.dart';
import 'package:kumbha_path/src/models/notification_model.dart';
import 'package:kumbha_path/src/modules/live_crowd/widgets/live_info.dart';

/// `/notifications`: updates from `api/crowd/notifications/`, filtered by
/// the API's own `type` parameter (All / ALERT / MESSAGE) as before.
///
/// Loaded when opened and when refreshed (no live stream). Items keep the
/// API's order and their own `created_at`; nothing is marked "new".
class LiveUpdates extends StatefulWidget {
  const LiveUpdates({super.key, this.bloc, this.now});

  /// Injected in tests. Defaults to a private AppDetailsBloc.
  final Bloc<AppDetailsEvent, AppDetailsState>? bloc;
  final DateTime Function()? now;

  @override
  State<LiveUpdates> createState() => _LiveUpdates();
}

class _LiveUpdates extends State<LiveUpdates> {
  static const List<(String type, String labelKey)> tabs = [
    ('', 'updates_tab_all'),
    ('ALERT', 'updates_tab_alerts'),
    ('MESSAGE', 'updates_tab_messages'),
  ];

  String _type = '';

  late final AppDetailsFeed _feed = AppDetailsFeed(
    bloc: widget.bloc,
    request: () => GetNotificationsEvent(type: _type),
    isReady: (s) => s == AppDetailsStatus.success,
    isFailed: (s) => s == AppDetailsStatus.failed,
  );

  static const double _maxWidth = 760;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _feed.load();
  }

  @override
  void dispose() {
    _feed.dispose();
    super.dispose();
  }

  void _setType(String type) {
    if (type == _type) return;
    setState(() => _type = type);
    _feed.load();
  }

  String get _locale =>
      EasyLocalization.of(context)?.locale.languageCode ??
      Localizations.localeOf(context).languageCode;

  @override
  Widget build(BuildContext context) {
    final locale = _locale;
    return MainLayout(
      showDefaultBottom: true,
      ctx: 1,
      appBar: AppAppBar(
        title: 'updates_title'.tr(),
        actions: [
          ValueListenableBuilder<FeedStatus>(
            valueListenable: _feed.status,
            builder:
                (context, status, _) => AppIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'crowd_refresh'.tr(),
                  onPressed: status == FeedStatus.loading ? null : _feed.load,
                ),
          ),
          AppSpacing.gapXs,
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _feed.load,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(
              AppSpacing.pageGutter,
              (constraints.maxWidth - _maxWidth) / 2,
            );
            return ValueListenableBuilder<FeedStatus>(
              valueListenable: _feed.status,
              builder:
                  (context, status, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      side,
                      AppSpacing.sm,
                      side,
                      AppSpacing.huge,
                    ),
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: [
                            for (final (type, key) in tabs)
                              ButtonSegment(value: type, label: Text(key.tr())),
                          ],
                          selected: {_type},
                          showSelectedIcon: false,
                          // A request in flight can't be replaced, so tabs
                          // wait for it (prevents mismatched results).
                          onSelectionChanged:
                              status == FeedStatus.loading
                                  ? null
                                  : (s) => _setType(s.first),
                        ),
                      ),
                      AppSpacing.gapMd,
                      Text(
                        [
                          'updates_note'.tr(),
                          if (status == FeedStatus.ready &&
                              _feed.lastUpdated != null)
                            'dash_crowd_checked_at'.tr(
                              args: [
                                formatClockTime(_feed.lastUpdated!, locale),
                              ],
                            ),
                        ].join(' '),
                        style: context.textTheme.bodySmall,
                      ),
                      AppSpacing.gapLg,
                      ..._body(status, locale),
                    ],
                  ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _body(FeedStatus status, String locale) {
    switch (status) {
      case FeedStatus.loading:
        return [
          for (var i = 0; i < 3; i++) ...[
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHigh,
                borderRadius: AppRadius.cardAll,
              ),
            ),
            AppSpacing.gapMd,
          ],
        ];
      case FeedStatus.failed:
        // A failed request is never shown as "no updates".
        return [
          AppCard(
            padding: EdgeInsets.zero,
            child: AppErrorView(
              compact: true,
              title: 'updates_failed'.tr(),
              onRetry: _feed.load,
            ),
          ),
        ];
      case FeedStatus.ready:
        final items = _dedupe(_feed.bloc.state.notificationList);
        if (items.isEmpty) {
          final key = switch (_type) {
            'ALERT' => 'updates_empty_alerts',
            'MESSAGE' => 'updates_empty_messages',
            _ => 'updates_empty_all',
          };
          return [
            AppCard(
              padding: EdgeInsets.zero,
              child: AppEmptyState(
                compact: true,
                icon: Icons.notifications_none_rounded,
                title: key.tr(),
              ),
            ),
          ];
        }
        final now = _now;
        return [
          for (final n in items) ...[
            UpdateCard(
              update: n,
              locale: locale,
              now: now,
              onViewMap:
                  (n.zoneName ?? '').trim().isEmpty
                      ? null
                      : () => Navigator.pushNamed(
                        context,
                        '/liveCroud',
                        arguments: {'zoneName': n.zoneName!.trim()},
                      ),
            ),
            AppSpacing.gapMd,
          ],
        ];
    }
  }

  /// Drops repeated ids (same item delivered twice); keeps API order.
  static List<NotificationModel> _dedupe(List<NotificationModel> list) {
    final seen = <int>{};
    return [
      for (final n in list)
        if (n.id == null || seen.add(n.id!)) n,
    ];
  }
}

/// One update. Alerts and high/critical severity stand out; messages are
/// calm. Time is the item's own `created_at`.
class UpdateCard extends StatelessWidget {
  const UpdateCard({
    super.key,
    required this.update,
    required this.locale,
    required this.now,
    this.onViewMap,
  });

  final NotificationModel update;
  final String locale;
  final DateTime now;
  final VoidCallback? onViewMap;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colorScheme;
    final isAlert = (update.type ?? '').trim().toUpperCase() == 'ALERT';
    final urgent = isUrgent(update.severity);
    final title = (update.title ?? '').trim();
    final body = (update.body ?? '').trim();
    final zone = (update.zoneName ?? '').trim();
    final time = sourceTimeLabel(update.createdAt, locale, now);
    final typeLabel =
        isAlert
            ? 'updates_type_alert'.tr()
            : ((update.type ?? '').trim().toUpperCase() == 'MESSAGE'
                ? 'updates_type_message'.tr()
                : prettifyCode(update.type));

    return AppCard(
      variant: urgent ? AppCardVariant.filled : AppCardVariant.outlined,
      color: urgent ? colors.errorContainer.withValues(alpha: 0.45) : null,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      isAlert
                          ? colors.errorContainer
                          : context.semanticColors.infoContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAlert
                      ? Icons.warning_amber_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color:
                      isAlert
                          ? colors.onErrorContainer
                          : context.semanticColors.onInfoContainer,
                ),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (typeLabel != null)
                      Text(typeLabel, style: text.labelLarge),
                    SeverityPill(severity: update.severity),
                  ],
                ),
              ),
            ],
          ),
          if (title.isNotEmpty) ...[
            AppSpacing.gapMd,
            Text(title, style: text.titleMedium),
          ],
          if (body.isNotEmpty) ...[
            AppSpacing.gapXs,
            Text(
              body,
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          if (zone.isNotEmpty || time != null) ...[
            AppSpacing.gapMd,
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                if (zone.isNotEmpty)
                  _Meta(icon: Icons.place_outlined, label: zone),
                if (time != null)
                  _Meta(icon: Icons.schedule_outlined, label: time),
              ],
            ),
          ],
          if (onViewMap != null) ...[
            AppSpacing.gapSm,
            TextButton.icon(
              onPressed: onViewMap,
              icon: const Icon(Icons.map_outlined),
              label: Text('updates_view_map'.tr()),
            ),
          ],
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = context.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        AppSpacing.gapXs,
        Flexible(
          child: Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
