import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_feed.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/components/maps/app_map.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/display_format.dart';
import 'package:kumbha_path/src/constant/place_format.dart';
import 'package:kumbha_path/src/models/zone_model.dart';
import 'package:kumbha_path/src/modules/live_crowd/widgets/live_info.dart';

/// Solid colour for a crowd level on the map (rings, occupancy bar).
Color crowdLevelColor(BuildContext context, CrowdLevel level) =>
    switch (level) {
      CrowdLevel.low => context.semanticColors.success,
      CrowdLevel.medium => context.semanticColors.warning,
      CrowdLevel.high || CrowdLevel.critical => context.colorScheme.error,
      _ => context.colorScheme.outline,
    };

typedef DetailsBlocFactory = Bloc<AppDetailsEvent, AppDetailsState> Function();

/// `/liveCroud`: crowd zones from `api/crowd/live-status/` on the map, with
/// quick alerts and the next featured event in a bottom sheet.
///
/// Data is fetched when the screen opens and when the user refreshes, as
/// before; there is no live stream, so the screen shows when it last
/// checked instead of claiming to be real-time. Zones carry no timestamp.
///
/// Optional route argument: `{'zoneName': ..}` selects that zone once
/// loaded (used by Live Updates).
class LiveCrowdMap extends StatefulWidget {
  const LiveCrowdMap({super.key, this.blocFactory, this.now});

  /// Creates the bloc behind each feed. Defaults to a new AppDetailsBloc;
  /// injected in tests.
  final DetailsBlocFactory? blocFactory;
  final DateTime Function()? now;

  @override
  State<LiveCrowdMap> createState() => _LiveCrowdMapState();
}

class _LiveCrowdMapState extends State<LiveCrowdMap> {
  /// Existing default camera target (Nashik) when no zone has coordinates.
  static const LatLng _fallbackCenter = LatLng(20.008314, 73.790856);

  late final AppDetailsFeed _zones = _feed(CrowdLiveStatusEvent.new);
  late final AppDetailsFeed _alerts = _feed(QuickAlertsEvent.new);
  late final AppDetailsFeed _featured = _feed(FeaturedEvent.new);
  AppDetailsFeed? _zoneDetail;

  final DraggableScrollableController _sheet = DraggableScrollableController();
  GoogleMapController? _map;
  String? _selectedCode;
  String? _pendingZoneName;
  bool _argsRead = false;

  static const double _sheetMin = 0.16;
  static const double _sheetInitial = 0.3;
  static const double _sheetMax = 0.86;

  DateTime get _now => (widget.now ?? DateTime.now)();

  AppDetailsFeed _feed(
    AppDetailsEvent Function() request, {
    bool Function(AppDetailsStatus)? ready,
  }) => AppDetailsFeed(
    bloc: widget.blocFactory?.call(),
    request: request,
    isReady: ready ?? (s) => s == AppDetailsStatus.success,
    isFailed: (s) => s == AppDetailsStatus.failed,
  );

