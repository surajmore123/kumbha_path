import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_bloc.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_event.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';
import 'package:kumbha_path/src/components/chat_screen/chat_input.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/models/chat_messages.dart';
import 'package:kumbha_path/src/models/chat_session.dart';
import 'package:kumbha_path/src/modules/ai_chat/ai_chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ------------------------------------------------------------------ fakes

enum Reply { answer, empty, fail, pending }

/// Mirrors WebhookBloc's emissions without any network or storage.
class FakeChatBloc extends WebhookBloc {
  final List<WebhookEvent> events = [];
  Reply reply = Reply.answer;
  String answer = 'Ramkund is the main ghat for the Shahi Snan in Nashik.';

  /// History pages keyed by cursor (null = first page).
  Map<int?, (List<ChatMessage>, bool hasMore, int nextCursor)> pages = {};
  bool historyFails = false;
  bool historyPending = false;

  // ignore: invalid_use_of_visible_for_testing_member
  void _emit(WebhookState s) => emit(s);

  @override
  void add(WebhookEvent event) {
    events.add(event);
    if (event is ChatBotEvent) {
      final user = switch (event.type) {
        ChatPayloadType.text => ChatMessage.text(
          text: event.message ?? '',
          isGuru: false,
        ),
        ChatPayloadType.image => ChatMessage.image(
          path: event.file!.path,
          isGuru: false,
        ),
        ChatPayloadType.audio => ChatMessage.audio(
          path: event.file!.path,
          isGuru: false,
        ),
      };
      final withUser = [...state.messages, user];
      _emit(state.copyWith(status: WebhookStatus.sending, messages: withUser));
      switch (reply) {
        case Reply.answer:
        case Reply.empty:
          _emit(
            state.copyWith(
              status: WebhookStatus.success,
              messages: [
                ...withUser,
                ChatMessage.text(
                  text: reply == Reply.empty ? '' : answer,
                  isGuru: true,
                ),
              ],
            ),
          );
        case Reply.fail:
          _emit(state.copyWith(status: WebhookStatus.failure));
        case Reply.pending:
          break;
      }
    } else if (event is ChatBothistoryEvent) {
      _emit(state.copyWith(status: WebhookStatus.loading));
      if (historyPending) return;
      final page = pages[event.isLoadMore ? event.cursor : null];
      if (historyFails || page == null) {
        _emit(
          state.copyWith(
            status: WebhookStatus.failure,
            chatSessionModel: ChatSessionModel.empty,
          ),
        );
        return;
      }
      final (msgs, hasMore, next) = page;
      _emit(
        state.copyWith(
          status: WebhookStatus.success,
          messages: event.isLoadMore ? [...msgs, ...state.messages] : msgs,
          cursor: next,
          chatSessionModel: ChatSessionModel(
            sessionId: 'S1',
            messages: const [],
            hasMore: hasMore,
            nextCursor: next,
          ),
        ),
      );
    }
  }

