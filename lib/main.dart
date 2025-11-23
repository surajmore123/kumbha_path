import 'package:flutter/material.dart';
import 'package:kumbha_path/app_router.dart';

void main() {
  runApp(MyApp(appRouter: AppRouter()));
}

class MyApp extends StatelessWidget {
  final AppRouter appRouter;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

  const MyApp({super.key, required this.appRouter});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),

      navigatorKey: MyApp.navigatorKey,

      initialRoute: '/launchScreen',
      onGenerateRoute: appRouter.onGenerateRoute,

      builder: (context, child) {
        return child!;
      },
    );
  }
}
