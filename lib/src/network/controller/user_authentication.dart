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
}
