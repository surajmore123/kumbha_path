import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/models/journal_list.dart';
import 'package:kumbha_path/src/modules/dashboard/dashboard_formatters.dart';

/// Entry point to the existing AI Guru chat (`/aichat`).
class AiExplorerCard extends StatelessWidget {
  const AiExplorerCard({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final semantic = context.semanticColors;
    final text = context.textTheme;

    return AppCard(
      variant: AppCardVariant.filled,
      color: colors.tertiaryContainer,
      padding: const EdgeInsets.all(AppSpacing.xl),
      onTap: onOpen,
      semanticLabel: 'dash_ai_title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSpacing.minTouchTarget,
                height: AppSpacing.minTouchTarget,
                decoration: BoxDecoration(
                  color: semantic.gold,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome, color: semantic.onGold),
              ),
              AppSpacing.gapMd,
              Expanded(
                child: Text(
                  'dash_ai_title'.tr(),
                  style: text.titleLarge?.copyWith(
                    color: colors.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapMd,
          Text(
            'dash_ai_message'.tr(),
            style: text.bodyMedium?.copyWith(color: colors.onTertiaryContainer),
          ),
          AppSpacing.gapLg,
          AppButton(
            label: 'dash_ai_action'.tr(),
            leadingIcon: Icons.chat_bubble_outline_rounded,
            expand: false,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}

/// Latest MyKumbh journal entry from `GetJournalEntry(page: 1)`, or an
/// invitation to start one. Opens the existing journal screen.
class JournalPreviewCard extends StatelessWidget {
  const JournalPreviewCard({
    super.key,
    required this.entries,
    required this.locale,
    required this.onOpen,
  });

  final List<JournalEntryModel> entries;
  final String locale;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final text = context.textTheme;
    final latest =
        entries
            .where(
              (e) =>
                  (e.title ?? '').trim().isNotEmpty ||
                  (e.notes ?? '').trim().isNotEmpty,
            )
            .firstOrNull;

    if (latest == null) {
      return AppCard(
        padding: EdgeInsets.zero,
        child: AppEmptyState(
          compact: true,
          icon: Icons.menu_book_outlined,
          title: 'dash_journal_title'.tr(),
          message: 'dash_journal_empty'.tr(),
          actionLabel: 'dash_journal_open'.tr(),
          actionIcon: Icons.edit_outlined,
          onAction: onOpen,
        ),
      );
    }

    final title = (latest.title ?? '').trim();
    final notes = (latest.notes ?? '').trim();
    final date = formatEventDate(latest.createdAt, locale);
    final mood = (latest.mood ?? '').trim();

    return AppCard(
      onTap: onOpen,
      semanticLabel: title.isNotEmpty ? title : 'dash_journal_latest'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ['dash_journal_latest'.tr(), if (date != null) date].join(' · '),
            style: text.labelMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          AppSpacing.gapSm,
          if (title.isNotEmpty)
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium,
            ),
          if (notes.isNotEmpty) ...[
            AppSpacing.gapXs,
            Text(
              notes,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          if (mood.isNotEmpty) ...[
            AppSpacing.gapSm,
            Text(mood, style: text.labelLarge),
          ],
          AppSpacing.gapLg,
          AppButton.outlined(
            label: 'dash_journal_open'.tr(),
            leadingIcon: Icons.menu_book_outlined,
            expand: false,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}
