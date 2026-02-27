import 'package:firebase_messaging/firebase_messaging.dart';


import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FcmService {
  static final _storage = FlutterSecureStorage();
  static String? _cachedToken;

  static Future<void> init() async {
    _cachedToken = await FirebaseMessaging.instance.getToken();

    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      await _storage.write(key: 'fcm_token', value: _cachedToken);
      print("🔥 FCM Token cached & saved: $_cachedToken");
    }
  }

  static Future<String?> getToken() async {
    return _cachedToken ??
        await _storage.read(key: 'fcm_token');
  }
}
