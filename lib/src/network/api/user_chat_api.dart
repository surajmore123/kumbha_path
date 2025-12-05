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
