import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/constant/app_color.dart';
import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/modules/journel/journer_screen.dart';

class NewJournalEntryScreen extends StatefulWidget {
  final String? aiReflection;
  final String? aiPrompt;
  const NewJournalEntryScreen({super.key, this.aiReflection, this.aiPrompt});

  @override
  State<NewJournalEntryScreen> createState() => _NewJournalEntryScreenState();
}

class _NewJournalEntryScreenState extends State<NewJournalEntryScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _aiThought = TextEditingController();
  final _yourThought = TextEditingController();
  XFile? profileImage;
  bool isLoading = false;
  int _selectedMoodIndex = 0;
  @override
  void initState() {
    super.initState();
    _notesController.text = widget.aiReflection ?? '';
    _aiThought.text = widget.aiPrompt ?? '';
  }

  final List<Map<String, String>> moods = [
    {'emoji': '🙏', 'label': 'Peaceful', 'value': 'peaceful'},
    {'emoji': '😊', 'label': 'Joyful', 'value': 'joyful'},
    {'emoji': '✨', 'label': 'Enlightened', 'value': 'enlightened'},
    {'emoji': '🤔', 'label': 'Reflective', 'value': 'reflective'},
    {'emoji': '😢', 'label': 'Emotional', 'value': 'emotional'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _aiThought.dispose();
    super.dispose();
  }

  Future<void> takeImage(BuildContext context) async {
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.of(bc).pop();
                  final pickedFile = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 25,
                  );
                  if (pickedFile != null) {
                    setState(() {
                      profileImage = pickedFile;
                      isLoading = true;
                    });

                    await Future.delayed(const Duration(seconds: 1));
                    setState(() {
                      isLoading = false;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.of(bc).pop();
                  final pickedFile = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 25,
                  );
                  if (pickedFile != null) {
                    setState(() {
                      profileImage = pickedFile;
                      isLoading = true;
                    });

                    await Future.delayed(const Duration(seconds: 1));
                    setState(() {
                      isLoading = false;
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
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
         iconTheme: IconThemeData(color: blackColor),
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

          return BlocConsumer<AppDetailsBloc, AppDetailsState>(
            listener: (context, state) {
              if (state.status == AppDetailsStatus.journalEntryCreated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      state.message ?? 'Journal entry created successfully!',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.push(context, MaterialPageRoute(builder: (context)=>JournerScreen() ));
              } else if (state.status == AppDetailsStatus.journalEntryError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      state.message ??
                          'Failed to create journal entry. Please try again.',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
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
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 520 : 480,
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ---------------- TITLE ----------------
                        Text(
                          LanguageHelper.t('journal_field_title'),
                          style: labelStyle,
                        ),
                        const SizedBox(height: 8),

                        TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            hintText: LanguageHelper.t(
                              'journal_field_title_hint',
                            ),
                            hintStyle: hintStyle,
                            filled: true,
                            fillColor: cs.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide(
                                color: cs.outline.withOpacity(0.2),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),
                        // Icons.add_circle_outline : Icons.auto_awesome,
                        widget.aiPrompt != null
                            ? Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('AI Asked...', style: labelStyle),

                                    Row(
                                      children: [
                                        Icon(
                                          Icons.auto_awesome,
                                          color: Colors.deepOrange,
                                          size: 15,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'AI Prompt Activated',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                SizedBox(
                                  height: 80,
                                  child: TextField(
                                    controller: _aiThought,
                                    maxLines: null,
                                    expands: true,
                                    textAlignVertical: TextAlignVertical.top,
                                    decoration: InputDecoration(
                                      hintText: 'AI Thought.....',
                                      // hintText: LanguageHelper.t(
                                      //   'journal_field_notes_hint',
                                      // ),
                                      hintStyle: hintStyle,
                                      filled: true,
                                      fillColor: cs.surface,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: BorderSide(
                                          color: cs.outline.withOpacity(0.2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),
                              ],
                            )
                            : SizedBox.shrink(),

                        Text('Your Thoughts', style: labelStyle),
                        const SizedBox(height: 8),

                        SizedBox(
                          height: 80,
                          child: TextField(
                            controller: _yourThought,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: InputDecoration(
                              hintText: 'Answer.....',
                              // hintText: LanguageHelper.t(
                              //   'journal_field_notes_hint',
                              // ),
                              hintStyle: hintStyle,
                              filled: true,
                              fillColor: cs.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: cs.outline.withOpacity(0.2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ---------------- ADD PHOTO ----------------
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: cs.outline.withOpacity(0.25),
                            ),
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
                                  print('jhjdbdhb');
                                  takeImage(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 10,
                                  ),
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
                                      Icon(
                                        Icons.upload_outlined,
                                        size: 18,
                                        color: cs.onPrimary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        LanguageHelper.t(
                                          'journal_add_photo_button',
                                        ),
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

                        Text(
                          LanguageHelper.t('journal_field_notes'),
                          style: labelStyle,
                        ),
                        const SizedBox(height: 8),

                        SizedBox(
                          height: 130,
                          child: TextField(
                            controller: _notesController,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: InputDecoration(
                              hintText: LanguageHelper.t(
                                'journal_field_notes_hint',
                              ),
                              hintStyle: hintStyle,
                              filled: true,
                              fillColor: cs.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: cs.outline.withOpacity(0.2),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          LanguageHelper.t('journal_how_feeling'),
                          style: labelStyle?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),

                        SizedBox(
                          height: 70,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(5, (index) {
                              final isSelected = _selectedMoodIndex == index;
                              final mood = moods[index];

                              return GestureDetector(
                                onTap:
                                    () => setState(
                                      () => _selectedMoodIndex = index,
                                    ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: isSelected ? 64 : 56,
                                  height: isSelected ? 64 : 56,
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? cs.surfaceVariant
                                            : cs.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? cs.primary
                                              : cs.outline.withOpacity(0.3),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow:
                                        isSelected
                                            ? [
                                              BoxShadow(
                                                color: cs.primary.withOpacity(
                                                  0.25,
                                                ),
                                                blurRadius: 6,
                                                offset: const Offset(0, 3),
                                              ),
                                            ]
                                            : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      mood['emoji']!,
                                      style: const TextStyle(fontSize: 26),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),

                        // const SizedBox(height: 20),
                        SizedBox(height: 8),
                        Center(
                          child: Text(
                            moods[_selectedMoodIndex]['label']!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                          ),
                        ),

                        SizedBox(height: 8),

   
                        GestureDetector(
                          onTap: () async {
                            final bloc = context.read<AppDetailsBloc>();
                            final selectedMood =
                                moods[_selectedMoodIndex]['value'] ?? '';
                            bloc.add(
                              CreateJournalEntryEvent(
                                title: _titleController.text.trim(),
                                notes: _yourThought.text.trim(),
                                aiPrompt: widget.aiPrompt.toString(),
                                aiReflection: _notesController.text.trim(),
                                mood: selectedMood,
                                imagePath: profileImage?.path,
                              ),
                            );
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
          );
        },
      ),
    );
  }
}
