import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';

String detectMimeType(File file, ChatPayloadType type) {
  final ext = p.extension(file.path).toLowerCase();

  if (type == ChatPayloadType.image) {
    if (ext == '.png') return 'image/png';
    if (ext == '.jpg' || ext == '.jpeg') return 'image/jpeg';
    if (ext == '.webp') return 'image/webp';
    // default
    return 'image/jpeg';
  } else {
    // audio
    if (ext == '.mp3') return 'audio/mpeg';
    if (ext == '.m4a') return 'audio/mp4';
    if (ext == '.wav') return 'audio/wav';
    // default
    return 'audio/mpeg';
  }
}