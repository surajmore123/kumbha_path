import 'package:kumbha_path/src/network/api/user_chat_api.dart';

class AppRepository extends UserChatApi {
  final UserChatApi userChatApi = UserChatApi();

  Future<dynamic> chatBot(jsonData) async {
    return userChatApi.chatBot(jsonData);
  }

  //chatHistory

  Future<dynamic> chatHistory(jsonData) async {
    return userChatApi.chatHistory(jsonData);
  }
}
