import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart'
    show AppDetailsBloc;
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/models/journal_details.dart';
import 'package:kumbha_path/src/modules/journel/widgets/journal_widgets.dart';

/// One journal entry, read from `AppDetailsState.journalDetailsModel`
/// (loaded by `GetJournalDetail` before this screen opens, as before).
///
/// Read-only: the journal API has no edit, delete or share endpoints.
/// Fields are shown exactly as stored; missing ones are left out.
class JournalDetails extends StatelessWidget {
  const JournalDetails({super.key});

  static const double _readingWidth = 680;

  @override
  Widget build(BuildContext context) {
    final locale =
        EasyLocalization.of(context)?.locale.languageCode ??
        Localizations.localeOf(context).languageCode;

    return MainLayout(
      showDefaultBottom: false,
      ctx: 3,
      appBar: AppAppBar(title: 'journal_entry_title'.tr()),
      body: BlocBuilder<AppDetailsBloc, AppDetailsState>(
        buildWhen: (a, b) => a.journalDetailsModel != b.journalDetailsModel,
        builder: (context, state) {
          final entry = state.journalDetailsModel ?? JournalDetailsModel.empty;
          return LayoutBuilder(
            builder: (context, constraints) {
              final side =
                  constraints.maxWidth >
                          _readingWidth + AppSpacing.pageGutter * 2
                      ? (constraints.maxWidth - _readingWidth) / 2
                      : AppSpacing.pageGutter;
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  side,
                  AppSpacing.md,
                  side,
                  AppSpacing.huge,
                ),
                children: _content(context, entry, locale),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    JournalDetailsModel e,
    String locale,
  ) {
    final text = context.textTheme;
    final colors = context.colorScheme;
    final title = (e.title ?? '').trim();
    final notes = (e.notes ?? '').trim();
    final prompt = (e.aiPrompt ?? '').trim();
    final reflection = (e.aiReflection ?? '').trim();
    final photo = (e.photo ?? '').trim();
    final time = journalTime(e.createdAt);

    return [
      if (photo.isNotEmpty) ...[
        LayoutBuilder(
          builder:
              (context, c) => JournalPhoto(
                source: photo,
                width: c.maxWidth,
                height: (c.maxWidth * 0.62).clamp(180.0, 360.0),
              ),
        ),
        AppSpacing.gapXl,
      ],
      if (time != null)
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: colors.primary,
            ),
            AppSpacing.gapXs,
            Expanded(
              child: Text(
                journalDateTimeLabel(time, locale),
                style: text.labelLarge?.copyWith(color: colors.primary),
              ),
            ),
          ],
        ),
      AppSpacing.gapSm,
      Semantics(
        header: true,
        child: Text(
          title.isEmpty ? 'journal_untitled'.tr() : title,
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontStyle: title.isEmpty ? FontStyle.italic : null,
          ),
        ),
      ),
      if ((e.mood ?? '').trim().isNotEmpty) ...[
        AppSpacing.gapMd,
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MoodChip(mood: e.mood),
        ),
      ],
      if (prompt.isNotEmpty) ...[
        AppSpacing.gapXl,
        AiContentCard(
          heading: 'journal_daily_prompt'.tr(),
          child: Text(prompt, style: text.bodyLarge?.copyWith(height: 1.5)),
        ),
      ],
      AppSpacing.gapXl,
      AppSectionHeader(title: 'journal_your_words'.tr()),
      AppSpacing.gapSm,
      SelectableText(
        notes.isEmpty ? 'journal_no_notes'.tr() : notes,
        style: text.bodyLarge?.copyWith(
          height: 1.7,
          color: notes.isEmpty ? colors.onSurfaceVariant : null,
          fontStyle: notes.isEmpty ? FontStyle.italic : null,
        ),
      ),
      if (reflection.isNotEmpty) ...[
        AppSpacing.gapXxl,
        AiContentCard(
          heading: 'journal_ai_reflection_heading'.tr(),
          child: SelectableText(
            reflection,
            style: text.bodyLarge?.copyWith(height: 1.6),
          ),
        ),
      ],
    ];
  }
}
