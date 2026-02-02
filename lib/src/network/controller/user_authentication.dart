import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserAuthentication extends ChangeNotifier {
  final storage = const FlutterSecureStorage();

  bool isLogin = false;
  checkLogin() async {
    final token = await storage.read(key: 'access_token');
    isLogin = (token == null) ? false : true;
    notifyListeners();
    return isLogin;
  }

  bool get loggedIn => isLogin;

    // ---------------- FCM ----------------

  Future<void> saveFcmToken(String token) async {
    await storage.write(key: 'fcm_token', value: token);
  }

  Future<String?> getFcmToken() async {
    return await storage.read(key: 'fcm_token');
  }

  Future<void> clearFcmToken() async {
    await storage.delete(key: 'fcm_token');
  }
}
