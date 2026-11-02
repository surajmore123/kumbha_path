import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/components/chat_screen/chat_rich_text.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/display_format.dart';
import 'package:kumbha_path/src/constant/place_format.dart';
import 'package:kumbha_path/src/models/chat_reply.dart';
import 'package:kumbha_path/src/modules/temple_explorer/temple_detail_screen.dart';

/// Structured parts of an assistant reply, shown under its bubble: temple
/// cards with Directions / Map / Details, event cards, live crowd and
/// alerts with their data age, sources, and a note when data was missing.
/// Links live here, so the reply text never has to show raw URLs.
class ReplyCards extends StatelessWidget {
  const ReplyCards({super.key, required this.reply, this.onOpenTemple});

  final ChatReplyData reply;

  /// Opens a temple's detail screen. Defaults to the app's existing
  /// `/templeDetail` flow; injected in tests.
  final ValueChanged<ReplyTemple>? onOpenTemple;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      if (reply.temples.isNotEmpty)
        _TempleSection(
          temples: reply.temples,
          mode: reply.templeMode,
          onOpen: onOpenTemple ?? (t) => _openTempleDetail(context, t),
        ),
      if (reply.events.isNotEmpty)
        _EventSection(events: reply.events, mode: reply.eventMode),
      if (reply.hasCrowd) _CrowdCard(reply: reply),
      if (reply.sources.isNotEmpty) _Sources(sources: reply.sources),
      if (reply.partial) const _PartialNote(),
    ];
    if (sections.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) AppSpacing.gapMd,
          sections[i],
        ],
      ],
    );
  }

  /// Same flow as the Temple Explorer list: request the detail into the
  /// shared AppDetailsBloc, then open `/templeDetail`. Falls back to the
  /// map if the bloc isn't available.
  static void _openTempleDetail(BuildContext context, ReplyTemple temple) {
    AppDetailsBloc? bloc;
    try {
      bloc = context.read<AppDetailsBloc>();
    } catch (_) {
      bloc = null;
    }
    if (bloc == null) {
      final url = temple.mapUrl ?? temple.directionsUrl;
      if (url != null) openChatLink(context, url);
      return;
    }
    bloc.add(GetTempleDetail(templeId: temple.id, latitude: '', longitude: ''));
    Navigator.of(context).pushNamed(
      '/templeDetail',
      arguments: TempleDetailArgs(
        templeId: temple.id,
        latitude: '',
        longitude: '',
      ),
    );
  }
}

const SizedBox _gapXxs = SizedBox(
  width: AppSpacing.xxs,
  height: AppSpacing.xxs,
);

String _locale(BuildContext context) =>
    EasyLocalization.of(context)?.locale.languageCode ??
    Localizations.localeOf(context).languageCode;

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: colors.primary),
            AppSpacing.gapXs,
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: context.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the first [visible] items and a "Show N more" toggle.
class _Collapsible extends StatefulWidget {
  const _Collapsible({required this.children});

  final List<Widget> children;
  static const int visible = 3;

  @override
  State<_Collapsible> createState() => _CollapsibleState();
}

class _CollapsibleState extends State<_Collapsible> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hidden = widget.children.length - _Collapsible.visible;
    final shown =
        _expanded || hidden <= 0
            ? widget.children
            : widget.children.take(_Collapsible.visible).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) AppSpacing.gapSm,
          shown[i],
        ],
        if (hidden > 0)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(
                _expanded
                    ? 'ai_show_less'.tr()
                    : 'ai_show_more'.tr(args: ['$hidden']),
              ),
            ),
          ),
      ],
    );
  }
}

// ---- Temples ----------------------------------------------------------------

class _TempleSection extends StatelessWidget {
  const _TempleSection({
    required this.temples,
    required this.mode,
    required this.onOpen,
  });

  final List<ReplyTemple> temples;
  final String? mode;
  final ValueChanged<ReplyTemple> onOpen;

  @override
  Widget build(BuildContext context) {
    final title = switch (mode) {
      'nearby' => 'ai_temples_nearby'.tr(),
      'list' => 'ai_temples_list'.tr(),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          _SectionTitle(title, icon: Icons.temple_hindu_outlined),
        _Collapsible(
          children: [
            for (final t in temples)
              _TempleCard(temple: t, onOpen: () => onOpen(t)),
          ],
        ),
      ],
    );
  }
}

