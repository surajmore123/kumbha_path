import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_event.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';
import 'package:kumbha_path/src/constant/api_constatnt.dart';
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
    late final ChatMessage userMessage;

    if (event.type == ChatPayloadType.text) {
      userMessage = ChatMessage.text(text: event.message ?? '', isGuru: false);
    } else if (event.type == ChatPayloadType.image) {
      userMessage = ChatMessage.image(path: event.file!.path, isGuru: false);
    } else {
      userMessage = ChatMessage.audio(path: event.file!.path, isGuru: false);
    }

    final updatedMessages = List<ChatMessage>.from(state.messages)
      ..add(userMessage);

    emit(
      state.copyWith(status: WebhookStatus.sending, messages: updatedMessages),
    );

    // 2) token
    final token = await storage.read(key: 'access_token');
    if (token == null) {
      emit(state.copyWith(status: WebhookStatus.failure));
      return;
    }

    dynamic result;

    if (event.type == ChatPayloadType.text) {
      // TEXT: same as before
      final jsonData = {
        "access_token": token.toString(),
        "message": event.message ?? '',
      };

      print('chat payload (text): $jsonData');
      result = await appRepository.chatBot(jsonData);
    } else {
      // MEDIA: send binary
      if (event.file == null) {
        emit(state.copyWith(status: WebhookStatus.failure));
        return;
      }

      print('chat payload (media): ${event.type} -> ${event.file!.path}');
      result = await appRepository.chatBotMedia(
        accessToken: token.toString(),
        file: event.file!,
        type: event.type,
      );
    }

    print('result of chat: $result');

    if (result != null && result['status'] == 'success') {
      final data = result['data'];

      final String sessionId = data['session_id'].toString();
      await storage.write(key: 'session_id', value: sessionId);

      final messages = data['messages'] as List;

      final assistantMessage = messages.lastWhere(
        (m) => m['role'] == 'assistant',
        orElse: () => {'content': ''},
      );

      final rawContent = assistantMessage['content'];

      String chatResponse = _cleanAiContent(rawContent);

      print('AI Clean Response: $chatResponse');

      final newMessages = List<ChatMessage>.from(updatedMessages)
        ..add(ChatMessage.text(text: chatResponse, isGuru: true));

      emit(
        state.copyWith(status: WebhookStatus.success, messages: newMessages),
      );
    } else {
      emit(state.copyWith(status: WebhookStatus.failure));
    }
  }

  // FutureOr<void> _onChatWithAiGuru(
  //   ChatBotEvent event,
  //   Emitter<WebhookState> emit,
  // ) async {
  //   // 1) Show user message in UI
  //   final userDisplayText = () {
  //     if (event.type == ChatPayloadType.text) {
  //       return event.message ?? '';
  //     } else if (event.type == ChatPayloadType.image) {
  //       return '[Image]';
  //     } else {
  //       return '[Audio]';
  //     }
  //   }();

  //   final updatedMessages = List<ChatMessage>.from(state.messages)
  //     ..add(ChatMessage(text: userDisplayText, isGuru: false));

  //   emit(
  //     state.copyWith(
  //       status: WebhookStatus.sending,
  //       messages: updatedMessages,
  //     ),
  //   );

  //   // 2) token
  //   final token = await storage.read(key: 'access_token');
  //   if (token == null) {
  //     emit(state.copyWith(status: WebhookStatus.failure));
  //     return;
  //   }

  //   dynamic result;

  //   if (event.type == ChatPayloadType.text) {
  //     // TEXT: same as before
  //     final jsonData = {
  //       "access_token": token.toString(),
  //       "message": event.message ?? '',
  //     };

  //     print('chat payload (text): $jsonData');
  //     result = await appRepository.chatBot(jsonData);
  //   } else {
  //     // MEDIA: send binary
  //     if (event.file == null) {
  //       emit(state.copyWith(status: WebhookStatus.failure));
  //       return;
  //     }

  //     print(
  //         'chat payload (media): ${event.type} -> ${event.file!.path}');
  //     result = await appRepository.chatBotMedia(
  //       accessToken: token.toString(),
  //       file: event.file!,
  //       type: event.type,
  //     );
  //   }

  //   print('result of chat: $result');

  //   if (result != null && result['status'] == 'success') {
  //     final data = result['data'];

  //     final String sessionId = data['session_id'].toString();
  //     await storage.write(key: 'session_id', value: sessionId);

  //     final messages = data['messages'] as List;

  //     final assistantMessage = messages.lastWhere(
  //       (m) => m['role'] == 'assistant',
  //       orElse: () => {'content': ''},
  //     );

  //     final rawContent = assistantMessage['content'];

  //     String chatResponse = _cleanAiContent(rawContent);

  //     print('AI Clean Response: $chatResponse');

  //     final newMessages = List<ChatMessage>.from(updatedMessages)
  //       ..add(ChatMessage(text: chatResponse, isGuru: true));

  //     emit(
  //       state.copyWith(
  //         status: WebhookStatus.success,
  //         messages: newMessages,
  //       ),
  //     );
  //   } else {
  //     emit(state.copyWith(status: WebhookStatus.failure));
  //   }
  // }

  // FutureOr<void> _onGetChatHistory(
  //   ChatBothistoryEvent event,
  //   Emitter<WebhookState> emit,
  // ) async {
  //   emit(state.copyWith(status: WebhookStatus.loading));

  //   final token = await storage.read(key: 'access_token');

  //   final Map<String, String> jsonData = {
  //     "access_token": token.toString(),
  //     "session_id": event.sessionId.toString(),
  //     "limit": event.limit.toString(),
  //   };

  //   if (event.cursor != null) {
  //     jsonData["cursor"] = event.cursor.toString();
  //   }

  //   final result = await appRepository.chatHistory(jsonData);

  //   if (result != null && result['status'] == "success") {
  //     final session = ChatSessionModel.fromJson(result);

  //     // Convert ChatMessageModel -> ChatMessage (your UI model)
  //     final historyMessages =
  //         (session.messages ?? [])
  //             .map(
  //               (m) => ChatMessage(
  //                 text:
  //                     m.role == 'assistant'
  //                         ? _cleanAiContent(m.content)
  //                         : (m.content ?? ''),
  //                 isGuru: m.role == 'assistant',
  //               ),
  //             )
  //             .toList();

  //     List<ChatMessage> updatedList;

  //     if (event.isLoadMore) {
  //       // prepend older messages
  //       updatedList = [...historyMessages, ...state.messages];
  //     } else {
  //       // initial load: just set latest 10
  //       updatedList = historyMessages;
  //     }

  //     emit(
  //       state.copyWith(
  //         status: WebhookStatus.success,
  //         messages: updatedList,
  //         cursor: session.nextCursor,
  //         chatSessionModel: session,
  //       ),
  //     );
  //   } else {
  //     emit(
  //       state.copyWith(
  //         status: WebhookStatus.failure,
  //         chatSessionModel: ChatSessionModel.empty,
  //       ),
  //     );
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
      "session_id": event.sessionId.toString(),
      "limit": event.limit.toString(),
    };

    if (event.cursor != null) {
      jsonData["cursor"] = event.cursor.toString();
    }

    final result = await appRepository.chatHistory(jsonData);

    if (result != null && result['status'] == "success") {
      final session = ChatSessionModel.fromJson(result);

      // ---------- CHANGED MAPPING STARTS HERE ----------

      final historyMessages =
          (session.messages ?? []).map((m) {
            final bool isGuru = m.role == 'assistant';

            // Adjust these property names to match your ChatMessageModel
            final String? fileUrl = m.fileUrl; // from "file_url"
            final String? contentType =
                m.metadata?.contentType; // from "metadata.content_type"

            // 1) MEDIA MESSAGE (image or audio)
            if (fileUrl != null &&
                fileUrl.isNotEmpty &&
                contentType != null &&
                contentType.isNotEmpty) {
              // If backend returns "/media/...", prefix with ApiConst.baseUrl
              final String fullUrl =
                  fileUrl.startsWith('http')
                      ? fileUrl
                      : '${ApiConst.baseUrl}$fileUrl';

              if (contentType.startsWith('image/')) {
                return ChatMessage.image(path: fullUrl, isGuru: isGuru);
              }

              if (contentType.startsWith('audio/')) {
                return ChatMessage.audio(path: fullUrl, isGuru: isGuru);
              }
            }

            // 2) TEXT MESSAGE (fallback)
            final rawContent = m.content ?? '';
            final text = isGuru ? _cleanAiContent(rawContent) : rawContent;

            return ChatMessage.text(text: text, isGuru: isGuru);
          }).toList();

      // ---------- CHANGED MAPPING ENDS HERE ----------

      List<ChatMessage> updatedList;

      if (event.isLoadMore) {
        // prepend older messages
        updatedList = [...historyMessages, ...state.messages];
      } else {
        // initial load
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
