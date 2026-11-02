import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/components/chat_screen/chat_rich_text.dart';

/// The AI Guru's mark: a small antique-gold circle. Used beside assistant
/// messages and in the chat header.
class AiGuruAvatar extends StatelessWidget {
  const AiGuruAvatar({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: semantic.gold, shape: BoxShape.circle),
        child: Icon(
          Icons.auto_awesome,
          size: size * 0.55,
          color: semantic.onGold,
        ),
      ),
    );
  }
}

/// Widest a message may be, as a share of the conversation width, so
/// lines stay comfortable to read.
const double kMessageWidthFactor = 0.82;

BorderRadius _bubbleRadius(bool isGuru) => BorderRadius.only(
  topLeft: Radius.circular(isGuru ? AppRadius.xs : AppRadius.lg),
  topRight: Radius.circular(isGuru ? AppRadius.lg : AppRadius.xs),
  bottomLeft: const Radius.circular(AppRadius.lg),
  bottomRight: const Radius.circular(AppRadius.lg),
);

/// Aligns a message to its side with the assistant avatar, width-limited.
class _MessageFrame extends StatelessWidget {
  const _MessageFrame({
    required this.isGuru,
    required this.child,
    this.showAvatar = true,
  });

  final bool isGuru;
  final bool showAvatar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth * kMessageWidthFactor;
        return Row(
          mainAxisAlignment:
              isGuru ? MainAxisAlignment.start : MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isGuru) ...[
              showAvatar ? const AiGuruAvatar() : const SizedBox(width: 32),
              AppSpacing.gapSm,
            ],
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ],
        );
      },
    );
  }
}

/// A text message. Assistant replies sit on a quiet surface and keep their
/// light formatting (lists, bold, headings); the user's own messages use
/// the soft saffron container. Text is selectable.
class ChatBubble extends StatelessWidget {
  final bool isGuru;

  /// Kept for existing callers; the assistant avatar is now [AiGuruAvatar].
  final String? avatarImage;
  final String text;
  final bool showCornerBadge;

  /// False for follow-up replies in a row, so the avatar appears once per
  /// group.
  final bool showAvatar;

  const ChatBubble({
    super.key,
    required this.isGuru,
    required this.text,
    this.avatarImage,
    this.showCornerBadge = false,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final bg = isGuru ? colors.surfaceContainerLow : colors.primaryContainer;
    final fg = isGuru ? colors.onSurface : colors.onPrimaryContainer;
    final speaker = isGuru ? 'ai_guru'.tr() : 'ai_you'.tr();
    final style = context.textTheme.bodyLarge?.copyWith(color: fg, height: 1.5);

    return _MessageFrame(
      isGuru: isGuru,
      showAvatar: showAvatar,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: _bubbleRadius(isGuru),
          border:
              isGuru ? Border.all(color: context.semanticColors.border) : null,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Semantics(
          label: '$speaker: ${isGuru ? plainChatText(text) : text}',
          excludeSemantics: true,
          child: SelectionArea(
            child:
                isGuru
                    ? ChatRichText(text: text, style: style)
                    : Text(text, style: style),
          ),
        ),
      ),
    );
  }
}

/// A photo message: a local file the user just sent, or a history URL.
class ChatImageBubble extends StatelessWidget {
  const ChatImageBubble({
    super.key,
    required this.isGuru,
    required this.imagePath,
    this.caption,
  });

  final bool isGuru;
  final String imagePath;

  /// Text the user sent with the photo.
  final String? caption;

  static const double _maxWidth = 240;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cache = (_maxWidth * dpr).round();
    Widget broken(BuildContext context, Object _, StackTrace? __) => Container(
      width: _maxWidth,
      height: 140,
      color: colors.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: colors.onSurfaceVariant),
          AppSpacing.gapXs,
          Text('ai_image_unavailable'.tr(), style: context.textTheme.bodySmall),
        ],
      ),
    );

    final image =
        imagePath.startsWith('http')
            ? Image.network(
              imagePath,
              width: _maxWidth,
              fit: BoxFit.cover,
              cacheWidth: cache,
              errorBuilder: broken,
            )
            : Image.file(
              File(imagePath),
              width: _maxWidth,
              fit: BoxFit.cover,
              cacheWidth: cache,
              errorBuilder: broken,
            );

    return _MessageFrame(
      isGuru: isGuru,
      child: Semantics(
        image: true,
        label:
            '${isGuru ? 'ai_guru'.tr() : 'ai_you'.tr()}: '
            '${'ai_image_message'.tr()}',
        child: Column(
          crossAxisAlignment:
              isGuru ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(borderRadius: _bubbleRadius(isGuru), child: image),
            if ((caption ?? '').trim().isNotEmpty) ...[
              AppSpacing.gapXs,
              _Caption(text: caption!.trim(), isGuru: isGuru),
            ],
          ],
        ),
      ),
    );
  }
}

/// Text sent alongside a photo or document.
class _Caption extends StatelessWidget {
  const _Caption({required this.text, required this.isGuru});

  final String text;
  final bool isGuru;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: isGuru ? colors.surfaceContainerLow : colors.primaryContainer,
        borderRadius: _bubbleRadius(isGuru),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: SelectableText(
        text,
        style: context.textTheme.bodyLarge?.copyWith(
          color: isGuru ? colors.onSurface : colors.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// A voice message. The app shows that one was sent (there is no
/// playback) and, once the server has heard it, what was said.
class ChatAudioBubble extends StatelessWidget {
  const ChatAudioBubble({super.key, required this.isGuru, this.transcript});

  final bool isGuru;
  final String? transcript;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final fg = isGuru ? colors.onSurface : colors.onPrimaryContainer;
    return _MessageFrame(
      isGuru: isGuru,
      child: Container(
        decoration: BoxDecoration(
          color: isGuru ? colors.surfaceContainerLow : colors.primaryContainer,
          borderRadius: _bubbleRadius(isGuru),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic_none_rounded, size: 20, color: fg),
                AppSpacing.gapSm,
                Flexible(
                  child: Text(
                    'audio_message'.tr(),
                    style: context.textTheme.bodyMedium?.copyWith(color: fg),
                  ),
                ),
              ],
            ),
            if ((transcript ?? '').isNotEmpty) ...[
              AppSpacing.gapXs,
              SelectableText(
                '“${transcript!}”',
                style: context.textTheme.bodyLarge?.copyWith(
                  color: fg,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A document the user sent (PDF, Word, text or spreadsheet).
class ChatDocumentBubble extends StatelessWidget {
  const ChatDocumentBubble({
    super.key,
    required this.isGuru,
    required this.fileName,
    this.caption,
  });

  final bool isGuru;
  final String fileName;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final fg = isGuru ? colors.onSurface : colors.onPrimaryContainer;
    return _MessageFrame(
      isGuru: isGuru,
      child: Semantics(
        label:
            '${isGuru ? 'ai_guru'.tr() : 'ai_you'.tr()}: '
            '${'ai_document_message'.tr()} $fileName',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment:
              isGuru ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color:
                    isGuru
                        ? colors.surfaceContainerLow
                        : colors.primaryContainer,
                borderRadius: _bubbleRadius(isGuru),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_outlined, size: 22, color: fg),
                  AppSpacing.gapSm,
                  Flexible(
                    child: Text(
                      fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(color: fg),
                    ),
                  ),
                ],
              ),
            ),
            if ((caption ?? '').trim().isNotEmpty) ...[
              AppSpacing.gapXs,
              _Caption(text: caption!.trim(), isGuru: isGuru),
            ],
          ],
        ),
      ),
    );
  }
}
