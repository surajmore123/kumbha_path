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

  Future<dynamic> templeNavigate(jsonData) async {
    try {
      final response = await requestPost(
        path: 'api/temples/navigate/${jsonData['temple_id']}/',
        parameters: jsonData,
      );
      print('temple navigate response $response');
      return response;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }

  Future<dynamic> getFeaturedEvent(jsonData) async {
    try {
      final response = await requestGet(
        path: 'api/events/featured/',
        parameters: jsonData,
      );
      print('featured temple response $response');
      return response;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }

  Future<dynamic> getUpcomingTemples(Map<String, String> jsonData) async {
    try {
      final response = await requestGet(
        path: 'api/events/upcoming/',
        parameters: jsonData,
      );
      print("upcomming events response $response");
      return response;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }

   Future<dynamic> eventNotification(jsonData) async {
    try {
      final response = await requestPost(
        path: 'api/events/${jsonData['event_id']}/reminder-toggle/',
        parameters: jsonData,
      );
      print('notification reminder response $response');
      return response;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }
}
