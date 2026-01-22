import 'package:kumbha_path/src/network/api/temple_api.dart';
import 'package:kumbha_path/src/repository/repository/repository.dart';

class TempleRepository extends Repository{
  final TempleApi templeApi = TempleApi();  

  Future<dynamic> getNearbyTemples(jsonData) async {
    return templeApi.getNearbyTemples(jsonData);
  }

  Future<dynamic>getTempleDetail(jsonData)async{
    return templeApi.getTempleDetail(jsonData);
  }

  

   Future<dynamic>templeNavigate(jsonData)async{
    return templeApi.templeNavigate(jsonData);
  }

  
   Future<dynamic>getFeaturedEvent(jsonData)async{
    return templeApi.getFeaturedEvent(jsonData);
  }
  

   Future<dynamic>getUpcomingTemples(jsonData)async{
    return templeApi.getUpcomingTemples(jsonData);
  }
}