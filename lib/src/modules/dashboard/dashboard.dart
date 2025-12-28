import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_bloc.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_event.dart';
import 'package:kumbha_path/src/components/dashboard_cards.dart';
import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/constant/location_service.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
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
        leadingWidth: 35,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/setting'),
            child: SizedBox(
              width: 24,
              height: 24,
              child: Image.asset(
                'assets/icons/user.png',
                fit: BoxFit.contain,
                color: cs.onSurface,
              ),
            ),
          ),
        ),
        title: Text(
          LanguageHelper.t('dashboard_title'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: cs.onBackground,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: LanguageIconButton(),
          ),
        ],
      ),

      body: ValueListenableBuilder<String>(
        valueListenable: LanguageHelper.currentLang,
        builder: (context, lang, _) {
          final titleStyle = theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize:
                isMobile
                    ? 22
                    : isTablet
                    ? 26
                    : 30,
            color: cs.onBackground,
          );

          final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
            fontSize: isMobile ? 14 : 16,
            color: cs.onBackground.withOpacity(0.78),
          );

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
                  // Greeting
                  Text(
                    LanguageHelper.t('dashboard_greeting'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onBackground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Quote / subtitle
                  Text(
                    LanguageHelper.t('dashboard_quote'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onBackground.withOpacity(0.85),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // Feature cards row
                  Row(
                    children: [
                      Expanded(
                        child: DashboardFeatureCard(
                          iconPath: 'assets/icons/chat.png',
                          titleKey: 'ai_guru_title',
                          subtitleKey: 'ai_guru_subtitle',
                          onTap: () => Navigator.pushNamed(context, '/aichat'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DashboardFeatureCard(
                          iconPath: 'assets/icons/temple.png',
                          titleKey: 'temple_explorer_title',
                          subtitleKey: 'temple_explorer_subtitle',
                          onTap: () async {
                            final position =
                                await LocationService.getCurrentLocation();
                            context.read<AppBloc>().add(
                              GetNearbyTemplesEvent(
                                // latitude: '20.0065434',
                                // longitude: '73.7071641',
                                latitude: position.latitude.toString(),
                                longitude: position.longitude.toString(),
                              ),
                            );
                            Navigator.pushNamed(
                              context,
                              '/nearTemples',
                              
                              arguments: {
                                'lat': position.latitude.toString(),
                                'lng': position.longitude.toString(),
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Live crowd wide card
                  DashboardWideCard(
                    iconPath: 'assets/icons/live_croud.png',
                    titleKey: 'live_crowd_title',
                    subtitleKey: 'live_crowd_subtitle',
                    onTap: () => Navigator.pushNamed(context, '/liveCroud'),
                  ),

                  const SizedBox(height: 16),

                  // Journal wide card
                  DashboardWideCard(
                    iconPath: 'assets/icons/journel.png',
                    titleKey: 'journal_home_title',
                    subtitleKey: 'journal_home_subtitle',
                    onTap: () => Navigator.pushNamed(context, '/journal'),
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
