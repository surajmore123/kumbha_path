import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kumbha_path/app_router.dart';
import 'package:kumbha_path/src/modules/family/invite_links.dart';
import 'package:kumbha_path/src/modules/family/offline/contact_sync.dart';
import 'package:kumbha_path/src/modules/lostfound/data/lf_drafts.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_bloc.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_bloc.dart';

import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_bloc.dart';
import 'package:kumbha_path/src/components/navigation/app_navigation.dart';
import 'package:kumbha_path/src/constant/design_system/app_typography.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/constant/theme_provider.dart';
import 'package:kumbha_path/src/services/fcm_service.dart';
import 'package:kumbha_path/src/services/local_notification_service.dart';
import 'package:kumbha_path/src/services/notification_router.dart';
import 'package:provider/provider.dart';

/// App in the background or closed: the system shows the push itself
/// (the backend always sends a `notification` with an Android channel).
/// Nothing else is needed here; it must stay a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// App open: FCM doesn't display notifications for a foreground app, so
/// show it as a local notification (tapping it opens the right screen).
Future<void> _showForegroundPush(RemoteMessage message) async {
  final title = message.notification?.title ?? message.data['title'];
  final body = message.notification?.body ?? message.data['body'];
  if (title == null && body == null) return;
  await NotificationService.show(
    title: title ?? 'Kumbh Path',
    body: body ?? '',
    data: message.data,
    channelId: message.notification?.android?.channelId,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // 🔹 Restore appearance preferences before the first frame
  final themeProvider = await ThemeProvider.load();

  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");

  // Notification taps open screens through the app's navigator.
  NotificationRouter.attach(MyApp.navigatorKey);

  // 🔹 Background / closed: handler for data processing
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  // 🔹 Channels, foreground display, taps on local notifications
  await NotificationService.init();

  // 🔹 Request notification permission
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // 🔹 Token: cache it, follow refreshes, and register it for the
  // signed-in user (not only at login).
  await FcmService.init();
  unawaited(FcmService.registerWithBackend());

  // 🔹 App open
  FirebaseMessaging.onMessage.listen(_showForegroundPush);

  // 🔹 App in background, user tapped the notification
  FirebaseMessaging.onMessageOpenedApp.listen(
    (message) => NotificationRouter.open(message.data),
  );

  // 🔹 App was closed and started by tapping the notification
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) NotificationRouter.open(initialMessage.data);

  InviteLinkRouter.attach(MyApp.navigatorKey);
  InviteLinkRouter.listen();

  // Sends any emergency contact changes saved while offline.
  FamilyContacts.service.start();
  LostFoundDrafts.sender.start();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: ChangeNotifierProvider<ThemeProvider>.value(
        value: themeProvider,
        child: MyApp(appRouter: AppRouter()),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppRouter appRouter;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

  const MyApp({super.key, required this.appRouter});

  @override
  Widget build(BuildContext context) {
    // Keep LanguageHelper (used by older screens) on the language that
    // easy_localization restored or the user picked.
    final code = context.locale.languageCode;
    if (LanguageHelper.currentLang.value != code) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => LanguageHelper.changeLanguage(code),
      );
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider<UserBloc>(create: (context) => UserBloc()),
        BlocProvider<WebhookBloc>(create: (context) => WebhookBloc()),
        BlocProvider<AppBloc>(create: (context) => AppBloc()),
        BlocProvider<AppDetailsBloc>(create: (context) => AppDetailsBloc()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Kumbh Path',
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            debugShowCheckedModeBanner: false,

            // Global design system: see lib/src/constant/design_system/.
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            // Applies the user's font-scale preference once, on top of the
            // device accessibility text size.
            builder:
                (context, child) => AppFontScaleScope(
                  fontScale: themeProvider.fontScalePreset,
                  child: child,
                ),

            navigatorKey: MyApp.navigatorKey,
            // Observe-only: lets tab taps return to an open tab screen.
            navigatorObservers: [AppNavigation.observer],
            initialRoute: '/launchScreen',
            onGenerateRoute: appRouter.onGenerateRoute,
          );
        },
      ),
    );
  }
}
