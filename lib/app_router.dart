import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_bloc.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_event.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';
import 'package:kumbha_path/src/modules/ai_chat/ai_chat_screen.dart';
import 'package:kumbha_path/src/modules/dashboard/dashboard.dart';
import 'package:kumbha_path/src/modules/event/events.dart';
import 'package:kumbha_path/src/modules/journel/create_my_journer.dart';
import 'package:kumbha_path/src/modules/journel/journer_screen.dart';
import 'package:kumbha_path/src/modules/launch_screen/launch_screen.dart';
import 'package:kumbha_path/src/modules/live_crowd/live_crowd_map.dart';
import 'package:kumbha_path/src/modules/live_updates/live_updates.dart';
import 'package:kumbha_path/src/modules/login_screen/login_screen.dart';
import 'package:kumbha_path/src/modules/login_screen/otp_verify_screen.dart';
import 'package:kumbha_path/src/models/website_models.dart';
import 'package:kumbha_path/src/modules/setting/setting.dart';
import 'package:kumbha_path/src/modules/website/announcements_screen.dart';
import 'package:kumbha_path/src/modules/website/listing_detail_screen.dart';
import 'package:kumbha_path/src/modules/website/services_screen.dart';
import 'package:kumbha_path/src/modules/temple_explorer/near_temples.dart';
import 'package:kumbha_path/src/modules/temple_explorer/temple_detail_screen.dart';

class AppRouter {
  Route? onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case '/loginScreen':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const LoginScreen(),
        );

      case '/verifyOtpScreen':
        final phone = routeSettings.arguments as String?;
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => OtpVerifyScreen(phoneNumber: phone ?? ''),
        );

      case '/dashboardScreen':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const Dashboard(),
        );

      case '/aichat':
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) => BlocProvider(
                create:
                    (context) =>
                        WebhookBloc()..add(
                          ChatBothistoryEvent(status: WebhookStatus.initial),
                        ),
                child: AskGuruAiScreen(),
              ),
          //  => const AskGuruAiScreen()
        );

      case '/launchScreen':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const LaunchScreen(),
        );

      case '/shahiEvents':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const ShahiEvents(),
        );

      case '/liveCroud':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const LiveCrowdMap(),
        );

      case '/journal':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const JournerScreen(),
        );

      // case '/myJournalEntry':
      //   return MaterialPageRoute(builder: (_) => const NewJournalEntryScreen());

      case '/notifications':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const LiveUpdates(),
        );

      case '/nearTemples':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const NearTemples(),
        );

      case '/templeDetail':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const TempleDetailsScreen(),
        );

      case '/announcements':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const AnnouncementsScreen(),
        );

      case '/services':
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) => ServicesScreen(
                initialCategory: routeSettings.arguments as ListingCategory?,
              ),
        );

      case '/listingDetail':
        final listing = routeSettings.arguments;
        if (listing is! Listing) {
          return MaterialPageRoute(
            settings: routeSettings,
            builder: (_) => const ServicesScreen(),
          );
        }
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => ListingDetailScreen(listing: listing),
        );

      case '/setting':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const Setting(),
        );

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
          settings: routeSettings,
          builder: (_) => const LaunchScreen(),
        );
    }
  }
}
