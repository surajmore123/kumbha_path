import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_bloc.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_event.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';
import 'package:kumbha_path/src/modules/ai_chat/ai_chat_screen.dart';
import 'package:kumbha_path/src/modules/akhada/akhadas_screens.dart';
import 'package:kumbha_path/src/modules/booking/booking_home_screen.dart';
import 'package:kumbha_path/src/modules/booking/models/booking_models.dart';
import 'package:kumbha_path/src/modules/booking/my_bookings_screens.dart';
import 'package:kumbha_path/src/modules/booking/stay_screens.dart';
import 'package:kumbha_path/src/modules/booking/transport_screen.dart';
import 'package:kumbha_path/src/modules/family/family_flows_screens.dart';
import 'package:kumbha_path/src/modules/family/family_home_screen.dart';
import 'package:kumbha_path/src/modules/family/family_member_screens.dart';
import 'package:kumbha_path/src/modules/family/invite_links.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:kumbha_path/src/modules/location/family_map_screen.dart';
import 'package:kumbha_path/src/modules/location/location_sharing_screen.dart';
import 'package:kumbha_path/src/modules/operations/ops_case_screen.dart';
import 'package:kumbha_path/src/modules/operations/ops_home_screen.dart';
import 'package:kumbha_path/src/modules/operations/ops_sign_in_screen.dart';
import 'package:kumbha_path/src/modules/reunion/models/reunion_models.dart';
import 'package:kumbha_path/src/modules/reunion/point_explorer_screen.dart';
import 'package:kumbha_path/src/modules/reunion/reunion_case_screen.dart';
import 'package:kumbha_path/src/modules/reunion/reunion_map_screen.dart';
import 'package:kumbha_path/src/modules/reunion/route_preview_screen.dart';
import 'package:kumbha_path/src/modules/emergency/assistance_screen.dart';
import 'package:kumbha_path/src/modules/emergency/sos_detail_screen.dart';
import 'package:kumbha_path/src/modules/emergency/sos_screen.dart';
import 'package:kumbha_path/src/modules/notification_centre/notification_centre_screen.dart';
import 'package:kumbha_path/src/modules/lostfound/case_screens.dart';
import 'package:kumbha_path/src/modules/lostfound/data/lf_drafts.dart';
import 'package:kumbha_path/src/modules/lostfound/lostfound_home_screen.dart';
import 'package:kumbha_path/src/modules/lostfound/models/lf_models.dart';
import 'package:kumbha_path/src/modules/lostfound/ops_screens.dart';
import 'package:kumbha_path/src/modules/lostfound/report_screens.dart';
import 'package:kumbha_path/src/modules/safety/safety_alerts_screen.dart';
import 'package:kumbha_path/src/modules/safety/safety_qr_screen.dart';
import 'package:kumbha_path/src/modules/safety/safety_scan_screen.dart';
import 'package:kumbha_path/src/modules/dashboard/dashboard.dart';
import 'package:kumbha_path/src/modules/event/events.dart';
import 'package:kumbha_path/src/modules/journel/create_my_journer.dart';
import 'package:kumbha_path/src/modules/journel/journer_screen.dart';
import 'package:kumbha_path/src/modules/journey/journey_detail_screen.dart';
import 'package:kumbha_path/src/modules/journey/journey_form_screen.dart';
import 'package:kumbha_path/src/modules/journey/journeys_screen.dart';
import 'package:kumbha_path/src/modules/journey/models/journey_models.dart';
import 'package:kumbha_path/src/modules/launch_screen/launch_screen.dart';
import 'package:kumbha_path/src/modules/live_crowd/live_crowd_map.dart';
import 'package:kumbha_path/src/modules/live_updates/live_updates.dart';
import 'package:kumbha_path/src/modules/login_screen/login_screen.dart';
import 'package:kumbha_path/src/modules/patrika/learn_screens.dart';
import 'package:kumbha_path/src/modules/patrika/news_screens.dart';
import 'package:kumbha_path/src/modules/login_screen/otp_verify_screen.dart';
import 'package:kumbha_path/src/modules/setting/setting.dart';
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

      case '/family':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const FamilyHomeScreen(),
        );

      case '/familyCreate':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const CreateFamilyScreen(),
        );

      case '/familyJoin':
        final invite = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) => JoinFamilyScreen(
                invite: invite is InvitePreview ? invite : null,
                link: invite is InviteLink ? invite : null,
              ),
        );

      case '/familyMember':
      case '/familyMemberForm':
      case '/familyInvite':
      case '/familyContacts':
      case '/familySettings':
        final args = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) {
            if (args is! FamilyArgs) return const FamilyHomeScreen();
            return switch (routeSettings.name) {
              '/familyMember' => MemberProfileScreen(args: args),
              '/familyMemberForm' => MemberFormScreen(args: args),
              '/familyInvite' => InviteScreen(args: args),
              '/familyContacts' => EmergencyContactsScreen(args: args),
              _ => FamilySettingsScreen(args: args),
            };
          },
        );

      case '/safetyQr':
        final args = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) =>
                  args is FamilyArgs
                      ? SafetyQrScreen(args: args)
                      : const FamilyHomeScreen(),
        );

      case '/safetyScan':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const SafetyScanScreen(),
        );

      case '/safetyAlerts':
        final args = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) => SafetyAlertsScreen(args: args is FamilyArgs ? args : null),
        );

      case '/familyMap':
        final target = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) => FamilyMapScreen(
                args: target is FamilyArgs ? target : null,
                familyId: target is String ? target : null,
              ),
        );

      case '/locationSharing':
        final args = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) =>
                  args is FamilyArgs
                      ? LocationSharingScreen(args: args)
                      : const FamilyHomeScreen(),
        );

      case '/reunionMap':
        final target = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) => ReunionMapScreen(
                args: target is FamilyArgs ? target : null,
                familyId:
                    target is Map<String, String> ? target['family_id'] : null,
                pointId:
                    target is Map<String, String> ? target['point_id'] : null,
              ),
        );

      case '/reunionPoints':
        final args = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) => PointExplorerScreen(
                args:
                    args is PointExplorerArgs
                        ? args
                        : const PointExplorerArgs(),
              ),
        );

      case '/reunionAddPoint':
        final id = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) =>
                  id is String
                      ? AddFamilyPointScreen(familyId: id)
                      : const PointExplorerScreen(),
        );

      case '/reunionRoute':
        final target = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) =>
                  target is RouteTarget
                      ? RoutePreviewScreen(target: target)
                      : const PointExplorerScreen(),
        );

      case '/reunionCase':
        final id = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) =>
                  id is String
                      ? ReunionCaseScreen(id: id)
                      : const LostFoundHomeScreen(),
        );

      case '/sos':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const SosScreen(),
        );

      case '/sosDetail':
        final id = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) => id is String ? SosDetailScreen(id: id) : const SosScreen(),
        );

      case '/sosHistory':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const SosHistoryScreen(),
        );

      case '/sosAssistance':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const AssistanceScreen(),
        );

      case '/notificationCentre':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const NotificationCentreScreen(),
        );

      case '/notificationPreferences':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const NotificationPreferencesScreen(),
        );

      case '/opsSignIn':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const OpsSignInScreen(),
        );

      case '/ops':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const VolunteerHomeScreen(),
        );

      case '/opsTeam':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const OpsTeamScreen(),
        );

      case '/opsSos':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const OpsSosScreen(),
        );

      case '/opsCase':
        final id = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) =>
                  id is String
                      ? AssignedCaseScreen(id: id)
                      : const VolunteerHomeScreen(),
        );

      case '/lostFound':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const LostFoundHomeScreen(),
        );

      case '/lostFoundReport':
      case '/lostFoundFound':
        final draftId = routeSettings.arguments;
        final id = draftId is String ? draftId : null;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) =>
                  routeSettings.name == '/lostFoundFound'
                      ? ReportFoundScreen(draftId: id)
                      : ReportLostScreen(draftId: id),
        );

      case '/lostFoundDone':
        final result = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) =>
                  result is SubmitResult
                      ? ReportDoneScreen(result: result)
                      : const LostFoundHomeScreen(),
        );

      case '/lostFoundCase':
      case '/lostFoundSighting':
      case '/lostFoundOpsCase':
        final id = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) {
            if (id is! String) return const LostFoundHomeScreen();
            return switch (routeSettings.name) {
              '/lostFoundCase' => CaseDetailScreen(id: id),
              '/lostFoundSighting' => AddSightingScreen(caseId: id),
              _ => OpsCaseScreen(id: id),
            };
          },
        );

      case '/lostFoundOps':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const OpsHomeScreen(),
        );

      case '/lostFoundMatch':
        final match = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) =>
                  match is CaseMatch
                      ? MatchReviewScreen(match: match)
                      : const OpsHomeScreen(),
        );

      case '/booking':
        final prefill = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) => BookingHomeScreen(
                prefill: prefill is JourneyPrefill ? prefill : null,
              ),
        );

      case '/stays':
        final search = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) => StayResultsScreen(
                search: search is StaySearch ? search : null,
              ),
        );

      case '/stayDetail':
        final id = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) =>
                  id is String && id.isNotEmpty
                      ? StayDetailScreen(id: id)
                      : const BookingHomeScreen(),
        );

      case '/transport':
        final args = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) =>
                  args is (String, JourneyPrefill?)
                      ? TransportScreen(mode: args.$1, prefill: args.$2)
                      : const TransportScreen(),
        );

      case '/myBookings':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const MyBookingsScreen(),
        );

      case '/bookingDetail':
        final id = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) =>
                  id is String && id.isNotEmpty
                      ? BookingDetailScreen(id: id)
                      : const MyBookingsScreen(),
        );

      case '/bookingForm':
        final args = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) => BookingFormScreen(
                draft: args is BookingDraft ? args : null,
                existing: args is SavedBooking ? args : null,
              ),
        );

      case '/kumbhNews':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const KumbhNewsScreen(),
        );

      case '/newsSearch':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const NewsSearchScreen(),
        );

      case '/learn':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const LearnHomeScreen(),
        );

      case '/glossary':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const GlossaryScreen(),
        );

      case '/patrikaSaved':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const PatrikaSavedScreen(),
        );

      case '/newsArticle':
      case '/learnArticle':
        final slug = routeSettings.arguments;
        if (slug is! String || slug.isEmpty) {
          return MaterialPageRoute(
            settings: const RouteSettings(name: '/learn'),
            builder: (_) => const LearnHomeScreen(),
          );
        }
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) =>
                  routeSettings.name == '/newsArticle'
                      ? NewsArticleScreen(slug: slug)
                      : LearnReaderScreen(slug: slug),
        );

      case '/akhadas':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const AkhadasHomeScreen(),
        );

      case '/akhadaList':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const AkhadaListScreen(),
        );

      case '/saints':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const SaintListScreen(),
        );

      case '/akhadaLearn':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const AkhadaLearnScreen(),
        );

      case '/akhadaActivities':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const AkhadaActivitiesScreen(),
        );

      case '/akhadaDetail':
      case '/saintDetail':
      case '/akhadaArticle':
        final slug = routeSettings.arguments;
        if (slug is! String || slug.isEmpty) {
          return MaterialPageRoute(
            settings: const RouteSettings(name: '/akhadas'),
            builder: (_) => const AkhadasHomeScreen(),
          );
        }
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) => switch (routeSettings.name) {
                '/akhadaDetail' => AkhadaDetailScreen(slug: slug),
                '/saintDetail' => SaintDetailScreen(slug: slug),
                _ => AkhadaArticleScreen(slug: slug),
              },
        );

      case '/journeys':
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const JourneysScreen(),
        );

      case '/journeyForm':
        final initial = routeSettings.arguments;
        return MaterialPageRoute(
          settings: routeSettings,
          builder:
              (_) => JourneyFormScreen(
                initial: initial is JourneyPlan ? initial : null,
              ),
        );

      case '/journeyDetail':
        final id = routeSettings.arguments;
        if (id is! String || id.isEmpty) {
          return MaterialPageRoute(
            settings: const RouteSettings(name: '/journeys'),
            builder: (_) => const JourneysScreen(),
          );
        }
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => JourneyDetailScreen(journeyId: id),
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
