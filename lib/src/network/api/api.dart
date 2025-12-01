import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/constant/api_constatnt.dart';

class Api  {
  final _host = ApiConst.host;
  final _protocol = ApiConst.protocol;
  final stringToBase64Url = utf8.fuse(base64Url);

  Future<dynamic> requestPostOtPSend({
  required String? path,
  dynamic parameters,
}) async {
  var headerData = _headers;

  print('final headers $headerData');

  dynamic res = jsonEncode(parameters);

  Uri uri;
  if (_protocol == "https") {
    uri = Uri.https(_host, path!);
  } else {
    uri = Uri.http(_host, path!);
  }

  print('url %%%%%%%%%$uri');

  final result = await http.post(uri, headers: headerData, body: res);

  if (result.body.isNotEmpty) {
    final jsonObject = json.decode(result.body);
    return jsonObject;
  } else {
    return {};
  }
}


dynamic stringToBase64(data) {
    return stringToBase64Url.decode(data);
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json, text/plain',
    "Content-Type": "application/json",
  };


}