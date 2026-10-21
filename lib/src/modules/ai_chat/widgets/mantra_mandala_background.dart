import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

/// Decorative chat backdrop: concentric rings of mantras around a faded
/// ॐ, with neighbouring rings slowly turning in opposite directions.
///
/// Purely decorative: excluded from semantics, ignores pointers, uses the
/// theme's primary colour at low opacity (light and dark), and holds still
/// when the platform asks for reduced motion. Each ring is recorded once as
/// a picture; a frame only re-draws those pictures rotated, so animation
/// never re-lays out text.
class MantraMandalaBackground extends StatefulWidget {
  const MantraMandalaBackground({super.key});

  /// Mantras are sacred phrases, shown as written in every app language.
  static const List<String> mantras = ['ॐ नमः शिवाय', 'ॐ नमो नारायणाय'];

  @override
  State<MantraMandalaBackground> createState() =>
      _MantraMandalaBackgroundState();
}

class _MantraMandalaBackgroundState extends State<MantraMandalaBackground>
    with SingleTickerProviderStateMixin {
  /// One full loop; every ring turns a whole number of times per loop, so
  /// the repeat is seamless.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(minutes: 6),
  );

  final _MandalaCache _cache = _MandalaCache();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _MandalaPainter(
              progress: _controller,
              cache: _cache,
              style: _MandalaStyle(
                ink: primary.withValues(alpha: dark ? 0.10 : 0.14),
                line: primary.withValues(alpha: dark ? 0.08 : 0.12),
                om: primary.withValues(alpha: dark ? 0.07 : 0.09),
                glow: primary.withValues(alpha: dark ? 0.06 : 0.07),
                textDirection: Directionality.of(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class _MandalaStyle {
  const _MandalaStyle({
    required this.ink,
    required this.line,
    required this.om,
    required this.glow,
    required this.textDirection,
  });

  final Color ink;
  final Color line;
  final Color om;
  final Color glow;
  final TextDirection textDirection;

  @override
  bool operator ==(Object other) =>
      other is _MandalaStyle &&
      other.ink == ink &&
      other.line == line &&
      other.om == om &&
      other.glow == glow &&
      other.textDirection == textDirection;

  @override
  int get hashCode => Object.hash(ink, line, om, glow, textDirection);
}

/// Ring pictures, rebuilt only when the size or colours change.
class _MandalaCache {
  Size? _size;
  _MandalaStyle? _style;
  final List<ui.Picture> rings = [];
  ui.Picture? centre;

  static const double innerRadius = 78;
  static const double ringGap = 34;
  static const double fontSize = 15;
  static const double phraseSpacing = 22;

  void ensure(Size size, _MandalaStyle style) {
    if (size == _size && style == _style && centre != null) return;
    dispose();
    _size = size;
    _style = style;

    // Rings reach the farthest corner so the whole area is covered.
    final outer =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final count = math.max(1, ((outer - innerRadius) / ringGap).ceil() + 1);

    for (var i = 0; i < count; i++) {
      rings.add(
        _recordRing(
          innerRadius + i * ringGap,
          MantraMandalaBackground.mantras[i %
              MantraMandalaBackground.mantras.length],
          style,
        ),
      );
    }
    centre = _recordCentre(size, style);
  }

  ui.Picture _recordRing(double radius, String mantra, _MandalaStyle style) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(
      Offset.zero,
      radius + fontSize,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = style.line,
    );

    // Whole phrases (not single letters) keep Devanagari shaping intact.
    final phrase = TextPainter(
      text: TextSpan(
        text: mantra,
        style: TextStyle(
          fontSize: fontSize,
          height: 1,
          fontWeight: FontWeight.w500,
          color: style.ink,
        ),
      ),
      textDirection: style.textDirection,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();

    final circumference = 2 * math.pi * radius;
    final copies = math.max(
      1,
      (circumference / (phrase.width + phraseSpacing)).floor(),
    );
    final step = 2 * math.pi / copies;
    for (var k = 0; k < copies; k++) {
      canvas
        ..save()
        ..rotate(k * step)
        ..translate(0, -radius);
      phrase.paint(canvas, Offset(-phrase.width / 2, -phrase.height / 2));
      canvas.restore();
    }
    phrase.dispose();
    return recorder.endRecording();
  }

  ui.Picture _recordCentre(Size size, _MandalaStyle style) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final glowRadius = size.longestSide * 0.6;
    canvas.drawCircle(
      Offset.zero,
      glowRadius,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, glowRadius, [
          style.glow,
          style.glow.withValues(alpha: 0),
        ]),
    );
    final om = TextPainter(
      text: TextSpan(
        text: 'ॐ',
        style: TextStyle(fontSize: innerRadius * 1.3, height: 1, color: style.om),
      ),
      textDirection: style.textDirection,
      textScaler: TextScaler.noScaling,
    )..layout();
    om.paint(canvas, Offset(-om.width / 2, -om.height / 2));
    om.dispose();
    return recorder.endRecording();
  }

  void dispose() {
    for (final p in rings) {
      p.dispose();
    }
    rings.clear();
    centre?.dispose();
    centre = null;
  }
}

class _MandalaPainter extends CustomPainter {
  _MandalaPainter({
    required this.progress,
    required this.cache,
    required this.style,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final _MandalaCache cache;
  final _MandalaStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    cache.ensure(size, style);
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(size.width / 2, size.height / 2);
    canvas.drawPicture(cache.centre!);
    final t = progress.value * 2 * math.pi;
    for (var i = 0; i < cache.rings.length; i++) {
      // Alternate direction; the inner rings turn twice per loop.
      final turns = (i.isEven ? 1.0 : -1.0) * (i < 3 ? 2 : 1);
      canvas
        ..save()
        ..rotate(t * turns)
        ..drawPicture(cache.rings[i])
        ..restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MandalaPainter old) =>
      old.style != style || old.cache != cache;
}
