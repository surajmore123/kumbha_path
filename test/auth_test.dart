import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_bloc.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_event.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_state.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/launch_screen/launch_screen.dart';
import 'package:kumbha_path/src/modules/login_screen/login_screen.dart';
import 'package:kumbha_path/src/modules/login_screen/otp_verify_screen.dart';
import 'package:kumbha_path/src/modules/login_screen/widgets/auth_widgets.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records events and answers with canned statuses; never touches the
/// network or secure storage.
class FakeUserBloc extends UserBloc {
  final List<UserEvent> events = [];

  /// Status to emit after `sending`, or null to never answer.
  UserStatus? Function(UserEvent event)? reply;

  @override
  void add(UserEvent event) {
    events.add(event);
    final result = reply?.call(event);
    // ignore: invalid_use_of_visible_for_testing_member
    emit(state.copyWith(status: UserStatus.sending));
    // ignore: invalid_use_of_visible_for_testing_member
    if (result != null) emit(state.copyWith(status: result));
  }

  /// Simulates a state change caused elsewhere in the app.
  void push(UserStatus status) =>
  // ignore: invalid_use_of_visible_for_testing_member
  emit(state.copyWith(status: status));
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    return json.decode(await file.readAsString()) as Map<String, dynamic>;
  }
}

/// Every route the auth flow can reach, recorded as (name, arguments).
final List<(String, Object?)> visited = [];

