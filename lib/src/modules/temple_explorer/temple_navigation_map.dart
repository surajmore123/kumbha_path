import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/location_service.dart';
import 'package:kumbha_path/src/modules/temple_explorer/temple_directions.dart';
import 'package:kumbha_path/src/modules/temple_explorer/widgets/temple_map.dart';

enum _RouteState { waitingForLocation, loading, ready, failed }

/// Route preview to a temple: Google Map with the temple marker, the user's
/// position and the Directions API route for driving or walking; "Start"
/// hands off to Google Maps for navigation (unchanged behavior).
///
/// The map is visible immediately, centred on the temple, while the user's
/// location and the route load. Distance and duration are shown only when
/// the Directions API returns them.
class TempleNavigationMap extends StatefulWidget {
  final double templelat;
  final double templelng;
  final String templeName;

  const TempleNavigationMap({
    super.key,
    required this.templelat,
    required this.templelng,
    required this.templeName,
    this.location,
    this.directions,
  });

  /// Injected in tests.
  final LocationGateway? location;
  final TempleDirections? directions;

  @override
  State<TempleNavigationMap> createState() => _TempleNavigationMapState();
}

class _TempleNavigationMapState extends State<TempleNavigationMap> {
  late final LocationGateway _location =
      widget.location ?? const LocationGateway();
  late final TempleDirections _directions =
      widget.directions ?? const TempleDirections();

  GoogleMapController? _mapController;
  LatLng? _userLocation;
  bool _locationFailed = false;
  String _travelMode = 'driving';
  RouteSummary? _route;
  _RouteState _routeState = _RouteState.waitingForLocation;
  int _routeRequest = 0;

  static const double _cardReserve = 260;

