
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/modules/launch_screen/launch_screen.dart';
import 'package:kumbha_path/src/modules/login_screen/login_screen.dart';

class AppRouter {
  Route? onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case '/loginScreen':
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      // case '/registrationScreen':
      //   return MaterialPageRoute(builder: (_) => const RegistrationScreen());

      // case '/dashboardScreen':
      //   return MaterialPageRoute(builder: (_) => const DashBoardScreen());


      // case '/launchScreen':
      //   return MaterialPageRoute(builder: (_) => const LaunchScreen()); 

      // case '/tutorialScreen':
      //   return MaterialPageRoute(builder: (_) => const TutorialScreen());

      // case '/settingScreen':
      //   return MaterialPageRoute(builder: (_) => const SettingScreen());

      // case '/aimilaunchScreen':
      //   return MaterialPageRoute(builder: (_) => const AimiScreen());

    
      // case '/welcomeScreen':
      //   return MaterialPageRoute(builder: (_) => const AimaWelcomeScreen());

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
