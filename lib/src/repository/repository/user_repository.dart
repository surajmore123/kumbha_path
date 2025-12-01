import 'package:kumbha_path/src/network/api/user_api.dart';
import 'package:kumbha_path/src/repository/webhook_repository/repository.dart';

class UserRepository extends Repository {
  final UserApi userApi = UserApi();

  Future<dynamic> createUser(jsonData) async {
    return userApi.createUser(jsonData);
  }

  Future<dynamic> verifyUserOtp(jsonData)async{
    return userApi.verifyUserOtp(jsonData);
  }
}
