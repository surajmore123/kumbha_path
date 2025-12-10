import 'dart:convert';
import 'dart:io';
import 'package:http_parser/http_parser.dart'; 
import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/constant/api_constatnt.dart';

class Api {
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

Future<dynamic> requestPostMultipart({
  required String path,
  required File file,
  required Map<String, String> fields,
  required String contentType,      // <-- explicit content type
  String? accessToken,
}) async {
  // copy headers but remove JSON content-type
  final headers = Map<String, String>.from(_headers);
  headers.remove('Content-Type');

  if (accessToken != null && accessToken.isNotEmpty) {
    headers['Authorization'] = 'Bearer $accessToken';
  }

  Uri uri;
  if (_protocol == "https") {
    uri = Uri.https(_host, path);
  } else {
    uri = Uri.http(_host, path);
  }
  print('url (multipart) %%%%%%%%%$uri');

  final request = http.MultipartRequest('POST', uri);
  request.headers.addAll(headers);

  // add text fields
  request.fields.addAll(fields);

  // also send content_type as a field (exactly as backend expects)
  request.fields['content_type'] = contentType;

  // attach file with correct MIME type (not application/octet-stream)
  request.files.add(
    await http.MultipartFile.fromPath(
      'file',                          // change if backend expects another key
      file.path,
      contentType: MediaType.parse(contentType),
    ),
  );

  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);

  if (response.body.isNotEmpty) {
    final jsonObject = json.decode(response.body);
    print('multipart response: $jsonObject');
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

  Future<Map> requestPATCH({
    required String? path,
    Map<String, Object>? parameters,
  }) async {
    bool chk = parameters!.containsKey('access_token');
    var headersData = _headers;
    if (chk) {
      headersData['Authorization'] = 'Bearer ${parameters['access_token']}';
    }

    Uri uri;
    if (_protocol == 'https') {
      uri = Uri.https(_host, path!);
    } else {
      uri = Uri.http(_host, path!);
    }

    print('url %%%%%%%%%$uri');

    final results = await http.patch(
      uri,
      headers: headersData,
      body: jsonEncode(parameters),
    );

    print("Status: ${results.statusCode}");
    print("Body: ${results.body}");

    if (results.body.isNotEmpty) {
      final jsonObject = jsonDecode(results.body);
      return jsonObject;
    } else {
      return {};
    }
  }


  Future<dynamic> requestPatchImg({
  required String? path,
  required Map<String, dynamic> parameters,
}) async {
  bool hasToken = parameters.containsKey("access_token");
  String? token = parameters['access_token'];
  String imagePath = parameters['profile_image']; // 👈 your correct field

  Uri uri = (_protocol == "https")
      ? Uri.https(_host, path!)
      : Uri.http(_host, path!);

  // 👇 Change POST → PATCH
  var request = http.MultipartRequest("PATCH", uri);

  // Auth header
  if (hasToken) {
    request.headers['Authorization'] = 'Bearer $token';
  }

  // Add non-image fields
  parameters.forEach((key, value) {
    if (key != "profile_image" && key != "access_token") {
      request.fields[key] = value.toString();
    }
  });

  // Add image file in form-data
  var imageFile = File(imagePath);

  request.files.add(
    await http.MultipartFile.fromPath(
      'profile_image',        // 👈 correct field name
      imageFile.path,
      contentType: http.MediaType('image', 'jpeg'),
    ),
  );

  // Send request
  var streamedResponse = await request.send();
  var response = await http.Response.fromStream(streamedResponse);

  print("PATCH Upload Status: ${response.statusCode}");
  print("PATCH Upload Body: ${response.body}");

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    return {"status": false, "message": "Failed", "code": response.statusCode};
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