Future<FakeUserBloc> pumpApp(
  WidgetTester tester, {
  required String initialRoute,
  Object? initialArgs,
  Future<bool> Function()? checkLogin,
  Locale locale = const Locale('en'),
  Size size = const Size(360, 780),
  Brightness brightness = Brightness.light,
  AppFontScale fontScale = AppFontScale.standard,
  double deviceScale = 1.0,
  double keyboard = 0,
}) async {
  visited.clear();
  await tester.runAsync(EasyLocalization.ensureInitialized);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  if (keyboard > 0) {
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  }
  addTearDown(tester.view.reset);

  final bloc = FakeUserBloc();
  addTearDown(bloc.close);

  Route<dynamic> route(RouteSettings settings) {
    final name = settings.name!;
    if (name != '/') visited.add((name, settings.arguments));
    final Widget page = switch (name) {
      '/launchScreen' => LaunchScreen(
        checkLogin: checkLogin ?? () async => false,
        minimumDisplay: const Duration(milliseconds: 100),
      ),
      '/loginScreen' => const LoginScreen(),
      '/verifyOtpScreen' => OtpVerifyScreen(
        phoneNumber: (settings.arguments as String?) ?? '',
      ),
      _ => Scaffold(body: Text('page $name')),
    };
    return MaterialPageRoute(settings: settings, builder: (_) => page);
  }

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
      path: 'assets/translations',
      assetLoader: const _FileAssetLoader(),
      fallbackLocale: const Locale('en'),
      startLocale: locale,
      saveLocale: false,
      child: BlocProvider<UserBloc>.value(
        value: bloc,
        child: Builder(
          builder:
              (context) => MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode:
                    brightness == Brightness.dark
                        ? ThemeMode.dark
                        : ThemeMode.light,
                onGenerateInitialRoutes:
                    (_) => [
                      route(
                        RouteSettings(
                          name: initialRoute,
                          arguments: initialArgs,
                        ),
                      ),
                    ],
                onGenerateRoute: route,
                builder:
                    (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(deviceScale)),
                      child: AppFontScaleScope(
                        fontScale: fontScale,
                        child: child,
                      ),
                    ),
              ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 20 && find.byType(Navigator).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pump();
  return bloc;
}

/// The OTP screen has a live countdown and a blinking cursor, so it never
/// "settles"; advance a fixed amount instead.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder get phoneField => find.byType(TextFormField);
Finder get getOtpButton => find.widgetWithText(FilledButton, 'Get OTP');
Finder get verifyButton => find.widgetWithText(FilledButton, 'Verify');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('phone masking', () {
    expect(maskPhoneNumber('9876543210'), '98•••••210');
    expect(maskPhoneNumber('123'), '123');
  });

  group('launch', () {
    testWidgets('signed in -> dashboard', (tester) async {
      await pumpApp(
        tester,
        initialRoute: '/launchScreen',
        checkLogin: () async => true,
      );
      expect(find.text('Kumbh Path'), findsOneWidget);
      expect(find.text('Your spiritual journey, guided.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(visited.last.$1, '/dashboardScreen');
    });

    testWidgets('signed out -> login, not before the check completes', (
      tester,
    ) async {
      var release = false;
      await pumpApp(
        tester,
        initialRoute: '/launchScreen',
        checkLogin: () async {
          while (!release) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          return false;
        },
      );
      await tester.pump(const Duration(seconds: 2));
      expect(visited.map((v) => v.$1), ['/launchScreen']);
      release = true;
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(visited.last.$1, '/loginScreen');
    });

    testWidgets('storage failure falls back to login', (tester) async {
      await pumpApp(
        tester,
        initialRoute: '/launchScreen',
        checkLogin: () async => throw Exception('keystore'),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(visited.last.$1, '/loginScreen');
    });
  });

  group('login', () {
    testWidgets('no fabricated login options', (tester) async {
      await pumpApp(tester, initialRoute: '/loginScreen');
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Welcome to Kumbh Path'), findsOneWidget);
    });

    testWidgets('validates before sending', (tester) async {
      final bloc = await pumpApp(tester, initialRoute: '/loginScreen');
      await tester.tap(getOtpButton);
      await tester.pump();
      expect(find.text('Phone number is required'), findsOneWidget);

      await tester.enterText(phoneField, '98765');
      await tester.tap(getOtpButton);
      await tester.pump();
      expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);

      // Non-digits are filtered and length is capped at 10.
      await tester.enterText(phoneField, '98a76-54321099');
      expect(
        tester.widget<TextFormField>(phoneField).controller!.text,
        '9876543210',
      );
      expect(bloc.events, isEmpty);
    });

    testWidgets('success opens OTP screen with the number', (tester) async {
      final bloc = await pumpApp(tester, initialRoute: '/loginScreen');
      bloc.reply = (_) => UserStatus.otpsended;
      await tester.enterText(phoneField, '9876543210');
      await tester.tap(getOtpButton);
      await settle(tester);

      final sent = bloc.events.single as UserCreateEvent;
      expect(sent.phoneNumber, '9876543210');
      expect(visited.last, ('/verifyOtpScreen', '9876543210'));
      expect(find.text('Code sent to 98•••••210'), findsOneWidget);
    });

    testWidgets('loading state blocks duplicate requests', (tester) async {
      final bloc = await pumpApp(tester, initialRoute: '/loginScreen');
      bloc.reply = (_) => null; // still sending
      await tester.enterText(phoneField, '9876543210');
      await tester.tap(getOtpButton);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(getOtpButton, warnIfMissed: false);
      await tester.pump();
      expect(bloc.events, hasLength(1));
    });

    testWidgets('server failure shows an inline error and allows retry', (
      tester,
    ) async {
      final bloc = await pumpApp(tester, initialRoute: '/loginScreen');
      bloc.reply = (_) => UserStatus.otpsendingfail;
      await tester.enterText(phoneField, '9876543210');
      await tester.tap(getOtpButton);
      await tester.pump();
      expect(find.text('OTP send failed'), findsOneWidget);
      expect(visited.last.$1, '/loginScreen');

      bloc.reply = (_) => UserStatus.otpsended;
      await tester.tap(getOtpButton);
      await settle(tester);
      expect(visited.last.$1, '/verifyOtpScreen');
    });

    testWidgets('no response: network error after the timeout', (tester) async {
      final bloc = await pumpApp(tester, initialRoute: '/loginScreen');
      bloc.reply = (_) => null;
      await tester.enterText(phoneField, '9876543210');
      await tester.tap(getOtpButton);
      await tester.pump(kAuthRequestTimeout + const Duration(seconds: 1));
      expect(find.textContaining("couldn't reach the server"), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('OTP-sent caused elsewhere does not push a screen', (
      tester,
    ) async {
      final bloc = await pumpApp(tester, initialRoute: '/loginScreen');
      bloc.push(UserStatus.otpsended);
      await settle(tester);
      expect(visited.map((v) => v.$1), ['/loginScreen']);
    });
  });

  group('otp', () {
    Future<FakeUserBloc> pumpOtp(WidgetTester tester) => pumpApp(
      tester,
      initialRoute: '/verifyOtpScreen',
      initialArgs: '9876543210',
    );

    testWidgets('verify enabled only with 6 digits; sends phone + code', (
      tester,
    ) async {
      final bloc = await pumpOtp(tester);
      expect(tester.widget<FilledButton>(verifyButton).onPressed, isNull);

      await tester.enterText(find.byType(Pinput), '12345');
      await tester.pump();
      expect(tester.widget<FilledButton>(verifyButton).onPressed, isNull);

      bloc.reply = (_) => UserStatus.otpverified;
      await tester.enterText(find.byType(Pinput), '123456');
      await tester.pump();
      await tester.tap(verifyButton);
      await settle(tester);

      final sent = bloc.events.single as VerifyOtpEvent;
      expect((sent.phoneNumber, sent.otp), ('9876543210', '123456'));
      expect(visited.last.$1, '/dashboardScreen');
      // Stack cleared: no way back to the OTP screen.
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
    });

    testWidgets('wrong code: inline error, can edit and retry', (tester) async {
      final bloc = await pumpOtp(tester);
      bloc.reply = (_) => UserStatus.otpverifiedfail;
      await tester.enterText(find.byType(Pinput), '000000');
      await tester.pump();
      await tester.tap(verifyButton);
      await tester.pump();
      expect(find.text('OTP verification failed'), findsOneWidget);
      expect(
        find.text('Check the code, or request a new one.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(Pinput), '12345');
      await tester.pump();
      expect(find.text('OTP verification failed'), findsNothing);
    });

    testWidgets('resend after countdown; failure re-enables it', (
      tester,
    ) async {
      final bloc = await pumpOtp(tester);
      expect(find.text('Resend OTP in 1:00'), findsOneWidget);
      expect(find.text('Resend code'), findsNothing);

      await tester.pump(const Duration(seconds: 60));
      expect(find.text('Resend code'), findsOneWidget);

      bloc.reply = (_) => UserStatus.otpsendingfail;
      await tester.tap(find.text('Resend code'));
      await tester.pump();
      expect((bloc.events.single as UserCreateEvent).phoneNumber, '9876543210');
      expect(find.text('OTP send failed'), findsOneWidget);
      expect(find.text('Resend code'), findsOneWidget);

      bloc.reply = (_) => UserStatus.otpsended;
      // The error message pushed Resend further down.
      await tester.ensureVisible(find.text('Resend code'));
      await tester.pump();
      await tester.tap(find.text('Resend code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(bloc.events, hasLength(2));
      expect(find.text('A new code has been sent'), findsOneWidget);
      expect(find.textContaining('Resend OTP in'), findsOneWidget);
      // Stays on this screen; no duplicate OTP screen pushed.
      expect(visited.map((v) => v.$1), ['/verifyOtpScreen']);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('back and "Change number" return to login', (tester) async {
      final bloc = await pumpApp(tester, initialRoute: '/loginScreen');
      bloc.reply = (_) => UserStatus.otpsended;
      await tester.enterText(phoneField, '9876543210');
      await tester.tap(getOtpButton);
      await settle(tester);

      await tester.tap(find.text('Change number'));
      await settle(tester);
      expect(find.text('Welcome to Kumbh Path'), findsOneWidget);

      await tester.tap(getOtpButton);
      await settle(tester);
      await tester.tap(find.byType(BackButtonIcon));
      await settle(tester);
      expect(find.text('Welcome to Kumbh Path'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final route in ['/launchScreen', '/loginScreen', '/verifyOtpScreen']) {
      for (final locale in const [Locale('en'), Locale('hi'), Locale('mr')]) {
        for (final brightness in Brightness.values) {
          for (final scale in AppFontScale.values) {
            testWidgets(
              'no overflow: $route ${locale.languageCode} ${brightness.name} '
              '${scale.name}, 1.3x device, 320x568'
              '${route == '/launchScreen' ? '' : ' + keyboard'}',
              (tester) async {
                await pumpApp(
                  tester,
                  initialRoute: route,
                  initialArgs: '9876543210',
                  // Keep the launch screen up for the check.
                  checkLogin: () => Completer<bool>().future,
                  locale: locale,
                  brightness: brightness,
                  fontScale: scale,
                  deviceScale: 1.3,
                  size: const Size(320, 568),
                  keyboard: route == '/launchScreen' ? 0 : 260,
                );
                await tester.pump(const Duration(milliseconds: 800));
                final scrollables = find.byType(Scrollable);
                if (scrollables.evaluate().isNotEmpty) {
                  await tester.drag(scrollables.first, const Offset(0, -1500));
                  await tester.pump();
                }
                expect(tester.takeException(), isNull);
              },
            );
          }
        }
      }
    }

    testWidgets('wide screens place the photo beside the form', (tester) async {
      await pumpApp(
        tester,
        initialRoute: '/loginScreen',
        size: const Size(1200, 800),
      );
      expect(tester.takeException(), isNull);
      final field = tester.getRect(phoneField);
      expect(field.left, greaterThan(600));
    });

    testWidgets('keyboard open: Get OTP stays reachable', (tester) async {
      await pumpApp(
        tester,
        initialRoute: '/loginScreen',
        size: const Size(360, 640),
        keyboard: 300,
      );
      await tester.showKeyboard(phoneField);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      final button = tester.getRect(getOtpButton);
      expect(button.bottom, lessThanOrEqualTo(640 - 300));
    });
  });
}
