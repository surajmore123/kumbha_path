import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

/// Opening section: Trimbakeshwar temple photograph with greeting, place
/// and an "Ask AI Guru" bar, so the assistant is one tap from the top.
/// Kept compact so the shortcuts below are visible without scrolling.
///
/// The greeting uses the user's first name only when the profile API has
/// returned one; otherwise it is a plain "Namaste". No location permission
/// is involved: the place line describes the Kumbh, not the user.
class WelcomeHero extends StatelessWidget {
  const WelcomeHero({super.key, this.fullName, this.onAsk});

  final String? fullName;

  /// Opens the AI Guru chat; the bar is hidden when null.
  final VoidCallback? onAsk;

  static const String imageAsset = 'assets/images/triambakeshwar.png';
  static const double _minHeight = 150;

  String? get _firstName {
    final name = (fullName ?? '').trim();
    if (name.isEmpty) return null;
    return name.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final text = context.textTheme;
    final onImage = semantic.onImage;
    final name = _firstName;
    final greeting =
        name == null
            ? 'dash_greeting'.tr()
            : 'dash_greeting_name'.tr(args: [name]);

    return ClipRRect(
      borderRadius: AppRadius.xlAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minHeight),
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dpr = MediaQuery.devicePixelRatioOf(context);
                  return Image.asset(
                    imageAsset,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.35),
                    // Decode at display size: the source is 1024px.
                    cacheWidth:
                        constraints.maxWidth.isFinite
                            ? (constraints.maxWidth * dpr).round()
                            : null,
                    excludeFromSemantics: true,
                    errorBuilder:
                        (_, __, ___) => ColoredBox(
                          color: context.colorScheme.primaryContainer,
                        ),
                  );
                },
              ),
            ),
            // Scrim keeps text legible over any part of the photo.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.45, 1.0],
                    colors: [
                      semantic.imageScrim.withValues(alpha: 0.05),
                      semantic.imageScrim.withValues(alpha: 0.35),
                      semantic.imageScrim.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: semantic.gold,
                      ),
                      AppSpacing.gapXs,
                      Flexible(
                        child: Text(
                          'dash_hero_place'.tr(),
                          style: text.labelLarge?.copyWith(
                            color: onImage.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapXs,
                  Semantics(
                    header: true,
                    child: Text(
                      greeting,
                      style: text.headlineSmall?.copyWith(
                        color: onImage,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onAsk != null) ...[
                    AppSpacing.gapMd,
                    _AskBar(onTap: onAsk!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Looks like a search field; opens the AI Guru chat.
class _AskBar extends StatelessWidget {
  const _AskBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final semantic = context.semanticColors;
    return Semantics(
      button: true,
      label: 'dash_ai_action'.tr(),
      excludeSemantics: true,
      child: Material(
        color: semantic.dialogSurface,
        shape: const StadiumBorder(),
        elevation: AppElevation.level1,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 20, color: semantic.gold),
                  AppSpacing.gapSm,
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'dash_ai_action'.tr(),
                          style: context.textTheme.labelLarge,
                        ),
                        Text(
                          'dash_ask_hint'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: colors.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
