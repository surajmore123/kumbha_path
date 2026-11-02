import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/location/widgets/location_parts.dart';
import 'package:kumbha_path/src/modules/reunion/data/reunion_repository.dart';
import 'package:kumbha_path/src/modules/reunion/models/reunion_models.dart';

String reunionErrorText(Object error) => switch (error) {
  UseSafePoint() => 're_use_safe_point'.tr(),
  RouteUnavailable() => 're_route_unavailable'.tr(),
  _ => locationErrorText(error),
};

String categoryLabel(String category) => 're_cat_$category'.tr();

IconData categoryIcon(String category) => switch (category) {
  'help_desk' => Icons.support_agent_rounded,
  'lost_found' => Icons.person_search_rounded,
  'police' => Icons.local_police_outlined,
  'emergency' => Icons.emergency_outlined,
  'medical' => Icons.medical_services_outlined,
  'hospital' => Icons.local_hospital_outlined,
  'ambulance' => Icons.airport_shuttle_outlined,
  'fire_rescue' => Icons.local_fire_department_outlined,
  _ => Icons.groups_outlined,
};

/// Great-circle distance, for sorting and filtering on the phone so that a
/// position needn't leave it. Always shown as straight-line.
double straightLineKm((double, double) a, double lat, double lng) {
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat - a.$1);
  final dLng = rad(lng - a.$2);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.$1)) *
          math.cos(rad(lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 6371 * 2 * math.asin(math.min(1, math.sqrt(h)));
}

String straightLineText(double km) =>
    km < 1
        ? 're_straight_m'.tr(args: ['${(km * 1000).round()}'])
        : 're_straight_km'.tr(args: [km.toStringAsFixed(1)]);

/// The provider's own figures, formatted. There's no way to call this without
/// them, so a distance can't appear from anywhere else.
String routeDistanceText(int metres) =>
    metres < 1000
        ? 're_route_m'.tr(args: ['$metres'])
        : 're_route_km'.tr(args: [(metres / 1000).toStringAsFixed(1)]);

String routeDurationText(int seconds) {
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return 're_route_min'.tr(args: ['$minutes']);
  return 're_route_hours'.tr(args: ['${minutes ~/ 60}', '${minutes % 60}']);
}

String googleMapsWalkingUrl(double latitude, double longitude) =>
    'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=walking';

/// Google's encoded polyline format.
List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;
  int next() {
    var shift = 0;
    var result = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20 && index < encoded.length);
    return result.isOdd ? ~(result >> 1) : result >> 1;
  }

  while (index < encoded.length) {
    lat += next();
    if (index >= encoded.length) break;
    lng += next();
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}

/// How far a point can be trusted, in words. This is the only wording used, so
/// nothing unverified can read as official.
class TrustTag extends StatelessWidget {
  const TrustTag(this.point, {super.key});

  final MeetingPoint point;

  @override
  Widget build(BuildContext context) {
    final s = context.semanticColors;
    final (icon, color, key) =
        point.isOfficial
            ? (Icons.verified_rounded, s.success, 're_trust_official')
            : point.isVerified
            ? (Icons.verified_outlined, s.success, 're_trust_verified')
            : point.isPrivate
            ? (Icons.lock_outline_rounded, s.info, 're_trust_family')
            : (Icons.help_outline_rounded, s.warning, 're_trust_community');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            key.tr(),
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// A place to go, as one row.
class PointRow extends StatelessWidget {
  const PointRow({
    super.key,
    required this.point,
    required this.onTap,
    this.km,
  });

  final MeetingPoint point;
  final VoidCallback onTap;
  final double? km;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final colors = context.colorScheme;
    final distance = km ?? point.straightLineKm;
    return Pressable(
      onTap: onTap,
      label: '${point.name}, ${categoryLabel(point.category)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(categoryIcon(point.category), color: colors.primary),
            ),
            AppSpacing.gapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(point.name, style: e.title),
                  MetaLine([
                    categoryLabel(point.category),
                    if (distance != null) straightLineText(distance),
                  ]),
                  AppSpacing.gapXs,
                  TrustTag(point),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What to do when someone can't look after themselves. Shown wherever a
/// protected person is involved, ahead of anything else.
class SafetyPanel extends StatelessWidget {
  const SafetyPanel({super.key, this.selfProtected = false, this.action});

  final bool selfProtected;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final s = context.semanticColors;
    final e = context.editorial;
    Widget line(String key) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 16,
              color: s.onWarningContainer,
            ),
          ),
          AppSpacing.gapSm,
          Expanded(
            child: Text(
              key.tr(),
              style: TextStyle(color: s.onWarningContainer),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: s.warningContainer,
          borderRadius: AppRadius.lgAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: s.onWarningContainer),
                AppSpacing.gapSm,
                Expanded(
                  child: Text(
                    (selfProtected ? 're_safe_self_title' : 're_safe_title')
                        .tr(),
                    style: e.title.copyWith(color: s.onWarningContainer),
                  ),
                ),
              ],
            ),
            if (selfProtected) ...[
              line('re_safe_self_1'),
              line('re_safe_self_2'),
              line('re_safe_self_3'),
            ] else ...[
              line('re_safe_1'),
              line('re_safe_2'),
              line('re_safe_3'),
              line('re_safe_4'),
            ],
            if (action != null) ...[AppSpacing.gapSm, action!],
          ],
        ),
      ),
    );
  }
}

