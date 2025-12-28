import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/constant/app_color.dart';
import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';


// class NewJournalEntryScreen extends StatefulWidget {
//   const NewJournalEntryScreen({super.key});

//   @override
//   State<NewJournalEntryScreen> createState() => _NewJournalEntryScreenState();
// }

// class _NewJournalEntryScreenState extends State<NewJournalEntryScreen> {
//   final _titleController = TextEditingController();
//   final _notesController = TextEditingController();

//   int _selectedMoodIndex = 0; // 0..4

//   @override
//   void dispose() {
//     _titleController.dispose();
//     _notesController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isMobile = context.isMobile;
//     final isTablet = context.isTablet;
//     final isDesktop = context.isDesktop;

//     return MainLayout(
//       showDefaultBottom: false,
//       ctx: 3,
//       appBar: AppBar(
//         backgroundColor: const Color(0xFFFFF7E9),
//         elevation: 0,
//         centerTitle: true,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.black87),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Text(
//           LanguageHelper.t('journal_new_entry_title'),
//           style: const TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.w700,
//             color: Color(0xFF111827),
//           ),
//         ),
//       ),
//       body: ValueListenableBuilder<String>(
//         valueListenable: LanguageHelper.currentLang,
//         builder: (context, lang, _) {
//           final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
//                 fontSize: isMobile ? 14 : 15,
//                 fontWeight: FontWeight.w600,
//                 color: const Color(0xFF111827),
//               );

//           final hintStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
//                 fontSize: isMobile ? 13.5 : 14,
//                 color: const Color(0xFFB08959),
//               );

//           return Container(
//             color: const Color(0xFFFFF7E9),
//             child: SingleChildScrollView(
//               padding: EdgeInsets.symmetric(
//                 horizontal: isMobile
//                     ? 16
//                     : isTablet
//                         ? 32
//                         : 56,
//                 vertical: isMobile ? 16 : 24,
//               ),
//               child: ConstrainedBox(
//                 constraints:
//                     BoxConstraints(maxWidth: isDesktop ? 520 : 480),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // ===== TITLE FIELD =====
//                     Text(LanguageHelper.t('journal_field_title'),
//                         style: labelStyle),
//                     const SizedBox(height: 8),
//                     TextField(
//                       controller: _titleController,
//                       decoration: InputDecoration(
//                         hintText: LanguageHelper
//                             .t('journal_field_title_hint'),
//                         hintStyle: hintStyle,
//                         filled: true,
//                         fillColor: Colors.white,
//                         contentPadding: const EdgeInsets.symmetric(
//                           horizontal: 16,
//                           vertical: 12,
//                         ),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(28),
//                           borderSide: BorderSide.none,
//                         ),
//                       ),
//                     ),

//                     const SizedBox(height: 18),

//                     // ===== ADD PHOTO CARD =====
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 16, vertical: 20),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(24),
//                         border: Border.all(
//                           color: const Color(0xFFF0D9B3),
//                           width: 1.2,
//                         ),
//                       ),
//                       child: Column(
//                         children: [
//                           Text(
//                             LanguageHelper.t('journal_add_photo_title'),
//                             style: Theme.of(context)
//                                 .textTheme
//                                 .titleMedium
//                                 ?.copyWith(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.w700,
//                                   color: const Color(0xFF111827),
//                                 ),
//                           ),
//                           const SizedBox(height: 6),
//                           Text(
//                             LanguageHelper
//                                 .t('journal_add_photo_subtitle'),
//                             textAlign: TextAlign.center,
//                             style: Theme.of(context)
//                                 .textTheme
//                                 .bodyMedium
//                                 ?.copyWith(
//                                   fontSize: 13.5,
//                                   color: const Color(0xFF8B6B3E),
//                                 ),
//                           ),
//                           const SizedBox(height: 14),
//                           GestureDetector(
//                             onTap: () {
//                               // TODO: open image picker
//                             },
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 22,
//                                 vertical: 10,
//                               ),
//                               decoration: BoxDecoration(
//                                 borderRadius: BorderRadius.circular(24),
//                                 gradient: const LinearGradient(
//                                   colors: [
//                                     Color(0xFFFFA726),
//                                     Color(0xFFFFC107),
//                                   ],
//                                 ),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: Colors.orange.withOpacity(0.25),
//                                     blurRadius: 6,
//                                     offset: const Offset(0, 3),
//                                   ),
//                                 ],
//                               ),
//                               child: Row(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   const Icon(
//                                     Icons.upload_outlined,
//                                     size: 18,
//                                     color: Colors.white,
//                                   ),
//                                   const SizedBox(width: 6),
//                                   Text(
//                                     LanguageHelper.t(
//                                         'journal_add_photo_button'),
//                                     style: const TextStyle(
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.w700,
//                                       fontSize: 14,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),

