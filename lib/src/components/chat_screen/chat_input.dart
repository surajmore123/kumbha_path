import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_bloc.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_event.dart';
import 'package:kumbha_path/src/components/buttons/app_icon_button.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Message composer: text, a photo (camera or gallery) and a voice note,
/// the three inputs the chat API accepts. Each is sent as the existing
/// `ChatBotEvent.text / .image / .audio`.
class ChatInputBar extends StatefulWidget {
  final VoidCallback? onMessageSent;

  /// While true (a reply is pending) nothing can be sent, so a message
  /// can't be submitted twice.
  final bool isSending;

  /// Receives each outgoing event. Defaults to adding it to the nearest
  /// [WebhookBloc], as before.
  final ValueChanged<ChatBotEvent>? onSubmit;

  const ChatInputBar({
    super.key,
    this.onMessageSent,
    this.isSending = false,
    this.onSubmit,
  });

  @override
  State<ChatInputBar> createState() => ChatInputBarState();
}

class ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;

  /// Created on first use so opening the chat touches no audio plugin.
  AudioRecorder? _recorder;
  bool _isRecording = false;
  String? _recordedAudioPath;

  bool get _hasText => _controller.text.trim().isNotEmpty;
  bool get _canSend =>
      !widget.isSending &&
      !_isRecording &&
      (_hasText || _selectedImage != null);

  @override
  void dispose() {
    _controller.dispose();
    _recorder?.dispose();
    super.dispose();
  }

  void _submit(ChatBotEvent event) {
    final handler = widget.onSubmit;
    if (handler != null) {
      handler(event);
    } else {
      context.read<WebhookBloc>().add(event);
    }
    widget.onMessageSent?.call();
  }

  void _snack(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------- TEXT / IMAGE ----------------

  void _onPressSend() {
    if (!_canSend) return;
    final image = _selectedImage;
    if (image != null) {
      _submit(ChatBotEvent.image(file: File(image.path)));
      setState(() => _selectedImage = null);
      return;
    }
    final text = _controller.text.trim();
    _submit(ChatBotEvent.text(message: text));
    _controller.clear();
    setState(() {});
  }

  Future<void> _showImageOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: Text('ai_camera'.tr()),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text('ai_gallery'.tr()),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickImage(ImageSource.gallery);
                  },
                ),
                AppSpacing.gapSm,
              ],
            ),
          ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(source: source);
      if (image != null && mounted) setState(() => _selectedImage = image);
    } catch (_) {
      if (mounted) _snack('ai_image_failed'.tr());
    }
  }

  // ---------------- AUDIO ----------------

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecordingAndSend();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      final recorder = _recorder ??= AudioRecorder();
      if (!await recorder.hasPermission()) {
        if (mounted) _snack('ai_mic_denied'.tr());
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      // Same recording settings as before.
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 16000,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordedAudioPath = path;
      });
    } catch (_) {
      if (mounted) _snack('ai_record_failed'.tr());
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      final stoppedPath = await _recorder?.stop();
      if (!mounted) return;
      setState(() => _isRecording = false);
      final path = stoppedPath ?? _recordedAudioPath;
      _recordedAudioPath = null;
      if (path == null) return;
      _submit(ChatBotEvent.audio(file: File(path)));
    } catch (_) {
      if (mounted) {
        setState(() => _isRecording = false);
        _snack('ai_record_failed'.tr());
      }
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final semantic = context.semanticColors;
    final busy = widget.isSending;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedImage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.mdAll,
                    child: Image.file(
                      File(_selectedImage!.path),
                      height: 140,
                      fit: BoxFit.cover,
                      cacheHeight:
                          (140 * MediaQuery.devicePixelRatioOf(context))
                              .round(),
                      errorBuilder:
                          (_, __, ___) => Container(
                            width: 140,
                            height: 140,
                            color: colors.surfaceContainerHigh,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: AppIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'ai_remove_image'.tr(),
                      variant: AppIconButtonVariant.tonal,
                      onPressed: () => setState(() => _selectedImage = null),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_isRecording)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(
                    Icons.fiber_manual_record,
                    size: 14,
                    color: colors.error,
                  ),
                  AppSpacing.gapSm,
                  Expanded(
                    child: Text(
                      'ai_recording'.tr(),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: semantic.inputFill,
            borderRadius: AppRadius.xlAll,
            border: Border.all(color: semantic.border),
          ),
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppIconButton(
                icon: Icons.add_photo_alternate_outlined,
                tooltip: 'ai_attach'.tr(),
                onPressed: busy || _isRecording ? null : _showImageOptions,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: TextField(
                    controller: _controller,
                    enabled: !_isRecording,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    style: context.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'ai_input_hint'.tr(),
                      semanticCounterText: '',
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.sm,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _onPressSend(),
                  ),
                ),
              ),
              if (!_hasText && _selectedImage == null)
                AppIconButton(
                  icon:
                      _isRecording
                          ? Icons.stop_rounded
                          : Icons.mic_none_rounded,
                  tooltip:
                      _isRecording ? 'ai_stop_record'.tr() : 'ai_record'.tr(),
                  variant:
                      _isRecording
                          ? AppIconButtonVariant.filled
                          : AppIconButtonVariant.standard,
                  onPressed: busy ? null : _toggleRecording,
                )
              else
                _SendButton(
                  busy: busy,
                  onPressed: _canSend ? _onPressSend : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox.square(
        dimension: AppSpacing.minTouchTarget,
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return AppIconButton(
      icon: Icons.arrow_upward_rounded,
      tooltip: 'ai_send'.tr(),
      variant: AppIconButtonVariant.filled,
      onPressed: onPressed,
    );
  }
}