class _TempleCard extends StatelessWidget {
  const _TempleCard({required this.temple, required this.onOpen});

  final ReplyTemple temple;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final text = context.textTheme;
    final distance = formatDistanceKm(temple.distanceKm, _locale(context));
    final subtitle = [
      if (temple.city != null) temple.city!,
      if (distance != null) 'ai_km_away'.tr(args: [distance]),
    ].join(' · ');
    final advisory =
        temple.advisoryLevel == null
            ? null
            : crowdStyle(
              context,
              crowdLevelOf(temple.advisoryLevel),
              temple.advisoryLevel,
            );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onOpen,
      semanticLabel: temple.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(url: temple.imageUrl),
              AppSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      temple.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      _gapXxs,
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (advisory != null) ...[
                      AppSpacing.gapXs,
                      Tooltip(
                        message:
                            temple.advisoryMessage ?? 'ai_advisory_hint'.tr(),
                        child: StatusPill(
                          label: '${'ai_advisory'.tr()}: ${advisory.label}',
                          foreground: advisory.fg,
                          background: advisory.bg,
                          icon: Icons.groups_outlined,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (temple.directionsUrl != null)
                FilledButton.tonalIcon(
                  style: _compactButton,
                  onPressed: () => openChatLink(context, temple.directionsUrl!),
                  icon: const Icon(Icons.directions_outlined, size: 18),
                  label: Text('ai_directions'.tr()),
                ),
              if (temple.mapUrl != null)
                OutlinedButton.icon(
                  style: _compactButton,
                  onPressed: () => openChatLink(context, temple.mapUrl!),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text('ai_view_map'.tr()),
                ),
              TextButton.icon(
                style: _compactButton,
                onPressed: onOpen,
                icon: const Icon(Icons.info_outline_rounded, size: 18),
                label: Text('ai_temple_details'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final ButtonStyle _compactButton = ButtonStyle(
  visualDensity: VisualDensity.compact,
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: AppSpacing.md),
  ),
);

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.url});

  final String? url;
  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final placeholder = Container(
      width: _size,
      height: _size,
      color: colors.primaryContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.temple_hindu_outlined,
        color: colors.onPrimaryContainer,
      ),
    );
    return ClipRRect(
      borderRadius: AppRadius.mdAll,
      child:
          url == null
              ? placeholder
              : Image.network(
                url!,
                width: _size,
                height: _size,
                fit: BoxFit.cover,
                cacheWidth:
                    (_size * MediaQuery.devicePixelRatioOf(context)).round(),
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => placeholder,
              ),
    );
  }
}

// ---- Events -------------------------------------------------------------------

class _EventSection extends StatelessWidget {
  const _EventSection({required this.events, required this.mode});

