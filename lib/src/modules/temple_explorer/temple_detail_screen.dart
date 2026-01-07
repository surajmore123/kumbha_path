import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/constant/app_color.dart';
import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
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
                      onTap: () {
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

// class TempleDetailsScreen extends StatelessWidget {
//   const TempleDetailsScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final cs = theme.colorScheme;
//     final isDark = theme.brightness == Brightness.dark;

//     final isMobile = context.isMobile;
//     final isTablet = context.isTablet;
//     final isDesktop = context.isDesktop;

//     return MainLayout(
//       showDefaultBottom: false,
//       ctx: 0,
//       appBar: AppBar(
//         backgroundColor: theme.appBarTheme.backgroundColor ?? cs.surface,
//         elevation: 0,
//         centerTitle: true,
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back, color: cs.onSurface),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           LanguageHelper.t('temple_details_appbar_title'), // "Temple Details"
//           style: theme.textTheme.titleMedium?.copyWith(
//             fontSize: 18,
//             fontWeight: FontWeight.w600,
//             color: cs.onSurface,
//           ),
//         ),
//       ),
//       body: ValueListenableBuilder<String>(
//         valueListenable: LanguageHelper.currentLang,
//         builder: (context, lang, _) {
//           final headingStyle = theme.textTheme.headlineSmall?.copyWith(
//             fontWeight: FontWeight.w700,
//             fontSize: isMobile ? 22 : isTablet ? 24 : 26,
//             color: cs.onBackground,
//           );

//           final sectionTitleStyle = theme.textTheme.titleMedium?.copyWith(
//             fontWeight: FontWeight.w700,
//             fontSize: isMobile ? 15 : 16,
//             color: cs.primary, // highlight color
//           );

//           final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
//             fontSize: isMobile ? 13.5 : 14,
//             height: 1.45,
//             color: cs.onBackground.withOpacity(0.88),
//           );

//           final metaTextStyle = theme.textTheme.bodySmall?.copyWith(
//             color: cs.onBackground.withOpacity(0.72),
//             fontSize: 13,
//           );

//           return Container(
//             color: theme.scaffoldBackgroundColor,
//             child: SingleChildScrollView(
//               padding: EdgeInsets.symmetric(
//                 horizontal: isMobile ? 16 : isTablet ? 32 : 56,
//                 vertical: isMobile ? 16 : 24,
//               ),
//               child: ConstrainedBox(
//                 constraints: BoxConstraints(maxWidth: isDesktop ? 720 : 640),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // ================= IMAGE CARD =================
//                     ClipRRect(
//                       borderRadius: BorderRadius.circular(24),
//                       child: Stack(
//                         children: [
//                           AspectRatio(
//                             aspectRatio: 4 / 3,
//                             child: Image.asset(
//                               'assets/images/kashi.png',
//                               fit: BoxFit.cover,
//                             ),
//                           ),

//                           // bookmark icon (overlay)
//                           Positioned(
//                             top: 12,
//                             right: 12,
//                             child: Container(
//                               decoration: BoxDecoration(
//                                 color: cs.surface.withOpacity(0.85),
//                                 borderRadius: BorderRadius.circular(20),
//                               ),
//                               child: IconButton(
//                                 icon: Icon(
//                                   Icons.bookmark_border,
//                                   color: cs.primary,
//                                 ),
//                                 onPressed: () {
//                                   // TODO: save / bookmark
//                                 },
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),

//                     const SizedBox(height: 20),

//                     // ================= TITLE + LOCATION =================
//                     Text(
//                       LanguageHelper.t('kashi_details_title'),
//                       style: headingStyle,
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       children: [
//                         Icon(
//                           Icons.location_on_outlined,
//                           size: 18,
//                           color: cs.primary,
//                         ),
//                         const SizedBox(width: 6),
//                         Expanded(
//                           child: Text(
//                             LanguageHelper.t('kashi_details_location'),
//                             style: metaTextStyle,
//                           ),
//                         ),
//                       ],
//                     ),

//                     const SizedBox(height: 20),

//                     // ================= ABOUT SECTION =================
//                     Text(
//                       LanguageHelper.t('temple_about_heading'),
//                       style: sectionTitleStyle,
//                     ),
//                     const SizedBox(height: 6),
//                     Text(
//                       LanguageHelper.t('kashi_details_about'),
//                       style: bodyStyle,
//                     ),

//                     const SizedBox(height: 18),

//                     // ================= BUTTONS =================
//                     Row(
//                       children: [
//                         Expanded(
//                           child: _PrimaryActionButton(
//                             text: LanguageHelper.t('temple_get_directions_btn'),
//                             icon: Icons.navigation_outlined,
//                             onTap: () {
//                               // TODO: open maps
//                             },
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 10),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: _SecondaryActionButton(
//                             text: LanguageHelper.t('temple_add_to_journal_btn'),
//                             icon: Icons.edit_note_outlined,
//                             onTap: () {
//                               // TODO: add to journal
//                             },
//                           ),
//                         ),
//                       ],
//                     ),

//                     const SizedBox(height: 18),

//                     // ================= STORY / EXTRA TEXT =================
//                     Text(
//                       LanguageHelper.t('kashi_details_story'),
//                       style: bodyStyle,
//                     ),

//                     const SizedBox(height: 20),

//                     // ================= AI INSIGHT =================
//                     Text(
//                       LanguageHelper.t('temple_ai_insight_heading'),
//                       style: sectionTitleStyle,
//                     ),
//                     const SizedBox(height: 6),
//                     Text(
//                       LanguageHelper.t('kashi_details_ai_insight'),
//                       style: bodyStyle,
//                     ),

//                     const SizedBox(height: 24),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// // ================= BUTTON WIDGETS =================

// class _PrimaryActionButton extends StatelessWidget {
//   final String text;
//   final IconData icon;
//   final VoidCallback? onTap;

//   const _PrimaryActionButton({
//     required this.text,
//     required this.icon,
//     this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;

//     // Use a gradient derived from primary; keep contrast with onPrimary
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(24),
//           gradient: LinearGradient(
//             colors: [
//               cs.primary,
//               cs.primaryContainer, // slight shift for depth
//             ],
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: cs.primary.withOpacity(0.20),
//               blurRadius: 8,
//               offset: const Offset(0, 3),
//             ),
//           ],
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(icon, size: 18, color: cs.onPrimary),
//             const SizedBox(width: 8),
//             Text(
//               text,
//               style: TextStyle(
//                 color: cs.onPrimary,
//                 fontWeight: FontWeight.w700,
//                 fontSize: 14,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _SecondaryActionButton extends StatelessWidget {
//   final String text;
//   final IconData icon;
//   final VoidCallback? onTap;

//   const _SecondaryActionButton({
//     required this.text,
//     required this.icon,
//     this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;

//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(24),
//           color: cs.surfaceVariant,
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(icon, size: 18, color: cs.onSurfaceVariant),
//             const SizedBox(width: 8),
//             Text(
//               text,
//               style: TextStyle(
//                 color: cs.onSurfaceVariant,
//                 fontWeight: FontWeight.w600,
//                 fontSize: 14,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
