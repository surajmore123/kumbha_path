
import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/constant/app_color.dart';

import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';


// class LiveCrowdMap extends StatelessWidget {
//   const LiveCrowdMap({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final isMobile = context.isMobile;
//     final isTablet = context.isTablet;
//     final isDesktop = context.isDesktop;

//     return MainLayout(
//       showDefaultBottom: true,
//       ctx: 0, // or whichever tab index you want selected
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.black87),
//           onPressed: () => Navigator.pop(context),
//         ),
//           title: Text(
//           LanguageHelper.t('live_crowd_location'), // "Temple Details"
//           style: const TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.w600,
//             color: Colors.black87,
//           ),
//         ),
//         actions:  [
//           Padding( 
//             padding: EdgeInsets.only(right: 8),
//             child: IconButton(onPressed: (){
//               Navigator.pushNamed(context, '/notifications');
//             }, icon: Icon(Icons.notifications_none, color: Colors.black87),)
//           ),
//         ],
//       ),
//       body: ValueListenableBuilder<String>(
//         valueListenable: LanguageHelper.currentLang,
//         builder: (context, lang, _) {
//           final titleStyle =
//               Theme.of(context).textTheme.headlineSmall?.copyWith(
//                     fontWeight: FontWeight.w800,
//                     fontSize: isMobile
//                         ? 26
//                         : isTablet
//                             ? 30
//                             : 32,
//                     color: const Color(0xFF101827),
//                   );

//           final subtitleStyle =
//               Theme.of(context).textTheme.bodyMedium?.copyWith(
//                     fontSize: isMobile ? 13 : 14,
//                     color: const Color(0xFF4B5563),
//                   );

//           return Container(
//             color: const Color(0xFFF3F4F6),
//             child: SingleChildScrollView(
//               padding: EdgeInsets.symmetric(
//                 horizontal: isMobile
//                     ? 16
//                     : isTablet
//                         ? 32
//                         : 56,
//                 vertical: isMobile ? 8 : 16,
//               ),
//               child: ConstrainedBox(
//                 constraints:
//                     BoxConstraints(maxWidth: isDesktop ? 520 : 480),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
                 

//                     const SizedBox(height: 10),

           
//                     Text(
//                       LanguageHelper.t('live_crowd_title'),
//                       style: titleStyle,
//                     ),

//                     const SizedBox(height: 16),

//                     // ========== MAP IMAGE ==========
//                     ClipRRect(
//                       borderRadius: BorderRadius.circular(24),
//                       child: AspectRatio(
//                         aspectRatio: 6 / 4, 
//                         child: Image.asset(
//                           'assets/images/nashik_map.png',
//                           fit: BoxFit.cover,
//                         ),
//                       ),
//                     ),

//                     const SizedBox(height: 16),

//                     // ========== BOTTOM SHEET STYLE PANEL ==========
//                     Container(
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(24),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.06),
//                             blurRadius: 8,
//                             offset: const Offset(0, 3),
//                           ),
//                         ],
//                       ),
//                       child: Padding(
//                         padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             // drag handle
//                             Center(
//                               child: Container(
//                                 width: 40,
//                                 height: 4,
//                                 margin:
//                                     const EdgeInsets.only(bottom: 12),
//                                 decoration: BoxDecoration(
//                                   color: const Color(0xFFE5E7EB),
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                               ),
//                             ),

//                             Text(
//                               LanguageHelper.t('live_crowd_quick_alerts'),
//                               style: Theme.of(context)
//                                   .textTheme
//                                   .titleMedium
//                                   ?.copyWith(
//                                     fontWeight: FontWeight.w700,
//                                     fontSize: isMobile ? 16 : 18,
//                                     color: const Color(0xFF111827),
//                                   ),
//                             ),

//                             const SizedBox(height: 14),

//                             // ========== NEXT SNAN SCHEDULE CARD ==========
//                             _ScheduleAlertCard(
//                               subtitleStyle: subtitleStyle,
//                             ),

//                             const SizedBox(height: 12),

//                             // ========== TRAFFIC ALERT ==========
//                             _AlertCard(
//                               categoryKey: 'live_crowd_traffic_category',
//                               titleKey: 'live_crowd_traffic_title',
//                               descriptionKey:
//                                   'live_crowd_traffic_description',
//                               imagePath:
//                                   'assets/images/kashi.png',
//                               categoryColor:
//                                   const Color(0xFFB45309), // brown/orange
//                               subtitleStyle: subtitleStyle,
//                             ),

//                             const SizedBox(height: 12),

//                             // ========== CROWD ALERT ==========
//                             _AlertCard(
//                               categoryKey: 'live_crowd_crowd_category',
//                               titleKey: 'live_crowd_crowd_title',
//                               descriptionKey:
//                                   'live_crowd_crowd_description',
//                               imagePath:
//                                   'assets/images/kashi.png',
//                               categoryColor:
//                                   const Color(0xFF92400E), // deep amber
//                               subtitleStyle: subtitleStyle,
//                             ),
//                           ],
//                         ),
//                       ),
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

// // =================== SCHEDULE CARD ===================

// class _ScheduleAlertCard extends StatelessWidget {
//   final TextStyle? subtitleStyle;