  List<ChatBotEvent> get sent => events.whereType<ChatBotEvent>().toList();
  List<ChatBothistoryEvent> get historyRequests =>
      events.whereType<ChatBothistoryEvent>().toList();
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

Future<FakeChatBloc> pumpChat(
  WidgetTester tester, {
  FakeChatBloc? bloc,
  String? sessionId,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  AppFontScale fontScale = AppFontScale.standard,
  double deviceScale = 1.0,
  double keyboard = 0,
}) async {
  final b = bloc ?? FakeChatBloc();
  addTearDown(b.close);
  await tester.runAsync(EasyLocalization.ensureInitialized);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  if (keyboard > 0) tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
      path: 'assets/translations',
      assetLoader: const _FileAssetLoader(),
      fallbackLocale: const Locale('en'),
      startLocale: locale,
      saveLocale: false,
      child: BlocProvider<WebhookBloc>.value(
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
                home: AskGuruAiScreen(readSessionId: () async => sessionId),
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

/// The thinking indicator animates forever, so never pumpAndSettle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder get composer => find.byType(TextField);

/// By icon, so it works in every locale.
Finder get sendButton => find.descendant(
  of: find.byType(ChatInputBar),
  matching: find.byIcon(Icons.arrow_upward_rounded),
);

Future<void> typeAndSend(WidgetTester tester, String text) async {
  await tester.enterText(composer, text);
  await tester.pump();
  await tester.tap(sendButton);
  await settle(tester);
}

ChatMessage u(String t) => ChatMessage.text(text: t, isGuru: false);
ChatMessage g(String t) => ChatMessage.text(text: t, isGuru: true);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('new conversation', () {
    testWidgets(
      'welcome with suggestions and disclaimer; no history request without a session',
      (tester) async {
        final b = await pumpChat(tester);
        expect(b.historyRequests, isEmpty);
        expect(find.text('AI Guru'), findsOneWidget);
        expect(
          find.text('Namaste! How may I guide you today?'),
          findsOneWidget,
        );
        for (final q in [
          'Tell me about the Nashik Kumbh Mela.',
          'What should I know before visiting a temple?',
          'Explain the significance of the Shahi Snan days.',
          'Help me explore spiritual places around Nashik.',
        ]) {
          await tester.scrollUntilVisible(
            find.text(q),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text(q), findsOneWidget);
        }
        await tester.scrollUntilVisible(
          find.textContaining('AI answers can be wrong'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
      },
    );

    testWidgets('a suggestion is sent as a normal text message', (
      tester,
    ) async {
      final b = await pumpChat(tester);
      b.reply = Reply.pending;
      await tester.tap(find.text('Tell me about the Nashik Kumbh Mela.'));
      await settle(tester);

      expect(b.sent.single.type, ChatPayloadType.text);
      expect(b.sent.single.message, 'Tell me about the Nashik Kumbh Mela.');
      expect(find.text('AI Guru is thinking…'), findsOneWidget);
      // Welcome gone; the question is in the conversation.
      expect(find.text('Try asking'), findsNothing);
    });
  });

  group('sending', () {
    testWidgets('composer sends text, clears, shows the reply', (tester) async {
      final b = await pumpChat(tester);
      expect(sendButton, findsNothing); // empty: mic instead
      await typeAndSend(tester, 'Where is Ramkund?');

      expect(b.sent.single.message, 'Where is Ramkund?');
      expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
      expect(find.text('Where is Ramkund?'), findsOneWidget);
      expect(find.text(b.answer), findsOneWidget);
      expect(find.text('AI Guru is thinking…'), findsNothing);
      // Newest at the bottom.
      expect(
        tester.getTopLeft(find.text('Where is Ramkund?')).dy,
        lessThan(tester.getTopLeft(find.text(b.answer)).dy),
      );
    });

    testWidgets('no duplicate submissions while a reply is pending', (
      tester,
    ) async {
      final b = await pumpChat(tester);
      b.reply = Reply.pending;
      await typeAndSend(tester, 'First question');
      await tester.enterText(composer, 'Second question');
      await tester.pump();
      expect(sendButton, findsNothing); // busy spinner instead
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await settle(tester);
      expect(b.sent, hasLength(1));
      // The draft is kept for when the reply arrives.
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Second question',
      );
    });

    testWidgets(
      'failure: inline retry re-sends without duplicating the message',
      (tester) async {
        final b = await pumpChat(tester);
        b.reply = Reply.fail;
        await typeAndSend(tester, 'What time is the aarti?');
        expect(find.text("Couldn't get a reply."), findsOneWidget);
        expect(find.text('What time is the aarti?'), findsOneWidget);

        b.reply = Reply.answer;
        await tester.tap(find.text('Try again'));
        await settle(tester);
        expect(b.sent, hasLength(2));
        expect(b.sent.last.message, 'What time is the aarti?');
        expect(find.text('What time is the aarti?'), findsOneWidget);
        expect(find.text("Couldn't get a reply."), findsNothing);
        expect(find.text(b.answer), findsOneWidget);
      },
    );

    testWidgets('empty reply is explained and can be asked again', (
      tester,
    ) async {
      final b = await pumpChat(tester);
      b.reply = Reply.empty;
      await typeAndSend(tester, 'Tell me a story');
      expect(
        find.text('No answer came back for this question.'),
        findsOneWidget,
      );
      b.reply = Reply.answer;
      await tester.tap(find.text('Ask again'));
      await settle(tester);
      expect(b.sent.last.message, 'Tell me a story');
      expect(find.text(b.answer), findsOneWidget);
    });

    testWidgets('photo option sheet offers camera and gallery', (tester) async {
      await pumpChat(tester);
      await tester.tap(find.byTooltip('Add a photo'));
      await settle(tester);
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
    });
  });

  group('history', () {
    testWidgets('loads the stored session in order with media', (tester) async {
      final b =
          FakeChatBloc()
            ..pages = {
              null: (
                [
                  u('Namaste'),
                  g('Namaste! How can I help?'),
                  ChatMessage.image(
                    path: 'https://example.invalid/ghat.jpg',
                    isGuru: false,
                  ),
                  ChatMessage.audio(
                    path: 'https://example.invalid/a.m4a',
                    isGuru: false,
                  ),
                  g('That photo shows Ramkund.'),
                ],
                false,
                0,
              ),
            };
      await pumpChat(tester, bloc: b, sessionId: 'S1');
      final req = b.historyRequests.single;
      expect((req.sessionId, req.limit, req.isLoadMore), ('S1', 10, false));

      expect(
        tester.getTopLeft(find.text('Namaste')).dy,
        lessThan(tester.getTopLeft(find.text('That photo shows Ramkund.')).dy),
      );
      expect(find.text('Audio message'), findsOneWidget);
      expect(
        find.text('Photo unavailable'),
        findsOneWidget,
      ); // network blocked in tests
      expect(find.text('Try asking'), findsNothing);
    });

    testWidgets('history failure is shown with retry, welcome still usable', (
      tester,
    ) async {
      final b = FakeChatBloc()..historyFails = true;
      await pumpChat(tester, bloc: b, sessionId: 'S1');
      expect(
        find.text("Couldn't load your earlier conversation."),
        findsOneWidget,
      );
      expect(find.text('Try asking'), findsOneWidget);

      b
        ..historyFails = false
        ..pages = {
          null: ([u('Hello'), g('Namaste')], false, 0),
        };
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(b.historyRequests, hasLength(2));
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets(
      'older messages load at the top without jumping to the bottom',
      (tester) async {
        final b =
            FakeChatBloc()
              ..pages = {
                null: (
                  [
                    for (var i = 10; i < 20; i++)
                      i.isEven ? u('Question $i') : g('Answer $i'),
                  ],
                  true,
                  5,
                ),
                5: (
                  [
                    for (var i = 0; i < 10; i++)
                      i.isEven ? u('Question $i') : g('Answer $i'),
                  ],
                  false,
                  0,
                ),
              };
        await pumpChat(tester, bloc: b, sessionId: 'S1');
        expect(find.text('Answer 19'), findsOneWidget);

        // Scroll up to the oldest loaded message.
        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, 3000),
          3000,
        );
        await settle(tester);
        final more = b.historyRequests.last;
        expect((more.cursor, more.isLoadMore), (5, true));

        final position =
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position;
        expect(
          position.pixels,
          greaterThan(0),
          reason: 'reading position kept',
        );
        expect(find.byTooltip('Jump to latest'), findsOneWidget);
        await tester.tap(find.byTooltip('Jump to latest'));
        await settle(tester);
        expect(position.pixels, 0);
        expect(find.text('Answer 19'), findsOneWidget);
        expect(b.historyRequests, hasLength(2)); // no duplicate page requests
      },
    );

    testWidgets('initial history loading state', (tester) async {
      final b = FakeChatBloc()..historyPending = true;
      await pumpChat(tester, bloc: b, sessionId: 'S1');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Try asking'), findsNothing);
    });
  });

  group('layout', () {
    const longMr =
        'नाशिकमधील रामकुंड हे गोदावरी नदीवरील सर्वात पवित्र घाटांपैकी एक आहे आणि सिंहस्थ कुंभमेळ्यात शाही स्नानासाठी लाखो भाविक येथे येतात.';
    for (final locale in const [Locale('en'), Locale('hi'), Locale('mr')]) {
      for (final br in Brightness.values) {
        for (final s in AppFontScale.values) {
          testWidgets(
            'no overflow: welcome + conversation ${locale.languageCode} ${br.name} ${s.name}, keyboard',
            (tester) async {
              final b = FakeChatBloc()..answer = longMr * 3;
              await pumpChat(
                tester,
                bloc: b,
                locale: locale,
                brightness: br,
                fontScale: s,
                deviceScale: 1.3,
                size: const Size(320, 640),
              );
              await tester.drag(
                find.byType(Scrollable).first,
                const Offset(0, -2000),
              );
              await tester.pump();
              expect(tester.takeException(), isNull);

              tester.view.viewInsets = const FakeViewPadding(bottom: 260);
              await settle(tester);
              await typeAndSend(tester, longMr);
              expect(tester.takeException(), isNull);
              // Composer stays above the keyboard.
              expect(
                tester.getRect(composer).bottom,
                lessThanOrEqualTo(640 - 260),
              );
              await tester.drag(
                find.byType(Scrollable).first,
                const Offset(0, 1500),
              );
              await tester.pump();
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });
}
