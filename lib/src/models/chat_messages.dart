import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';

class ChatMessage {
  final String? text;              // for text messages
  final bool isGuru;
  final ChatPayloadType type;      // text / image / audio
  final String? mediaPath;         // local file path or remote URL for media

  ChatMessage({
    this.text,
    required this.isGuru,
    required this.type,
    this.mediaPath,
  });

  factory ChatMessage.text({
    required String text,
    required bool isGuru,
  }) {
    return ChatMessage(
      text: text,
      isGuru: isGuru,
      type: ChatPayloadType.text,
    );
  }

  factory ChatMessage.image({
    required String path,
    required bool isGuru,
  }) {
    return ChatMessage(
      isGuru: isGuru,
      type: ChatPayloadType.image,
      mediaPath: path,
    );
  }

  factory ChatMessage.audio({
    required String path,
    required bool isGuru,
  }) {
    return ChatMessage(
      isGuru: isGuru,
      type: ChatPayloadType.audio,
      mediaPath: path,
    );
  }
}
