import 'dart:io';

import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';
import 'package:kumbha_path/src/network/api/user_chat_api.dart';

class AppRepository extends UserChatApi {
  final UserChatApi userChatApi = UserChatApi();

  Future<dynamic> chatBot(jsonData) async {
    return userChatApi.chatBot(jsonData);
  }

  Future<dynamic> chatBotMedia({
    required String accessToken,
    required File file,
    required ChatPayloadType type,
  }) async {
    return userChatApi.chatBotMedia(
      accessToken: accessToken,
      file: file,
      type: type,
    );
  }

  //chatHistory

  Future<dynamic> chatHistory(jsonData) async {
    return userChatApi.chatHistory(jsonData);
  }
}
