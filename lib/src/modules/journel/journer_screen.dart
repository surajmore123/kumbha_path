import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/constant/app_color.dart';

import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/modules/journel/daily_ai_reflection.dart';
class JournerScreen extends StatelessWidget {
  const JournerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isDesktop = context.isDesktop;

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

          return Container(
            color: theme.scaffoldBackgroundColor,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : isTablet ? 32 : 56,
                vertical: isMobile ? 16 : 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 520 : 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ======= TOP TOGGLE BUTTONS =======
                    Row(
                      children: [
                        Expanded(
                          child: _JournalToggleButton(
                            useGradient: true, // show gradient (purple in dark, orange in light)
                            labelKey: 'journal_ai_reflection',
                            isPrimary: false,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DailyReflectionScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _JournalToggleButton(
                            labelKey: 'journal_add_entry',
                            isPrimary: true,
                            onTap: () {
                              Navigator.pushNamed(context, '/myJournalEntry');
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
                        gradient: buildThemeGradient(context, isPrimary: true),
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
                                // TODO: generate AI prompt
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
                      style: sectionTitleStyle,
                    ),

                    const SizedBox(height: 12),

                    // ======= PAST ENTRY CARDS =======
                    _JournalEntryCard(
                      icon: Icons.emoji_emotions_outlined,
                      iconColor: cs.primary,
                      dateKey: 'journal_entry_1_date',
                      textKey: 'journal_entry_1_text',
                      moodKey: 'journal_entry_1_mood',
                    ),
                    const SizedBox(height: 12),
                    _JournalEntryCard(
                      icon: Icons.self_improvement_outlined,
                      iconColor: cs.secondary,
                      dateKey: 'journal_entry_2_date',
                      textKey: 'journal_entry_2_text',
                      moodKey: 'journal_entry_2_mood',
                    ),
                    const SizedBox(height: 12),
                    _JournalEntryCard(
                      icon: Icons.celebration_outlined,
                      iconColor: cs.tertiary ?? cs.primary,
                      dateKey: 'journal_entry_3_date',
                      textKey: 'journal_entry_3_text',
                      moodKey: 'journal_entry_3_mood',
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ========== TOP TOGGLE BUTTON ==========

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
          gradient: applyGradient ? buildThemeGradient(context, isPrimary: true) : null,
          color: applyGradient ? null : cs.surfaceVariant,
          boxShadow: applyGradient
              ? [
                  BoxShadow(
                    color: isDark ? cs.primary.withOpacity(0.14) : cs.primary.withOpacity(0.18),
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

// ========== PRIMARY SMALL BUTTON (GET AI PROMPT) ==========

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
              color: Theme.of(context).brightness == Brightness.dark
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

// ========== JOURNAL ENTRY CARD ==========

class _JournalEntryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String dateKey;
  final String textKey;
  final String moodKey;

  const _JournalEntryCard({
    required this.icon,
    required this.iconColor,
    required this.dateKey,
    required this.textKey,
    required this.moodKey,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = LanguageHelper.t(dateKey);
    final text = LanguageHelper.t(textKey);
    final mood = LanguageHelper.t(moodKey);

    // We'll apply the same primary gradient to cards (matches buttons).
    final applyGradient = true;

    final textPrimaryColor = applyGradient ? cs.onPrimary : cs.onBackground;
    final bodyTextColor = applyGradient ? cs.onPrimary.withOpacity(0.92) : cs.onBackground.withOpacity(0.82);
    final iconColorFinal = applyGradient ? cs.onPrimary : iconColor;
    final iconTileBg = applyGradient ? cs.onPrimary.withOpacity(0.10) : cs.surface.withOpacity(0.06);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: applyGradient ? buildThemeGradient(context, isPrimary: true) : null,
        color: applyGradient ? null : cs.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // icon tile
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconTileBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 26, color: iconColorFinal),
          ),
          const SizedBox(width: 12),

          // text area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimaryColor,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: bodyTextColor,
                        height: 1.3,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  mood,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimaryColor,
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}
