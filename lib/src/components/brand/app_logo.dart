import 'package:flutter/material.dart';

/// The Kumbh Path logo (temple, sun and Godavari) on a transparent
/// background. Decorative by default; give [semanticLabel] where the logo
/// is the only thing naming the app.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40, this.semanticLabel});

  final double size;
  final String? semanticLabel;

  static const String asset = 'assets/app/app_logo.png';

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: (size * dpr).round(),
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      errorBuilder: (_, __, ___) => SizedBox.square(dimension: size),
    );
  }
}
