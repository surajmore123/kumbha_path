import 'dart:io';

import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';
import 'package:kumbha_path/src/network/api/user_chat_api.dart';

class AppRepository extends UserChatApi {
  final UserChatApi userChatApi = UserChatApi();

  @override
  Future<dynamic> chatBot(jsonData) async {
    return userChatApi.chatBot(jsonData);
  }

  @override
  Future<dynamic> chatBotMedia({
    required String accessToken,
    required File file,
    required ChatPayloadType type,
    Map<String, String> fields = const {},
  }) async {
    return userChatApi.chatBotMedia(
      accessToken: accessToken,
      file: file,
      type: type,
      fields: fields,
    );
  }


  @override
  Future<dynamic> chatHistory(jsonData) async {
    return userChatApi.chatHistory(jsonData);
  }
}
