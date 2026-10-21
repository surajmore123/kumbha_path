import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_bloc.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_event.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/models/user_profile.dart';
import 'package:kumbha_path/src/modules/setting/setting.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ------------------------------------------------------------------ fakes

class FakeUserBloc extends UserBloc {
  final List<UserEvent> events = [];
  bool loadFails = false;
  bool saveFails = false;
  bool photoFails = false;
  UserData profile = const UserData(
    userId: 'u1',
    phoneNumber: '9876543210',
    fullName: 'Savitri Deshmukh',
    email: 'savitri@example.com',
    profileUrl: '',
  );

  // ignore: invalid_use_of_visible_for_testing_member
  void _emit(UserState s) => emit(s);

  @override
  void add(UserEvent event) {
    events.add(event);
    switch (event) {
      case ProfileGetEvent():
        _emit(state.copyWith(status: UserStatus.loading));
        _emit(
          loadFails
              ? state.copyWith(status: UserStatus.failure)
              : state.copyWith(
                status: UserStatus.profileLoaded,
                profileData: profile,
              ),
        );
      case UserProfileCreateEvent(:final fullName, :final email):
        _emit(state.copyWith(status: UserStatus.sending));
        if (saveFails) {
          _emit(state.copyWith(status: UserStatus.profileUpdatedFailure));
        } else {
          profile = UserData(
            userId: profile.userId,
            phoneNumber: profile.phoneNumber,
            fullName: fullName,
            email: email,
            profileUrl: profile.profileUrl,
          );
          _emit(state.copyWith(status: UserStatus.profileUpdatedSuccess));
        }
      case ImageAddEvent():
        _emit(state.copyWith(status: UserStatus.sending));
        _emit(
          state.copyWith(
            status:
                photoFails
                    ? UserStatus.profileImageUploadFailure
                    : UserStatus.profileImageUploadSuccess,
          ),
        );
      default:
        break;
    }
  }

  List<T> of<T>() => events.whereType<T>().toList();
}

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    return json.decode(await file.readAsString()) as Map<String, dynamic>;
  }
}

// ---------------------------------------------------------------- harness

class Harness {
  final bloc = FakeUserBloc();
  late ThemeProvider theme;
  bool? notifications = false;
  int settingsOpened = 0;
  int tokenDeletes = 0;
  XFile? photo;
}

final List<String> pushed = [];