  @override
  void initState() {
    super.initState();
    _zones.status.addListener(_onZonesChanged);
    _zones.load();
    _alerts.load();
    _featured.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['zoneName'] is String) {
      _pendingZoneName = (args['zoneName'] as String).trim();
    }
  }

  @override
  void dispose() {
    _zones.status.removeListener(_onZonesChanged);
    _zones.dispose();
    _alerts.dispose();
    _featured.dispose();
    _zoneDetail?.dispose();
    _sheet.dispose();
    super.dispose();
  }

  List<ZoneModel> get _zoneList =>
      _zones.status.value == FeedStatus.ready
          ? _zones.bloc.state.zoneModel
          : const [];

  ZoneModel? get _selected {
    final code = _selectedCode;
    if (code == null) return null;
    for (final z in _zoneList) {
      if (z.code == code) return z;
    }
    return null;
  }

  void _onZonesChanged() {
    if (_zones.status.value != FeedStatus.ready) return;
    final name = _pendingZoneName;
    if (name != null && name.isNotEmpty) {
      _pendingZoneName = null;
      for (final z in _zoneList) {
        if ((z.name ?? '').trim().toLowerCase() == name.toLowerCase()) {
          _select(z);
          return;
        }
      }
    }
    _fitAll();
  }

  LatLng? _pos(ZoneModel z) => parseLatLng(z.latitude, z.longitude);

  void _fitAll() {
    final points = _zoneList.map(_pos).whereType<LatLng>().toList();
    final map = _map;
    if (map == null || points.isEmpty) return;
    if (points.length == 1) {
      map.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }
    double minLat = points.first.latitude, maxLat = minLat;
    double minLng = points.first.longitude, maxLng = minLng;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    map.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  /// Same request as before (`GetZoneDetailEvent(code)`), now in its own
  /// feed so switching zones never shows the previous zone's alerts.
  void _select(ZoneModel zone) {
    final code = zone.code;
    if (code == null || code.isEmpty) return;
    _zoneDetail?.dispose();
    final detail = _feed(() => GetZoneDetailEvent(zoneCode: code));
    setState(() {
      _selectedCode = code;
      _zoneDetail = detail;
    });
    detail.load();
    final pos = _pos(zone);
    if (pos != null) _map?.animateCamera(CameraUpdate.newLatLng(pos));
    if (_sheet.isAttached && _sheet.size < 0.45) {
      _sheet.animateTo(
        0.45,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _deselect() {
    if (_selectedCode == null) return;
    setState(() => _selectedCode = null);
  }

  Future<void> _refresh() => Future.wait([
    _zones.load(),
    _alerts.load(),
    _featured.load(),
    if (_zoneDetail != null) _zoneDetail!.load(),
  ]);

  String get _locale =>
      EasyLocalization.of(context)?.locale.languageCode ??
      Localizations.localeOf(context).languageCode;

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      showDefaultBottom: true,
      ctx: 0,
      appBar: AppAppBar(
        title: 'crowd_screen_title'.tr(),
        actions: [
          ValueListenableBuilder<FeedStatus>(
            valueListenable: _zones.status,
            builder:
                (context, status, _) =>
                    status == FeedStatus.loading && _zones.hasRequested
                        ? const SizedBox.square(
                          dimension: AppSpacing.minTouchTarget,
                          child: Center(
                            child: SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                        : AppIconButton(
                          icon: Icons.refresh_rounded,
                          tooltip: 'crowd_refresh'.tr(),
                          onPressed: _refresh,
                        ),
          ),
          AppIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'dash_notifications'.tr(),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          AppSpacing.gapXs,
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(child: _mapLayer(height)),
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                child: _StatusStrip(
                  zones: _zones,
                  locale: _locale,
                  onRetry: _zones.load,
                ),
              ),
              DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: _sheetInitial,
                minChildSize: _sheetMin,
                maxChildSize: _sheetMax,
                snap: true,
                snapSizes: const [_sheetInitial],
                builder: (context, scroll) => _sheetContent(scroll),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _mapLayer(double height) {
    return ValueListenableBuilder<FeedStatus>(
      valueListenable: _zones.status,
      builder: (context, _, __) {
        final zones = _zoneList;
        final markers = <Marker>{};
        final circles = <Circle>{};
        for (final z in zones) {
          final pos = _pos(z);
          final code = z.code;
          if (pos == null || code == null || code.isEmpty) continue;
          final level = crowdLevelOf(z.status);
          final style = crowdStyle(context, level, z.status);
          final selected = code == _selectedCode;
          final occupancy = formatOccupancy(z.occupancyPercent, _locale);
          markers.add(
            Marker(
              markerId: MarkerId(code),
              position: pos,
              icon: BitmapDescriptor.defaultMarkerWithHue(_hue(level)),
              zIndexInt: selected ? 2 : 0,
              infoWindow: InfoWindow(
                title: z.name ?? code,
                // Status in words too, not only marker colour.
                snippet: [
                  style.label,
                  if (occupancy != null) 'dash_occupancy'.tr(args: [occupancy]),
                ].join(' · '),
              ),
              onTap: () => _select(z),
            ),
          );
          final ring = crowdLevelColor(context, level);
          circles.add(
            Circle(
              circleId: CircleId(code),
              center: pos,
              radius: selected ? 60 : 30,
              fillColor: ring.withValues(alpha: 0.22),
              strokeColor: ring,
              strokeWidth: selected ? 4 : 2,
            ),
          );
        }
        final first = zones.map(_pos).whereType<LatLng>().firstOrNull;
        return AppMap(
          config: AppMapConfig(
            target: first ?? _fallbackCenter,
            zoom: 14,
            markers: markers,
            circles: circles,
            padding: EdgeInsets.only(
              top: AppSpacing.huge * 2,
              bottom: height * _sheetInitial,
            ),
            onMapCreated: (c) {
              _map = c;
              _fitAll();
            },
            onTap: (_) => _deselect(),
          ),
        );
      },
    );
  }

  static double _hue(CrowdLevel level) => switch (level) {
    CrowdLevel.low => BitmapDescriptor.hueGreen,
    CrowdLevel.medium => BitmapDescriptor.hueYellow,
    CrowdLevel.high => BitmapDescriptor.hueOrange,
    CrowdLevel.critical => BitmapDescriptor.hueRed,
    // Unknown status is neither "low" nor "critical".
    _ => BitmapDescriptor.hueAzure,
  };

  Widget _sheetContent(ScrollController scroll) {
    final colors = context.colorScheme;
    final locale = _locale;
    return Material(
      color: context.semanticColors.dialogSurface,
      elevation: AppElevation.level3,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      clipBehavior: Clip.antiAlias,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          _zones.status,
          _alerts.status,
          _featured.status,
          if (_zoneDetail != null) _zoneDetail!.status,
        ]),
        builder: (context, _) {
          final selected = _selected;
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: AppRadius.pillAll,
                  ),
                ),
              ),
              if (selected != null)
                _ZonePanel(
                  zone: selected,
                  detail: _zoneDetail!,
                  checkedAt: _zones.lastUpdated,
                  locale: locale,
                  onClose: _deselect,
                )
              else if (_zoneList.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      color: colors.onSurfaceVariant,
                    ),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Text(
                        'crowd_tap_zone'.tr(),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              AppSpacing.gapXl,
              AppSectionHeader(title: 'crowd_alerts_title'.tr()),
              AppSpacing.gapMd,
              ..._alertsSection(locale),
              ..._nextEvent(locale),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _alertsSection(String locale) {
    switch (_alerts.status.value) {
      case FeedStatus.loading:
        return const [
          Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: CircularProgressIndicator(),
            ),
          ),
        ];
      case FeedStatus.failed:
        return [
          _InlineError(
            message: 'crowd_alerts_failed'.tr(),
            onRetry: _alerts.load,
          ),
        ];
      case FeedStatus.ready:
        final alerts =
            _alerts.bloc.state.quickAlerts
                .where((a) => (a.title ?? '').trim().isNotEmpty)
                .toList();
        if (alerts.isEmpty) {
          return [
            Text(
              'crowd_no_alerts'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ];
        }
        final now = _now;
        return [
          for (final a in alerts) ...[
            QuickAlertTile(
              alert: a,
              locale: locale,
              now: now,
              onTap: () {
                for (final z in _zoneList) {
                  if (z.code != null && z.code == a.zoneCode) {
                    _select(z);
                    return;
                  }
                }
              },
            ),
            AppSpacing.gapSm,
          ],
        ];
    }
  }

  List<Widget> _nextEvent(String locale) {
    if (_featured.status.value != FeedStatus.ready) return const [];
    final e = _featured.bloc.state.eventDetailsModel;
    final name = (e.eventName ?? '').trim();
    if (name.isEmpty) return const [];
    final date = formatEventDate(e.eventDate, locale);
    return [
      AppSpacing.gapXl,
      AppSectionHeader(title: 'crowd_next_event'.tr()),
      AppSpacing.gapMd,
      AppCard(
        onTap: () => Navigator.pushNamed(context, '/shahiEvents'),
        semanticLabel: name,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_outlined,
                size: 20,
                color: context.colorScheme.onPrimaryContainer,
              ),
            ),
            AppSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: context.textTheme.titleSmall),
                  if (date != null)
                    Text(date, style: context.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ];
  }
}

/// Compact overlay: legend plus when the data was fetched (or why not).
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.zones,
    required this.locale,
    required this.onRetry,
  });

  final AppDetailsFeed zones;
  final String locale;
  final VoidCallback onRetry;

  static const _legend = [
    CrowdLevel.low,
    CrowdLevel.medium,
    CrowdLevel.high,
    CrowdLevel.critical,
    CrowdLevel.unknown,
  ];

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colorScheme;
    return Material(
      color: context.semanticColors.dialogSurface.withValues(alpha: 0.96),
      borderRadius: AppRadius.lgAll,
      elevation: AppElevation.level2,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: ValueListenableBuilder<FeedStatus>(
          valueListenable: zones.status,
          builder: (context, status, _) {
            final Widget line = switch (status) {
              FeedStatus.loading => Text(
                'common_loading'.tr(),
                style: text.bodySmall,
              ),
              FeedStatus.failed => Row(
                children: [
                  Icon(Icons.cloud_off_rounded, size: 16, color: colors.error),
                  AppSpacing.gapXs,
                  Expanded(
                    child: Text(
                      'crowd_zones_failed'.tr(),
                      style: text.bodySmall?.copyWith(color: colors.error),
                    ),
                  ),
                  TextButton(
                    onPressed: onRetry,
                    child: Text('common_retry'.tr()),
                  ),
                ],
              ),
              FeedStatus.ready =>
                zones.bloc.state.zoneModel.isEmpty
                    ? Text('crowd_no_zones'.tr(), style: text.bodySmall)
                    : Text(
                      [
                        'dash_crowd_zones'.tr(
                          args: ['${zones.bloc.state.zoneModel.length}'],
                        ),
                        if (zones.lastUpdated != null)
                          'dash_crowd_checked_at'.tr(
                            args: [formatClockTime(zones.lastUpdated!, locale)],
                          ),
                      ].join(' · '),
                      style: text.bodySmall,
                    ),
            };
            return Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final level in _legend) _LegendItem(level: level),
                    ],
                  ),
                  AppSpacing.gapXs,
                  line,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.level});

  final CrowdLevel level;

  @override
  Widget build(BuildContext context) {
    final style = crowdStyle(context, level, null);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: style.bg, shape: BoxShape.circle),
          child: Icon(crowdIcon(level), size: 14, color: style.fg),
        ),
        AppSpacing.gapXs,
        Text(style.label, style: context.textTheme.labelMedium),
      ],
    );
  }
}

