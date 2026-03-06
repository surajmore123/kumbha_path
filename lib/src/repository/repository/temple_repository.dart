import 'package:kumbha_path/src/network/api/temple_api.dart';
import 'package:kumbha_path/src/repository/repository/repository.dart';

class TempleRepository extends Repository {
  final TempleApi templeApi = TempleApi();

  Future<dynamic> getNearbyTemples(jsonData) async {
    return templeApi.getNearbyTemples(jsonData);
  }

  Future<dynamic> getTempleDetail(jsonData) async {
    return templeApi.getTempleDetail(jsonData);
  }

  Future<dynamic> templeNavigate(jsonData) async {
    return templeApi.templeNavigate(jsonData);
  }

  Future<dynamic> getFeaturedEvent(jsonData) async {
    return templeApi.getFeaturedEvent(jsonData);
  }

  Future<dynamic> getUpcomingTemples(jsonData) async {
    return templeApi.getUpcomingTemples(jsonData);
  }

  Future<dynamic> eventNotification(jsonData) async {
    return templeApi.eventNotification(jsonData);
  }

  Future<dynamic> getCrowdLiveStatus(jsonData) async {
    return templeApi.getCrowdLiveStatus(jsonData);
  }

  Future<dynamic> getZoneDetail(jsonData) async {
    return templeApi.getZoneDetail(jsonData);
  }

  Future<dynamic> getQuickAlerts(jsonData) async {
    return templeApi.getQuickAlerts(jsonData);
  }

  
    Future<dynamic> getNotifications(jsonData) async {
    return templeApi.getNotifications(jsonData);
  }

  
    
    Future<dynamic> getAiReflection(jsonData) async {
    return templeApi.getAiReflection(jsonData);
  }

  
    Future<dynamic> getAiPrompt(jsonData) async {
    return templeApi.getAiPrompt(jsonData);
  }

  
   Future<dynamic> createJournalEntry(jsonData) async {
    return templeApi.createJournalEntry(jsonData);
  }
  
    Future<dynamic> getJournalEntry(jsonData) async {
    return templeApi.getJournalEntry(jsonData);
  }

  
      Future<dynamic> getJournalDetail(jsonData) async {
    return templeApi.getJournalDetail(jsonData);
  }
}
