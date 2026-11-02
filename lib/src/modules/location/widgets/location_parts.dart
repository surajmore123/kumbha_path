import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/location/data/location_repository.dart';
import 'package:kumbha_path/src/modules/location/models/location_models.dart';

String locationErrorText(Object error) =>
    error is SharingClosed ? 'loc_session_ended'.tr() : familyErrorText(error);

/// "2 min ago". Always how long ago, never a claim about now.
String agoText(int seconds) {
  if (seconds < 60) return 'loc_ago_now'.tr();
  if (seconds < 3600) return 'loc_ago_minutes'.plural(seconds ~/ 60);
  return 'loc_ago_hours'.plural(seconds ~/ 3600);
}

String timeLeftText(Duration left) {
  final hours = left.inHours;
  final minutes = left.inMinutes.remainder(60);
  if (hours == 0) return 'loc_left_minutes'.tr(args: ['${left.inMinutes}']);
  return 'loc_left_hours'.tr(args: ['$hours', '$minutes']);
}

String durationLabel(int minutes) =>
    minutes < 60
        ? 'loc_minutes_short'.tr(args: ['$minutes'])
        : 'loc_hours_short'.tr(args: ['${minutes ~/ 60}']);

String accuracyText(double metres) =>
    'loc_accuracy'.tr(args: [metres.round().toString()]);

String freshnessLabel(Freshness freshness) => switch (freshness) {
  Freshness.live => 'loc_state_live'.tr(),
  Freshness.recent => 'loc_state_recent'.tr(),
  Freshness.lastKnown => 'loc_state_last_known'.tr(),
  Freshness.unavailable => 'loc_state_unavailable'.tr(),
  Freshness.paused => 'loc_state_paused'.tr(),
  Freshness.expired => 'loc_state_expired'.tr(),
};

Color freshnessColor(BuildContext context, Freshness freshness) {
  final s = context.semanticColors;
  return switch (freshness) {
    Freshness.live => s.success,
    Freshness.recent => s.info,
    Freshness.lastKnown => s.warning,
    Freshness.paused => s.gold,
    _ => context.colorScheme.outline,
  };
}

IconData freshnessIcon(Freshness freshness) => switch (freshness) {
  Freshness.live => Icons.radio_button_checked_rounded,
  Freshness.recent => Icons.schedule_rounded,
  Freshness.lastKnown => Icons.history_rounded,
  Freshness.unavailable => Icons.location_off_outlined,
  Freshness.paused => Icons.pause_circle_outline_rounded,
  Freshness.expired => Icons.timer_off_outlined,
};

/// The state in words and an icon, so it never relies on colour.
class FreshnessTag extends StatelessWidget {
  const FreshnessTag(this.freshness, {super.key});

  final Freshness freshness;

  @override
  Widget build(BuildContext context) {
    final color = freshnessColor(context, freshness);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(freshnessIcon(freshness), size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            freshnessLabel(freshness),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

/// A portrait with a ring in the colour of how fresh the position is.
class PersonBadge extends StatelessWidget {
  const PersonBadge({
    super.key,
    required this.person,
    required this.familyId,
    required this.freshness,
    this.repository,
    this.size = 44,
  });

  final LocationPerson person;
  final String familyId;
  final Freshness freshness;
  final FamilyRepository? repository;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final initials = Center(
      child: Text(
        initialsOf(person.name),
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w600,
          color: colors.onPrimary,
        ),
      ),
    );
    final repo = repository;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: freshnessColor(context, freshness),
          width: 2.5,
        ),
      ),
      child: ClipOval(
        child: ColoredBox(
          color: colors.primary,
          child:
              person.hasPhoto && repo != null
                  ? FutureBuilder<Uint8List?>(
                    future: FamilyPhotos.load(repo, familyId, person.memberId),
                    builder: (context, snapshot) {
                      final bytes = snapshot.data;
                      if (bytes == null) return initials;
                      return Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        width: size,
                        height: size,
                        errorBuilder: (_, __, ___) => initials,
                      );
                    },
                  )
                  : initials,
        ),
      ),
    );
  }
}

/// Drawn map pins: the person's initials in a disc, ringed in the freshness
/// colour. A position that isn't current gets a broken ring and a hollow
/// disc, so old and live pins differ in shape as well as colour.
class LocationMarkers {
  LocationMarkers._();

  /// Tests have no engine to draw with.
  @visibleForTesting
  static bool debugPlain = false;

  static final _cache = <String, BitmapDescriptor>{};

  static Future<BitmapDescriptor> pin({
    required String initials,
    required Color ring,
    required Color fill,
    required Color text,
    required bool current,
  }) async {
    if (debugPlain) return BitmapDescriptor.defaultMarker;
    final key = '$initials|${ring.toARGB32()}|${fill.toARGB32()}|$current';
    final cached = _cache[key];
    if (cached != null) return cached;
    final bytes = await drawPin(
      initials: initials,
      ring: ring,
      fill: fill,
      text: text,
      current: current,
    );
    return _cache[key] = BitmapDescriptor.bytes(bytes, width: 52, height: 62);
  }

  @visibleForTesting
  static Future<Uint8List> drawPin({
    required String initials,
    required Color ring,
    required Color fill,
    required Color text,
    required bool current,
  }) async {
    const scale = 3.0;
    const width = 52.0;
    const height = 62.0;
    const radius = 22.0;
    const center = Offset(width / 2, radius + 3);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);

    final tip =
        Path()
          ..moveTo(center.dx - 9, center.dy + radius - 4)
          ..lineTo(center.dx, height - 2)
          ..lineTo(center.dx + 9, center.dy + radius - 4)
          ..close();
    canvas.drawPath(tip, Paint()..color = ring);
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = current ? fill : const Color(0xFFFFFFFF),
    );
    final stroke =
        Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;
    if (current) {
      canvas.drawCircle(center, radius - 2, stroke);
    } else {
      const dashes = 10;
      const sweep = 3.14159265 * 2 / dashes;
      final rect = Rect.fromCircle(center: center, radius: radius - 2);
      for (var i = 0; i < dashes; i++) {
        canvas.drawArc(rect, i * sweep, sweep * 0.6, false, stroke);
      }
    }
    final painter = TextPainter(
      text: TextSpan(
        text: initials,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: current ? text : const Color(0xFF444444),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );

    final image = await recorder.endRecording().toImage(
      (width * scale).round(),
      (height * scale).round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}
