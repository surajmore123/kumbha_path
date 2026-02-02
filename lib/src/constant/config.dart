import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kumbha_path/src/network/controller/user_authentication.dart';
import 'package:kumbha_path/src/repository/repository/app_repository.dart';
import 'package:kumbha_path/src/repository/repository/temple_repository.dart';
import 'package:kumbha_path/src/repository/repository/user_repository.dart';

FlutterSecureStorage storage = const FlutterSecureStorage();
 final UserRepository userRepository = UserRepository();
  final AppRepository appRepository = AppRepository();
  final TempleRepository templeRepository = TempleRepository();

  final UserAuthentication userAuthentication = UserAuthentication();