import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/constant/app_color.dart';
import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';


class ShahiEvents extends StatelessWidget {
  const ShahiEvents({super.key});

  @override
  Widget build(BuildContext context) {
        final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isDesktop = context.isDesktop;

    return MainLayout(
      // prefer theme scaffold color; MainLayout may accept backgroundColor
      backgroundColor: theme.scaffoldBackgroundColor,
      showDefaultBottom: true,
      ctx: 2,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          LanguageHelper.t('events_appbar_title'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: cs.onSurface
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.settings_outlined, color: cs.onSurface),
          ),
        ],
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: LanguageHelper.currentLang,
        builder: (context, lang, _) {
          final titleStyle = theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: isMobile ? 22 : isTablet ? 24 : 26,
            color: cs.onBackground,
          );

          final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
            fontSize: isMobile ? 13.5 : 14,
            color: cs.onBackground.withOpacity(0.9),
            height: 1.4,
          );

          final sectionTitleStyle = theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: isMobile ? 16 : 18,
            color: cs.onBackground,
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
                    // ========= MAIN SHAHI SNAN CARD =========
                    _MainSnanCard(
                      titleStyle: titleStyle,
                      bodyStyle: bodyStyle,
                    ),

                    const SizedBox(height: 24),

                    // ========= OTHER KEY EVENTS HEADER =========
                    Text(
                      LanguageHelper.t('events_other_key_events'),
                      style: sectionTitleStyle,
                    ),
                    const SizedBox(height: 16),

                    // ========= LIST OF OTHER EVENTS =========
                    _OtherEventRow(
                      icon: Icons.wb_sunny_outlined,
                      iconBgColor: cs.primaryContainer.withOpacity(0.14),
                      titleKey: 'event_ganga_aarti_title',
                      descriptionKey: 'event_ganga_aarti_description',
                    ),
                    const SizedBox(height: 12),

                    _OtherEventRow(
                      icon: Icons.groups_2_outlined,
                      iconBgColor: cs.primaryContainer.withOpacity(0.14),
                      titleKey: 'event_sant_samagam_title',
                      descriptionKey: 'event_sant_samagam_description',
                    ),
                    const SizedBox(height: 12),

                    _OtherEventRow(
                      icon: Icons.music_note_outlined,
                      iconBgColor: cs.primaryContainer.withOpacity(0.14),
                      titleKey: 'event_cultural_evening_title',
                      descriptionKey: 'event_cultural_evening_description',
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

// ================= MAIN SNAN CARD =================

class _MainSnanCard extends StatelessWidget {
  final TextStyle? titleStyle;
  final TextStyle? bodyStyle;

  const _MainSnanCard({
    required this.titleStyle,
    required this.bodyStyle,
  });

  @override
  Widget build(BuildContext context) {
   final cs = Theme.of(context).colorScheme;

    final applyGradient = true;

    return Container(
      padding:  EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: applyGradient ? buildThemeGradient(context, isPrimary: true) : null,
        // gradient: LinearGradient(
        //   colors: [
        //     cs.primary,
        //     cs.primaryContainer,
        //   ],
        //   begin: Alignment.topLeft,
        //   end: Alignment.bottomRight,
        // ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: cs.onPrimary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              LanguageHelper.t('shahi_snan_timing'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimary,
                  ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            LanguageHelper.t('shahi_snan_title'),
            style: titleStyle?.copyWith(color: cs.onPrimary),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: cs.onPrimary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  LanguageHelper.t('shahi_snan_location'),
                  style: bodyStyle?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            LanguageHelper.t('shahi_snan_description'),
            style: bodyStyle?.copyWith(color: cs.onPrimary.withOpacity(0.92)),
          ),

          const SizedBox(height: 16),

          // Remind Me button aligned to right
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                // TODO: set reminder
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: applyGradient ? buildThemeGradient(context, isPrimary: true) : null,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: cs.secondary.withOpacity(0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_active_outlined, color: cs.onSecondary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      LanguageHelper.t('events_remind_me'),
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= OTHER EVENTS ROW =================

class _OtherEventRow extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final String titleKey;
  final String descriptionKey;

  const _OtherEventRow({
    required this.icon,
    required this.iconBgColor,
    required this.titleKey,
    required this.descriptionKey,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final cs = Theme.of(context).colorScheme;

    final titleStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: isMobile ? 15 : 16,
          color: cs.onBackground,
        );

    final descStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: isMobile ? 13 : 14,
          color: cs.onBackground.withOpacity(0.72),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left icon box
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: cs.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),

        // Texts
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LanguageHelper.t(titleKey),
                style: titleStyle,
              ),
              const SizedBox(height: 4),
              Text(
                LanguageHelper.t(descriptionKey),
                style: descStyle,
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Calendar icon
        Icon(
          Icons.event_available_outlined,
          color: cs.primary,
          size: 24,
        ),
      ],
    );
  }
}
