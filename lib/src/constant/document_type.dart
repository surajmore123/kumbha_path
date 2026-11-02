import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';

/// Document extensions the chat accepts (the server checks the contents).
const List<String> kChatDocumentExtensions = ['pdf', 'docx', 'txt', 'csv', 'xlsx'];

String detectMimeType(File file, ChatPayloadType type) {
  final ext = p.extension(file.path).toLowerCase();

  if (type == ChatPayloadType.image) {
    if (ext == '.png') return 'image/png';
    if (ext == '.jpg' || ext == '.jpeg') return 'image/jpeg';
    if (ext == '.webp') return 'image/webp';
    // default
    return 'image/jpeg';
  } else if (type == ChatPayloadType.document) {
    return switch (ext) {
      '.pdf' => 'application/pdf',
      '.docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.csv' => 'text/csv',
      '.txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
  } else {
    // audio
    if (ext == '.mp3') return 'audio/mpeg';
    if (ext == '.m4a') return 'audio/mp4';
    if (ext == '.wav') return 'audio/wav';
    // default
    return 'audio/mpeg';
  }
}
