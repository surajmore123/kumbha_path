import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_event.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/models/chat_messages.dart';
import 'package:kumbha_path/src/models/chat_session.dart';

class WebhookBloc extends Bloc<WebhookEvent, WebhookState> {
  WebhookBloc() : super(WebhookState()) {
    on<ChatBotEvent>(_onChatWithAiGuru);
    on<ChatBothistoryEvent>(_onGetChatHistory);
  }

  String _cleanAiContent(dynamic rawContent) {
    if (rawContent == null) return '';

    String contentStr = rawContent.toString().trim();

    // case: {'output': '...'}
    if (contentStr.startsWith("{'output':")) {
      contentStr = contentStr.replaceFirst("{'output':", '');
      if (contentStr.endsWith('}')) {
        contentStr = contentStr.substring(0, contentStr.length - 1);
      }
      contentStr = contentStr.replaceAll("'", '').trim();
    }

    // remove both \n and \\n
    contentStr = contentStr.replaceAll("\\n", ' ');
    contentStr = contentStr.replaceAll('\n', ' ');

    // collapse multiple spaces
    contentStr = contentStr.replaceAll(RegExp(r'\s+'), ' ').trim();

    return contentStr;
  }
FutureOr<void> _onChatWithAiGuru(
  ChatBotEvent event,
  Emitter<WebhookState> emit,
) async {
  // 1) Add user message immediately
  final updatedMessages = List<ChatMessage>.from(state.messages)
    ..add(ChatMessage(text: event.message, isGuru: false));

  emit(
    state.copyWith(
      status: WebhookStatus.sending, // 👈 for typing indicator
      messages: updatedMessages,
    ),
  );

  // 2) Call API
  final token = await storage.read(key: 'access_token');

  final jsonData = {
    "access_token": token.toString(),
    "message": event.message,
  };

  print('chat payload: $jsonData');
  final result = await appRepository.chatBot(jsonData);
  print('result of chat: $result');

  if (result != null && result['status'] == 'success') {
    final data = result['data'];

    // store/update session_id
    final String sessionId = data['session_id'].toString();
    await storage.write(key: 'chat_session_id', value: sessionId);

    final messages = data['messages'] as List;

    final assistantMessage = messages.lastWhere(
      (m) => m['role'] == 'assistant',
      orElse: () => {'content': ''},
    );

    final rawContent = assistantMessage['content'];

    String chatResponse = _cleanAiContent(rawContent);

    print('AI Clean Response: $chatResponse');

    final newMessages = List<ChatMessage>.from(updatedMessages)
      ..add(ChatMessage(text: chatResponse, isGuru: true));

    emit(
      state.copyWith(
        status: WebhookStatus.success,
        messages: newMessages,
      ),
    );
  } else {
    emit(state.copyWith(status: WebhookStatus.failure));
  }
}

  // FutureOr<void> _onChatWithAiGuru(
  //   ChatBotEvent event,
  //   Emitter<WebhookState> emit,
  // ) async {
  //   // 1) Add user message immediately
  //   final updatedMessages = List<ChatMessage>.from(state.messages)
  //     ..add(ChatMessage(text: event.message, isGuru: false));

  //   emit(
  //     state.copyWith(status: WebhookStatus.loading, messages: updatedMessages),
  //   );

  //   // 2) Call API
  //   final token = await storage.read(key: 'access_token');

  //   final jsonData = {
  //     "access_token": token.toString(),
  //     "message": event.message,
  //   };

  //   print('chat payload: $jsonData');
  //   final result = await appRepository.chatBot(jsonData);
  //   print('result of chat: $result');

  //   if (result != null && result['status'] == 'success') {
  //     final messages = result['data']['messages'] as List;
  //     final data = result['data'];
  //     final String sessionId = data['session_id'].toString();
  //     await storage.write(key: 'chat_session_id', value: sessionId);

  //     print('✅ Session ID stored: $sessionId');

  //     final assistantMessage = messages.lastWhere(
  //       (m) => m['role'] == 'assistant',
  //       orElse: () => {'content': ''},
  //     );

  //     final rawContent = assistantMessage['content'];

  //     String chatResponse = '';

  //     if (rawContent is Map && rawContent['output'] != null) {
  //       // Case 1: backend already returns a map
  //       chatResponse = rawContent['output'].toString();
  //     } else if (rawContent is String) {
  //       final contentStr = rawContent.trim();

  //       // Case 2: Valid JSON string: {"output":"..."}
  //       if (contentStr.startsWith('{') && contentStr.contains('"output"')) {
  //         try {
  //           final decoded = jsonDecode(contentStr);
  //           if (decoded is Map && decoded['output'] != null) {
  //             chatResponse = decoded['output'].toString();
  //           } else {
  //             chatResponse = contentStr;
  //           }
  //         } catch (_) {
  //           chatResponse = contentStr;
  //         }
  //       }
  //       // Case 3: looks like {'output': '...'}
  //       else if (contentStr.startsWith("{'output':")) {
  //         chatResponse =
  //             contentStr
  //                 .replaceFirst("{'output':", '')
  //                 .replaceAll("'}", '')
  //                 .replaceAll("'", '')
  //                 .replaceAll("\n", '')
  //                 .trim();
  //       } else {
  //         chatResponse = contentStr;
  //       }
  //     } else {
  //       chatResponse = rawContent?.toString() ?? '';
  //     }

  //     print('AI Clean Response: $chatResponse');

  //     final newMessages = List<ChatMessage>.from(updatedMessages)
  //       ..add(ChatMessage(text: chatResponse, isGuru: true));

  //     emit(
  //       state.copyWith(status: WebhookStatus.success, messages: newMessages),
  //     );
  //   } else {
  //     emit(state.copyWith(status: WebhookStatus.failure));
  //   }
  // }

  FutureOr<void> _onGetChatHistory(
    ChatBothistoryEvent event,
    Emitter<WebhookState> emit,
  ) async {
    emit(state.copyWith(status: WebhookStatus.loading));

    final token = await storage.read(key: 'access_token');

    final Map<String, String> jsonData = {
      "access_token": token.toString(),
      "session_id": event.sessionId,
      "limit": event.limit.toString(),
    };

    if (event.cursor != null) {
      jsonData["cursor"] = event.cursor.toString();
    }

    final result = await appRepository.chatHistory(jsonData);

    if (result != null && result['status'] == "success") {
      final session = ChatSessionModel.fromJson(result);

      // Convert ChatMessageModel -> ChatMessage (your UI model)
      final historyMessages =
          (session.messages ?? [])
              .map(
                (m) => ChatMessage(
                  text:
                      m.role == 'assistant'
                          ? _cleanAiContent(m.content)
                          : (m.content ?? ''),
                  isGuru: m.role == 'assistant',
                ),
              )
              .toList();

      List<ChatMessage> updatedList;

      if (event.isLoadMore) {
        // prepend older messages
        updatedList = [...historyMessages, ...state.messages];
      } else {
        // initial load: just set latest 10
        updatedList = historyMessages;
      }

      emit(
        state.copyWith(
          status: WebhookStatus.success,
          messages: updatedList,
          cursor: session.nextCursor,
          chatSessionModel: session,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: WebhookStatus.failure,
          chatSessionModel: ChatSessionModel.empty,
        ),
      );
    }
  }
}