//   const _ScheduleAlertCard({this.subtitleStyle});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: const Color(0xFFFFF4D7),
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Row(
//         children: [
//           // icon circle
//           Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               color: const Color(0xFFFFE0A8),
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: const Icon(
//               Icons.access_time_rounded,
//               color: Color(0xFFB45309),
//               size: 22,
//             ),
//           ),
//           const SizedBox(width: 12),
//           // text
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   LanguageHelper.t('live_crowd_next_snan_label'),
//                   style: subtitleStyle?.copyWith(
//                     fontWeight: FontWeight.w600,
//                     fontSize: 13,
//                     color: const Color(0xFF6B7280),
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   LanguageHelper.t('live_crowd_next_snan_value'),
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w700,
//                     color: Color(0xFF111827),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // =================== GENERIC ALERT CARD ===================

// class _AlertCard extends StatelessWidget {
//   final String categoryKey;
//   final String titleKey;
//   final String descriptionKey;
//   final String imagePath;
//   final Color categoryColor;
//   final TextStyle? subtitleStyle;

//   const _AlertCard({
//     required this.categoryKey,
//     required this.titleKey,
//     required this.descriptionKey,
//     required this.imagePath,
//     required this.categoryColor,
//     required this.subtitleStyle,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: const Color(0xFFFFF4D7),
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // left text area
//           Flexible(
//             fit: FlexFit.tight,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   LanguageHelper.t(categoryKey),
//                   style: subtitleStyle?.copyWith(
//                     fontWeight: FontWeight.w600,
//                     fontSize: 13,
//                     color: categoryColor,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   LanguageHelper.t(titleKey),
//                   style: const TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.w700,
//                     color: Color(0xFF111827),
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   LanguageHelper.t(descriptionKey),
//                   style: subtitleStyle,
//                 ),
//               ],
//             ),
//           ),

//           const SizedBox(width: 12),

//           // right image
//           ClipRRect(
//             borderRadius: BorderRadius.circular(16),
//             child: Image.asset(
//               imagePath,
//               width: 80,
//               height: 80,
//               fit: BoxFit.cover,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


class LiveCrowdMap extends StatelessWidget {
  const LiveCrowdMap({super.key});

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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          LanguageHelper.t('live_crowd_location'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/notifications');
              },
              icon: Icon(Icons.notifications_none, color: cs.onSurface),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: LanguageHelper.currentLang,
        builder: (context, lang, _) {
          final titleStyle = theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: isMobile ? 26 : isTablet ? 30 : 32,
            color: cs.onBackground,
          );

          final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
            fontSize: isMobile ? 13 : 14,
            color: cs.onBackground.withOpacity(0.72),
          );

          return Container(
            color: theme.scaffoldBackgroundColor,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : isTablet ? 32 : 56,
                vertical: isMobile ? 8 : 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 520 : 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    Text(
                      LanguageHelper.t('live_crowd_title'),
                      style: titleStyle,
                    ),

                    const SizedBox(height: 16),

                    // ========== MAP IMAGE ==========
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                        aspectRatio: 6 / 4,
                        child: Image.asset(
                          'assets/images/nashik_map.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ========== BOTTOM SHEET STYLE PANEL ==========
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: cs.shadow.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // drag handle
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: cs.outline.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),

                            Text(
                              LanguageHelper.t('live_crowd_quick_alerts'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: isMobile ? 16 : 18,
                                color: cs.onSurface,
                              ),
                            ),

                            const SizedBox(height: 14),

                            // ========== NEXT SNAN SCHEDULE CARD ==========
                            _ScheduleAlertCard(
                              subtitleStyle: subtitleStyle,
                            ),

                            const SizedBox(height: 12),

                            // ========== TRAFFIC ALERT ==========
                            _AlertCard(
                              categoryKey: 'live_crowd_traffic_category',
                              titleKey: 'live_crowd_traffic_title',
                              descriptionKey: 'live_crowd_traffic_description',
                              imagePath: 'assets/images/kashi.png',
                              // map categoryColor to theme primary variant
                              categoryColor: cs.primary,
                              subtitleStyle: subtitleStyle,
                            ),

                            const SizedBox(height: 12),

                            // ========== CROWD ALERT ==========
                            _AlertCard(
                              categoryKey: 'live_crowd_crowd_category',
                              titleKey: 'live_crowd_crowd_title',
                              descriptionKey: 'live_crowd_crowd_description',
                              imagePath: 'assets/images/kashi.png',
                              categoryColor: cs.secondary,
                              subtitleStyle: subtitleStyle,
                            ),
                          ],
                        ),
                      ),
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

// =================== SCHEDULE CARD ===================

class _ScheduleAlertCard extends StatelessWidget {
  final TextStyle? subtitleStyle;

  const _ScheduleAlertCard({this.subtitleStyle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // icon circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.22),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.access_time_rounded,
              color: cs.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LanguageHelper.t('live_crowd_next_snan_label'),
                  style: subtitleStyle?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: cs.onBackground.withOpacity(0.64),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  LanguageHelper.t('live_crowd_next_snan_value'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onBackground,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =================== GENERIC ALERT CARD ===================

class _AlertCard extends StatelessWidget {
  final String categoryKey;
  final String titleKey;
  final String descriptionKey;
  final String imagePath;
  final Color categoryColor;
  final TextStyle? subtitleStyle;

  const _AlertCard({
    required this.categoryKey,
    required this.titleKey,
    required this.descriptionKey,
    required this.imagePath,
    required this.categoryColor,
    required this.subtitleStyle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;


    final gradient = buildThemeGradient(context, isPrimary: true);

    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // left text area
          Flexible(
            fit: FlexFit.tight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LanguageHelper.t(categoryKey),
                  style: subtitleStyle?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: categoryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  LanguageHelper.t(titleKey),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cs.onBackground,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  LanguageHelper.t(descriptionKey),
                  style: subtitleStyle,
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // right image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              imagePath,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}
