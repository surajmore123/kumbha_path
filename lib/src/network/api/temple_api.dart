import 'package:kumbha_path/src/network/api/api.dart';

class TempleApi extends Api {
  Future<dynamic> getNearbyTemples(Map<String, String> jsonData) async {
    try {
      final response = await requestGet(
        path: 'api/temples/nearby-temples/',
        parameters: jsonData,
      );
      print("nearby temples response $response");
      return response;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }

  Future<dynamic> getTempleDetail(jsonData) async {
    try {
      final response = await requestGet(
        path: 'api/temples/nearby-temples/${jsonData['temple_id']}',
        parameters: jsonData,
      );
      print('temple details response $response');
      return response;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }
}
