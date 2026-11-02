import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/setting/widgets/notification_preferences_card.dart';
import 'package:kumbha_path/src/services/notification_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    return json.decode(await file.readAsString()) as Map<String, dynamic>;
  }
}

/// Scriptable stand-in for the server.
class FakePreferences extends NotificationPreferencesApi {
  FakePreferences();

  Map<NotificationCategory, bool> saved = {
    for (final c in NotificationCategory.values) c: true,
  };
  bool failLoad = false;
  bool failSave = false;
  final List<(NotificationCategory, bool)> updates = [];

  @override
  Future<Map<NotificationCategory, bool>?> load() async =>
      failLoad ? null : Map.of(saved);

  @override
  Future<Map<NotificationCategory, bool>?> update(
    NotificationCategory category,
    bool enabled,
  ) async {
    updates.add((category, enabled));
    if (failSave) return null;
    saved = {...saved, category: enabled};
    return Map.of(saved);
  }
}

Future<void> pumpCard(
  WidgetTester tester,
  FakePreferences api, {
  bool? systemAllowed = true,
}) async {
  await tester.runAsync(EasyLocalization.ensureInitialized);
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
      path: 'assets/translations',
      assetLoader: const _FileAssetLoader(),
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      saveLocale: false,
      child: Builder(
        builder:
            (context) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: AppTheme.light,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: NotificationPreferencesCard(
                    api: api,
                    systemAllowed: systemAllowed,
                  ),
                ),
              ),
            ),
      ),
    ),
  );
  for (
    var i = 0;
    i < 20 && find.text('Notification types').evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

bool switchValue(WidgetTester tester, String title) =>
    tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
        .value;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows every type with the saved value', (tester) async {
    final api =
        FakePreferences()..saved[NotificationCategory.crowdAlerts] = false;
    await pumpCard(tester, api);
    for (final title in [
      'Event reminders',
      'Event changes',
      'New events',
      'Crowd alerts',
      'Safety alerts',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(switchValue(tester, 'Crowd alerts'), isFalse);
    expect(switchValue(tester, 'Safety alerts'), isTrue);
  });

  testWidgets('turning a type off saves it', (tester) async {
    final api = FakePreferences();
    await pumpCard(tester, api);
    await tester.tap(find.text('New events'));
    await tester.pumpAndSettle();
    expect(api.updates.single, (NotificationCategory.newEvents, false));
    expect(switchValue(tester, 'New events'), isFalse);
  });

  testWidgets('a failed save moves the switch back and says so', (
    tester,
  ) async {
    final api = FakePreferences()..failSave = true;
    await pumpCard(tester, api);
    await tester.tap(find.text('Safety alerts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();
    expect(switchValue(tester, 'Safety alerts'), isTrue);
    expect(
      find.text("Couldn't save that change. Please try again."),
      findsOneWidget,
    );
  });

  testWidgets('load failure offers retry', (tester) async {
    final api = FakePreferences()..failLoad = true;
    await pumpCard(tester, api);
    expect(
      find.text("Couldn't load your notification choices."),
      findsOneWidget,
    );
    api.failLoad = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Event reminders'), findsOneWidget);
  });

  testWidgets('warns when the phone blocks notifications', (tester) async {
    await pumpCard(tester, FakePreferences(), systemAllowed: false);
    expect(find.textContaining('turned off for this app'), findsOneWidget);
  });
}
