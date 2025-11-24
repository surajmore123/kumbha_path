import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';

import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';


class JournerScreen extends StatelessWidget {
  const JournerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isDesktop = context.isDesktop;

    return MainLayout(
      showDefaultBottom: true,
      ctx: 3, // Journal tab index in your bottom bar
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF6DD),
        elevation: 0,
        centerTitle: true,
        title: Text(
          LanguageHelper.t('journal_title'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        // actions: const [
        //   Padding(
        //     padding: EdgeInsets.only(right: 12),
        //     child: LanguageIconButton(),
        //   ),
        // ],
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: LanguageHelper.currentLang,
        builder: (context, lang, _) {
          final bodyStyle =
              Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: isMobile ? 13.5 : 14,
                    color: const Color(0xFF4B5563),
                    height: 1.4,
                  );

          final sectionTitleStyle =
              Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: isMobile ? 16 : 18,
                    color: const Color(0xFF111827),
                  );

          return Container(
            color: const Color(0xFFFFF6DD),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile
                    ? 16
                    : isTablet
                        ? 32
                        : 56,
                vertical: isMobile ? 16 : 24,
              ),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: isDesktop ? 520 : 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ======= TOP TOGGLE BUTTONS =======
                    Row(
                      children: [
                        Expanded(
                          child: _JournalToggleButton(
                            labelKey: 'journal_ai_reflection',
                            isPrimary: false,
                            onTap: () {
                              // TODO: open AI reflection flow
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _JournalToggleButton(
                            labelKey: 'journal_add_entry',
                            isPrimary: true,
                            onTap: () {
                              // myJournalEntry
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
                        color: const Color(0xFFFFF0B8),
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
                            style: bodyStyle,
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
                      iconColor: const Color(0xFFF59E0B),
                      dateKey: 'journal_entry_1_date',
                      textKey: 'journal_entry_1_text',
                      moodKey: 'journal_entry_1_mood',
                    ),
                    const SizedBox(height: 12),
                    _JournalEntryCard(
                      icon: Icons.self_improvement_outlined,
                      iconColor: const Color(0xFFF97316),
                      dateKey: 'journal_entry_2_date',
                      textKey: 'journal_entry_2_text',
                      moodKey: 'journal_entry_2_mood',
                    ),
                    const SizedBox(height: 12),
                    _JournalEntryCard(
                      icon: Icons.celebration_outlined,
                      iconColor: const Color(0xFFFB923C),
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
  final VoidCallback? onTap;

  const _JournalToggleButton({
    required this.labelKey,
    required this.isPrimary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = LanguageHelper.t(labelKey);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [
                    Color(0xFFFFA726),
                    Color(0xFFFFC107),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color:
              isPrimary ? null : const Color(0xFFFFF4D0),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isPrimary) ...[
              const Icon(
                Icons.auto_awesome,
                size: 18,
                color: Color(0xFFB45309),
              ),
              const SizedBox(width: 6),
            ] else ...[
              const Icon(
                Icons.add_circle_outline,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPrimary
                    ? Colors.white
                    : const Color(0xFF92400E),
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

  const _PrimaryJournalButton({
    required this.labelKey,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = LanguageHelper.t(labelKey);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFA726),
              Color(0xFFFFC107),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
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
    final date = LanguageHelper.t(dateKey);
    final text = LanguageHelper.t(textKey);
    final mood = LanguageHelper.t(moodKey);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0B8),
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
              color: const Color(0xFFFFFAEB),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              size: 26,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),

          // text area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  mood,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF6B7280),
          ),
        ],
      ),
    );
  }
}
