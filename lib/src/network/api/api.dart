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

Future<dynamic> requestPost({
    required String? path,
    dynamic parameters,
  }) async {
    bool chk = parameters.containsKey("access_token");

    print('tokeeeeennnn $chk');

    var headerData = _headers;
    print('final headers $headerData');

    dynamic res = jsonEncode(parameters);
    if (chk) {
      headerData['Authorization'] = 'Bearer ${parameters['access_token']}';
    }

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

    Future<dynamic> requestGet({
    required String path,
    Map<String, Object>? parameters,
  }) async {
    bool chk = parameters!.containsKey('access_token');
    var headersData = _headers;

    if (chk) {
      headersData['Authorization'] = 'Bearer ${parameters['access_token']}';
    }
    dynamic uri;
    if (_protocol == 'https') {
      uri = Uri.https(_host, path, parameters);
    } else {
      uri = Uri.http(_host, path, parameters);
    }
    print('url %%%%%%%%%$uri');

    final result = await http.get(uri, headers: headersData);

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