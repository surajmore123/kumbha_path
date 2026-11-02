import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an https link outside the app; tells the user if it can't.
Future<void> openChatLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  var opened = false;
  if (uri != null && uri.scheme == 'https') {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('ai_link_failed'.tr())));
  }
}

/// Reply text with the light formatting the assistant uses: paragraphs,
/// `-`/`*`/`1.` lists, `#` headings, `**bold**`, `*italic*` and `code`.
/// Links are shown as a short tappable label instead of a raw URL.
class ChatRichText extends StatelessWidget {
  const ChatRichText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  static final RegExp _heading = RegExp(r'^\s{0,3}#{1,6}\s+(.*)$');
  static final RegExp _bullet = RegExp(r'^\s*[-*•]\s+(.*)$');
  static final RegExp _numbered = RegExp(r'^\s*(\d{1,3})[.)]\s+(.*)$');
  static final RegExp _inline = RegExp(
    r'(\*\*[^*\n]+\*\*|__[^_\n]+__|`[^`\n]+`|https?://[^\s<>()\[\]]+|(?<![\w*])\*[^*\s][^*\n]*\*(?![\w*]))',
  );

  /// Plain text needs no parsing (and stays a single `Text`).
  static bool _isPlain(String text) =>
      !text.contains('\n') &&
      !_inline.hasMatch(text) &&
      !_heading.hasMatch(text);

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    if (_isPlain(text)) return Text(text, style: base);

    final blocks = <Widget>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      blocks.add(_InlineText(text: paragraph.join('\n'), style: base));
      paragraph.clear();
    }

    for (final line in text.split('\n')) {
      final heading = _heading.firstMatch(line);
      final bullet = _bullet.firstMatch(line);
      final numbered = _numbered.firstMatch(line);
      if (line.trim().isEmpty) {
        flushParagraph();
      } else if (heading != null) {
        flushParagraph();
        blocks.add(
          _InlineText(
            text: heading.group(1)!,
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (bullet != null || numbered != null) {
        flushParagraph();
        blocks.add(
          _ListItem(
            marker: numbered != null ? '${numbered.group(1)}.' : '•',
            text: numbered?.group(2) ?? bullet!.group(1)!,
            style: base,
          ),
        );
      } else {
        paragraph.add(line.trim());
      }
    }
    flushParagraph();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0)
            SizedBox(
              height:
                  blocks[i] is _ListItem && blocks[i - 1] is _ListItem
                      ? AppSpacing.xs
                      : AppSpacing.sm,
            ),
          blocks[i],
        ],
      ],
    );
  }
}

class _ListItem extends StatelessWidget {
  const _ListItem({
    required this.marker,
    required this.text,
    required this.style,
  });

  final String marker;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          child: Text(
            marker,
            style: style.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: _InlineText(text: text, style: style)),
      ],
    );
  }
}

class _InlineText extends StatelessWidget {
  const _InlineText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  String _linkLabel(Uri uri) {
    final host = uri.host.replaceFirst('www.', '');
    if (host.contains('google.') &&
        (uri.path.contains('/maps') || host.startsWith('maps.'))) {
      return 'ai_view_map'.tr();
    }
    return host;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spans = <InlineSpan>[];
    var index = 0;
    for (final match in ChatRichText._inline.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('http')) {
        final uri = Uri.tryParse(token.replaceAll(RegExp(r'[.,;:!?]+$'), ''));
        if (uri != null && uri.host.isNotEmpty) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: InkWell(
                borderRadius: AppRadius.smAll,
                onTap: () => openChatLink(context, uri.toString()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 14,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _linkLabel(uri),
                        style: style.copyWith(
                          color: colors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      } else if (token.startsWith('**') || token.startsWith('__')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('`')) {
        spans.add(TextSpan(text: token.substring(1, token.length - 1)));
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      index = match.end;
    }
    if (index < text.length) spans.add(TextSpan(text: text.substring(index)));
    return Text.rich(TextSpan(children: spans), style: style);
  }
}

/// Reply text without formatting symbols, for screen-reader labels.
String plainChatText(String text) =>
    text
        .replaceAll(RegExp(r'\*\*|__|`|^\s{0,3}#{1,6}\s+', multiLine: true), '')
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'^\s*[-*•]\s+', multiLine: true), '')
        .trim();
