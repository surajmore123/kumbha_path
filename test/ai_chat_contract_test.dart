import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_bloc.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_event.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';
import 'package:kumbha_path/src/components/chat_screen/chat_input.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/document_type.dart';
import 'package:kumbha_path/src/models/chat_messages.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File('assets/translations/${locale.languageCode}.json');
    return json.decode(await file.readAsString()) as Map<String, dynamic>;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('reply metadata (backend contract)', () {
    test('temples keep only safe https links', () {
      final reply = ChatReplyData.fromMetadata({
        'temples': [
          {
            'id': 't1',
            'name': 'Trimbakeshwar Jyotirling Mandir',
            'directions_url':
                'https://www.google.com/maps/dir/?api=1&destination=19.9,73.5',
            'map_url': 'javascript:alert(1)',
            'image_url': 'http://insecure.example/x.jpg',
            'distance_km': 2.5,
          },
          {'name': 'No id is dropped'},
        ],
      });
      final temple = reply.temples.single;
      expect(
        temple.directionsUrl,
        startsWith('https://www.google.com/maps/dir'),
      );
      expect(temple.mapUrl, isNull);
      expect(temple.imageUrl, isNull);
      expect(temple.distanceKm, 2.5);
    });

    test('events, crowd, sources and status', () {
      final reply = ChatReplyData.fromMetadata({
        'status': 'ok',
        'event_mode': 'recent',
        'events': [
          {
            'id': 'e1',
            'name': 'Amrit Snan',
            'date': '2027-08-31',
            'is_all_day': true,
          },
          {'id': 'e2', 'name': 'No date'},
        ],
        'crowd': {
          'zones': [
            {
              'name': 'Ramkund',
              'status': 'HIGH',
              'occupancy_percent': 88,
              'calculated_at': '2026-10-24T10:00:00Z',
              'stale': false,
            },
            {'name': 'Panchavati', 'calculated_at': null},
          ],
          'freshness': {
            'calculated_at': '2026-10-24T10:00:00Z',
            'stale': false,
          },
        },
        'citations': [
          {'type': 'temple', 'id': '1', 'name': 'Shown as a card instead'},
          {
            'type': 'knowledge',
            'title': 'Ghat guide',
            'verification_status': 'unverified',
          },
          {
            'type': 'knowledge',
            'title': 'Official schedule',
            'verification_status': 'verified',
            'source_url': 'https://example.gov.in/s',
          },
          {'type': 'document', 'name': 'notice.pdf', 'location': 'page 2'},
          {'type': 'document', 'name': 'notice.pdf', 'location': 'page 2'},
        ],
      });
      expect(reply.events.single.isAllDay, isTrue);
      expect(reply.eventMode, 'recent');
      expect(reply.zones.first.occupancyPercent, 88);
      expect(reply.zones.last.hasReading, isFalse);
      expect(reply.crowdStale, isFalse);
      expect(reply.sources.map((s) => s.label), [
        'Ghat guide',
        'Official schedule',
        'notice.pdf · page 2',
      ]);
      expect(reply.sources[0].unverified, isTrue);
      expect(reply.sources[1].url, 'https://example.gov.in/s');
      expect(reply.partial, isFalse);
      expect(
        ChatReplyData.fromMetadata({'status': 'degraded'}).partial,
        isTrue,
      );
      expect(ChatReplyData.fromMetadata(null).isEmpty, isTrue);
    });

    test('transcript is read from user message metadata', () {
      expect(
        ChatMessage.transcriptFromMetadata({
          'transcript': {'text': ' When is the Amrit Snan? ', 'language': 'en'},
        }),
        'When is the Amrit Snan?',
      );
      expect(
        ChatMessage.transcriptFromMetadata({
          'transcript': {'text': ''},
        }),
        isNull,
      );
      expect(ChatMessage.transcriptFromMetadata(null), isNull);
    });

    test('reply text keeps paragraphs and list lines', () {
      expect(
        WebhookBloc.cleanAiContent(
          'Line one\\n- item a\n- item b\n\n\n\nEnd  here',
        ),
        'Line one\n- item a\n- item b\n\nEnd here',
      );
      expect(WebhookBloc.cleanAiContent("{'output': 'Hello'}"), 'Hello');
    });

    test('document MIME types sent with uploads', () {
      expect(
        detectMimeType(File('a.PDF'), ChatPayloadType.document),
        'application/pdf',
      );
      expect(
        detectMimeType(File('a.csv'), ChatPayloadType.document),
        'text/csv',
      );
      expect(
        detectMimeType(File('a.xlsx'), ChatPayloadType.document),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    });
  });

  group('composer documents', () {
    Future<List<ChatBotEvent>> pumpComposer(WidgetTester tester) async {
      final sent = <ChatBotEvent>[];
      await tester.runAsync(EasyLocalization.ensureInitialized);
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
                    body: Align(
                      alignment: Alignment.bottomCenter,
                      child: ChatInputBar(
                        onSubmit: sent.add,
                        pickDocument: () async => '/tmp/notice.pdf',
                      ),
                    ),
                  ),
                ),
          ),
        ),
      );
      for (
        var i = 0;
        i < 20 && find.byType(ChatInputBar).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      return sent;
    }

    testWidgets('a picked document is sent with the typed caption', (
      tester,
    ) async {
      final sent = await pumpComposer(tester);
      await tester.tap(find.byTooltip('Add a photo or document'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a document'));
      await tester.pumpAndSettle();
      expect(find.text('notice.pdf'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'What date does it give?');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();

      final event = sent.single;
      expect(event.type, ChatPayloadType.document);
      expect(event.file!.path, '/tmp/notice.pdf');
      expect(event.message, 'What date does it give?');
      expect(find.text('notice.pdf'), findsNothing);
    });

    testWidgets('a picked document can be removed before sending', (
      tester,
    ) async {
      final sent = await pumpComposer(tester);
      await tester.tap(find.byTooltip('Add a photo or document'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a document'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove file'));
      await tester.pumpAndSettle();
      expect(find.text('notice.pdf'), findsNothing);
      expect(sent, isEmpty);
    });
  });
}
