import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/components/maps/app_map.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show openExternal;
import 'package:kumbha_path/src/modules/location/models/location_models.dart';
import 'package:kumbha_path/src/modules/location/widgets/location_parts.dart';
import 'package:kumbha_path/src/modules/lostfound/report_screens.dart'
    show PositionReader;
import 'package:kumbha_path/src/modules/lostfound/widgets/lf_parts.dart'
    show readPosition;
import 'package:kumbha_path/src/modules/reunion/data/reunion_repository.dart';
import 'package:kumbha_path/src/modules/reunion/models/reunion_models.dart';
import 'package:kumbha_path/src/modules/reunion/widgets/reunion_parts.dart';

/// `/reunionRoute`: a walking route, with the provider's own distance and time.
/// When there's no route, it says so and offers Google Maps. It never estimates.
class RoutePreviewScreen extends StatefulWidget {
  const RoutePreviewScreen({
    super.key,
    required this.target,
    this.repository,
    this.position,
  });

  final RouteTarget target;
  final ReunionRepository? repository;
  final PositionReader? position;

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

enum _Problem { none, noGps, noProvider, offline, safety, other }

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  late final ReunionRepository _repo =
      widget.repository ?? ReunionServices.repository;
  bool _loading = true;
  WalkingRoute? _route;
  (double, double)? _origin;
  _Problem _problem = _Problem.none;
  Object? _error;
  GoogleMapController? _map;

