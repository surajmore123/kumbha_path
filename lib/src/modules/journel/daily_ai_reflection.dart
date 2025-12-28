import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/constant/app_color.dart';
import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';

class DailyReflectionScreen extends StatelessWidget {
  const DailyReflectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isDesktop = context.isDesktop;

    return MainLayout(
      showDefaultBottom: true,
      ctx: 0,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? cs.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          LanguageHelper.t('daily_reflection_title'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: cs.onSurface,
          ),
        ),
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: LanguageHelper.currentLang,
        builder: (context, lang, _) {
          final titleStyle = theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: isMobile ? 16 : isTablet ? 18 : 20,
            color: cs.onBackground,
          );

          final dateStyle = theme.textTheme.bodySmall?.copyWith(
            color: cs.onBackground.withOpacity(0.72),
            fontSize: 12,
          );

          final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
            fontSize: isMobile ? 14 : 15,
            height: 1.5,
            color: cs.onBackground.withOpacity(0.9),
          );

          return Container(
            color: theme.scaffoldBackgroundColor,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : isTablet ? 32 : 56,
                  vertical: isMobile ? 16 : 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 520 : 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ReflectionCard(
                        titleStyle: titleStyle,
                        dateStyle: dateStyle,
                        bodyStyle: bodyStyle,
                      ),
                      const SizedBox(height: 32),
                      _ReflectionActions(
                        onShare: () {
                          // TODO: implement share reflection
                        },
                        onAddToJournal: () {
                          // TODO: implement add to journal navigation
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReflectionCard extends StatelessWidget {
  final TextStyle? titleStyle;
  final TextStyle? dateStyle;
  final TextStyle? bodyStyle;

  const _ReflectionCard({
    required this.titleStyle,
    required this.dateStyle,
    required this.bodyStyle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Use the shared gradient builder so light shows orange, dark uses cs.primary -> cs.primaryContainer
    final gradient = buildThemeGradient(context, isPrimary: true);

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? cs.primary.withOpacity(0.12)
                : cs.primary.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: square + title + date
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: gradient,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LanguageHelper.t('reflection_author_title'),
                    style: titleStyle?.copyWith(color: cs.onPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LanguageHelper.t('reflection_date'),
                    style: dateStyle?.copyWith(color: cs.onPrimary.withOpacity(0.9)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            LanguageHelper.t('reflection_paragraph_1'),
            style: bodyStyle?.copyWith(color: cs.onPrimary.withOpacity(0.95)),
          ),
          const SizedBox(height: 18),
          Text(
            LanguageHelper.t('reflection_paragraph_2'),
            style: bodyStyle?.copyWith(color: cs.onPrimary.withOpacity(0.95)),
          ),
        ],
      ),
    );
  }
}

class _ReflectionActions extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback onAddToJournal;

  const _ReflectionActions({
    required this.onShare,
    required this.onAddToJournal,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Share button (subtle surface variant)
        GestureDetector(
          onTap: onShare,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isMobile ? 14 : 16,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.ios_share_outlined, size: 22, color: cs.onSurface),
                const SizedBox(width: 10),
                Text(
                  LanguageHelper.t('reflection_share_button'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Add to Journal button (primary gradient)
        GestureDetector(
          onTap: onAddToJournal,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isMobile ? 16 : 18,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: buildThemeGradient(context, isPrimary: true),
              boxShadow: [
                BoxShadow(
                  color: brightness == Brightness.dark
                      ? cs.primary.withOpacity(0.18)
                      : cs.primary.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_note, color: cs.onPrimary, size: 24),
                const SizedBox(width: 10),
                Text(
                  LanguageHelper.t('reflection_add_to_journal_button'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

