import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _luminance(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Mirrors the MaterialApp wiring in lib/main.dart.
Widget _app(ThemeProvider provider, {required Widget home}) {
  return ChangeNotifierProvider<ThemeProvider>.value(
    value: provider,
    child: Consumer<ThemeProvider>(
      builder:
          (context, p, _) => MaterialApp(
            theme: p.lightTheme,
            darkTheme: p.darkTheme,
            themeMode: p.themeMode,
            builder:
                (context, child) => AppFontScaleScope(
                  fontScale: p.fontScalePreset,
                  child: child,
                ),
            home: home,
          ),
    ),
  );
}

void main() {
  group('ThemeProvider persistence', () {
    test('defaults to System and 1.00 when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = await ThemeProvider.load();
      expect(provider.currentTheme, AppThemeOption.system);
      expect(provider.themeMode, ThemeMode.system);
      expect(provider.fontScalePreset, AppFontScale.standard);
      expect(provider.fontScale, 1.00);
    });

    test('invalid stored values fall back safely', () async {
      SharedPreferences.setMockInitialValues({
        ThemeProvider.themeModeKey: 'sepia',
        ThemeProvider.fontScaleKey: 'huge',
      });
      final provider = await ThemeProvider.load();
      expect(provider.currentTheme, AppThemeOption.system);
      expect(provider.fontScalePreset, AppFontScale.standard);
    });

    test('selections persist and are restored', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = await ThemeProvider.load();
      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.setTheme(AppThemeOption.dark);
      await provider.setFontScale(AppFontScale.large);
      expect(notifications, 2);
      expect(provider.themeMode, ThemeMode.dark);

      // Setting the same value is a no-op.
      await provider.setTheme(AppThemeOption.dark);
      expect(notifications, 2);

      final restored = await ThemeProvider.load();
      expect(restored.currentTheme, AppThemeOption.dark);
      expect(restored.fontScalePreset, AppFontScale.large);
    });

    test('font scale presets', () {
      expect(AppFontScale.small.factor, 0.90);
      expect(AppFontScale.standard.factor, 1.00);
      expect(AppFontScale.large.factor, 1.15);
    });
  });

  group('Font scaling', () {
    test('composes with the device scaler exactly once', () {
      const device = TextScaler.linear(1.3);
      final once = AppTypography.resolveTextScaler(device, AppFontScale.large);
      final twice = AppTypography.resolveTextScaler(once, AppFontScale.large);
      expect(once.scale(10), closeTo(10 * 1.3 * 1.15, 1e-9));
      expect(twice, once);
      expect(
        AppTypography.resolveTextScaler(device, AppFontScale.standard),
        device,
      );
    });

    testWidgets('applies globally and reacts without restart', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final provider = await ThemeProvider.load();
      late BuildContext ctx;
      await tester.pumpWidget(
        _app(
          provider,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Text('नमस्कार');
            },
          ),
        ),
      );

      final base = MediaQuery.textScalerOf(ctx).scale(14);
      await provider.setFontScale(AppFontScale.large);
      await tester.pump();
      expect(
        MediaQuery.textScalerOf(ctx).scale(14),
        closeTo(base * 1.15, 1e-9),
      );

      // Theme styles stay unscaled base sizes, so nothing scales twice.
      expect(
        Theme.of(ctx).textTheme.bodyMedium!.fontSize,
        AppTypography.bodyMediumSize,
      );
    });
  });

  group('Theme modes', () {
    testWidgets('light, dark and system reach MaterialApp', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final provider = await ThemeProvider.load();
      late BuildContext ctx;
      await tester.pumpWidget(
        _app(
          provider,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpAndSettle();
      expect(Theme.of(ctx).brightness, Brightness.dark, reason: 'system');

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(Theme.of(ctx).brightness, Brightness.light, reason: 'system');

      await provider.setTheme(AppThemeOption.dark);
      await tester.pumpAndSettle();
      expect(Theme.of(ctx).brightness, Brightness.dark);
      expect(ctx.semanticColors.success, AppColors.dark.success);

      await provider.setTheme(AppThemeOption.light);
      await tester.pumpAndSettle();
      expect(Theme.of(ctx).brightness, Brightness.light);
      expect(ctx.colorScheme.primary, AppColors.light.primary);
    });
  });

  group('Color accessibility (WCAG AA 4.5:1)', () {
    for (final tokens in [AppColors.light, AppColors.dark]) {
      final name = tokens.brightness.name;
      final pairs = <String, (Color, Color)>{
        'onPrimary/primary': (tokens.onPrimary, tokens.primary),
        'onSecondary/secondary': (tokens.onSecondary, tokens.secondary),
        'onTertiary/tertiary': (tokens.onTertiary, tokens.tertiary),
        'onSurface/background': (tokens.onSurface, tokens.background),
        'onSurface/surface': (tokens.onSurface, tokens.surface),
        'onSurfaceVariant/surface': (tokens.onSurfaceVariant, tokens.surface),
        'onSurfaceVariant/inputFill': (
          tokens.onSurfaceVariant,
          tokens.inputFill,
        ),
        'primary/background': (tokens.primary, tokens.background),
        'error/surface': (tokens.error, tokens.surface),
        'onError/error': (tokens.onError, tokens.error),
        'success/surface': (tokens.success, tokens.surface),
        'onSuccess/success': (tokens.onSuccess, tokens.success),
        'warning/surface': (tokens.warning, tokens.surface),
        'onWarning/warning': (tokens.onWarning, tokens.warning),
        'info/surface': (tokens.info, tokens.surface),
        'onInfo/info': (tokens.onInfo, tokens.info),
        'onPrimaryContainer/primaryContainer': (
          tokens.onPrimaryContainer,
          tokens.primaryContainer,
        ),
        'onSurface/navigationIndicator': (
          tokens.onSurface,
          tokens.navigationIndicator,
        ),
      };
      pairs.forEach((label, pair) {
        test('$name $label', () {
          expect(_contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        });
      });
    }
  });
}
