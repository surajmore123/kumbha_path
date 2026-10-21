import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:url_launcher/url_launcher.dart';

/// Route preview returned by the Google Directions API. Text values are
/// Google's own (already localized by Google), never computed here.
@immutable
class RouteSummary {
  const RouteSummary({
    required this.distanceText,
    required this.durationText,
    required this.points,
  });

  final String distanceText;
  final String durationText;
  final List<LatLng> points;
}

/// The navigation map's existing network calls, unchanged: the Directions
/// API request (same URL, parameters and `ApiConst.googleMapsKey`) and the
/// hand-off to the Google Maps app for turn-by-turn navigation.
class TempleDirections {
  const TempleDirections();

  /// `mode` is `driving` or `walking`, as before. Returns null on any
  /// failure (network, non-OK status, unexpected response).
  Future<RouteSummary?> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    required String mode,
  }) async {
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&mode=$mode&"
        "&key=${ApiConst.googleMapsKey}";
    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      if (data['status'] != 'OK') return null;
      final route = data['routes'][0];
      final leg = route['legs'][0];
      final decoded = PolylinePoints.decodePolyline(
        route['overview_polyline']['points'] as String,
      );
      return RouteSummary(
        distanceText: leg['distance']['text'] as String,
        durationText: leg['duration']['text'] as String,
        points: [for (final p in decoded) LatLng(p.latitude, p.longitude)],
      );
    } catch (_) {
      return null;
    }
  }

  /// Opens Google Maps directions (external app or browser), as the Start
  /// button did. Without a known [origin], Google Maps uses the device's
  /// current location itself.
  Future<bool> openInGoogleMaps({
    LatLng? origin,
    required LatLng destination,
    required String mode,
  }) async {
    final url =
        "https://www.google.com/maps/dir/?api=1"
        "${origin == null ? '' : '&origin=${origin.latitude},${origin.longitude}'}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&travelmode=$mode";
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
