import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/journel/create_my_journer.dart';
import 'package:kumbha_path/src/modules/journel/widgets/journal_widgets.dart';

/// Shows the reflection returned by `GetAiReflectionEvent`
/// (`api/journal/ai-reflection`), fetched by the journal screen before
/// opening this one. Nothing here generates or alters text.
///
/// "Add to Journal" opens a new entry with the reflection pre-filled, as
/// before. The previous Share button had no action, so it is not shown.
class DailyReflectionScreen extends StatelessWidget {
  final String aiReflection;

  /// Server message from the same response. Kept for compatibility; not
  /// displayed (it is a status string, not content).
  final String message;

  const DailyReflectionScreen({
    super.key,
    required this.aiReflection,
    required this.message,
  });

  static const double _readingWidth = 680;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final reflection = aiReflection.trim();

    return MainLayout(
      showDefaultBottom: false,
      ctx: 3,
      appBar: AppAppBar(title: 'daily_reflection_title'.tr()),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final side =
              constraints.maxWidth > _readingWidth + AppSpacing.pageGutter * 2
                  ? (constraints.maxWidth - _readingWidth) / 2
                  : AppSpacing.pageGutter;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              side,
              AppSpacing.md,
              side,
              AppSpacing.huge,
            ),
            children: [
              Text(
                'journal_reflection_intro'.tr(),
                style: text.bodyLarge?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.gapXl,
              if (reflection.isEmpty)
                AppCard(
                  padding: EdgeInsets.zero,
                  child: AppEmptyState(
                    compact: true,
                    icon: Icons.auto_awesome_outlined,
                    title: 'journal_reflection_empty'.tr(),
                  ),
                )
              else ...[
                AiContentCard(
                  heading: 'reflection_author_title'.tr(),
                  child: SelectableText(
                    reflection,
                    style: text.bodyLarge?.copyWith(height: 1.7),
                  ),
                ),
                AppSpacing.gapXl,
                AppButton(
                  label: 'reflection_add_to_journal_button'.tr(),
                  leadingIcon: Icons.edit_note_rounded,
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => NewJournalEntryScreen(
                                aiReflection: aiReflection,
                              ),
                        ),
                      ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