/// The workflow as a thread, with the current step in words.
class ReunionStageRail extends StatelessWidget {
  const ReunionStageRail({super.key, required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final step = reunionStages.indexOf(stage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (step >= 0) ...[
          StepThread(step: step, total: reunionStages.length),
          AppSpacing.gapSm,
        ],
        Text('re_stage_$stage'.tr(), style: e.title),
        Text('re_stage_${stage}_means'.tr(), style: e.meta),
      ],
    );
  }
}

/// The map's marker shapes. Each kind has its own outline as well as its own
/// colour, so they can be told apart without colour.
enum MarkerShape {
  helpPoint,
  meetingSpot,
  lastSeen,
  sightingReported,
  sightingVerified,
}

class ReunionMarkers {
  ReunionMarkers._();

  @visibleForTesting
  static bool debugPlain = false;

  static final _cache = <String, BitmapDescriptor>{};

  static Future<BitmapDescriptor> icon({
    required MarkerShape shape,
    required IconData glyph,
    required Color color,
    required Color onColor,
  }) async {
    if (debugPlain) return BitmapDescriptor.defaultMarker;
    final key = '${shape.name}|${glyph.codePoint}|${color.toARGB32()}';
    final cached = _cache[key];
    if (cached != null) return cached;
    final bytes = await draw(
      shape: shape,
      glyph: glyph,
      color: color,
      onColor: onColor,
    );
    return _cache[key] = BitmapDescriptor.bytes(bytes, width: 46, height: 46);
  }

  @visibleForTesting
  static Future<Uint8List> draw({
    required MarkerShape shape,
    required IconData glyph,
    required Color color,
    required Color onColor,
  }) async {
    const scale = 3.0;
    const size = 46.0;
    const center = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    final fill = Paint()..color = color;
    final edge =
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
    final hollow = Paint()..color = const Color(0xFFFFFFFF);
    final line =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
    var glyphColor = onColor;
    switch (shape) {
      case MarkerShape.helpPoint:
        final box = RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 38, height: 38),
          const Radius.circular(10),
        );
        canvas
          ..drawRRect(box, fill)
          ..drawRRect(box, edge);
      case MarkerShape.meetingSpot:
        final box = RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 36, height: 36),
          const Radius.circular(10),
        );
        canvas
          ..drawRRect(box, hollow)
          ..drawRRect(box, line);
        glyphColor = color;
      case MarkerShape.lastSeen:
        final diamond =
            Path()
              ..moveTo(center.dx, 2)
              ..lineTo(size - 2, center.dy)
              ..lineTo(center.dx, size - 2)
              ..lineTo(2, center.dy)
              ..close();
        canvas
          ..drawPath(diamond, fill)
          ..drawPath(diamond, edge);
      case MarkerShape.sightingVerified:
      case MarkerShape.sightingReported:
        final triangle =
            Path()
              ..moveTo(center.dx, 3)
              ..lineTo(size - 3, size - 6)
              ..lineTo(3, size - 6)
              ..close();
        final verified = shape == MarkerShape.sightingVerified;
        canvas
          ..drawPath(triangle, verified ? fill : hollow)
          ..drawPath(triangle, verified ? edge : line);
        if (!verified) glyphColor = color;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(glyph.codePoint),
        style: TextStyle(
          fontFamily: glyph.fontFamily,
          package: glyph.fontPackage,
          fontSize: shape == MarkerShape.helpPoint ? 24 : 18,
          color: glyphColor,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final isTriangle =
        shape == MarkerShape.sightingReported ||
        shape == MarkerShape.sightingVerified;
    painter.paint(
      canvas,
      center -
          Offset(painter.width / 2, painter.height / 2) +
          Offset(0, isTriangle ? 5 : 0),
    );
    final image = await recorder.endRecording().toImage(
      (size * scale).round(),
      (size * scale).round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}
