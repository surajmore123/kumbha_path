import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';


class TempleDetailsScreen extends StatelessWidget {
  const TempleDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isDesktop = context.isDesktop;

    return MainLayout(
      showDefaultBottom: false,
      ctx: 0,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF5E9),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          LanguageHelper.t('temple_details_appbar_title'), // "Temple Details"
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
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
          final headingStyle =
              Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: isMobile
                        ? 22
                        : isTablet
                            ? 24
                            : 26,
                    color: const Color(0xFF212121),
                  );

          final sectionTitleStyle =
              Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: isMobile ? 15 : 16,
                    color: const Color(0xFFB35C00),
                  );

          final bodyStyle =
              Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: isMobile ? 13.5 : 14,
                    height: 1.45,
                    color: const Color(0xFF4E5B68),
                  );

          return Container(
            color: const Color(0xFFFDF5E9),
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
                    // ================= IMAGE CARD =================
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Image.asset(
                              'assets/images/kashi.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                          // bookmark icon
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.bookmark_border,
                                  color: Color(0xFFB35C00),
                                ),
                                onPressed: () {
                                  // TODO: save / bookmark
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ================= TITLE + LOCATION =================
                    Text(
                      LanguageHelper.t('kashi_details_title'),
                      style: headingStyle,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: Color(0xFFEF6C00),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            LanguageHelper.t('kashi_details_location'),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontSize: 13,
                                  color: const Color(0xFF6B7580),
                                ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ================= ABOUT SECTION =================
                    Text(
                      LanguageHelper.t('temple_about_heading'),
                      style: sectionTitleStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      LanguageHelper.t('kashi_details_about'),
                      style: bodyStyle,
                    ),

                    const SizedBox(height: 18),

                    // ================= BUTTONS =================
                    Row(
                      children: [
                        Expanded(
                          child: _PrimaryActionButton(
                            text:
                                LanguageHelper.t('temple_get_directions_btn'),
                            icon: Icons.navigation_outlined,
                            onTap: () {
                              // TODO: open maps
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _SecondaryActionButton(
                            text:
                                LanguageHelper.t('temple_add_to_journal_btn'),
                            icon: Icons.edit_note_outlined,
                            onTap: () {
                              // TODO: add to journal
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ================= STORY / EXTRA TEXT =================
                    Text(
                      LanguageHelper.t('kashi_details_story'),
                      style: bodyStyle,
                    ),

                    const SizedBox(height: 20),

                    // ================= AI INSIGHT =================
                    Text(
                      LanguageHelper.t('temple_ai_insight_heading'),
                      style: sectionTitleStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      LanguageHelper.t('kashi_details_ai_insight'),
                      style: bodyStyle,
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

// ================= BUTTON WIDGETS =================

class _PrimaryActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  const _PrimaryActionButton({
    required this.text,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
              color: Colors.orange.withOpacity(0.30),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  const _SecondaryActionButton({
    required this.text,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFF90A4AE),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
