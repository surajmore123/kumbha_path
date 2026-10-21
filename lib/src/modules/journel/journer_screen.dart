import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/models/journal_list.dart';
import 'package:kumbha_path/src/modules/journel/create_my_journer.dart';
import 'package:kumbha_path/src/modules/journel/daily_ai_reflection.dart';
import 'package:kumbha_path/src/modules/journel/journal_details.dart';
import 'package:kumbha_path/src/modules/journel/widgets/journal_widgets.dart';

enum _Pending { none, list, more, reflection, prompt, detail }

/// `/journal`: the pilgrim's MyKumbh Journal.
///
/// Uses the app-wide AppDetailsBloc exactly as before: `GetJournalEntry`
/// (paged), `GetJournalDetail` → detail screen, `GetAiReflectionEvent` →
/// reflection screen, `GetAiPromptEvent` → prompt sheet. That bloc shares
/// one status across requests, so each action here tracks which request
/// it is waiting for and reacts only to that one.
class JournerScreen extends StatefulWidget {
  const JournerScreen({super.key});

  @override
  State<JournerScreen> createState() => _JournerScreenState();
}

class _JournerScreenState extends State<JournerScreen> {
  int currentPage = 1;
  _Pending _pending = _Pending.none;
  String? _pendingEntryId;
  Timer? _timeout;
  bool _listFailed = false;
  bool _moreFailed = false;

  static const double _maxWidth = 760;
  static const Duration _requestTimeout = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    // After the first frame, so the listener below is subscribed before
    // the request can complete.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadFirstPage();
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _start(_Pending kind, AppDetailsEvent event, {String? entryId}) {
    if (_pending != _Pending.none) return; // one request at a time
    _timeout?.cancel();
    setState(() {
      _pending = kind;
      _pendingEntryId = entryId;
      if (kind == _Pending.list) _listFailed = false;
      if (kind == _Pending.more) _moreFailed = false;
    });
    _timeout = Timer(_requestTimeout, () => _fail(kind));
    context.read<AppDetailsBloc>().add(event);
  }

  void _done() {
    _timeout?.cancel();
    _pending = _Pending.none;
    _pendingEntryId = null;
  }

