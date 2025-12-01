import 'dart:convert';

class Repository {
  Codec<String, String> stringToBase64Url = utf8.fuse(base64Url);

  List decodeStringToBase64(String data) {
    dynamic jsonData = stringToBase64Url.decode(data);
    return jsonDecode(jsonData) as List;
  }

  String decodeStringToBase64Single(String data) {
    dynamic jsonData = stringToBase64Url.decode(data);
    return jsonData;
  }
}