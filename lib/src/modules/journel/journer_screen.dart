import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/constant/app_color.dart';

import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/constant/time_formator.dart';
import 'package:kumbha_path/src/models/journal_list.dart';
import 'package:kumbha_path/src/modules/journel/create_my_journer.dart';
import 'package:kumbha_path/src/modules/journel/daily_ai_reflection.dart';
import 'package:kumbha_path/src/modules/journel/journal_details.dart';

class JournerScreen extends StatefulWidget {
  const JournerScreen({super.key});

  @override
  State<JournerScreen> createState() => _JournerScreenState();
}

class _JournerScreenState extends State<JournerScreen> {
  int currentPage = 1;
  @override
  void initState() {
    super.initState();
    context.read<AppDetailsBloc>().add(GetJournalEntry(page: 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isDesktop = context.isDesktop;

    void _showAiPromptBottomSheet(
      BuildContext context, {
      required String prompt,
      required String message,
    }) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) {
          final theme = Theme.of(context);
          final cs = theme.colorScheme;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// MESSAGE
                Text(
                  message,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),

                const SizedBox(height: 16),

                /// PROMPT
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    prompt,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                      color: cs.onSurface,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                /// ADD TO JOURNAL BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // close bottom sheet

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => NewJournalEntryScreen(aiPrompt: prompt),
                        ),
                      );
                    },
                    child: const Text("Add to Journal Entry"),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return MainLayout(
      showDefaultBottom: true,
      ctx: 3,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? cs.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          LanguageHelper.t('journal_title'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: LanguageHelper.currentLang,
        builder: (context, lang, _) {
          final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
            fontSize: isMobile ? 13.5 : 14,
            color: cs.onBackground.withOpacity(0.9),
            height: 1.4,
          );

          final sectionTitleStyle = theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: isMobile ? 16 : 18,
            color: cs.onPrimary,
          );

          return BlocConsumer<AppDetailsBloc, AppDetailsState>(
            listener: (context, state) {
              if (state.status == AppDetailsStatus.aiReflectionLoaded) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => DailyReflectionScreen(
                          aiReflection: state.aiReflection.toString(),
                          message: state.message.toString(),
                        ),
                  ),
                );
              } else if (state.status == AppDetailsStatus.aiReflectionError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message.toString())),
                );
              }

              if (state.status == AppDetailsStatus.aiPromptLoaded) {
                _showAiPromptBottomSheet(
                  context,
                  prompt: state.aiPrompt.toString(),
                  message: state.message.toString(),
                );
              }

              if (state.status == AppDetailsStatus.aiPromptError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message.toString())),
                );
              }

              if (state.status == AppDetailsStatus.journalDetailLoaded) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => JournalDetails()),
                );
              }
            },
            builder: (context, state) {
              final journalModel = state.journalEntryListModel;

              return Container(
                color: theme.scaffoldBackgroundColor,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        isMobile
                            ? 16
                            : isTablet
                            ? 32
                            : 56,
                    vertical: isMobile ? 16 : 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 520 : 480,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _JournalToggleButton(
                                useGradient: true,
                                labelKey: 'journal_ai_reflection',
                                isPrimary: false,
                                onTap: () {
                                  final bloc = context.read<AppDetailsBloc>();
                                  bloc.add(GetAiReflectionEvent());
                                  // Navigator.push(
                                  //   context,
                                  //   MaterialPageRoute(
                                  //     builder: (context) => DailyReflectionScreen(
                                  //       aiReflection: bloc.state.aiReflection,
                                  //       message: bloc.state.message,
                                  //     ),
                                  //   ),
                                  // );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _JournalToggleButton(
                                labelKey: 'journal_add_entry',
                                isPrimary: true,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => NewJournalEntryScreen(
                                            aiPrompt: state.aiPrompt,
                                            aiReflection: state.aiReflection,
                                          ),
                                    ),
                                  );
                                  //  e
                                  //       Navigator.pushNamed(
                                  //         context,
                                  //         '/myJournalEntry',
                                  //       );
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ======= AI PROMPT CARD =======
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: buildThemeGradient(
                              context,
                              isPrimary: true,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LanguageHelper.t('journal_prompt_title'),
                                style: sectionTitleStyle,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                LanguageHelper.t('journal_prompt_subtitle'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: isMobile ? 13.5 : 14,
                                  color: cs.onPrimary.withOpacity(0.92),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerRight,
                                child: _PrimaryJournalButton(
                                  labelKey: 'journal_get_ai_prompt',
                                  onTap: () {
                                    final bloc = context.read<AppDetailsBloc>();
                                    bloc.add(GetAiPromptEvent());
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ======= PAST ENTRIES TITLE =======
                        Text(
                          LanguageHelper.t('journal_past_entries'),
                          style: TextStyle(color: blackColor),
                        ),

                        const SizedBox(height: 12),

                        if (journalModel?.results == null ||
                            journalModel!.results.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                "No entries yet",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          )
                        else
                          Column(
                            children: [
                              ...journalModel.results.map((entry) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _DynamicJournalCard(
                                    entry: entry,
                                    ontap: () {
                                      context.read<AppDetailsBloc>().add(
                                        GetJournalDetail(
                                          id: entry.id.toString(),
                                        ),
                                      );
                                      // Navigator.push(
                                      //   context,
                                      //   MaterialPageRoute(
                                      //     builder:
                                      //         (context) => JournalDetails(),
                                      //   ),
                                      // );
                                    },
                                  ),
                                );
                              }).toList(),

                              /// Show More Button
                              if (journalModel.next != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      currentPage++;
                                      context.read<AppDetailsBloc>().add(
                                        GetJournalEntry(page: currentPage),
                                      );
                                    },
                                    child: const Text("Show More"),
                                  ),
                                ),
                            ],
                          ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _JournalToggleButton extends StatelessWidget {
  final String labelKey;
  final bool isPrimary;
  final bool useGradient; // NEW
  final VoidCallback? onTap;

  const _JournalToggleButton({
    required this.labelKey,
    required this.isPrimary,
    this.useGradient = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = LanguageHelper.t(labelKey);
    final cs = Theme.of(context).colorScheme;
    final bool applyGradient = useGradient || isPrimary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient:
              applyGradient
                  ? buildThemeGradient(context, isPrimary: true)
                  : null,
          color: applyGradient ? null : cs.surfaceVariant,
          boxShadow:
              applyGradient
                  ? [
                    BoxShadow(
                      color:
                          isDark
                              ? cs.primary.withOpacity(0.14)
                              : cs.primary.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPrimary ? Icons.add_circle_outline : Icons.auto_awesome,
              size: 18,
              color: applyGradient ? cs.onPrimary : cs.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: applyGradient ? cs.onPrimary : cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryJournalButton extends StatelessWidget {
  final String labelKey;
  final VoidCallback? onTap;

  const _PrimaryJournalButton({required this.labelKey, this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = LanguageHelper.t(labelKey);
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: buildThemeGradient(context, isPrimary: true),
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? cs.primary.withOpacity(0.18)
                      : cs.primary.withOpacity(0.18),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: cs.onPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _DynamicJournalCard extends StatelessWidget {
  final JournalEntryModel entry;
  final VoidCallback ontap;

  const _DynamicJournalCard({required this.entry, required this.ontap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
  

    return GestureDetector(
      onTap: ontap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: buildThemeGradient(context, isPrimary: true),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateTimeHelper.formatAlertTime(entry.createdAt ?? ""),

              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.onPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.notes ?? "",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              entry.mood ?? "",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