//                     const SizedBox(height: 20),

//                     // ===== NOTES FIELD =====
//                     Text(LanguageHelper.t('journal_field_notes'),
//                         style: labelStyle),
//                     const SizedBox(height: 8),
//                     SizedBox(
//                       height: 130,
//                       child: TextField(
//                         controller: _notesController,
//                         maxLines: null,
//                         expands: true,
//                         textAlignVertical: TextAlignVertical.top,
//                         decoration: InputDecoration(
//                           hintText: LanguageHelper
//                               .t('journal_field_notes_hint'),
//                           hintStyle: hintStyle,
//                           filled: true,
//                           fillColor: Colors.white,
//                           contentPadding: const EdgeInsets.symmetric(
//                             horizontal: 16,
//                             vertical: 12,
//                           ),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(24),
//                             borderSide: BorderSide.none,
//                           ),
//                         ),
//                       ),
//                     ),

//                     const SizedBox(height: 20),

//                     // ===== HOW ARE YOU FEELING =====
//                     Text(
//                       LanguageHelper.t('journal_how_feeling'),
//                       style: labelStyle?.copyWith(
//                         fontSize: 15,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                     SizedBox(
//                       height: 70,
//                       child: Row(
//                         mainAxisAlignment:
//                             MainAxisAlignment.spaceBetween,
//                         children: List.generate(5, (index) {
//                           final emojis = ['🙏', '😊', '🤔', '😢', '✨'];
//                           final isSelected =
//                               _selectedMoodIndex == index;
//                           return GestureDetector(
//                             onTap: () {
//                               setState(() {
//                                 _selectedMoodIndex = index;
//                               });
//                             },
//                             child: AnimatedContainer(
//                               duration:
//                                   const Duration(milliseconds: 150),
//                               width: isSelected ? 64 : 56,
//                               height: isSelected ? 64 : 56,
//                               decoration: BoxDecoration(
//                                 color: isSelected
//                                     ? const Color(0xFFFFF0B8)
//                                     : Colors.white,
//                                 shape: BoxShape.circle,
//                                 border: Border.all(
//                                   color: isSelected
//                                       ? const Color(0xFFFFA726)
//                                       : const Color(0xFFE5E7EB),
//                                   width: isSelected ? 2 : 1,
//                                 ),
//                                 boxShadow: isSelected
//                                     ? [
//                                         BoxShadow(
//                                           color: Colors.orange
//                                               .withOpacity(0.25),
//                                           blurRadius: 6,
//                                           offset:
//                                               const Offset(0, 3),
//                                         ),
//                                       ]
//                                     : null,
//                               ),
//                               child: Center(
//                                 child: Text(
//                                   emojis[index],
//                                   style: const TextStyle(
//                                     fontSize: 26,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           );
//                         }),
//                       ),
//                     ),

//                     const SizedBox(height: 20),

//                     // ===== AI REFLECTION BUTTON =====
//                     GestureDetector(
//                       onTap: () {
//                         // TODO: AI reflection based on entry
//                       },
//                       child: Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.symmetric(
//                           vertical: 12,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Colors.transparent,
//                           borderRadius: BorderRadius.circular(28),
//                           border: Border.all(
//                             color: const Color(0xFFFFB54C),
//                             width: 1.4,
//                           ),
//                         ),
//                         child: Center(
//                           child: Text(
//                             LanguageHelper
//                                 .t('journal_btn_ai_reflection'),
//                             style: const TextStyle(
//                               fontSize: 14.5,
//                               fontWeight: FontWeight.w600,
//                               color: Color(0xFFB45309),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),

//                     const SizedBox(height: 12),

//                     // ===== SAVE ENTRY BUTTON =====
//                     GestureDetector(
//                       onTap: () {
//                         // TODO: save logic
//                       },
//                       child: Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.symmetric(
//                           vertical: 14,
//                         ),
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(28),
//                           gradient: const LinearGradient(
//                             colors: [
//                               Color(0xFFFFA726),
//                               Color(0xFFFFC107),
//                             ],
//                           ),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.orange.withOpacity(0.3),
//                               blurRadius: 8,
//                               offset: const Offset(0, 3),
//                             ),
//                           ],
//                         ),
//                         child: Center(
//                           child: Text(
//                             LanguageHelper.t('journal_btn_save_entry'),
//                             style: const TextStyle(
//                               fontSize: 15,
//                               fontWeight: FontWeight.w700,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),

