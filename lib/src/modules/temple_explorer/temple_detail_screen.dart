import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/constant/app_color.dart';
import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/constant/location_service.dart';
import 'package:kumbha_path/src/modules/temple_explorer/temple_navigation_map.dart';

class TempleDetailsScreen extends StatefulWidget {
  const TempleDetailsScreen({super.key});

  @override
  State<TempleDetailsScreen> createState() => _TempleDetailsScreenState();
}

class _TempleDetailsScreenState extends State<TempleDetailsScreen> {
  String? templeName;
  String? templeState;
  String? templeCity;
  String? templeDetail;
  String? templeImage;
  String? crowdLevel;
  late String userLat;
  late String userLng;

  void assignValues(AppDetailsState state) {
    final data = state.templeDetail;

    templeName = data.name ?? '';
    templeState = data.state ?? '';
    templeCity = data.city ?? '';
    templeDetail = data.description ?? '';
    templeImage = data.imageUrl ?? '';
    crowdLevel = data.crowdLevel ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isDesktop = context.isDesktop;

    return MainLayout(
      showDefaultBottom: false,
      ctx: 0,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          LanguageHelper.t('temple_details_appbar_title'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ),
      body: BlocConsumer<AppDetailsBloc, AppDetailsState>(
        listener: (context, state) {
          if (state.status == AppDetailsStatus.success) {
            assignValues(state);
          }
        },
        builder: (context, state) {
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
                constraints: BoxConstraints(maxWidth: isDesktop ? 520 : 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // IMAGE
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Image.network(
                              templeImage ?? '',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Image.asset(
                                  'assets/images/placeholder.jpg',
                                  fit: BoxFit.cover,
                                );
                              },
                            ),

                            // Image.asset(
                            //   'assets/images/kashi.png',
                            //   fit: BoxFit.cover,
                            // ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                color: cs.surface.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.bookmark_border,
                                  color:
                                      isDark
                                          ? cs.primary
                                          : const Color(0xFFEF6C00),
                                ),
                                onPressed: () {},
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      templeName.toString(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onBackground,
                      ),
                    ),

                    // Text(
                    //   LanguageHelper.t('kashi_details_title'),
                    // style: theme.textTheme.headlineSmall?.copyWith(
                    //   fontWeight: FontWeight.w700,
                    //   color: cs.onBackground,
                    // ),
                    // ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: isDark ? cs.primary : const Color(0xFFEF6C00),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$templeState,$templeCity',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onBackground.withOpacity(0.7),
                            ),
                          ),
                          //  Text(
                          //   LanguageHelper.t('kashi_details_location'),
                          // style: theme.textTheme.bodyMedium?.copyWith(
                          //   color: cs.onBackground.withOpacity(0.7),
                          // ),
                          // ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Text(
                      LanguageHelper.t('temple_about_heading'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? cs.primary : const Color(0xFFB35C00),
                      ),
                    ),

                    const SizedBox(height: 6),
                    Text(
                      templeDetail.toString(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onBackground.withOpacity(0.88),
                      ),
                    ),

                    // Text(
                    //   LanguageHelper.t('kashi_details_about'),
                    // style: theme.textTheme.bodyMedium?.copyWith(
                    //   color: cs.onBackground.withOpacity(0.88),
                    // ),
                    // ),
                    const SizedBox(height: 18),

                    _PrimaryActionButton(
                      onTap: () async {
                        final position =
                            await LocationService.getCurrentLocation();

                        userLat = position.latitude.toString();
                        userLng = position.longitude.toString();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => TempleNavigationMap(
                                  templelat: double.parse(
                                    state.templeDetail.latitude.toString(),
                                  ),
                                  templelng: double.parse(
                                    state.templeDetail.longitude.toString(),
                                  ),
                                  templeName: state.templeDetail.name!,
                                ),
                          ),
                        );
                        context.read<AppDetailsBloc>().add(
                          TempleNavigate(
                            templeId: state.templeDetail.templeId.toString(),
                            latitude: userLat,
                            longitude: userLng,
                          ),
                        );
                      },
                      text: LanguageHelper.t('temple_get_directions_btn'),
                      icon: Icons.navigation_outlined,
                    ),

                    const SizedBox(height: 10),

                    _SecondaryActionButton(
                      text: LanguageHelper.t('temple_add_to_journal_btn'),
                      icon: Icons.edit_note_outlined,
                    ),
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
  VoidCallback onTap;

  _PrimaryActionButton({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: buildThemeGradient(context, isPrimary: true),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: cs.onPrimary),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: cs.onPrimary,
                fontWeight: FontWeight.w700,
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
