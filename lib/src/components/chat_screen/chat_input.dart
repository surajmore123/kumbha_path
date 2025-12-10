import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_bloc.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_event.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

// import your bloc + events here
// import 'your_bloc_file.dart';

class ChatInputBar extends StatefulWidget {
  final VoidCallback? onMessageSent;
  const ChatInputBar({super.key, this.onMessageSent});

  @override
  State<ChatInputBar> createState() => ChatInputBarState();
}

class ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;

  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isRecording = false;
  String? _recordedAudioPath;

  late final AnimationController _micAnimController;
  late final Animation<double> _micScaleAnimation;

  @override
  void initState() {
    super.initState();

    _micAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _micScaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _micAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _micAnimController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // ---------------- TEXT ----------------

  void _sendText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // your existing event
    context.read<WebhookBloc>().add(ChatBotEvent.text(message: text));

    _controller.clear();
    setState(() {});
    widget.onMessageSent?.call();
  }

  // ---------------- IMAGE ----------------

  Future<void> _showImageOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Capture Image'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _sendImage() {
    if (_selectedImage == null) return;

    final file = File(_selectedImage!.path);
    debugPrint('Sending image: ${file.path}');
    context.read<WebhookBloc>().add(ChatBotEvent.image(file: file));

    setState(() {
      _selectedImage = null;
    });
    widget.onMessageSent?.call();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecordingAndSend();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        debugPrint('No mic permission');
        return;
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 16000,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordedAudioPath = path;
      });

      // ✅ start the pulsing animation
      _micAnimController.repeat(reverse: true);
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      final stoppedPath = await _audioRecorder.stop();

      // ✅ stop and reset animation
      _micAnimController.stop();
      _micAnimController.reset();

      setState(() {
        _isRecording = false;
      });

      final path = stoppedPath ?? _recordedAudioPath;
      if (path == null) return;

      _sendAudio(path);
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  void _sendAudio(String path) {
    final file = File(path);

    // TODO: Replace with your actual event for sending audio
    // context.read<WebhookBloc>().add(SendAudioEvent(audioFile: file));
    debugPrint('Sending audio: ${file.path}');
    context.read<WebhookBloc>().add(ChatBotEvent.audio(file: file));

    _recordedAudioPath = null;
    widget.onMessageSent?.call();
  }

  void _onPressSend() {
    if (_selectedImage != null) {
      _sendImage();
      return;
    }

    _sendText();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedImage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 220, // adjust as you like
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // image preview
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_selectedImage!.path),
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // close icon (only one option like your first screenshot)
                Positioned(
                  top: 8,
                  left: 8,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _selectedImage = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // if (_selectedImage != null)
        //   Container(
        //     margin: const EdgeInsets.only(bottom: 4),
        //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        //     decoration: BoxDecoration(
        //       color: const Color(0xFFF2F4F7),
        //       borderRadius: BorderRadius.circular(12),
        //     ),
        //     child: Row(
        //       mainAxisSize: MainAxisSize.min,
        //       children: [
        //         const Icon(Icons.image, size: 16),
        //         const SizedBox(width: 6),
        //         const Text('Image selected', style: TextStyle(fontSize: 12)),
        //         const SizedBox(width: 8),
        //         GestureDetector(
        //           onTap: () {
        //             setState(() {
        //               _selectedImage = null;
        //             });
        //           },
        //           child: const Icon(Icons.close, size: 16),
        //         ),
        //       ],
        //     ),
        //   ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: _showImageOptions,
                child: const Icon(
                  Icons.add_circle_outline,
                  size: 26,
                  color: Color(0xFF6C6C6C),
                ),
              ),
              const SizedBox(width: 10),

              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Ask a question or share your thoughts.',
                    hintStyle: TextStyle(
                      color: Color(0xFFB0B5C0),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                  ),
                  minLines: 1,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _onPressSend(),
                ),
              ),

              const SizedBox(width: 10),

              // MIC with animation only when recording
              GestureDetector(
                onTap: _toggleRecording,
                child: ScaleTransition(
                  scale:
                      _isRecording
                          ? _micScaleAnimation
                          : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          _isRecording
                              ? const Color(0xFFFF4D4D).withOpacity(0.15)
                              : Colors.transparent,
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic_none,
                      size: 22,
                      color:
                          _isRecording
                              ? const Color(0xFFFF4D4D)
                              : const Color(0xFF6C6C6C),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              GestureDetector(
                onTap: _onPressSend,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        (hasText || _selectedImage != null)
                            ? const Color(0xFFFFC72C)
                            : const Color(0xFFFFC72C).withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send,
                    size: 18,
                    color: Color(0xFF6C4A00),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
