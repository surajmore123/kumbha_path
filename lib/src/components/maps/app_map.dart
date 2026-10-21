import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Everything an app map needs, independent of the map widget.
@immutable
class AppMapConfig {
  const AppMapConfig({
    required this.target,
    required this.zoom,
    this.markers = const {},
    this.circles = const {},
    this.polylines = const {},
    this.interactive = true,
    this.showMyLocation = false,
    this.liteMode = false,
    this.padding = EdgeInsets.zero,
    this.onMapCreated,
    this.onTap,
  });

  final LatLng target;
  final double zoom;
  final Set<Marker> markers;
  final Set<Circle> circles;
  final Set<Polyline> polylines;

  /// False for small previews embedded in scrolling pages.
  final bool interactive;

  /// The platform "blue dot". Requires location permission.
  final bool showMyLocation;

  /// Android lite mode: a static bitmap, cheap for previews.
  final bool liteMode;

  /// Keeps the Google logo and camera fits clear of overlays.
  final EdgeInsets padding;
  final MapCreatedCallback? onMapCreated;

  /// Taps on the map itself (not on markers).
  final ArgumentCallback<LatLng>? onTap;
}

typedef AppMapBuilder =
    Widget Function(BuildContext context, AppMapConfig config);

/// The app's Google Map (google_maps_flutter with the existing platform
/// keys), shared by Temple Explorer and Live Crowd.
class AppMap extends StatelessWidget {
  const AppMap({super.key, required this.config});

  final AppMapConfig config;

  /// Replaces the native map in widget tests, where the platform view
  /// isn't available. Never set in app code.
  @visibleForTesting
  static AppMapBuilder? debugBuilder;

  @override
  Widget build(BuildContext context) {
    final override = debugBuilder;
    if (override != null) return override(context, config);

    final c = config;
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: c.target, zoom: c.zoom),
      markers: c.markers,
      circles: c.circles,
      polylines: c.polylines,
      myLocationEnabled: c.showMyLocation,
      // The screen provides its own, theme-matched recenter button.
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: c.interactive,
      liteModeEnabled:
          c.liteMode && defaultTargetPlatform == TargetPlatform.android,
      scrollGesturesEnabled: c.interactive,
      zoomGesturesEnabled: c.interactive,
      rotateGesturesEnabled: c.interactive,
      tiltGesturesEnabled: c.interactive,
      padding: c.padding,
      onMapCreated: c.onMapCreated,
      onTap: c.onTap,
    );
  }
}

/// Parses an API coordinate pair. `null` unless both are valid numbers in
/// range and not the (0, 0) placeholder the models default to.
LatLng? parseLatLng(Object? lat, Object? lng) {
  double? toDouble(Object? v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.trim());
  final la = toDouble(lat), lo = toDouble(lng);
  if (la == null || lo == null) return null;
  if (la.abs() > 90 || lo.abs() > 180) return null;
  if (la == 0 && lo == 0) return null;
  return LatLng(la, lo);
}
