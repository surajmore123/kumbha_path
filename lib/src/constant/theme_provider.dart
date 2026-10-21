import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/app_theme.dart';
import 'package:kumbha_path/src/constant/design_system/app_typography.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeOption {
  light,
  dark,
  system;

  static const AppThemeOption fallback = AppThemeOption.system;

  /// Parses a persisted value. Unknown or missing values fall back to
  /// [AppThemeOption.system].
  static AppThemeOption fromName(String? name) {
    for (final option in values) {
      if (option.name == name) return option;
    }
    return fallback;
  }
}

/// Single source of truth for appearance preferences: theme mode and global
/// font scale.
///
/// Created once in `main()` via [ThemeProvider.load] (so the saved values are
/// known before the first frame) and exposed with Provider. Read it with
/// `context.watch<ThemeProvider>()` to rebuild on change, or
/// `context.read<ThemeProvider>()` to call setters.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({
    AppThemeOption initialTheme = AppThemeOption.fallback,
    AppFontScale initialFontScale = AppFontScale.fallback,
    SharedPreferences? preferences,
  }) : _theme = initialTheme,
       _fontScale = initialFontScale,
       _preferences = preferences;

  static const String themeModeKey = 'kp_theme_mode';
  static const String fontScaleKey = 'kp_font_scale';

  /// Restores saved preferences. Never throws: if storage is unavailable or
  /// values are invalid, defaults (System, 1.00) are used.
  static Future<ThemeProvider> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return ThemeProvider(
        initialTheme: AppThemeOption.fromName(prefs.getString(themeModeKey)),
        initialFontScale: AppFontScale.fromName(prefs.getString(fontScaleKey)),
        preferences: prefs,
      );
    } catch (error) {
      debugPrint('ThemeProvider: could not restore preferences ($error)');
      return ThemeProvider();
    }
  }

  AppThemeOption _theme;
  AppFontScale _fontScale;
  SharedPreferences? _preferences;

  /// The user's selection, including [AppThemeOption.system].
  AppThemeOption get currentTheme => _theme;

  /// Value for `MaterialApp.themeMode`. In System mode Flutter follows the
  /// platform brightness and reacts to changes automatically.
  ThemeMode get themeMode {
    switch (_theme) {
      case AppThemeOption.light:
        return ThemeMode.light;
      case AppThemeOption.dark:
        return ThemeMode.dark;
      case AppThemeOption.system:
        return ThemeMode.system;
    }
  }

  ThemeData get lightTheme => AppTheme.light;
  ThemeData get darkTheme => AppTheme.dark;

  /// The selected font-scale preset.
  AppFontScale get fontScalePreset => _fontScale;

  /// The selected font multiplier (0.90 / 1.00 / 1.15). Informational only:
  /// it is already applied globally through `MediaQuery.textScaler`, so do
  /// not multiply font sizes by it.
  double get fontScale => _fontScale.factor;

  Future<void> setTheme(AppThemeOption option) async {
    if (option == _theme) return;
    _theme = option;
    notifyListeners();
    await _write(themeModeKey, option.name);
  }

  Future<void> setFontScale(AppFontScale scale) async {
    if (scale == _fontScale) return;
    _fontScale = scale;
    notifyListeners();
    await _write(fontScaleKey, scale.name);
  }

  Future<void> _write(String key, String value) async {
    try {
      final prefs = _preferences ??= await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (error) {
      // The in-memory value still applies for this session.
      debugPrint('ThemeProvider: could not save $key ($error)');
    }
  }
}
