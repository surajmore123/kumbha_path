import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

const _longMarathi =
    'कुंभमेळ्यातील पवित्र स्नानाच्या वेळा आणि घाटांवरील गर्दीची माहिती पहा';

/// Pumps [child] under the real app themes with the given font preset and
/// device text scale, on a small phone-sized surface.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  AppFontScale fontScale = AppFontScale.standard,
  double deviceScale = 1.0,
  Map<String, WidgetBuilder>? routes,
}) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode:
          brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      routes: routes ?? const {},
      builder:
          (context, appChild) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(deviceScale)),
            child: AppFontScaleScope(fontScale: fontScale, child: appChild),
          ),
      home: child,
    ),
  );
}

Widget _gallery() {
  return Scaffold(
    appBar: const AppAppBar(title: _longMarathi, subtitle: _longMarathi),
    body: ListView(
      padding: AppSpacing.page,
      children: [
        const AppSectionHeader(
          title: _longMarathi,
          subtitle: _longMarathi,
          actionLabel: 'सर्व पहा',
          onAction: _noop,
        ),
        AppSpacing.gapLg,
        const AppButton(
          label: _longMarathi,
          onPressed: _noop,
          leadingIcon: Icons.place,
        ),
        AppSpacing.gapMd,
        const AppButton.secondary(label: _longMarathi, onPressed: _noop),
        AppSpacing.gapMd,
        const AppButton.outlined(
          label: 'Cancel',
          onPressed: null,
          expand: false,
        ),
        AppSpacing.gapMd,
        const AppCard(onTap: _noop, child: Text(_longMarathi)),
        AppSpacing.gapMd,
        const AppTextField(
          label: _longMarathi,
          hint: _longMarathi,
          errorText: _longMarathi,
          prefixIcon: Icons.phone,
        ),
        const SizedBox(
          height: 420,
          child: AppErrorView(message: _longMarathi, onRetry: _noop),
        ),
        const SizedBox(
          height: 420,
          child: AppEmptyState(
            message: _longMarathi,
            actionLabel: _longMarathi,
            onAction: _noop,
          ),
        ),
        const AppLoading(message: _longMarathi),
      ],
    ),
    bottomNavigationBar: AppBottomNavigation(
      currentIndex: 2,
      onDestinationSelected: (_) {},
    ),
  );
}

void _noop() {}

void main() {
  group('Layout robustness', () {
    for (final brightness in Brightness.values) {
      for (final scale in AppFontScale.values) {
        for (final device in [1.0, 1.3]) {
          testWidgets(
            'no overflow: ${brightness.name}, ${scale.name}, device x$device',
            (tester) async {
              await _pump(
                tester,
                _gallery(),
                brightness: brightness,
                fontScale: scale,
                deviceScale: device,
              );
              // Scroll through the whole list so every item lays out.
              await tester.drag(find.byType(ListView), const Offset(0, -3000));
              await tester.pump();
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });

  group('AppButton', () {
    testWidgets('loading ignores taps and keeps enabled colors', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        Scaffold(
          body: AppButton(
            label: 'Get OTP',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(taps, 0);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final bg = button.style!.backgroundColor!.resolve({WidgetState.disabled});
      expect(bg, AppColors.light.primary);
    });

    testWidgets('meets the minimum touch target', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: Center(
            child: AppButton(label: 'OK', onPressed: () {}, expand: false),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(AppSpacing.minTouchTarget),
      );
    });
  });

  group('AppTextField', () {
    testWidgets('runs Form validation and toggles obscured text', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await _pump(
        tester,
        Scaffold(
          body: Form(
            key: formKey,
            child: AppTextField(
              label: 'Password',
              obscureText: true,
              validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);

      EditableText editable() =>
          tester.widget<EditableText>(find.byType(EditableText));
      expect(editable().obscureText, isTrue);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(editable().obscureText, isFalse);

      await tester.enterText(find.byType(TextFormField), 'secret');
      expect(formKey.currentState!.validate(), isTrue);
    });
  });

  group('AppAppBar', () {
    testWidgets('shows back only when the route can pop', (tester) async {
      await _pump(
        tester,
        const Scaffold(appBar: AppAppBar(title: 'Home')),
        routes: {
          '/next': (_) => const Scaffold(appBar: AppAppBar(title: 'Temple')),
        },
      );
      expect(find.byType(BackButtonIcon), findsNothing);

      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pushNamed('/next');
      await tester.pumpAndSettle();
      expect(find.byType(BackButtonIcon), findsOneWidget);

      await tester.tap(find.byType(BackButtonIcon));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });
  });

  group('AppBottomNavigation in MainLayout', () {
    testWidgets('pushes the tapped route and ignores the current tab', (
      tester,
    ) async {
      final pushed = <String>[];
      await _pump(
        tester,
        MainLayout(showDefaultBottom: true, ctx: 0, body: const SizedBox()),
        routes: {
          for (final d in AppBottomNavigation.destinations)
            if (d.route != '/')
              d.route: (context) {
                pushed.add(d.route);
                return const Scaffold();
              },
        },
      );
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.tap(find.byIcon(Icons.home_rounded));
      await tester.pumpAndSettle();
      expect(pushed, isEmpty);

      await tester.tap(find.byIcon(Icons.event_outlined));
      await tester.pumpAndSettle();
      expect(pushed, ['/shahiEvents']);
    });

    testWidgets('hidden when showDefaultBottom is false', (tester) async {
      await _pump(tester, MainLayout(ctx: 4, body: const SizedBox()));
      expect(find.byType(NavigationBar), findsNothing);
    });
  });
}
