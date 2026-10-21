import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/models/journal_details.dart';
import 'package:kumbha_path/src/models/journal_list.dart';
import 'package:kumbha_path/src/modules/journel/create_my_journer.dart';
import 'package:kumbha_path/src/modules/journel/daily_ai_reflection.dart';
import 'package:kumbha_path/src/modules/journel/journal_details.dart';
import 'package:kumbha_path/src/modules/journel/journer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ------------------------------------------------------------------ fakes

class FakeDetailsBloc extends AppDetailsBloc {
  final List<AppDetailsEvent> events = [];
  bool listFails = false;
  bool moreFails = false;
  bool detailFails = false;
  bool reflectionFails = false;
  bool createFails = false;
  bool createPending = false;
  List<JournalEntryModel> page1 = entries;
  String? next = 'page2';
  String reflection = 'Like the Godavari, let your mind flow gently today.';
  String prompt = 'What did you feel at Ramkund this morning?';

  // ignore: invalid_use_of_visible_for_testing_member
  void _emit(AppDetailsState s) => emit(s);

  @override
  void add(AppDetailsEvent event) {
    events.add(event);
    final s = state;
    switch (event) {
      case GetJournalEntry(:final page):
        if (page == 1) _emit(s.copyWith(status: AppDetailsStatus.loading));
        final fail = page == 1 ? listFails : moreFails;
        if (fail) {
          _emit(state.copyWith(status: AppDetailsStatus.journalEntryError));
          return;
        }
        final results =
            page == 1
                ? page1
                : [
                  ...state.journalEntryListModel!.results,
                  const JournalEntryModel(
                    id: 9,
                    title: 'Older entry',
                    createdAt: '2026-12-30T10:00:00',
                  ),
                ];
        _emit(
          state.copyWith(
            status: AppDetailsStatus.journalEntryoaded,
            journalEntryListModel: JournalEntryListModel(
              count: results.length,
              next: page == 1 ? next : null,
              results: results,
            ),
          ),
        );
      case GetJournalDetail():
        _emit(s.copyWith(status: AppDetailsStatus.loading));
        _emit(
          detailFails
              ? state.copyWith(status: AppDetailsStatus.failed)
              : state.copyWith(
                status: AppDetailsStatus.journalDetailLoaded,
                journalDetailsModel: detail,
              ),
        );
      case GetAiReflectionEvent():
        _emit(s.copyWith(status: AppDetailsStatus.loading));
        _emit(
          reflectionFails
              ? state.copyWith(
                status: AppDetailsStatus.aiReflectionError,
                message: 'Failed to load AI reflection',
              )
              : state.copyWith(
                status: AppDetailsStatus.aiReflectionLoaded,
                aiReflection: reflection,
                message: 'ok',
              ),
        );
      case GetAiPromptEvent():
        _emit(s.copyWith(status: AppDetailsStatus.loading));
        _emit(
          state.copyWith(
            status: AppDetailsStatus.aiPromptLoaded,
            aiPrompt: prompt,
            message: 'ok',
          ),
        );
      case CreateJournalEntryEvent():
        _emit(s.copyWith(status: AppDetailsStatus.sending));
        if (createPending) return;
        _emit(
          state.copyWith(
            status:
                createFails
                    ? AppDetailsStatus.journalEntryError
                    : AppDetailsStatus.journalEntryCreated,
            message: 'server says hi',
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

// ------------------------------------------------------------------- data

const entries = [
  JournalEntryModel(
    id: 3,
    title: 'Morning at Ramkund',
    notes: 'The aarti lamps floated on the Godavari as the sun rose.',
    mood: 'peaceful',
    createdAt: '2027-01-14T06:10:00',
    photo: 'https://example.invalid/ramkund.jpg',
  ),
  JournalEntryModel(
    id: 2,
    title: '',
    notes: 'Walked to Kalaram temple.',
    mood: 'joyful',
    createdAt: '2027-01-12T17:00:00',
  ),
  JournalEntryModel(
    id: 1,
    title: 'Arrival in Nashik',
    notes: '',
    mood: 'calm-ish',
    createdAt: '2026-12-31T21:00:00',
  ),
];

const detail = JournalDetailsModel(
  id: '3',
  title: 'Morning at Ramkund',
  notes: 'The aarti lamps floated on the Godavari as the sun rose.',
  aiPrompt: 'What did you feel at Ramkund this morning?',
  aiReflection: 'Stillness is also a pilgrimage.',
  mood: 'peaceful',
  photo: '',
  createdAt: '2027-01-14T06:10:00',
);

// ---------------------------------------------------------------- harness

Future<FakeDetailsBloc> pumpJournal(
  WidgetTester tester, {
  FakeDetailsBloc? bloc,
  Widget? home,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  AppFontScale fontScale = AppFontScale.standard,
  double deviceScale = 1.0,
}) async {
  final b = bloc ?? FakeDetailsBloc();
  addTearDown(b.close);
  await tester.runAsync(EasyLocalization.ensureInitialized);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    EasyLocalization(
      // Fresh tree per pump, so a new `home` really replaces the old one.
      key: UniqueKey(),
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
      path: 'assets/translations',
      assetLoader: const _FileAssetLoader(),
      fallbackLocale: const Locale('en'),
      startLocale: locale,
      saveLocale: false,
      child: BlocProvider<AppDetailsBloc>.value(
        value: b,
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
                onGenerateInitialRoutes:
                    (_) => [
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/journal'),
                        builder: (_) => home ?? const JournerScreen(),
                      ),
                    ],
                onGenerateRoute:
                    (s) => MaterialPageRoute(
                      settings: s,
                      builder: (_) => Scaffold(body: Text('page ${s.name}')),
                    ),
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
  await settle(tester);
  return b;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
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

Finder field(String label) =>
    find
        .ancestor(of: find.text(label), matching: find.byType(AppTextField))
        .first;

Future<void> fill(WidgetTester tester, String label, String value) async {
  await scrollTo(tester, find.text(label));
  await tester.enterText(
    find.descendant(of: field(label), matching: find.byType(TextFormField)),
    value,
  );
  await tester.pump();
}

Future<void> tapSave(WidgetTester tester) async {
  await scrollTo(tester, find.text('Save Entry'));
  await tester.tap(find.text('Save Entry'));
  await settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // CachedNetworkImage's cache needs path_provider, which has no
  // implementation in widget tests.
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
  });

  group('journal list', () {
    testWidgets('entries grouped by month with real fields only', (
      tester,
    ) async {
      final b = await pumpJournal(tester);
      expect((b.of<GetJournalEntry>().single).page, 1);
      expect(find.text('MyKumbh Journal'), findsOneWidget);

      await scrollTo(tester, find.text('Morning at Ramkund'));
      expect(find.text('January 2027'), findsOneWidget);
      expect(
        find.text('The aarti lamps floated on the Godavari as the sun rose.'),
        findsOneWidget,
      );
      expect(find.text('🙏  Peaceful'), findsOneWidget);

      await scrollTo(tester, find.text('Arrival in Nashik'));
      expect(find.text('Untitled entry'), findsOneWidget);
      expect(find.text('December 2026'), findsOneWidget);
      // Unknown stored mood is shown as stored.
      expect(find.text('calm-ish'), findsOneWidget);
    });

    testWidgets('failed load is not shown as an empty journal', (tester) async {
      final b = FakeDetailsBloc()..listFails = true;
      await pumpJournal(tester, bloc: b);
      await scrollTo(tester, find.text("Couldn't load your journal."));
      expect(find.text('No entries yet'), findsNothing);
      b.listFails = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      await scrollTo(tester, find.text('Morning at Ramkund'));
    });

    testWidgets('empty journal invites the first entry', (tester) async {
      final b =
          FakeDetailsBloc()
            ..page1 = const []
            ..next = null;
      await pumpJournal(tester, bloc: b);
      await scrollTo(tester, find.text('No entries yet'));
      expect(find.text('Show More'), findsNothing);
    });

    testWidgets('show more uses the next page; failure can be retried', (
      tester,
    ) async {
      final b = await pumpJournal(tester)
        ..moreFails = true;
      await scrollTo(tester, find.text('Show More'));
      await tester.tap(find.text('Show More'));
      await settle(tester);
      expect(b.of<GetJournalEntry>().last.page, 2);
      await scrollTo(tester, find.text("Couldn't load more entries."));

      b.moreFails = false;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(b.of<GetJournalEntry>().last.page, 2); // same page again
      await scrollTo(tester, find.text('Older entry'));
    });
  });

  group('entry details', () {
    testWidgets('opens with stored fields; AI parts are labelled', (
      tester,
    ) async {
      final b = await pumpJournal(tester);
      await scrollTo(tester, find.text('Morning at Ramkund'));
      await tester.tap(find.text('Morning at Ramkund'));
      await settle(tester);

      expect(b.of<GetJournalDetail>().single.id, '3');
      expect(find.byType(JournalDetails), findsOneWidget);
      expect(find.text('Journal entry'), findsOneWidget);
      expect(find.text('Daily prompt'), findsOneWidget);
      expect(
        find.text('What did you feel at Ramkund this morning?'),
        findsOneWidget,
      );
      await scrollTo(tester, find.text('Stillness is also a pilgrimage.'));
      expect(find.text('Generated by AI Guru'), findsNWidgets(2));
      // No edit / delete / share: the API has none.
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('failed open is reported', (tester) async {
      final b = FakeDetailsBloc()..detailFails = true;
      await pumpJournal(tester, bloc: b);
      await scrollTo(tester, find.text('Morning at Ramkund'));
      await tester.tap(find.text('Morning at Ramkund'));
      await settle(tester);
      expect(find.text("Couldn't open this entry."), findsOneWidget);
      expect(find.byType(JournalDetails), findsNothing);
    });

    testWidgets('missing title and notes are handled', (tester) async {
      final b = FakeDetailsBloc();
      // ignore: invalid_use_of_visible_for_testing_member
      b.emit(AppDetailsState(journalDetailsModel: JournalDetailsModel.empty));
      await pumpJournal(tester, bloc: b, home: const JournalDetails());
      expect(find.text('Untitled entry'), findsOneWidget);
      expect(find.text('No notes in this entry.'), findsOneWidget);
      expect(find.text('Generated by AI Guru'), findsNothing);
    });
  });

  group('AI reflection and prompt', () {
    testWidgets('reflection opens, can become an entry', (tester) async {
      final b = await pumpJournal(tester);
      await tester.tap(find.text('AI Reflection'));
      await settle(tester);
      expect(b.of<GetAiReflectionEvent>(), hasLength(1));
      expect(find.byType(DailyReflectionScreen), findsOneWidget);
      expect(find.text(b.reflection), findsOneWidget);
      expect(find.text('Share'), findsNothing); // never had an action

      await tester.tap(find.text('Add to Journal'));
      await settle(tester);
      expect(find.byType(NewJournalEntryScreen), findsOneWidget);
      expect(find.text(b.reflection), findsOneWidget); // pre-filled notes
    });

    testWidgets('reflection failure is reported, localized', (tester) async {
      final b = FakeDetailsBloc()..reflectionFails = true;
      await pumpJournal(tester, bloc: b);
      await tester.tap(find.text('AI Reflection'));
      await settle(tester);
      expect(
        find.text("Couldn't get an AI reflection right now."),
        findsOneWidget,
      );
      expect(find.byType(DailyReflectionScreen), findsNothing);
    });

    testWidgets('prompt sheet adds a read-only prompt to a new entry', (
      tester,
    ) async {
      final b = await pumpJournal(tester);
      await tester.tap(find.text('Get AI Prompt'));
      await settle(tester);
      expect(find.text(b.prompt), findsOneWidget);
      await tester.tap(find.text('Add to Journal Entry'));
      await settle(tester);
      expect(find.byType(NewJournalEntryScreen), findsOneWidget);
      expect(find.text('Prompt from AI Guru'), findsOneWidget);
      // Shown as text, not an editable (and silently ignored) field.
      expect(
        find.descendant(
          of: find.byType(TextFormField),
          matching: find.text(b.prompt),
        ),
        findsNothing,
      );
    });
  });

  group('create entry', () {
    Widget create({String? prompt, String? reflection, XFile? photo}) =>
        NewJournalEntryScreen(
          aiPrompt: prompt,
          aiReflection: reflection,
          pickImage: (_) async => photo,
        );

    testWidgets('empty entry is not submitted', (tester) async {
      final b = await pumpJournal(tester, home: create());
      await tapSave(tester);
      expect(
        find.text('Write something or add a photo before saving.'),
        findsOneWidget,
      );
      expect(b.of<CreateJournalEntryEvent>(), isEmpty);
    });

    testWidgets('same payload mapping as before; mood selectable', (
      tester,
    ) async {
      final b = await pumpJournal(tester, home: create());
      await fill(tester, 'Title', 'Ganga aarti');
      await fill(tester, 'Your Thoughts', 'The lamps were beautiful.');
      await fill(tester, 'Notes', 'Went with family.');
      await scrollTo(tester, find.text('Joyful'));
      await tester.tap(find.text('Joyful'));
      await tester.pump();
      await tapSave(tester);

      final e = b.of<CreateJournalEntryEvent>().single;
      expect(e.title, 'Ganga aarti');
      expect(e.notes, 'The lamps were beautiful.'); // "Your thoughts"
      expect(e.aiReflection, 'Went with family.'); // notes box
      expect(e.aiPrompt, 'null'); // unchanged: aiPrompt.toString()
      expect(e.mood, 'joyful');
      expect(e.imagePath, isNull);
    });

    testWidgets('default mood stays Peaceful', (tester) async {
      final b = await pumpJournal(tester, home: create());
      await fill(tester, 'Title', 'x');
      await tapSave(tester);
      expect(b.of<CreateJournalEntryEvent>().single.mood, 'peaceful');
    });

    testWidgets('photo can be attached and is sent', (tester) async {
      final b = await pumpJournal(
        tester,
        home: create(photo: XFile('/tmp/ghat.jpg')),
      );
      await scrollTo(tester, find.text('Upload Photo'));
      await tester.tap(find.text('Upload Photo'));
      await settle(tester);
      await tester.tap(find.text('Choose from gallery'));
      await settle(tester);
      await scrollTo(tester, find.text('Change photo'));
      await tapSave(tester);
      expect(b.of<CreateJournalEntryEvent>().single.imagePath, '/tmp/ghat.jpg');
    });

    testWidgets(
      'saving blocks duplicates; success returns to the journal and reloads',
      (tester) async {
        final b = FakeDetailsBloc()..createPending = true;
        await pumpJournal(tester, bloc: b);
        await tester.tap(find.text('Add Entry'));
        await settle(tester);
        await fill(tester, 'Title', 'First darshan');
        await tapSave(tester);
        await tester.tap(find.text('Save Entry'), warnIfMissed: false);
        await settle(tester);
        expect(b.of<CreateJournalEntryEvent>(), hasLength(1));

        // ignore: invalid_use_of_visible_for_testing_member
        b.emit(b.state.copyWith(status: AppDetailsStatus.journalEntryCreated));
        await settle(tester);
        expect(find.byType(NewJournalEntryScreen), findsNothing);
        expect(find.byType(JournerScreen), findsOneWidget);
        expect(
          find.text('Journal entry created successfully!'),
          findsOneWidget,
        );
        expect(b.of<GetJournalEntry>(), hasLength(2)); // list refreshed
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
          isFalse,
        );
      },
    );

    testWidgets('failure keeps the draft and allows retry', (tester) async {
      final b = FakeDetailsBloc()..createFails = true;
      await pumpJournal(tester, bloc: b, home: create());
      await fill(tester, 'Title', 'Keep me');
      await tapSave(tester);
      expect(
        find.text('Failed to create journal entry. Please try again.'),
        findsOneWidget,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await settle(tester);
      expect(find.text('Keep me'), findsOneWidget);
      b.createFails = false;
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .removeCurrentSnackBar();
      await settle(tester);
      await tapSave(tester);
      expect(b.of<CreateJournalEntryEvent>(), hasLength(2));
    });

    testWidgets('unsaved changes ask before leaving', (tester) async {
      await pumpJournal(tester);
      await tester.tap(find.text('Add Entry'));
      await settle(tester);
      await fill(tester, 'Title', 'Half written');
      await tester.tap(find.byType(BackButtonIcon));
      await settle(tester);
      expect(find.text('Discard this entry?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await settle(tester);
      expect(find.byType(NewJournalEntryScreen), findsOneWidget);

      await tester.tap(find.byType(BackButtonIcon));
      await settle(tester);
      await tester.tap(find.text('Discard'));
      await settle(tester);
      expect(find.byType(NewJournalEntryScreen), findsNothing);
    });

    testWidgets('untouched form leaves without asking', (tester) async {
      await pumpJournal(tester);
      await tester.tap(find.text('Add Entry'));
      await settle(tester);
      await tester.tap(find.byType(BackButtonIcon));
      await settle(tester);
      expect(find.text('Discard this entry?'), findsNothing);
      expect(find.byType(NewJournalEntryScreen), findsNothing);
    });
  });

  group('layout', () {
    const longMr =
        'त्र्यंबकेश्वर कुशावर्त तीर्थावर पहाटेच्या आरतीचा अनुभव आणि गोदावरीच्या काठावरील शांतता';
    for (final locale in const [Locale('en'), Locale('hi'), Locale('mr')]) {
      for (final br in Brightness.values) {
        for (final s in AppFontScale.values) {
          testWidgets(
            'no overflow: list, create, detail, reflection ${locale.languageCode} ${br.name} ${s.name}',
            (tester) async {
              Future<void> scrollAll() async {
                for (var i = 0; i < 10; i++) {
                  await tester.drag(
                    find.byType(Scrollable).first,
                    const Offset(0, -500),
                  );
                  await tester.pump(const Duration(milliseconds: 50));
                }
                expect(tester.takeException(), isNull);
              }

              final b =
                  FakeDetailsBloc()
                    ..page1 = [
                      for (final e in entries)
                        e.copyWith(title: '$longMr ${e.title}'),
                    ]
                    ..reflection = longMr * 4;
              await pumpJournal(
                tester,
                bloc: b,
                locale: locale,
                brightness: br,
                fontScale: s,
                deviceScale: 1.3,
                size: const Size(320, 640),
              );
              await scrollAll();

              await pumpJournal(
                tester,
                bloc: FakeDetailsBloc(),
                home: NewJournalEntryScreen(aiPrompt: longMr),
                locale: locale,
                brightness: br,
                fontScale: s,
                deviceScale: 1.3,
                size: const Size(320, 640),
              );
              tester.view.viewInsets = const FakeViewPadding(bottom: 260);
              await settle(tester);
              await scrollAll();
              tester.view.viewInsets = FakeViewPadding.zero;

              final d = FakeDetailsBloc();
              // ignore: invalid_use_of_visible_for_testing_member
              d.emit(
                AppDetailsState(
                  journalDetailsModel: detail.copyWith(
                    title: longMr,
                    notes: longMr * 6,
                  ),
                ),
              );
              await pumpJournal(
                tester,
                bloc: d,
                home: const JournalDetails(),
                locale: locale,
                brightness: br,
                fontScale: s,
                deviceScale: 1.3,
                size: const Size(320, 640),
              );
              await scrollAll();

              await pumpJournal(
                tester,
                home: DailyReflectionScreen(
                  aiReflection: longMr * 5,
                  message: '',
                ),
                locale: locale,
                brightness: br,
                fontScale: s,
                deviceScale: 1.3,
                size: const Size(320, 640),
              );
              await scrollAll();
            },
          );
        }
      }
    }
  });
}
