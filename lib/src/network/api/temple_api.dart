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

 Future<dynamic> getCrowdLiveStatus(Map<String, String> jsonData) async {
    try {
      final response = await requestGet(
        path: 'api/crowd/live-status/',
        parameters: jsonData,
      );
      print("crowd live status response $response");
      return response;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }

    Future<dynamic> getZoneDetail(jsonData) async {
    try {
      final response = await requestGet(
        path: 'api/crowd/zones/${jsonData['code']}/details/',
        parameters: jsonData,
      );
      print('zone details response $response');
      return response;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }

 Future<dynamic> getQuickAlerts(jsonData) async {
    try {
      final response = await requestGet(
        path: 'api/crowd/quick-alerts/',
        parameters: jsonData,
      );
      print('quick alerts response $response');
      return response;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }

  Future<dynamic> getNotifications(jsonData)async{
    try{
      final response = await requestGet(path: 'api/crowd/notifications/', parameters: jsonData);
      print('notifications response $response');
      return response;
    }catch (e, _) {
      print(e);
      print('error');
    }
  }

  Future<dynamic> getAiReflection(jsonData)async{
    try{
      final response = await requestGet(path:'api/journal/ai-reflection', parameters: jsonData);
      return response;
    }catch (e, _) {
      print(e);
      print('error');
    }
  }

   Future<dynamic> getAiPrompt(jsonData)async{
    try{
      final response = await requestGet(path:'api/journal/ai-prompt', parameters: jsonData);
      return response;
    }catch (e, _) {
      print(e);
      print('error');
    }
  }



Future<dynamic> createJournalEntry(jsonData) async {
  try {

    String? imagePath = jsonData["photo"];

    jsonData.remove("photo");

    final response = await requestMultipartPost(
      path: 'api/journal/create-entry/',
      parameters: jsonData,
      fileKey: "photo",
      filePath: imagePath,
    );

    return response;

  } catch (e, _) {
    print(e);
    print('error');
  }
}

   Future<dynamic> getJournalEntry(jsonData)async{
    try{
      final response = await requestGet(path:'api/journal/entries/', parameters: jsonData);
      return response;
    }catch (e, _) {
      print(e);
      print('error');
    }
  }


 Future<dynamic> getJournalDetail(jsonData) async {
    try {
      final response = await requestGet(
        path: 'api/journal/entries/${jsonData['id']}/',
        parameters: jsonData,
      );
      return response;
    } catch (e, _) {
      print(e);
      print('error');
    }
  }


}
