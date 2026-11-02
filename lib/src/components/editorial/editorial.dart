import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

/// Editorial side margin, wider than the app default for easier reading.
const double editorialMargin = AppSpacing.xl;
const EdgeInsets editorialPage = EdgeInsets.symmetric(
  horizontal: editorialMargin,
);

/// Comfortable line length for reading on tablets.
const double editorialMaxWidth = 680;

bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// A stepped lower edge, like ghat stairs going down into the river. The
/// signature shape of the journal: images end here and fall into the page.
class GhatEdgeClipper extends CustomClipper<Path> {
  const GhatEdgeClipper({this.stepHeight = 10, this.steps = 5});

  final double stepHeight;
  final int steps;

  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(size.width, 0);
    final stepWidth = size.width * 0.34 / steps;
    var y = size.height - stepHeight * steps;
    path.lineTo(size.width, y);
    var x = size.width;
    for (var i = 0; i < steps; i++) {
      x -= stepWidth;
      path
        ..lineTo(x, y)
        ..lineTo(x, y + stepHeight);
      y += stepHeight;
    }
    path
      ..lineTo(0, y)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(GhatEdgeClipper oldClipper) =>
      oldClipper.stepHeight != stepHeight || oldClipper.steps != steps;
}

/// A temple-arch crop for places: a pointed shikhara over straight sides.
class ArchClipper extends CustomClipper<Path> {
  const ArchClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final shoulder = w * 0.62;
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(0, shoulder)
      ..cubicTo(0, shoulder * 0.46, w * 0.34, shoulder * 0.3, w / 2, 0)
      ..cubicTo(w * 0.66, shoulder * 0.3, w, shoulder * 0.46, w, shoulder)
      ..lineTo(w, size.height)
      ..close();
  }

  @override
  bool shouldReclip(ArchClipper oldClipper) => false;
}

/// A hairline rule with three small steps at its left end.
class GhatRule extends StatelessWidget {
  const GhatRule({super.key, this.padding = editorialPage});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: ExcludeSemantics(
      child: CustomPaint(
        size: const Size(double.infinity, 10),
        painter: _GhatRulePainter(context.semanticColors.gold),
      ),
    ),
  );
}

class _GhatRulePainter extends CustomPainter {
  const _GhatRulePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    const step = 8.0;
    const rise = 3.0;
    final path = Path()..moveTo(0, 1);
    for (var i = 0; i < 3; i++) {
      path
        ..relativeLineTo(step, 0)
        ..relativeLineTo(0, rise);
    }
    path.lineTo(size.width, 1 + rise * 3);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_GhatRulePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A network image that fades in from a plain tone, and stays a plain tone
/// if it can't load. Broken-image icons have no place in a journal.
class EditorialImage extends StatelessWidget {
  const EditorialImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.fallbackIcon,
  });

  final String? url;
  final BoxFit fit;
  final Alignment alignment;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final tone = ColoredBox(
      color: colors.surfaceContainerHigh,
      child:
          fallbackIcon == null
              ? const SizedBox.expand()
              : Center(
                child: Icon(
                  fallbackIcon,
                  size: 32,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
    );
    final link = url;
    if (link == null) return tone;
    return CachedNetworkImage(
      imageUrl: link,
      fit: fit,
      alignment: alignment,
      fadeInDuration:
          reduceMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
      placeholder: (_, __) => tone,
      errorWidget: (_, __, ___) => tone,
    );
  }
}

/// A small category label over a hairline tick.
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = context.editorial.kicker.copyWith(color: color);
    return Row(
      children: [
        Container(width: 16, height: 1.5, color: style.color),
        AppSpacing.gapSm,
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

/// Publisher and date, or any two small facts, separated by a dot.
class MetaLine extends StatelessWidget {
  const MetaLine(this.parts, {super.key, this.color});

  final List<String> parts;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    parts.where((p) => p.isNotEmpty).join('  ·  '),
    style: context.editorial.meta.copyWith(color: color),
  );
}

/// Presses down very slightly, so tappable editorial blocks feel physical
/// without a ripple across a photograph.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.label,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? label;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (value != _down) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: AnimatedScale(
          scale: _down && !reduceMotion(context) ? 0.985 : 1,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Round icon button that stays readable over a photograph.
class ImageIconButton extends StatelessWidget {
  const ImageIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Material(
      color: colors.surface.withValues(alpha: 0.88),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 20,
          color: selected ? colors.primary : colors.onSurface,
        ),
      ),
    );
  }
}

/// A plain block standing in for text or an image while content loads.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, this.width, this.height = 14});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    decoration: BoxDecoration(
      color: context.colorScheme.surfaceContainerHigh,
      borderRadius: AppRadius.mdAll,
    ),
  );
}
