
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/modules/ai_chat/ai_chat_screen.dart';
import 'package:kumbha_path/src/modules/dashboard/dashboard.dart';
import 'package:kumbha_path/src/modules/event/events.dart';
import 'package:kumbha_path/src/modules/journel/create_my_journer.dart';
import 'package:kumbha_path/src/modules/journel/journer_screen.dart';
import 'package:kumbha_path/src/modules/launch_screen/launch_screen.dart';
import 'package:kumbha_path/src/modules/live_crowd/live_crowd_map.dart';
import 'package:kumbha_path/src/modules/live_updates/live_updates.dart';
import 'package:kumbha_path/src/modules/login_screen/login_screen.dart';
import 'package:kumbha_path/src/modules/setting/setting.dart';
import 'package:kumbha_path/src/modules/temple_explorer/near_temples.dart';
import 'package:kumbha_path/src/modules/temple_explorer/temple_detail_screen.dart';

class AppRouter {
  Route? onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case '/loginScreen':
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case '/dashboardScreen':
        return MaterialPageRoute(builder: (_) => const Dashboard());

      case '/aichat':
        return MaterialPageRoute(builder: (_) => const AskGuruAiScreen());

      case '/launchScreen':
        return MaterialPageRoute(builder: (_) => const LaunchScreen());

      case '/shahiEvents':
        return MaterialPageRoute(builder: (_) => const ShahiEvents());


      case '/liveCroud':
        return MaterialPageRoute(builder: (_) => const LiveCrowdMap()); 

        

      case '/journal':
        return MaterialPageRoute(builder: (_) => const JournerScreen());

      case '/myJournalEntry':
        return MaterialPageRoute(builder: (_) => const NewJournalEntryScreen());

      case '/notifications':
        return MaterialPageRoute(builder: (_) => const LiveUpdates());

        

      case '/nearTemples':
        return MaterialPageRoute(builder: (_) => const NearTemples());

      case '/templeDetail':
        return MaterialPageRoute(builder: (_) => const TempleDetailsScreen());

      case '/setting':
        return MaterialPageRoute(builder: (_) => const Setting());

    
      

      // case '/getStartScreen':
      //   return MaterialPageRoute(builder: (_) => const ChatGetStartScreen());

      // case '/chatScreen':
      //   return MaterialPageRoute(builder: (_) => const ChatScreen());
      
      // case '/campaignHistory':
      //   return MaterialPageRoute(builder: (_) => const CampaignHistory());

   

      // case '/changePassword':
      //   return MaterialPageRoute(builder: (_) => const Changepassword());
      
      // case '/resetPassword':
      //   return MaterialPageRoute(builder: (_) => const ResetPassword());

      default:
        return MaterialPageRoute(
          builder: (_) => const LaunchScreen(),
        );
    }
  }
}
