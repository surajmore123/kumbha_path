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

  Future<dynamic> userProfileCreate(jsonData) async {
    try {
      final usercreate = await requestPATCH(
        path: '/api/auth/profile/',
        parameters: jsonData,
      );
      print('response from user data $usercreate');
      return usercreate;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }

  Future<dynamic> userProfileImageUpload(jsonData) async {
    try {
      final profileImageUpload = await requestPatchImg(
        path: '/api/auth/profile/image/',
        parameters: jsonData,
      );
      print('response from profile image upload $profileImageUpload');
      return profileImageUpload;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }

  Future<dynamic> getUserProfile(jsonData) async {
    try {
      final userProfile = await requestGet(
        path: '/api/auth/profile/',
        parameters: jsonData,
      );
      print('response from get user profile $userProfile');
      return userProfile;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }

  Future<dynamic> registerFcm(jsonData) async {
    try {
      final fcmresult = await requestPost(
        path: '/api/auth/fcm/register/',
        parameters: jsonData,
      );
      print('response from fcm registered $fcmresult');
      return fcmresult;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }
}
