import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';
import 'package:kumbha_path/src/models/chat_reply.dart';

export 'package:kumbha_path/src/models/chat_reply.dart';

class ChatMessage {
  final String? text; // for text messages (or a media caption)
  final bool isGuru;
  final ChatPayloadType type; // text / image / audio / document
  final String? mediaPath; // local file path or remote URL for media

  /// Document file name, shown on document messages.
  final String? fileName;

  /// What the user said in a voice message, once the server has heard it.
  final String? transcript;

  /// Assistant extras from the reply metadata: temple, event and crowd
  /// cards, sources.
  final ChatReplyData reply;

  ChatMessage({
    this.text,
    required this.isGuru,
    required this.type,
    this.mediaPath,
    this.fileName,
    this.transcript,
    this.reply = ChatReplyData.empty,
  });

  factory ChatMessage.text({
    required String text,
    required bool isGuru,
    ChatReplyData reply = ChatReplyData.empty,
  }) {
    return ChatMessage(
      text: text,
      isGuru: isGuru,
      type: ChatPayloadType.text,
      reply: reply,
    );
  }

  factory ChatMessage.image({
    required String path,
    required bool isGuru,
    String? caption,
  }) {
    return ChatMessage(
      isGuru: isGuru,
      type: ChatPayloadType.image,
      mediaPath: path,
      text: caption,
    );
  }

  factory ChatMessage.audio({
    required String path,
    required bool isGuru,
    String? transcript,
  }) {
    return ChatMessage(
      isGuru: isGuru,
      type: ChatPayloadType.audio,
      mediaPath: path,
      transcript: transcript,
    );
  }

  factory ChatMessage.document({
    required String path,
    required String fileName,
    required bool isGuru,
    String? caption,
  }) {
    return ChatMessage(
      isGuru: isGuru,
      type: ChatPayloadType.document,
      mediaPath: path,
      fileName: fileName,
      text: caption,
    );
  }

  ChatMessage withTranscript(String? value) => ChatMessage(
    text: text,
    isGuru: isGuru,
    type: type,
    mediaPath: mediaPath,
    fileName: fileName,
    transcript: value,
    reply: reply,
  );

  /// Transcript text from a user message's metadata, if any.
  static String? transcriptFromMetadata(Map<String, dynamic>? metadata) {
    final transcript = metadata?['transcript'];
    if (transcript is Map && transcript['text'] is String) {
      final text = (transcript['text'] as String).trim();
      return text.isEmpty ? null : text;
    }
    return null;
  }
}
