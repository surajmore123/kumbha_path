import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/journel/widgets/journal_widgets.dart';

/// New MyKumbh journal entry.
///
/// Sends the existing `CreateJournalEntryEvent` with the same field
/// mapping as before: "Your thoughts" → `notes`, the notes box (pre-filled
/// with an AI reflection when coming from Daily Reflection) →
/// `aiReflection`, the prompt passed in → `aiPrompt`, the selected mood →
/// `mood` (Peaceful by default), and the optional photo (quality 25).
class NewJournalEntryScreen extends StatefulWidget {
  final String? aiReflection;
  final String? aiPrompt;

  /// Picks a photo; defaults to image_picker. Injected in tests.
  final Future<XFile?> Function(ImageSource source)? pickImage;

  const NewJournalEntryScreen({
    super.key,
    this.aiReflection,
    this.aiPrompt,
    this.pickImage,
  });

  @override
  State<NewJournalEntryScreen> createState() => _NewJournalEntryScreenState();
}

class _NewJournalEntryScreenState extends State<NewJournalEntryScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _yourThought = TextEditingController();
  XFile? profileImage;
  int _selectedMoodIndex = 0;

  bool _saving = false;
  bool _saved = false;
  String? _validation;
  Timer? _timeout;

  /// Photo upload can be slow; after this the user can try again.
  static const Duration _saveTimeout = Duration(seconds: 60);
  static const double _maxWidth = 720;

  String? get _prompt {
    final p = (widget.aiPrompt ?? '').trim();
    return p.isEmpty ? null : p;
  }

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.aiReflection ?? '';
    for (final c in [_titleController, _notesController, _yourThought]) {
      c.addListener(_onEdited);
    }
  }

  bool _wasDirty = false;

  /// Rebuild only when it matters: clearing the validation message, or the
  /// form switching between pristine and edited (for the discard warning).
  void _onEdited() {
    final dirty = _isDirty;
    if (_validation != null || dirty != _wasDirty) {
      setState(() {
        _validation = null;
        _wasDirty = dirty;
      });
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _titleController.dispose();
    _notesController.dispose();
    _yourThought.dispose();
    super.dispose();
  }

  bool get _isDirty =>
      _titleController.text.trim().isNotEmpty ||
      _yourThought.text.trim().isNotEmpty ||
      _notesController.text.trim() != (widget.aiReflection ?? '').trim() ||
      profileImage != null ||
      _selectedMoodIndex != 0;

  bool get _hasContent =>
      _titleController.text.trim().isNotEmpty ||
      _yourThought.text.trim().isNotEmpty ||
      _notesController.text.trim().isNotEmpty ||
      profileImage != null;

  // ---------------- photo ----------------

  Future<XFile?> _pick(ImageSource source) => (widget.pickImage ??
      (s) => ImagePicker().pickImage(source: s, imageQuality: 25))(source);

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder:
          (sheet) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: Text('ai_camera'.tr()),
                  onTap: () => Navigator.pop(sheet, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text('ai_gallery'.tr()),
                  onTap: () => Navigator.pop(sheet, ImageSource.gallery),
                ),
                AppSpacing.gapSm,
              ],
            ),
          ),
    );
    if (source == null) return;
    try {
      final picked = await _pick(source);
      if (picked != null && mounted) {
        setState(() {
          profileImage = picked;
          _validation = null;
        });
      }
    } catch (_) {
      if (mounted) _snack('ai_image_failed'.tr());
    }
  }

  // ---------------- save ----------------

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? context.colorScheme.error : null,
        ),
      );
  }

  void _save() {
    if (_saving) return; // no duplicate submissions
    FocusScope.of(context).unfocus();
    if (!_hasContent) {
      setState(() => _validation = 'journal_empty_entry'.tr());
      return;
    }
    setState(() => _saving = true);
    _timeout?.cancel();
    _timeout = Timer(_saveTimeout, () {
      if (!mounted || !_saving) return;
      setState(() => _saving = false);
      _snack('auth_network_error'.tr(), error: true);
    });
    context.read<AppDetailsBloc>().add(
      CreateJournalEntryEvent(
        title: _titleController.text.trim(),
        notes: _yourThought.text.trim(),
        aiPrompt: widget.aiPrompt.toString(),
        aiReflection: _notesController.text.trim(),
        mood: JournalMood.all[_selectedMoodIndex].value,
        imagePath: profileImage?.path,
      ),
    );
  }

  void _onState(BuildContext context, AppDetailsState state) {
    if (!_saving) return;
    if (state.status == AppDetailsStatus.journalEntryCreated) {
      _timeout?.cancel();
      setState(() {
        _saving = false;
        _saved = true;
      });
      _snack('journal_create_success'.tr());
      // Refresh the list, then return to the journal already open below
      // (instead of stacking another journal screen on top).
      context.read<AppDetailsBloc>().add(GetJournalEntry(page: 1));
      final navigator = Navigator.of(context);
      if (AppNavigation.observer.navigator == navigator &&
          AppNavigation.observer.contains('/journal')) {
        navigator.popUntil((r) => r.settings.name == '/journal' || r.isFirst);
      } else if (navigator.canPop()) {
        navigator.pop();
      } else {
        navigator.pushReplacementNamed('/journal');
      }
    } else if (state.status == AppDetailsStatus.journalEntryError) {
      _timeout?.cancel();
      setState(() => _saving = false);
      _snack('journal_create_failed'.tr(), error: true);
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder:
          (dialog) => AlertDialog(
            title: Text('journal_discard_title'.tr()),
            content: Text('journal_discard_body'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text('journal_keep_editing'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text('journal_discard'.tr()),
              ),
            ],
          ),
    );
    return discard ?? false;
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colorScheme;

    return PopScope(
      // Ask before throwing away what was written.
      canPop: _saved || !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _saved = true); // allow the pop
          Navigator.pop(context);
        }
      },
      child: MainLayout(
        showDefaultBottom: false,
        ctx: 3,
        appBar: AppAppBar(title: 'journal_new_entry_title'.tr()),
        body: BlocListener<AppDetailsBloc, AppDetailsState>(
          listener: _onState,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side =
                  constraints.maxWidth > _maxWidth + AppSpacing.pageGutter * 2
                      ? (constraints.maxWidth - _maxWidth) / 2
                      : AppSpacing.pageGutter;
              return ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  side,
                  AppSpacing.md,
                  side,
                  AppSpacing.huge,
                ),
                children: [
                  if (_prompt != null) ...[
                    AiContentCard(
                      heading: 'journal_prompt_from_ai'.tr(),
                      child: Text(
                        _prompt!,
                        style: text.bodyLarge?.copyWith(height: 1.5),
                      ),
                    ),
                    AppSpacing.gapXl,
                  ],
                  AppTextField(
                    controller: _titleController,
                    label: 'journal_field_title'.tr(),
                    hint: 'journal_field_title_hint'.tr(),
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    enabled: !_saving,
                  ),
                  AppSpacing.gapXl,
                  AppTextField(
                    controller: _yourThought,
                    label: 'journal_your_thoughts'.tr(),
                    hint: 'journal_answer_hint'.tr(),
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 6,
                    maxLines: null,
                    enabled: !_saving,
                  ),
                  AppSpacing.gapXl,
                  AppTextField(
                    controller: _notesController,
                    label: 'journal_field_notes'.tr(),
                    hint: 'journal_field_notes_hint'.tr(),
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 3,
                    maxLines: null,
                    enabled: !_saving,
                  ),
                  AppSpacing.gapXl,
                  _PhotoField(
                    image: profileImage,
                    enabled: !_saving,
                    onChoose: _choosePhoto,
                    onRemove: () => setState(() => profileImage = null),
                  ),
                  AppSpacing.gapXl,
                  Text('journal_how_feeling'.tr(), style: text.titleSmall),
                  AppSpacing.gapSm,
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (var i = 0; i < JournalMood.all.length; i++)
                        ChoiceChip(
                          avatar: Text(JournalMood.all[i].emoji),
                          label: Text(JournalMood.all[i].label),
                          selected: _selectedMoodIndex == i,
                          onSelected:
                              _saving
                                  ? null
                                  : (_) =>
                                      setState(() => _selectedMoodIndex = i),
                        ),
                    ],
                  ),
                  if (_validation != null) ...[
                    AppSpacing.gapLg,
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _validation!,
                        style: text.bodyMedium?.copyWith(color: colors.error),
                      ),
                    ),
                  ],
                  AppSpacing.gapXl,
                  AppButton(
                    label: 'journal_btn_save_entry'.tr(),
                    leadingIcon: Icons.check_rounded,
                    isLoading: _saving,
                    onPressed: _save,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.image,
    required this.enabled,
    required this.onChoose,
    required this.onRemove,
  });

  final XFile? image;
  final bool enabled;
  final VoidCallback onChoose;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final img = image;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('journal_add_photo_title'.tr(), style: text.titleSmall),
          AppSpacing.gapXs,
          Text('journal_add_photo_subtitle'.tr(), style: text.bodySmall),
          AppSpacing.gapMd,
          if (img != null) ...[
            Stack(
              children: [
                JournalPhoto(
                  source: img.path,
                  height: 180,
                  width: double.infinity,
                ),
                PositionedDirectional(
                  top: AppSpacing.xs,
                  end: AppSpacing.xs,
                  child: AppIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'ai_remove_image'.tr(),
                    variant: AppIconButtonVariant.tonal,
                    onPressed: enabled ? onRemove : null,
                  ),
                ),
              ],
            ),
            AppSpacing.gapMd,
          ],
          AppButton.outlined(
            label:
                img == null
                    ? 'journal_add_photo_button'.tr()
                    : 'journal_photo_change'.tr(),
            leadingIcon: Icons.add_photo_alternate_outlined,
            expand: false,
            onPressed: enabled ? onChoose : null,
          ),
        ],
      ),
    );
  }
}
