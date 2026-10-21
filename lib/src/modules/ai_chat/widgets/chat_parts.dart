import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/chat_screen/chat_bubble.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

/// Suggested first questions. Each is sent as an ordinary text message in
/// the user's language through the normal chat request.
const List<String> kSuggestionKeys = [
  'ai_suggest_1',
  'ai_suggest_2',
  'ai_suggest_3',
  'ai_suggest_4',
];

const List<IconData> _suggestionIcons = [
  Icons.festival_outlined,
  Icons.temple_hindu_outlined,
  Icons.water_drop_outlined,
  Icons.explore_outlined,
];

/// Start of a new conversation: who the guide is, what to ask, and a
/// reminder that AI answers should be checked.
class ChatWelcome extends StatelessWidget {
  const ChatWelcome({
    super.key,
    required this.onSuggestion,
    this.enabled = true,
    this.historyError,
  });

  final ValueChanged<String> onSuggestion;
  final bool enabled;

  /// Shown above the welcome when earlier messages couldn't be loaded.
  final Widget? historyError;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.xl,
        AppSpacing.pageGutter,
        AppSpacing.lg,
      ),
      children: [
        if (historyError != null) ...[historyError!, AppSpacing.gapXl],
        const Center(child: AiGuruAvatar(size: 64)),
        AppSpacing.gapLg,
        Semantics(
          header: true,
          child: Text(
            'namaste'.tr(),
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        AppSpacing.gapSm,
        Text(
          'dash_ai_message'.tr(),
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
        AppSpacing.gapXxl,
        Text('ai_suggestions_title'.tr(), style: text.titleSmall),
        AppSpacing.gapSm,
        for (var i = 0; i < kSuggestionKeys.length; i++) ...[
          AppCard(
            onTap: enabled ? () => onSuggestion(kSuggestionKeys[i].tr()) : null,
            semanticLabel: kSuggestionKeys[i].tr(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(_suggestionIcons[i], color: colors.primary),
                AppSpacing.gapMd,
                Expanded(
                  child: Text(kSuggestionKeys[i].tr(), style: text.bodyLarge),
                ),
                Icon(
                  Icons.arrow_upward_rounded,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
          AppSpacing.gapSm,
        ],
        AppSpacing.gapLg,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: colors.onSurfaceVariant),
            AppSpacing.gapSm,
            Expanded(child: Text('ai_disclaimer'.tr(), style: text.bodySmall)),
          ],
        ),
      ],
    );
  }
}

/// Under a message whose request failed: what happened and a retry.
class ChatFailureRow extends StatelessWidget {
  const ChatFailureRow({super.key, required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.error_outline, size: 18, color: colors.error),
          AppSpacing.gapXs,
          Flexible(
            child: Text(
              'ai_reply_failed'.tr(),
              style: context.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text('common_retry'.tr()),
          ),
        ],
      ),
    );
  }
}

/// An assistant reply that came back empty: said plainly, never a blank
/// bubble.
class ChatEmptyReply extends StatelessWidget {
  const ChatEmptyReply({super.key, this.onAskAgain});

  final VoidCallback? onAskAgain;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AiGuruAvatar(),
        AppSpacing.gapSm,
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: context.semanticColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ai_empty_reply'.tr(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (onAskAgain != null)
                  TextButton(
                    onPressed: onAskAgain,
                    child: Text('ai_ask_again'.tr()),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Inline notice when earlier conversation couldn't be loaded.
class ChatHistoryError extends StatelessWidget {
  const ChatHistoryError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.filled,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: context.colorScheme.onSurfaceVariant,
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Text(
              'ai_history_failed'.tr(),
              style: context.textTheme.bodyMedium,
            ),
          ),
          TextButton(onPressed: onRetry, child: Text('common_retry'.tr())),
        ],
      ),
    );
  }
}