/// Same app wiring as lib/main.dart: ThemeProvider → MaterialApp theme,
/// darkTheme, themeMode and the global font scale.
Future<Harness> pumpSettings(
  WidgetTester tester, {
  Harness? harness,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  double deviceScale = 1.0,
  Map<String, Object> prefs = const {},
}) async {
  final h = harness ?? Harness();
  pushed.clear();
  SharedPreferences.setMockInitialValues(prefs);
  await tester.runAsync(EasyLocalization.ensureInitialized);
  h.theme = (await tester.runAsync(ThemeProvider.load))!;
  addTearDown(h.bloc.close);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    EasyLocalization(
      key: UniqueKey(),
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
      path: 'assets/translations',
      assetLoader: const _FileAssetLoader(),
      fallbackLocale: const Locale('en'),
      startLocale: locale,
      child: ChangeNotifierProvider<ThemeProvider>.value(
        value: h.theme,
        child: BlocProvider<UserBloc>.value(
          value: h.bloc,
          child: Consumer<ThemeProvider>(
            builder:
                (context, theme, _) => MaterialApp(
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  theme: theme.lightTheme,
                  darkTheme: theme.darkTheme,
                  themeMode: theme.themeMode,
                  builder:
                      (context, child) => MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: TextScaler.linear(deviceScale)),
                        child: AppFontScaleScope(
                          fontScale: theme.fontScalePreset,
                          child: child,
                        ),
                      ),
                  onGenerateInitialRoutes:
                      (_) => [
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/setting'),
                          builder:
                              (_) => Setting(
                                notificationStatus: () async => h.notifications,
                                openSystemSettings: () async {
                                  h.settingsOpened++;
                                  return true;
                                },
                                deleteToken: () async => h.tokenDeletes++,
                                pickImage: (_) async => h.photo,
                              ),
                        ),
                      ],
                  onGenerateRoute: (s) {
                    pushed.add(s.name!);
                    return MaterialPageRoute(
                      settings: s,
                      builder: (_) => Scaffold(body: Text('page ${s.name}')),
                    );
                  },
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
  await settle(tester);
  return h;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await settle(tester);
}

BuildContext ctx(WidgetTester tester) => tester.element(find.byType(Setting));

void main() {
  tearDown(() => LanguageHelper.changeLanguage('en'));

  testWidgets('only working controls: no fake notification toggles', (
    tester,
  ) async {
    await pumpSettings(tester);
    for (final t in [
      'Profile',
      'Appearance',
      'Language',
      'Notifications',
      'Account',
    ]) {
      await scrollTo(tester, find.text(t));
    }
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Real-time alerts'), findsNothing);
  });

  group('appearance', () {
    testWidgets('theme: shows current, applies instantly, persists', (
      tester,
    ) async {
      final h = await pumpSettings(
        tester,
        prefs: {ThemeProvider.themeModeKey: 'light'},
      );
      SegmentedButton<AppThemeOption> seg() =>
          tester.widget<SegmentedButton<AppThemeOption>>(
            find.byType(SegmentedButton<AppThemeOption>),
          );
      expect(seg().selected, {AppThemeOption.light});

      await tester.tap(find.text('Dark'));
      await settle(tester);
      expect(Theme.of(ctx(tester)).brightness, Brightness.dark);
      expect(h.theme.themeMode, ThemeMode.dark);
      final saved = await tester.runAsync(SharedPreferences.getInstance);
      expect(saved!.getString(ThemeProvider.themeModeKey), 'dark');

      await tester.tap(find.text('System'));
      await settle(tester);
      expect(h.theme.themeMode, ThemeMode.system);
      expect(seg().selected, {AppThemeOption.system});
    });

    testWidgets(
      'text size: applies globally once, persists, keeps device scaling',
      (tester) async {
        final h = await pumpSettings(tester, deviceScale: 1.2);
        expect(
          MediaQuery.textScalerOf(ctx(tester)).scale(10),
          closeTo(12, 1e-9),
        );
        await scrollTo(tester, find.text('Large'));
        await tester.tap(find.text('Large'));
        await settle(tester);
        expect(h.theme.fontScalePreset, AppFontScale.large);
        expect(
          MediaQuery.textScalerOf(ctx(tester)).scale(10),
          closeTo(10 * 1.2 * 1.15, 1e-9),
        );
        final saved = await tester.runAsync(SharedPreferences.getInstance);
        expect(saved!.getString(ThemeProvider.fontScaleKey), 'large');
        // Icons are not text and don't scale.
        expect(IconTheme.of(ctx(tester)).size, 24);
      },
    );

    testWidgets('restored preferences are shown', (tester) async {
      await pumpSettings(
        tester,
        prefs: {
          ThemeProvider.themeModeKey: 'dark',
          ThemeProvider.fontScaleKey: 'small',
        },
      );
      expect(
        tester
            .widget<SegmentedButton<AppThemeOption>>(
              find.byType(SegmentedButton<AppThemeOption>),
            )
            .selected,
        {AppThemeOption.dark},
      );
      await scrollTo(tester, find.byType(SegmentedButton<AppFontScale>));
      expect(
        tester
            .widget<SegmentedButton<AppFontScale>>(
              find.byType(SegmentedButton<AppFontScale>),
            )
            .selected,
        {AppFontScale.small},
      );
    });
  });

  group('language', () {
    testWidgets('switches both translation systems and is saved', (
      tester,
    ) async {
      await pumpSettings(tester);
      await scrollTo(tester, find.text('मराठी'));
      await tester.tap(find.text('मराठी'));
      // Translations load with real file I/O.
      for (var i = 0; i < 20 && find.text('सेटिंग्ज').evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(find.text('सेटिंग्ज'), findsOneWidget); // screen re-translated
      expect(LanguageHelper.currentLang.value, 'mr');
      final saved = await tester.runAsync(SharedPreferences.getInstance);
      expect(saved!.getKeys().map(saved.get), contains('mr'));
    });
  });

  group('profile', () {
    testWidgets('shows stored profile; edit + save uses the existing event', (
      tester,
    ) async {
      final h = await pumpSettings(tester);
      expect(h.bloc.of<ProfileGetEvent>(), hasLength(1));
      expect(find.text('Savitri Deshmukh'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);

      await tester.tap(find.text('Edit profile'));
      await settle(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Savitri D.');
      await scrollTo(tester, find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await settle(tester);

      final e = h.bloc.of<UserProfileCreateEvent>().single;
      expect((e.fullName, e.email), ('Savitri D.', 'savitri@example.com'));
      expect(find.text('Profile updated'), findsOneWidget);
      expect(h.bloc.of<ProfileGetEvent>(), hasLength(2)); // refreshed
      expect(find.text('Savitri D.'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('save failure keeps the form; cancel restores values', (
      tester,
    ) async {
      final h = Harness()..bloc.saveFails = true;
      await pumpSettings(tester, harness: h);
      await tester.tap(find.text('Edit profile'));
      await settle(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Changed');
      await scrollTo(tester, find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await settle(tester);
      expect(find.text("Couldn't update your profile."), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Savitri Deshmukh'), findsOneWidget);
    });

    testWidgets('photo upload success and failure', (tester) async {
      final h = Harness()..photo = XFile('/tmp/me.jpg');
      await pumpSettings(tester, harness: h);
      await tester.tap(find.byTooltip('Change profile photo'));
      await settle(tester);
      await tester.tap(find.text('Choose from gallery'));
      await settle(tester);
      expect(h.bloc.of<ImageAddEvent>().single.image, '/tmp/me.jpg');
      expect(find.text('Profile photo updated'), findsOneWidget);

      h.bloc.photoFails = true;
      await tester.tap(find.byTooltip('Change profile photo'));
      await settle(tester);
      await tester.tap(find.text('Choose from gallery'));
      await settle(tester);
      expect(find.text("Couldn't upload the photo."), findsOneWidget);
    });

    testWidgets('profile load failure offers retry', (tester) async {
      final h = Harness()..bloc.loadFails = true;
      await pumpSettings(tester, harness: h);
      expect(find.text("Couldn't load your profile."), findsOneWidget);
      h.bloc.loadFails = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Savitri Deshmukh'), findsOneWidget);
    });
  });

  group('notifications', () {
    testWidgets('shows the real permission state and opens settings', (
      tester,
    ) async {
      final h = await pumpSettings(tester);
      await scrollTo(tester, find.text('Turned off'));
      await tester.tap(find.text('Open settings'));
      await settle(tester);
      expect(h.settingsOpened, 1);
      await scrollTo(tester, find.text('Go to events'));
      await tester.tap(find.text('Go to events'));
      await settle(tester);
      expect(pushed, ['/shahiEvents']);
    });

    testWidgets('allowed and unknown states', (tester) async {
      await pumpSettings(tester, harness: Harness()..notifications = true);
      await scrollTo(tester, find.text('Allowed'));
      await pumpSettings(tester, harness: Harness()..notifications = null);
      await scrollTo(tester, find.text('Status unavailable'));
    });
  });

  group('logout', () {
    testWidgets('asks first; confirm removes the token and clears the stack', (
      tester,
    ) async {
      final h = await pumpSettings(tester);
      await scrollTo(tester, find.text('Log out'));
      await tester.tap(find.text('Log out'));
      await settle(tester);
      expect(find.text('Log out of Kumbh Path?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(h.tokenDeletes, 0);

      await tester.tap(find.text('Log out'));
      await settle(tester);
      await tester.tap(find.text('Log out').last);
      await settle(tester);
      expect(h.tokenDeletes, 1);
      expect(pushed.last, '/loginScreen');
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
    });
  });

  group('layout', () {
    for (final locale in const [Locale('en'), Locale('hi'), Locale('mr')]) {
      for (final theme in ['light', 'dark']) {
        for (final scale in ['small', 'standard', 'large']) {
          testWidgets(
            'no overflow: $theme $scale ${locale.languageCode}, editing',
            (tester) async {
              await pumpSettings(
                tester,
                locale: locale,
                deviceScale: 1.3,
                size: const Size(320, 640),
                prefs: {
                  ThemeProvider.themeModeKey: theme,
                  ThemeProvider.fontScaleKey: scale,
                },
              );
              await tester.tap(find.byType(AppButton).first); // Edit profile
              await settle(tester);
              for (var i = 0; i < 12; i++) {
                await tester.drag(
                  find.byType(Scrollable).first,
                  const Offset(0, -400),
                );
                await tester.pump(const Duration(milliseconds: 50));
              }
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });
}
