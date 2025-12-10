import 'dart:io';

import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';
import 'package:kumbha_path/src/constant/document_type.dart';
import 'package:kumbha_path/src/network/api/api.dart';

class UserChatApi extends Api {
  Future<dynamic> chatBot(jsonData) async {
    try {
      final response = await requestPost(
        path: 'api/chat/chat-send/',
        parameters: jsonData,
      );
      print("chat response ai $response");
      return response;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }

  Future<dynamic> chatBotMedia({
    required String accessToken,
    required File file,
    required ChatPayloadType type,
  }) async {
    try {
      final mime = detectMimeType(file, type);

      final response = await requestPostMultipart(
        path: 'api/chat/chat-send/',
        file: file,
        contentType: mime, // <-- "image/jpeg" or "audio/mpeg" etc.
        fields: {
          // Adjust keys as your backend expects:
          'message_type': type == ChatPayloadType.image ? 'image' : 'audio',
          // if your backend also wants content_type as a field, you can add:
          // 'content_type': mime,
        },
        accessToken: accessToken,
      );
      print("chat media response ai $response");
      return response;
    } catch (e, _) {
      print(e);
      print('error media');
    }
  }

  Future<dynamic> chatHistory(Map<String, String> jsonData) async {
    try {
      final response = await requestGet(
        path: "api/chat/chat-history/",
        parameters: jsonData,
      );
      print('chat history response ai $response');
      return response;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }
}