  RouteTarget get _target => widget.target;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _problem = _Problem.none;
    });
    final origin = await (widget.position ?? readPosition)();
    if (!mounted) return;
    if (origin == null) {
      setState(() {
        _loading = false;
        _problem = _Problem.noGps;
      });
      return;
    }
    _origin = origin;
    try {
      final route = await _repo.route(_target, origin);
      ReunionServices.lastRoutes[_target.key] = route;
      if (!mounted) return;
      setState(() {
        _route = route;
        _loading = false;
      });
      _fit();
    } on UseSafePoint {
      ReunionServices.lastRoutes.remove(_target.key);
      if (mounted) _fail(_Problem.safety);
    } on RouteUnavailable {
      if (mounted) _fail(_Problem.noProvider);
    } on FamilyException catch (e) {
      if (e.kind == FamilyFailure.notFound) {
        // Sharing ended or access went: an old route must not survive that.
        ReunionServices.lastRoutes.remove(_target.key);
      }
      if (mounted) {
        _error = e;
        _fail(
          e.kind == FamilyFailure.offline ? _Problem.offline : _Problem.other,
        );
      }
    }
  }

  void _fail(_Problem problem) {
    setState(() {
      _loading = false;
      _problem = problem;
      _route =
          problem == _Problem.offline
              ? ReunionServices.lastRoutes[_target.key]
              : null;
    });
  }

  List<LatLng> get _line => decodePolyline(_route?.polyline ?? '');

  void _fit() {
    final map = _map;
    final points = [..._line, LatLng(_target.latitude, _target.longitude)];
    if (map == null || points.length < 2) return;
    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    map.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            lats.reduce((a, b) => a < b ? a : b),
            lngs.reduce((a, b) => a < b ? a : b),
          ),
          northeast: LatLng(
            lats.reduce((a, b) => a > b ? a : b),
            lngs.reduce((a, b) => a > b ? a : b),
          ),
        ),
        64,
      ),
    );
  }

  void _openGoogleMaps() => openExternal(
    context,
    googleMapsWalkingUrl(_target.latitude, _target.longitude),
  );

  Freshness? get _destination => switch (_route?.state) {
    'live' => Freshness.live,
    'recent' => Freshness.recent,
    'last_known' => Freshness.lastKnown,
    _ => null,
  };

  Widget _mapView() {
    final colors = context.colorScheme;
    final line = _line;
    return AppMap(
      config: AppMapConfig(
        target: LatLng(_target.latitude, _target.longitude),
        zoom: 15,
        showMyLocation: _origin != null,
        markers: {
          Marker(
            markerId: const MarkerId('destination'),
            position: LatLng(_target.latitude, _target.longitude),
            infoWindow: InfoWindow(title: _target.name),
          ),
        },
        polylines: {
          if (line.isNotEmpty)
            Polyline(
              polylineId: const PolylineId('route'),
              points: line,
              width: 6,
              color: colors.primary,
              patterns:
                  _problem == _Problem.offline
                      ? [PatternItem.dash(18), PatternItem.gap(12)]
                      : const [],
            ),
        },
        padding: const EdgeInsets.only(bottom: 260),
        onMapCreated: (controller) {
          _map = controller;
          _fit();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    if (!_loading && problem == _Problem.safety) {
      return Scaffold(
        appBar: AppBar(title: Text('re_route_title'.tr())),
        body: ListView(
          padding: const EdgeInsets.all(editorialMargin),
          children: [
            SafetyPanel(
              selfProtected: true,
              action: AppButton(
                label: 're_find_help'.tr(),
                leadingIcon: Icons.support_agent_rounded,
                onPressed:
                    () => Navigator.pushReplacementNamed(
                      context,
                      '/reunionPoints',
                      arguments: PointExplorerArgs(
                        safeOnly: true,
                        caseId: _target.caseId,
                      ),
                    ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('re_route_title'.tr()),
        backgroundColor: context.colorScheme.surface.withValues(alpha: 0.9),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _mapView()),
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: context.colorScheme.surface,
              elevation: 8,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _panel(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel() {
    final e = context.editorial;
    final route = _route;
    final destination = _destination;
    final captured = route?.capturedAt;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            _target.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: e.headline,
          ),
        ),
        AppSpacing.gapXs,
        if (_loading)
          const SkeletonLine()
        else if (route != null) ...[
          MetaLine([
            routeDistanceText(route.distanceM),
            routeDurationText(route.durationS),
            're_route_walking'.tr(),
          ]),
          if (_problem == _Problem.offline) ...[
            AppSpacing.gapXs,
            Text(
              're_route_old'.tr(
                args: [TimeOfDay.fromDateTime(route.fetchedAt).format(context)],
              ),
              style: e.meta.copyWith(color: context.colorScheme.error),
            ),
          ],
        ] else
          Text(switch (_problem) {
            _Problem.noGps => 're_route_no_gps'.tr(),
            _Problem.noProvider => 're_route_unavailable'.tr(),
            _Problem.offline => 're_route_offline'.tr(),
            _ => _error == null ? '' : reunionErrorText(_error!),
          }),
        if (destination != null) ...[
          AppSpacing.gapSm,
          FreshnessTag(destination),
          if (captured != null)
            Text(
              'loc_updated'.tr(
                args: [agoText(DateTime.now().difference(captured).inSeconds)],
              ),
              style: e.meta,
            ),
          if (destination == Freshness.lastKnown)
            Text('loc_may_have_moved'.tr(), style: e.meta),
        ],
        if (route?.caution == 'stay_put') ...[
          AppSpacing.gapSm,
          FamilyNote(text: 're_caution_stay_put'.tr()),
        ],
        AppSpacing.gapMd,
        AppButton(
          label: 're_open_google_maps'.tr(),
          leadingIcon: Icons.navigation_outlined,
          onPressed: _openGoogleMaps,
        ),
        if (!_loading && _problem != _Problem.none)
          TextButton(onPressed: _load, child: Text('common_retry'.tr())),
      ],
    );
  }
}

/// Arguments for the point explorer.
class PointExplorerArgs {
  const PointExplorerArgs({
    this.safeOnly = false,
    this.caseId,
    this.familyId,
    this.picking = false,
  });

  /// Only verified, staffed places.
  final bool safeOnly;
  final String? caseId;
  final String? familyId;

  /// Choosing a place for the case, rather than browsing.
  final bool picking;
}
