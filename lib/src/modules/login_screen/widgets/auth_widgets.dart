import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

/// How long an auth request may stay pending before the screen offers a
/// retry. The bloc stays in `sending` forever if the API call fails at the
/// network level, so the screens time out on their own.
const Duration kAuthRequestTimeout = Duration(seconds: 30);

/// Masks the middle digits of a phone number: `9876543210` → `98•••••210`.
/// Short or non-numeric input is returned unchanged.
String maskPhoneNumber(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 6) return phone;
  final hidden = digits.length - 5;
  return '${digits.substring(0, 2)}${'•' * hidden}'
      '${digits.substring(digits.length - 3)}';
}

/// The Kumbh Path lotus mark in a soft circle.
class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key, this.size = 72});

  final double size;

  static const String asset = 'assets/icons/login_screen.png';

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      image: true,
      label: 'app_title'.tr(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerLowest,
          shape: BoxShape.circle,
          boxShadow: AppElevation.shadow(2, context.theme.brightness),
        ),
        padding: EdgeInsets.all(size * 0.06),
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          cacheWidth: (size * dpr).round(),
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

/// Trimbakeshwar temple photograph with the scrim used for on-image text.
class AuthPhoto extends StatelessWidget {
  const AuthPhoto({super.key, this.child, this.alignment});

  final Widget? child;
  final Alignment? alignment;

  static const String asset = 'assets/images/triambakeshwar.png';

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    // Photo and scrim fill whatever size the child (or parent) dictates.
    return Stack(
      alignment: AlignmentDirectional.bottomStart,
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dpr = MediaQuery.devicePixelRatioOf(context);
              final longest =
                  constraints.biggest.longestSide.isFinite
                      ? constraints.biggest.longestSide
                      : 1024.0;
              return Image.asset(
                asset,
                fit: BoxFit.cover,
                alignment: alignment ?? const Alignment(0, -0.3),
                cacheWidth: (longest * dpr).round().clamp(1, 2048),
                excludeFromSemantics: true,
                errorBuilder:
                    (_, __, ___) =>
                        ColoredBox(color: context.colorScheme.primaryContainer),
              );
            },
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 1.0],
                colors: [
                  semantic.imageScrim.withValues(alpha: 0.15),
                  semantic.imageScrim.withValues(alpha: 0.45),
                  semantic.imageScrim.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}

/// Inline, screen-reader-announced message under a form.
class AuthMessage extends StatelessWidget {
  const AuthMessage({
    super.key,
    required this.message,
    this.detail,
    this.isError = true,
  });

  final String message;
  final String? detail;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final semantic = context.semanticColors;
    final fg = isError ? colors.onErrorContainer : semantic.onInfoContainer;
    final bg = isError ? colors.errorContainer : semantic.infoContainer;
    final text = context.textTheme;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: bg, borderRadius: AppRadius.mdAll),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              size: 20,
              color: fg,
            ),
            AppSpacing.gapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: text.bodyMedium?.copyWith(color: fg)),
                  if (detail != null)
                    Text(detail!, style: text.bodySmall?.copyWith(color: fg)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Phone-width: photo banner above the form. Wide: photo panel beside it.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.form,
    required this.banner,
    this.scrollController,
  });

  /// Form content (title, fields, actions).
  final Widget form;

  /// Content placed over the photo.
  final Widget banner;
  final ScrollController? scrollController;

  static const double _wideBreakpoint = 840;
  static const double _formMaxWidth = 440;
  static const double _bannerMinHeight = 168;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;

        final scrollable = SingleChildScrollView(
          controller: scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _formMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!wide) ...[
                    ClipRRect(
                      borderRadius: AppRadius.xlAll,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: _bannerMinHeight,
                        ),
                        child: AuthPhoto(child: banner),
                      ),
                    ),
                    AppSpacing.gapXxl,
                  ],
                  form,
                ],
              ),
            ),
          ),
        );

        if (!wide) return SafeArea(top: false, child: scrollable);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(AppRadius.xl),
                ),
                child: AuthPhoto(child: banner),
              ),
            ),
            SizedBox(
              width: _formMaxWidth + AppSpacing.xl * 2,
              child: SafeArea(left: false, top: false, child: scrollable),
            ),
          ],
        );
      },
    );
  }
}

/// Logo, app name and tagline for the photo banner.
class AuthBanner extends StatelessWidget {
  const AuthBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final onImage = context.semanticColors.onImage;
    final text = context.textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const AuthBrandMark(size: 56),
          AppSpacing.gapMd,
          Text(
            'app_title'.tr(),
            style: text.headlineSmall?.copyWith(
              color: onImage,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'auth_tagline'.tr(),
            style: text.bodyMedium?.copyWith(
              color: onImage.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
