import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kumbha_path/app_router.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_bloc.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_bloc.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_event.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_bloc.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/constant/theme_provider.dart';
import 'package:kumbha_path/src/services/fcm_service.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  await FcmService.init();
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    print("🔁 FCM TOKEN REFRESHED: $newToken");

    await userAuthentication.saveFcmToken(newToken);
  });
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  print("📩 PUSH RECEIVED (FOREGROUND)");

  if (message.notification != null) {
    print("🔔 Title: ${message.notification!.title}");
    print("🔔 Body: ${message.notification!.body}");
  }

  if (message.data.isNotEmpty) {
    print("📦 Data: ${message.data}");
  }
});

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(appRouter: AppRouter()),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppRouter appRouter;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

  const MyApp({super.key, required this.appRouter});

  @override
  Widget build(BuildContext context) {
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
            title: 'Flutter Demo',
            debugShowCheckedModeBanner: false,

            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: const Color(0xFFFFF7E9),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFFFF7E9),
                foregroundColor: Color(0xFF111827),
              ),
            ),

            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: const Color(0xFF020617),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF020617),
                foregroundColor: Colors.white,
              ),
            ),

            themeMode: themeProvider.themeMode,

            navigatorKey: MyApp.navigatorKey,
            initialRoute: '/launchScreen',
            onGenerateRoute: appRouter.onGenerateRoute,
          );
        },
      ),
    );
  }
}
