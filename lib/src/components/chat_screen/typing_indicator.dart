import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/chat_screen/chat_bubble.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

/// Shown while a reply is being prepared. The backend returns complete
/// replies (no streaming), so this is a plain "thinking" state, never fake
/// partial text. Honors the system "reduce motion" setting.
class TypingIndicatorRow extends StatefulWidget {
  /// Kept for existing callers; the avatar is now [AiGuruAvatar].
  final List<String> avatars;

  const TypingIndicatorRow({this.avatars = const [], super.key});

  @override
  State<TypingIndicatorRow> createState() => TypingIndicatorRowState();
}

class TypingIndicatorRowState extends State<TypingIndicatorRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final List<Animation<double>> _dots = [
    for (var i = 0; i < 3; i++)
      CurvedAnimation(
        parent: _controller,
        curve: Interval(i * 0.15, 0.6 + i * 0.15, curve: Curves.easeInOut),
      ),
  ];

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Semantics(
      liveRegion: true,
      label: 'ai_thinking'.tr(),
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const AiGuruAvatar(),
            AppSpacing.gapSm,
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: AppRadius.lgAll,
                border: Border.all(color: context.semanticColors.border),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.xs),
                    _Dot(animation: _dots[i]),
                  ],
                ],
              ),
            ),
            AppSpacing.gapSm,
            Flexible(
              child: Text(
                'ai_thinking'.tr(),
                style: context.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(animation),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: context.colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