/// Selected zone: values from the live-status list (which keeps missing
/// values as null) plus alerts from the zone-details request.
class _ZonePanel extends StatelessWidget {
  const _ZonePanel({
    required this.zone,
    required this.detail,
    required this.checkedAt,
    required this.locale,
    required this.onClose,
  });

  final ZoneModel zone;
  final AppDetailsFeed detail;
  final DateTime? checkedAt;
  final String locale;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colorScheme;
    final level = crowdLevelOf(zone.status);
    final style = crowdStyle(context, level, zone.status);
    final occupancy = formatOccupancy(zone.occupancyPercent, locale);
    final facts = [
      if (occupancy != null) 'dash_occupancy'.tr(args: [occupancy]),
      if (zone.totalPeople != null)
        'crowd_people'.tr(args: ['${zone.totalPeople}']),
      if (zone.capacity != null && zone.capacity! > 0)
        'crowd_capacity'.tr(args: ['${zone.capacity}']),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  (zone.name ?? zone.code ?? '').trim(),
                  style: text.titleLarge,
                ),
              ),
            ),
            AppIconButton(
              icon: Icons.close_rounded,
              tooltip: 'crowd_close_zone'.tr(),
              onPressed: onClose,
            ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusPill(
            label: style.label,
            icon: crowdIcon(level),
            foreground: style.fg,
            background: style.bg,
          ),
        ),
        if (occupancy != null) ...[
          AppSpacing.gapMd,
          Semantics(
            label: 'dash_occupancy'.tr(args: [occupancy]),
            child: ClipRRect(
              borderRadius: AppRadius.pillAll,
              child: LinearProgressIndicator(
                value: (zone.occupancyPercent! / 100).clamp(0.0, 1.0),
                minHeight: 8,
                color: crowdLevelColor(context, level),
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
          ),
        ],
        if (facts.isNotEmpty) ...[
          AppSpacing.gapSm,
          Text(facts.join(' · '), style: text.bodyMedium),
        ],
        if (checkedAt != null) ...[
          AppSpacing.gapXs,
          Text(
            'dash_crowd_checked_at'.tr(
              args: [formatClockTime(checkedAt!, locale)],
            ),
            style: text.bodySmall,
          ),
        ],
        AppSpacing.gapLg,
        Text('crowd_zone_alerts'.tr(), style: text.titleSmall),
        AppSpacing.gapSm,
        ...switch (detail.status.value) {
          FeedStatus.loading => [const LinearProgressIndicator()],
          FeedStatus.failed => [
            _InlineError(
              message: 'crowd_zone_failed'.tr(),
              onRetry: detail.load,
            ),
          ],
          FeedStatus.ready => () {
            final alerts =
                (detail.bloc.state.zoneDetails.alerts ?? const [])
                    .where((a) => (a.title ?? '').trim().isNotEmpty)
                    .toList();
            if (alerts.isEmpty) {
              return [
                Text(
                  'crowd_no_zone_alerts'.tr(),
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ];
            }
            return [
              for (final a in alerts)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        severityStyle(context, a.severity)?.icon ??
                            Icons.campaign_outlined,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                      AppSpacing.gapSm,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title!.trim(), style: text.bodyMedium),
                            AppSpacing.gapXs,
                            SeverityPill(severity: a.severity),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ];
          }(),
        },
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Row(
      children: [
        Icon(Icons.cloud_off_rounded, size: 20, color: colors.onSurfaceVariant),
        AppSpacing.gapSm,
        Expanded(child: Text(message, style: context.textTheme.bodyMedium)),
        TextButton(onPressed: onRetry, child: Text('common_retry'.tr())),
      ],
    );
  }
}