//                     const SizedBox(height: 20),
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



class NewJournalEntryScreen extends StatefulWidget {
  const NewJournalEntryScreen({super.key});

  @override
  State<NewJournalEntryScreen> createState() => _NewJournalEntryScreenState();
}

class _NewJournalEntryScreenState extends State<NewJournalEntryScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  int _selectedMoodIndex = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
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
      ctx: 3,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? cs.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          LanguageHelper.t('journal_new_entry_title'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ),

      body: ValueListenableBuilder<String>(
        valueListenable: LanguageHelper.currentLang,
        builder: (context, lang, _) {
          final labelStyle = theme.textTheme.bodyMedium?.copyWith(
            fontSize: isMobile ? 14 : 15,
            fontWeight: FontWeight.w600,
            color: cs.onBackground,
          );

          final hintStyle = theme.textTheme.bodyMedium?.copyWith(
            fontSize: isMobile ? 13.5 : 14,
            color: cs.onBackground.withOpacity(0.5),
          );

          // shared primary gradient (light => orange, dark => cs.primary -> cs.primaryContainer)
          final primaryGradient = buildThemeGradient(context, isPrimary: true);

          return Container(
            color: theme.scaffoldBackgroundColor,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : isTablet ? 32 : 56,
                vertical: isMobile ? 16 : 24,
              ),

              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: isDesktop ? 520 : 480),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ---------------- TITLE ----------------
                    Text(LanguageHelper.t('journal_field_title'), style: labelStyle),
                    const SizedBox(height: 8),

                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: LanguageHelper.t('journal_field_title_hint'),
                        hintStyle: hintStyle,
                        filled: true,
                        fillColor: cs.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide(color: cs.outline.withOpacity(0.2)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ---------------- ADD PHOTO ----------------
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cs.outline.withOpacity(0.25)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            LanguageHelper.t('journal_add_photo_title'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: cs.onBackground,
                            ),
                          ),
                          const SizedBox(height: 6),

                          Text(
                            LanguageHelper.t('journal_add_photo_subtitle'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13.5,
                              color: cs.onBackground.withOpacity(0.65),
                            ),
                          ),
                          const SizedBox(height: 14),

                          GestureDetector(
                            onTap: () {
                              // TODO: open image picker
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: primaryGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.primary.withOpacity(0.30),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.upload_outlined, size: 18, color: cs.onPrimary),
                                  const SizedBox(width: 6),
                                  Text(
                                    LanguageHelper.t('journal_add_photo_button'),
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ---------------- NOTES ----------------
                    Text(LanguageHelper.t('journal_field_notes'), style: labelStyle),
                    const SizedBox(height: 8),

                    SizedBox(
                      height: 130,
                      child: TextField(
                        controller: _notesController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: LanguageHelper.t('journal_field_notes_hint'),
                          hintStyle: hintStyle,
                          filled: true,
                          fillColor: cs.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: cs.outline.withOpacity(0.2)),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ---------------- FEELING EMOJIS ----------------
                    Text(
                      LanguageHelper.t('journal_how_feeling'),
                      style: labelStyle?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      height: 70,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(5, (index) {
                          final emojis = ['🙏', '😊', '🤔', '😢', '✨'];
                          final isSelected = _selectedMoodIndex == index;

                          return GestureDetector(
                            onTap: () => setState(() => _selectedMoodIndex = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: isSelected ? 64 : 56,
                              height: isSelected ? 64 : 56,
                              decoration: BoxDecoration(
                                color: isSelected ? cs.surfaceVariant : cs.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? cs.primary : cs.outline.withOpacity(0.3),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: cs.primary.withOpacity(0.25),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  emojis[index],
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ---------------- AI REFLECTION BUTTON ----------------
                    GestureDetector(
                      onTap: () {
                        // TODO: AI reflection
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          // apply primary gradient to this button as well so it matches other primary surfaces
                          gradient: primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withOpacity(0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            LanguageHelper.t('journal_btn_ai_reflection'),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: cs.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ---------------- SAVE ENTRY BUTTON ----------------
                    GestureDetector(
                      onTap: () {
                        // TODO: save logic
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            LanguageHelper.t('journal_btn_save_entry'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
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