  void _fail(_Pending kind) {
    if (!mounted || _pending != kind) return;
    setState(() {
      _done();
      switch (kind) {
        case _Pending.list:
          _listFailed = true;
        case _Pending.more:
          _moreFailed = true;
          currentPage--;
        case _Pending.reflection:
          _snack('journal_ai_failed'.tr());
        case _Pending.prompt:
          _snack('journal_prompt_failed'.tr());
        case _Pending.detail:
          _snack('journal_open_failed'.tr());
        case _Pending.none:
          break;
      }
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _loadFirstPage() {
    currentPage = 1;
    _start(_Pending.list, GetJournalEntry(page: 1));
  }

  void _loadMore() {
    currentPage++;
    _start(_Pending.more, GetJournalEntry(page: currentPage));
  }

  void _onState(BuildContext context, AppDetailsState state) {
    final pending = _pending;
    switch (state.status) {
      case AppDetailsStatus.journalEntryoaded
          when pending == _Pending.list || pending == _Pending.more:
        setState(_done);
      case AppDetailsStatus.journalEntryError
          when pending == _Pending.list || pending == _Pending.more:
        _fail(pending);
      case AppDetailsStatus.aiReflectionLoaded
          when pending == _Pending.reflection:
        setState(_done);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => DailyReflectionScreen(
                  aiReflection: state.aiReflection ?? '',
                  message: state.message ?? '',
                ),
          ),
        );
      case AppDetailsStatus.aiReflectionError
          when pending == _Pending.reflection:
        _fail(pending);
      case AppDetailsStatus.aiPromptLoaded when pending == _Pending.prompt:
        setState(_done);
        _showPromptSheet(state.aiPrompt ?? '');
      case AppDetailsStatus.aiPromptError when pending == _Pending.prompt:
        _fail(pending);
      case AppDetailsStatus.journalDetailLoaded when pending == _Pending.detail:
        setState(_done);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const JournalDetails()),
        );
      case AppDetailsStatus.failed when pending == _Pending.detail:
        _fail(pending);
      default:
        break;
    }
  }

  /// A blank entry. (It no longer pre-fills a prompt or reflection fetched
  /// earlier for something else.)
  void _newEntry({String? aiPrompt, String? aiReflection}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => NewJournalEntryScreen(
              aiPrompt: aiPrompt,
              aiReflection: aiReflection,
            ),
      ),
    );
  }

  void _showPromptSheet(String prompt) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (sheet) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'journal_prompt_heading'.tr(),
                    style: sheet.textTheme.titleLarge,
                  ),
                  AppSpacing.gapLg,
                  AiContentCard(
                    heading: 'journal_prompt_from_ai'.tr(),
                    child: Text(
                      prompt.trim().isEmpty
                          ? 'journal_prompt_failed'.tr()
                          : prompt,
                      style: sheet.textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                  ),
                  AppSpacing.gapXl,
                  AppButton(
                    label: 'journal_add_to_entry'.tr(),
                    leadingIcon: Icons.edit_note_rounded,
                    onPressed:
                        prompt.trim().isEmpty
                            ? null
                            : () {
                              Navigator.pop(sheet);
                              _newEntry(aiPrompt: prompt);
                            },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale =
        EasyLocalization.of(context)?.locale.languageCode ??
        Localizations.localeOf(context).languageCode;
    final text = context.textTheme;

    return MainLayout(
      showDefaultBottom: true,
      ctx: 3,
      appBar: AppAppBar(title: 'dash_journal_title'.tr()),
      body: BlocConsumer<AppDetailsBloc, AppDetailsState>(
        listener: _onState,
        buildWhen: (a, b) => a.journalEntryListModel != b.journalEntryListModel,
        builder: (context, state) {
          final list = state.journalEntryListModel;
          final entries = list?.results ?? const <JournalEntryModel>[];
          return RefreshIndicator(
            onRefresh: () async => _loadFirstPage(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = math.max(
                  AppSpacing.pageGutter,
                  (constraints.maxWidth - _maxWidth) / 2,
                );
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    side,
                    AppSpacing.sm,
                    side,
                    AppSpacing.huge,
                  ),
                  children: [
                    Text(
                      'journal_intro'.tr(),
                      style: text.bodyLarge?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    AppSpacing.gapLg,
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        AppButton(
                          label: 'journal_add_entry'.tr(),
                          leadingIcon: Icons.edit_note_rounded,
                          expand: false,
                          onPressed: _newEntry,
                        ),
                        AppButton.secondary(
                          label: 'journal_ai_reflection'.tr(),
                          leadingIcon: Icons.auto_awesome,
                          expand: false,
                          isLoading: _pending == _Pending.reflection,
                          onPressed:
                              () => _start(
                                _Pending.reflection,
                                GetAiReflectionEvent(),
                              ),
                        ),
                      ],
                    ),
                    AppSpacing.gapXl,
                    _PromptCard(
                      loading: _pending == _Pending.prompt,
                      onPressed:
                          () => _start(_Pending.prompt, GetAiPromptEvent()),
                    ),
                    AppSpacing.gapXxl,
                    AppSectionHeader(title: 'journal_past_entries'.tr()),
                    AppSpacing.gapMd,
                    ..._entries(entries, list?.next != null, locale),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  List<Widget> _entries(
    List<JournalEntryModel> entries,
    bool hasMore,
    String locale,
  ) {
    if (entries.isEmpty) {
      if (_pending == _Pending.list) {
        return [
          for (var i = 0; i < 3; i++) ...[
            Container(
              height: 104,
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHigh,
                borderRadius: AppRadius.cardAll,
              ),
            ),
            AppSpacing.gapMd,
          ],
        ];
      }
      if (_listFailed) {
        // A failed load is never shown as an empty journal.
        return [
          AppCard(
            padding: EdgeInsets.zero,
            child: AppErrorView(
              compact: true,
              title: 'journal_load_failed'.tr(),
              onRetry: _loadFirstPage,
            ),
          ),
        ];
      }
      return [
        AppCard(
          padding: EdgeInsets.zero,
          child: AppEmptyState(
            compact: true,
            icon: Icons.menu_book_outlined,
            title: 'journal_no_entries'.tr(),
            message: 'dash_journal_empty'.tr(),
            actionLabel: 'journal_add_entry'.tr(),
            actionIcon: Icons.edit_note_rounded,
            onAction: _newEntry,
          ),
        ),
      ];
    }

    // Grouped by month, in the API's order.
    final widgets = <Widget>[];
    String? lastMonth;
    for (final e in entries) {
      final t = journalTime(e.createdAt);
      final month = t == null ? '' : journalMonthLabel(t, locale);
      if (month != lastMonth) {
        if (widgets.isNotEmpty) widgets.add(AppSpacing.gapLg);
        if (month.isNotEmpty) {
          widgets.add(
            Semantics(
              header: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(month, style: context.textTheme.titleSmall),
              ),
            ),
          );
        }
        lastMonth = month;
      }
      widgets
        ..add(
          _EntryCard(
            entry: e,
            locale: locale,
            loading:
                _pending == _Pending.detail &&
                _pendingEntryId == e.id.toString(),
            onTap:
                () => _start(
                  _Pending.detail,
                  GetJournalDetail(id: e.id.toString()),
                  entryId: e.id.toString(),
                ),
          ),
        )
        ..add(AppSpacing.gapMd);
    }

    if (hasMore || _moreFailed) {
      widgets.add(
        Center(
          child: Column(
            children: [
              if (_moreFailed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'journal_more_failed'.tr(),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.error,
                    ),
                  ),
                ),
              AppButton.outlined(
                label:
                    _moreFailed
                        ? 'common_retry'.tr()
                        : 'journal_show_more'.tr(),
                leadingIcon: Icons.expand_more_rounded,
                expand: false,
                isLoading: _pending == _Pending.more,
                onPressed: _loadMore,
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final text = context.textTheme;
    return AppCard(
      variant: AppCardVariant.filled,
      color: colors.primaryContainer,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: colors.onPrimaryContainer),
              AppSpacing.gapSm,
              Expanded(
                child: Text(
                  'journal_prompt_heading'.tr(),
                  style: text.titleMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapXs,
          Text(
            'journal_prompt_subtitle'.tr(),
            style: text.bodyMedium?.copyWith(color: colors.onPrimaryContainer),
          ),
          AppSpacing.gapMd,
          AppButton.outlined(
            label: 'journal_get_ai_prompt'.tr(),
            leadingIcon: Icons.auto_awesome,
            expand: false,
            isLoading: loading,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.locale,
    required this.loading,
    required this.onTap,
  });

  final JournalEntryModel entry;
  final String locale;
  final bool loading;
  final VoidCallback onTap;

  static const double _thumb = 64;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final text = context.textTheme;
    final title = (entry.title ?? '').trim();
    final notes = (entry.notes ?? '').trim();
    final photo = (entry.photo ?? '').trim();
    final t = journalTime(entry.createdAt);
    final badge = t == null ? null : journalDayBadge(t, locale);

    return AppCard(
      onTap: loading ? null : onTap,
      semanticLabel: title.isEmpty ? 'journal_untitled'.tr() : title,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: AppRadius.mdAll,
            ),
            child:
                badge == null
                    ? Icon(
                      Icons.menu_book_outlined,
                      color: colors.onPrimaryContainer,
                    )
                    : Column(
                      children: [
                        Text(
                          badge.day,
                          style: text.titleLarge?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          badge.weekday,
                          style: text.labelSmall?.copyWith(
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'journal_untitled'.tr() : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    fontStyle: title.isEmpty ? FontStyle.italic : null,
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  AppSpacing.gapXs,
                  Text(
                    notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                if ((entry.mood ?? '').trim().isNotEmpty) ...[
                  AppSpacing.gapSm,
                  MoodChip(mood: entry.mood),
                ],
              ],
            ),
          ),
          if (photo.isNotEmpty) ...[
            AppSpacing.gapMd,
            JournalPhoto(
              source: photo,
              width: _thumb,
              height: _thumb,
              radius: AppRadius.mdAll,
            ),
          ],
          if (loading) ...[
            AppSpacing.gapSm,
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }
}
