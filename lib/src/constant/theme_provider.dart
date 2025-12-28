import 'package:flutter/material.dart';

enum AppThemeOption { light, dark, system }

class ThemeProvider extends ChangeNotifier {
  AppThemeOption currentTheme = AppThemeOption.system;

  ThemeMode get themeMode {
    switch (currentTheme) {
      case AppThemeOption.light:
        return ThemeMode.light;
      case AppThemeOption.dark:
        return ThemeMode.dark;
      case AppThemeOption.system:
      default:
        return ThemeMode.light;
    }
  }

  void setTheme(AppThemeOption option) {
    currentTheme = option;
    notifyListeners();
  }
}
