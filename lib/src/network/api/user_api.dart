import 'package:kumbha_path/src/network/api/api.dart';

class UserApi extends Api {
  Future<dynamic> createUser(jsonData) async {
    try {
      final user = await requestPostOtPSend(
        path: 'api/auth/send-mobile-otp/',
        parameters: jsonData,
      );
      print('response from send mobile otp $user');
      return user;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }

  Future<dynamic> verifyUserOtp(jsonData) async {
    try {
      final otpverify = await requestPostOtPSend(
        path: 'api/auth/verify-mobile-otp/',
        parameters: jsonData,
      );
      print('response from verify mobile otp $otpverify');
      return otpverify;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }
}
