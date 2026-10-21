import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads translations straight from assets/translations so tests see real
/// Hindi / Marathi labels.
class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    return json.decode(await file.readAsString()) as Map<String, dynamic>;
  }
}

/// A tab screen with a counter, to detect whether state survives.
class _TabScreen extends StatefulWidget {
  const _TabScreen(this.index, {this.showNav = true});
  final int index;
  final bool showNav;

  @override
  State<_TabScreen> createState() => _TabScreenState();
}

class _TabScreenState extends State<_TabScreen> {
  int taps = 0;

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      showDefaultBottom: widget.showNav,
      ctx: widget.index,
      appBar: AppAppBar(title: 'Screen ${widget.index}'),
      body: Center(
        child: TextButton(
          key: ValueKey('counter-${widget.index}'),
          onPressed: () => setState(() => taps++),
          child: Text('taps ${widget.index}: $taps'),
        ),
      ),
    );
  }
}

Map<String, WidgetBuilder> _routes() => {
  '/dashboardScreen': (_) => const _TabScreen(0),
  '/aichat': (_) => const _TabScreen(1, showNav: false),
  '/shahiEvents': (_) => const _TabScreen(2),
  '/journal': (_) => const _TabScreen(3),
  '/setting': (_) => const _TabScreen(4, showNav: false),
  '/nearTemples': (_) => const _TabScreen(0),
};

Future<void> _pumpShell(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  Size size = const Size(360, 720),
  Brightness brightness = Brightness.light,
  AppFontScale fontScale = AppFontScale.standard,
  double deviceScale = 1.0,
  String initialRoute = '/dashboardScreen',
}) async {
  await tester.runAsync(EasyLocalization.ensureInitialized);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
      path: 'assets/translations',
      assetLoader: const _FileAssetLoader(),
      fallbackLocale: const Locale('en'),
      startLocale: locale,
      saveLocale: false,
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
              navigatorObservers: [AppNavigation.observer],
              initialRoute: initialRoute,
              routes: _routes(),
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
  );
  // Translation loading is real file I/O.
  for (var i = 0; i < 20 && find.byType(Navigator).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

NavigatorState _nav(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator));

int _selected(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Tab switching', () {
    testWidgets('returns to an open tab with its state intact', (tester) async {
      await _pumpShell(tester);
      expect(find.text('Home'), findsOneWidget);

      // Change Home's state.
      await tester.tap(find.byKey(const ValueKey('counter-0')));
      await tester.pump();
      expect(find.text('taps 0: 1'), findsOneWidget);

      // Home -> Events -> Journal
      await tester.tap(find.text('Events'));
      await tester.pumpAndSettle();
      expect(_selected(tester), 2);
      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();
      expect(_selected(tester), 3);

      // Back to Home: pops to the existing screen instead of a new one.
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('taps 0: 1'), findsOneWidget);
      expect(_nav(tester).canPop(), isFalse, reason: 'no duplicate routes');
    });

    testWidgets('tapping the current tab does nothing', (tester) async {
      await _pumpShell(tester);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(_nav(tester).canPop(), isFalse);
    });

    testWidgets('system back still pops in history order', (tester) async {
      await _pumpShell(tester);
      await tester.tap(find.text('Events'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_selected(tester), 2);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_selected(tester), 0);
    });

    testWidgets('routes without a nav bar are pushed and pop back', (
      tester,
    ) async {
      await _pumpShell(tester);
      await tester.tap(find.text('AI Chat'));
      await tester.pumpAndSettle();
      expect(find.text('Screen 1'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BackButtonIcon), findsOneWidget);

      await tester.tap(find.byType(BackButtonIcon));
      await tester.pumpAndSettle();
      expect(find.text('Screen 0'), findsOneWidget);
    });

    testWidgets('sub-screens of Home highlight Home and return to it', (
      tester,
    ) async {
      await _pumpShell(tester);
      _nav(tester).pushNamed('/nearTemples');
      await tester.pumpAndSettle();
      expect(_selected(tester), 0);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(_nav(tester).canPop(), isFalse);
    });
  });

  group('Responsive shell', () {
    testWidgets('uses a navigation rail on wide screens', (tester) async {
      await _pumpShell(tester, size: const Size(1024, 768));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.tap(find.text('Events'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        2,
      );
    });

    for (final locale in const [Locale('en'), Locale('hi'), Locale('mr')]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'no overflow at 320dp, ${locale.languageCode}, ${brightness.name}, '
          'Large + device 1.3x',
          (tester) async {
            await _pumpShell(
              tester,
              locale: locale,
              size: const Size(320, 640),
              brightness: brightness,
              fontScale: AppFontScale.large,
              deviceScale: 1.3,
            );
            expect(tester.takeException(), isNull);
            expect(find.byType(NavigationBar), findsOneWidget);
          },
        );
      }
    }

    testWidgets('localized labels are shown', (tester) async {
      await _pumpShell(tester, locale: const Locale('mr'));
      expect(find.text('जर्नल'), findsOneWidget);
      expect(find.text('प्रोफाइल'), findsOneWidget);
    });
  });

  group('System bars', () {
    testWidgets('overlay style follows the theme', (tester) async {
      final light = AppTheme.systemOverlayStyle(Brightness.light);
      final dark = AppTheme.systemOverlayStyle(Brightness.dark);
      expect(light.statusBarIconBrightness, Brightness.dark);
      expect(dark.statusBarIconBrightness, Brightness.light);
      expect(light.statusBarColor, Colors.transparent);
      expect(dark.systemNavigationBarColor, AppColors.dark.background);

      await _pumpShell(tester, brightness: Brightness.dark);
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find
            .descendant(
              of: find.byType(MainLayout),
              matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
            )
            .first,
      );
      expect(
        region.value.systemNavigationBarColor,
        AppColors.dark.navigationSurface,
      );
    });
  });
}