  LatLng get _temple => LatLng(widget.templelat, widget.templelng);

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    setState(() {
      _locationFailed = false;
      _routeState = _RouteState.waitingForLocation;
    });
    try {
      final position = await _location.currentPosition();
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
      await _fetchRoute();
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationFailed = true);
    }
  }

  Future<void> _fetchRoute() async {
    final origin = _userLocation;
    if (origin == null) return;
    final request = ++_routeRequest;
    setState(() => _routeState = _RouteState.loading);
    final route = await _directions.fetchRoute(
      origin: origin,
      destination: _temple,
      mode: _travelMode,
    );
    // Ignore responses for an older mode selection.
    if (!mounted || request != _routeRequest) return;
    setState(() {
      _route = route;
      _routeState = route == null ? _RouteState.failed : _RouteState.ready;
    });
    _zoomToFit();
  }

  void _zoomToFit() {
    final user = _userLocation;
    if (user == null) return;
    final points = [user, _temple, ...?_route?.points];
    final bounds = LatLngBounds(
      southwest: LatLng(
        points.map((p) => p.latitude).reduce(math.min),
        points.map((p) => p.longitude).reduce(math.min),
      ),
      northeast: LatLng(
        points.map((p) => p.latitude).reduce(math.max),
        points.map((p) => p.longitude).reduce(math.max),
      ),
    );
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
  }

  void _setMode(String mode) {
    if (mode == _travelMode) return;
    setState(() => _travelMode = mode);
    _fetchRoute(); // refetch route on mode change, as before
  }

  Future<void> _startNavigation() async {
    final opened = await _directions.openInGoogleMaps(
      origin: _userLocation,
      destination: _temple,
      mode: _travelMode,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('map_open_failed'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final route = _route;
    final safe = MediaQuery.paddingOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Status bar sits over the map tiles, which are light.
      value: AppTheme.systemOverlayStyle(Brightness.light),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: TempleMap(
                config: TempleMapConfig(
                  target: _temple,
                  zoom: 14,
                  showMyLocation: _userLocation != null,
                  padding: EdgeInsets.only(
                    top: safe.top + AppSpacing.huge + AppSpacing.lg,
                    bottom: _cardReserve,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('temple'),
                      position: _temple,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange,
                      ),
                      infoWindow: InfoWindow(title: widget.templeName),
                    ),
                  },
                  polylines: {
                    if (route != null && _routeState == _RouteState.ready)
                      Polyline(
                        polylineId: const PolylineId('route'),
                        color: colors.primary,
                        width: 6,
                        points: route.points,
                      ),
                  },
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _zoomToFit();
                  },
                ),
              ),
            ),
            // Top: back + place name.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    _MapButton(
                      icon: Icons.arrow_back,
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    AppSpacing.gapSm,
                    Flexible(
                      child: Material(
                        color: context.semanticColors.dialogSurface,
                        shape: const StadiumBorder(),
                        elevation: AppElevation.level2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          child: Text(
                            widget.templeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.titleSmall,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom: route card, with the recenter control above it.
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (_userLocation != null) ...[
                          _MapButton(
                            icon: Icons.my_location,
                            tooltip: 'map_recenter'.tr(),
                            onPressed:
                                () => _mapController?.animateCamera(
                                  CameraUpdate.newLatLng(_userLocation!),
                                ),
                          ),
                          AppSpacing.gapMd,
                        ],
                        _RouteCard(
                          templeName: widget.templeName,
                          routeState: _routeState,
                          route: route,
                          locationFailed: _locationFailed,
                          travelMode: _travelMode,
                          onModeChanged:
                              _userLocation == null ? null : _setMode,
                          onRetryLocation: _getUserLocation,
                          onStart: _startNavigation,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.semanticColors.dialogSurface,
      shape: const CircleBorder(),
      elevation: AppElevation.level2,
      child: AppIconButton(
        icon: icon,
        tooltip: tooltip,
        color: context.colorScheme.onSurface,
        onPressed: onPressed,
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.templeName,
    required this.routeState,
    required this.route,
    required this.locationFailed,
    required this.travelMode,
    required this.onModeChanged,
    required this.onRetryLocation,
    required this.onStart,
  });

  final String templeName;
  final _RouteState routeState;
  final RouteSummary? route;
  final bool locationFailed;
  final String travelMode;
  final ValueChanged<String>? onModeChanged;
  final VoidCallback onRetryLocation;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colorScheme;

    Widget status;
    if (locationFailed) {
      status = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'map_location_unavailable'.tr(),
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          TextButton.icon(
            onPressed: onRetryLocation,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('common_retry'.tr()),
          ),
        ],
      );
    } else {
      status = switch (routeState) {
        _RouteState.waitingForLocation => _Progress(
          'map_finding_location'.tr(),
        ),
        _RouteState.loading => _Progress('map_route_loading'.tr()),
        _RouteState.failed => Text(
          'map_route_unavailable'.tr(),
          style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        _RouteState.ready => Semantics(
          liveRegion: true,
          child: Text(
            'map_route_summary'.tr(
              args: [route!.durationText, route!.distanceText],
            ),
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      };
    }

    return Material(
      color: context.semanticColors.dialogSurface,
      borderRadius: AppRadius.xlAll,
      elevation: AppElevation.level3,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              templeName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.labelLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
            AppSpacing.gapXs,
            status,
            AppSpacing.gapMd,
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'driving',
                  icon: const Icon(Icons.directions_car_outlined),
                  label: Text('map_mode_driving'.tr()),
                ),
                ButtonSegment(
                  value: 'walking',
                  icon: const Icon(Icons.directions_walk),
                  label: Text('map_mode_walking'.tr()),
                ),
              ],
              selected: {travelMode},
              showSelectedIcon: false,
              onSelectionChanged:
                  onModeChanged == null ? null : (s) => onModeChanged!(s.first),
            ),
            AppSpacing.gapMd,
            AppButton(
              label: 'map_start'.tr(),
              leadingIcon: Icons.navigation_outlined,
              onPressed: onStart,
            ),
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        AppSpacing.gapSm,
        Expanded(
          child: Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
