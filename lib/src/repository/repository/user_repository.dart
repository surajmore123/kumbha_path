import 'package:kumbha_path/src/network/api/user_api.dart';
import 'package:kumbha_path/src/repository/repository/repository.dart';

class UserRepository extends Repository {
  final UserApi userApi = UserApi();

  Future<dynamic> createUser(jsonData) async {
    return userApi.createUser(jsonData);
  }

  Future<dynamic> verifyUserOtp(jsonData) async {
    return userApi.verifyUserOtp(jsonData);
  }

  //getUserProfile
  Future<dynamic> userProfileCreate(jsonData) async {
    return userApi.userProfileCreate(jsonData);
  }

  Future<dynamic> userProfileImageUpload(jsonData) async {
    return userApi.userProfileImageUpload(jsonData);
  }

  Future<dynamic> getUserProfile(jsonData) async {
    return userApi.getUserProfile(jsonData);
  }

  Future<dynamic> registerFcm(jsonData) async {
    return userApi.registerFcm(jsonData);
  }
}
