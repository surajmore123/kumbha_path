import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kumbha_path/app_router.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_bloc.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_bloc.dart';

import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_bloc.dart';
import 'package:kumbha_path/src/bloc/website_bloc/website_bloc.dart';
import 'package:kumbha_path/src/components/navigation/app_navigation.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/constant/design_system/app_typography.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/constant/theme_provider.dart';
import 'package:kumbha_path/src/services/fcm_service.dart';
import 'package:kumbha_path/src/services/local_notification_service.dart';
import 'package:provider/provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📩 BACKGROUND PUSH RECEIVED: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // 🔹 Restore appearance preferences before the first frame
  final themeProvider = await ThemeProvider.load();

  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");

  // 🔹 Background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  // 🔹 Initialize local notifications
  await NotificationService.init();

  // 🔹 Request notification permission
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // 🔹 Initialize FCM token
  await FcmService.init();

  // 🔹 Listen for token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    print("🔁 FCM TOKEN REFRESHED: $newToken");
    await userAuthentication.saveFcmToken(newToken);
  });

  // 🔹 FOREGROUND PUSH HANDLER
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print("📩 FOREGROUND PUSH RECEIVED");

    if (message.notification != null) {
      await NotificationService.show(
        title: message.notification!.title ?? "Crowd Alert",
        body: message.notification!.body ?? "",
        payload: message.data['zone_id'],
      );
    }
  });

  // 🔹 When app opened from notification (background → foreground)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("📲 Notification opened app");
    print("Payload: ${message.data}");
  });

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
        BlocProvider<WebsiteBloc>(create: (context) => WebsiteBloc()),
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