  final List<ReplyEvent> events;
  final String? mode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionTitle(
          mode == 'recent'
              ? 'ai_events_recent'.tr()
              : 'ai_events_upcoming'.tr(),
          icon: Icons.event_outlined,
        ),
        _Collapsible(children: [for (final e in events) _EventCard(event: e)]),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/shahiEvents'),
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text('ai_events_all'.tr()),
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final ReplyEvent event;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final text = context.textTheme;
    final locale = _locale(context);
    final badge = eventDateBadge(event.date, locale);
    final time =
        formatEventTimeRange(event.startTime, event.endTime, locale) ??
        (event.isAllDay ? 'ai_all_day'.tr() : null);
    final date = formatEventDate(event.date, locale) ?? event.date;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      semanticLabel: '${event.name}, $date',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: AppRadius.mdAll,
            ),
            child: Column(
              children: [
                Text(
                  badge?.day ?? '—',
                  style: text.titleLarge?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                Text(
                  badge?.month ?? '',
                  style: text.labelSmall?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                _gapXxs,
                Text(
                  [date, if (time != null) time].join(' · '),
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (event.location != null) ...[
                  _gapXxs,
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                      _gapXxs,
                      Flexible(
                        child: Text(
                          prettifyCode(event.location) ?? event.location!,
                          style: text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (event.directionsUrl != null)
            AppIconButton(
              icon: Icons.directions_outlined,
              tooltip: 'ai_directions'.tr(),
              onPressed: () => openChatLink(context, event.directionsUrl!),
            ),
        ],
      ),
    );
  }
}

// ---- Crowd --------------------------------------------------------------------

class _CrowdCard extends StatelessWidget {
  const _CrowdCard({required this.reply});

  final ChatReplyData reply;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final semantic = context.semanticColors;
    final text = context.textTheme;
    final locale = _locale(context);
    final updated = describeTimestamp(
      reply.crowdUpdatedAt,
      locale,
      DateTime.now(),
    );
    final stamp =
        updated == null
            ? null
            : updated.isToday
            ? updated.time
            : '${updated.date}, ${updated.time}';

    return AppCard(
      variant: AppCardVariant.filled,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reply.zones.isNotEmpty) ...[
            _SectionTitle('ai_crowd_title'.tr(), icon: Icons.groups_outlined),
            for (final zone in reply.zones)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _ZoneRow(zone: zone, locale: locale),
              ),
            if (stamp != null)
              Row(
                children: [
                  Icon(
                    reply.crowdStale
                        ? Icons.warning_amber_rounded
                        : Icons.schedule_rounded,
                    size: 16,
                    color:
                        reply.crowdStale
                            ? semantic.onWarningContainer
                            : colors.onSurfaceVariant,
                  ),
                  AppSpacing.gapXs,
                  Expanded(
                    child: Text(
                      reply.crowdStale
                          ? 'ai_crowd_stale'.tr(args: [stamp])
                          : 'ai_crowd_updated'.tr(args: [stamp]),
                      style: text.bodySmall?.copyWith(
                        color:
                            reply.crowdStale
                                ? semantic.onWarningContainer
                                : colors.onSurfaceVariant,
                        fontWeight: reply.crowdStale ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ],
              ),
          ],
          if (reply.incidents.isNotEmpty) ...[
            if (reply.zones.isNotEmpty) AppSpacing.gapMd,
            _SectionTitle('ai_alerts'.tr(), icon: Icons.campaign_outlined),
            for (final incident in reply.incidents)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: colors.error,
                    ),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(incident.title, style: text.bodyMedium),
                          Text(
                            [
                              if (incident.zone != null) incident.zone!,
                              if (incident.type != null)
                                prettifyCode(incident.type)!,
                              if (incident.severity != null)
                                prettifyCode(incident.severity)!,
                            ].join(' · '),
                            style: text.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({required this.zone, required this.locale});

  final ReplyZone zone;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colorScheme;
    final style = crowdStyle(context, crowdLevelOf(zone.status), zone.status);
    final occupancy = formatOccupancy(zone.occupancyPercent, locale);
    return Row(
      children: [
        Expanded(child: Text(zone.name, style: text.bodyMedium)),
        if (!zone.hasReading)
          Text(
            'ai_crowd_no_reading'.tr(),
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          )
        else ...[
          if (occupancy != null) ...[
            Text('$occupancy%', style: text.bodySmall),
            AppSpacing.gapSm,
          ],
          StatusPill(
            label: style.label,
            foreground: style.fg,
            background: style.bg,
          ),
        ],
      ],
    );
  }
}

// ---- Sources and notes --------------------------------------------------------

class _Sources extends StatelessWidget {
  const _Sources({required this.sources});

  final List<ReplySource> sources;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionTitle('ai_sources'.tr(), icon: Icons.menu_book_outlined),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final source in sources)
              ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  source.url != null
                      ? Icons.open_in_new_rounded
                      : Icons.description_outlined,
                  size: 16,
                ),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    source.unverified
                        ? '${source.label} (${'ai_unverified'.tr()})'
                        : source.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                onPressed:
                    source.url == null
                        ? null
                        : () => openChatLink(context, source.url!),
              ),
          ],
        ),
      ],
    );
  }
}

class _PartialNote extends StatelessWidget {
  const _PartialNote();

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: colors.onSurfaceVariant,
        ),
        AppSpacing.gapXs,
        Expanded(
          child: Text(
            'ai_partial'.tr(),
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
