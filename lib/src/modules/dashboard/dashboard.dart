import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/dashboard_cards.dart';
import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/modules/ai_chat/ai_chat_screen.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isDesktop = context.isDesktop;

    return MainLayout(
      showDefaultBottom: true,
      ctx: 0,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        leadingWidth: 35,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () {
               Navigator.pushNamed(context, '/setting');
            },
            child: SizedBox(
              width: 24,
              height: 24,
              child: Image.asset('assets/icons/user.png', fit: BoxFit.contain),
            ),
          ),
        ),
        title: Text(
          LanguageHelper.t('dashboard_title'), // e.g. "Sadhana Path"
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: LanguageIconButton(), // user can change language here
          ),
        ],
      ),

      body: ValueListenableBuilder<String>(
        valueListenable: LanguageHelper.currentLang,
        builder: (context, lang, _) {
          final titleStyle = Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize:
                isMobile
                    ? 22
                    : isTablet
                    ? 26
                    : 30,
          );

          final subtitleStyle = Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontSize: isMobile ? 14 : 16, color: Colors.grey[700]);

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal:
                  isMobile
                      ? 24
                      : isTablet
                      ? 40
                      : 56,
              vertical: isMobile ? 16 : 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 520 : 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 👋 Greeting
                  Text(
                    LanguageHelper.t('dashboard_greeting'), // "Namaste, Suraj"
                    style: titleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // 🧘 Quote
                  Text(
                    LanguageHelper.t('dashboard_quote'),
                    style: subtitleStyle,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: DashboardFeatureCard(
                          iconPath: 'assets/icons/chat.png',
                          titleKey: 'ai_guru_title',
                          subtitleKey: 'ai_guru_subtitle',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AskGuruAiScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DashboardFeatureCard(
                          iconPath: 'assets/icons/temple.png',
                          titleKey: 'temple_explorer_title',
                          subtitleKey: 'temple_explorer_subtitle',
                          onTap: () {
                          Navigator.pushNamed(context, '/nearTemples');
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 🔹 Live Crowd Map
                  DashboardWideCard(
                    iconPath: 'assets/icons/live_croud.png',
                    titleKey: 'live_crowd_title',
                    subtitleKey: 'live_crowd_subtitle',
                    onTap: () {
                     Navigator.pushNamed(context, '/liveCroud');
                    },
                  ),

                  const SizedBox(height: 16),

                  // 🔹 Journal
                  DashboardWideCard(
                    iconPath: 'assets/icons/journel.png',
                    titleKey: 'journal_home_title',
                    subtitleKey: 'journal_home_subtitle',
                    onTap: () {
                      Navigator.pushNamed(context, '/journal');
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
