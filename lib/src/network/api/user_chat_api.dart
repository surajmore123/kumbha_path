import 'dart:io';

import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';
import 'package:kumbha_path/src/constant/document_type.dart';
import 'package:kumbha_path/src/network/api/api.dart';

// Chat payloads and replies are not logged: they can hold personal
// questions, photos and documents.
class UserChatApi extends Api {
  Future<dynamic> chatBot(jsonData) async {
    try {
      return await requestPost(
        path: 'api/chat/chat-send/',
        parameters: jsonData,
      );
    } catch (_) {
      return null;
    }
  }

  /// [fields] are optional form fields sent with the file, e.g. a
  /// `message` caption and the app `language`.
  Future<dynamic> chatBotMedia({
    required String accessToken,
    required File file,
    required ChatPayloadType type,
    Map<String, String> fields = const {},
  }) async {
    try {
      final mime = detectMimeType(file, type);

      return await requestPostMultipart(
        path: 'api/chat/chat-send/',
        file: file,
        contentType: mime,
        fields: {
          'message_type': switch (type) {
            ChatPayloadType.image => 'image',
            ChatPayloadType.audio => 'audio',
            _ => 'file',
          },
          ...fields,
        },
        accessToken: accessToken,
      );
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> chatHistory(Map<String, String> jsonData) async {
    try {
      return await requestGet(
        path: "api/chat/chat-history/",
        parameters: jsonData,
      );
    } catch (_) {
      return null;
    }
  }
}
