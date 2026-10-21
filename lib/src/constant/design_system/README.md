# Kumbh Path design system

One import for feature code:

```dart
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
```

| File | Owns |
| --- | --- |
| `../app_color.dart` | `AppPalette` (raw hues), `AppColorTokens`, `AppColors.light` / `.dark`: the single source of every color. Legacy globals above the banner are frozen. |
| `app_theme.dart` | `AppTheme.light` / `.dark`: the only `ThemeData` in the app, including component themes. |
| `app_theme_extensions.dart` | `AppSemanticColors` (success / warning / info / gold / border / divider / card / input / dialog / nav) and `context.colorScheme`, `context.textTheme`, `context.semanticColors`, `context.isDarkTheme`. |
| `app_typography.dart` | Type scale, `AppFontScale` presets, and `AppFontScaleScope`, which applies the font scale. |
| `app_spacing.dart` / `app_radius.dart` / `app_elevation.dart` | Layout tokens. These don't change with font scale. |
| `../theme_provider.dart` | `ThemeProvider`: theme mode + font scale, persisted in SharedPreferences. |
| `../app_responsive.dart` | Screen-size breakpoints and helpers (layout only). |

## Rules for feature screens

1. **Colors:** use `context.colorScheme.*` or `context.semanticColors.*`. Don't use `Color(0x...)`, `Colors.*` (except `transparent`) or the legacy globals (`textColor`, `buttonColor`, `whiteColor`, ...).
2. **Text:** use `context.textTheme.<role>` and adjust only weight or color with `copyWith`. Don't pass a literal `fontSize`, don't use width-based scaling, and don't use `AppTextTheme`.
3. **Font scale is already applied.** `AppFontScaleScope` in `MaterialApp.builder` composes the user's preset with the device accessibility scaler, once, for all text. Never multiply by `ThemeProvider.fontScale` and never override `MediaQuery.textScaler`.
4. **Spacing / radius / elevation:** use `AppSpacing`, `AppRadius` and `AppElevation`. Don't use magic numbers.
5. **Theme state:** call `context.read<ThemeProvider>().setTheme(AppThemeOption.x)` or `.setFontScale(AppFontScale.x)`. Both persist and update the app immediately. Don't keep a local copy of the selection; read `currentTheme` / `fontScalePreset` instead.

## Migrating a folder (later phases)

For each file in the folder:

- Replace hardcoded colors with the semantic role they mean (for example, grey caption → `onSurfaceVariant`, card bg → `semanticColors.cardSurface`, green "live" → `semanticColors.success`).
- Replace `TextStyle(fontSize: n, ...)` and `isMobile ? 14 : 15` font sizes with the closest `textTheme` role.
- Replace `buildThemeGradient` / legacy gradients with flat `colorScheme.primary` or a container role, unless the design calls for a gradient.
- Check both appearances and all three font presets.
- When no file references a legacy global any more, delete it from `app_color.dart`.
