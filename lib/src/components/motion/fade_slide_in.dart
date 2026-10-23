import 'dart:async';

import 'package:flutter/material.dart';

/// Fades and slides its child up into place once, when first built.
///
/// [index] staggers items in a list (each starts [stagger] after the
/// previous, capped so long lists don't wait). With the system "reduce
/// motion" setting on, the child simply appears.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.stagger = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 380),
    this.offset = 24,
  });

  final Widget child;
  final int index;
  final Duration stagger;
  final Duration duration;

  /// Starting distance below the final position, in logical pixels.
  final double offset;

  static const int _maxStaggered = 8;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  Timer? _delay;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    final steps = widget.index.clamp(0, FadeSlideIn._maxStaggered);
    if (steps == 0) {
      _controller.forward();
    } else {
      _delay = Timer(widget.stagger * steps, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder:
          (context, child) => Opacity(
            opacity: _curve.value,
            child: Transform.translate(
              offset: Offset(0, widget.offset * (1 - _curve.value)),
              child: child,
            ),
          ),
    );
  }
}

/// Scales its child down slightly while pressed, for tappable cards.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: widget.onTap == null ? null : (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !reduce ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
