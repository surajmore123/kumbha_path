// import 'dart:convert';

// import 'package:http/http.dart' as http;
// import 'package:kumbha_path/src/constant/api_constatnt.dart';

// class WebhookApi {
//   final _webhookHost = Constants.webhook;
//   final _protocol = Constants.protocol;

//   Future<dynamic> requestPost({
//   required String? path,
//   dynamic parameters,
// }) async {
//   var headerData = _headers;

//   print('final headers $headerData');

//   dynamic res = jsonEncode(parameters);

//   Uri uri;
//   if (_protocol == "https") {
//     uri = Uri.https(_webhookHost, path!);
//   } else {
//     uri = Uri.http(_webhookHost, path!);
//   }

//   print('url %%%%%%%%%$uri');

//   final result = await http.post(uri, headers: headerData, body: res);

//   if (result.body.isNotEmpty) {
//     final jsonObject = json.decode(result.body);
//     return jsonObject;
//   } else {
//     return {};
//   }
// }




//   Map<String, String> get _headers => {
//     'Accept': 'application/json, text/plain',
//     "Content-Type": "application/json",
//   };
// }