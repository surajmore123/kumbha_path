import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_event.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/models/chat_messages.dart';
import 'package:kumbha_path/src/models/chat_session.dart';
import 'package:path/path.dart' as p;

class WebhookBloc extends Bloc<WebhookEvent, WebhookState> {
  WebhookBloc() : super(WebhookState()) {
    on<ChatBotEvent>(_onChatWithAiGuru);
    on<ChatBothistoryEvent>(_onGetChatHistory);
  }

  /// Normalises reply text while keeping paragraphs and list lines.
  static String cleanAiContent(dynamic rawContent) {
    if (rawContent == null) return '';

    String contentStr = rawContent.toString().trim();

    // case: {'output': '...'} (legacy n8n replies)
    if (contentStr.startsWith("{'output':")) {
      contentStr = contentStr.replaceFirst("{'output':", '');
      if (contentStr.endsWith('}')) {
        contentStr = contentStr.substring(0, contentStr.length - 1);
      }
      contentStr = contentStr.replaceAll("'", '').trim();
    }

    // Escaped newlines become real ones; runs of blank lines collapse.
    contentStr = contentStr.replaceAll('\\n', '\n');
    contentStr = contentStr.replaceAll(RegExp(r'[ \t]+'), ' ');
    contentStr = contentStr.replaceAll(RegExp(r' *\n *'), '\n');
    contentStr = contentStr.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return contentStr.trim();
  }

  static Map<String, dynamic>? _metadata(dynamic message) {
    final value = message is Map ? message['metadata'] : null;
    return value is Map<String, dynamic> ? value : null;
  }

  static ChatMessage _assistantMessage(dynamic message) {
    final metadata = _metadata(message);
    return ChatMessage.text(
      text: cleanAiContent(message is Map ? message['content'] : null),
      isGuru: true,
      reply: ChatReplyData.fromMetadata(metadata),
    );
  }

  ChatMessage _userMessage(ChatBotEvent event) {
    final file = event.file;
    return switch (event.type) {
      ChatPayloadType.text => ChatMessage.text(
        text: event.message ?? '',
        isGuru: false,
      ),
      ChatPayloadType.image => ChatMessage.image(
        path: file!.path,
        isGuru: false,
        caption: event.message,
      ),
      ChatPayloadType.audio => ChatMessage.audio(
        path: file!.path,
        isGuru: false,
      ),
      ChatPayloadType.document => ChatMessage.document(
        path: file!.path,
        fileName: p.basename(file.path),
        isGuru: false,
        caption: event.message,
      ),
    };
  }

  FutureOr<void> _onChatWithAiGuru(
    ChatBotEvent event,
    Emitter<WebhookState> emit,
  ) async {
    // 1) Add user message immediately
    final userMessage = _userMessage(event);
    var updatedMessages = List<ChatMessage>.from(state.messages)
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

    final language = LanguageHelper.currentLang.value;
    dynamic result;

    if (event.type == ChatPayloadType.text) {
      result = await appRepository.chatBot({
        "access_token": token.toString(),
        "message": event.message ?? '',
        "language": language,
      });
    } else {
      // MEDIA: send binary, with an optional caption
      if (event.file == null) {
        emit(state.copyWith(status: WebhookStatus.failure));
        return;
      }
      final caption = (event.message ?? '').trim();
      result = await appRepository.chatBotMedia(
        accessToken: token.toString(),
        file: event.file!,
        type: event.type,
        fields: {
          'language': language,
          if (caption.isNotEmpty) 'message': caption,
        },
      );
    }

    if (result != null && result['status'] == 'success') {
      final data = result['data'];

      final String sessionId = data['session_id'].toString();
      await storage.write(key: 'session_id', value: sessionId);

      final messages = data['messages'] as List;

      // A voice message: show what the server heard.
      final sentMessage = messages.firstWhere(
        (m) => m['role'] == 'user',
        orElse: () => null,
      );
      final transcript = ChatMessage.transcriptFromMetadata(
        _metadata(sentMessage),
      );
      if (transcript != null && userMessage.type == ChatPayloadType.audio) {
        updatedMessages = List<ChatMessage>.from(updatedMessages)
          ..[updatedMessages.length - 1] = userMessage.withTranscript(
            transcript,
          );
      }

      final assistantMessage = messages.lastWhere(
        (m) => m['role'] == 'assistant',
        orElse: () => {'content': ''},
      );

      final newMessages = List<ChatMessage>.from(updatedMessages)
        ..add(_assistantMessage(assistantMessage));

      emit(
        state.copyWith(status: WebhookStatus.success, messages: newMessages),
      );
    } else {
      emit(state.copyWith(status: WebhookStatus.failure));
    }
  }

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
      final rawMessages =
          ((result['data'] ?? result)['messages'] as List?) ?? const [];

      final historyMessages = <ChatMessage>[];
      for (var i = 0; i < (session.messages ?? []).length; i++) {
        final m = session.messages![i];
        final raw = i < rawMessages.length ? rawMessages[i] : null;
        final bool isGuru = m.role == 'assistant';

        final String? fileUrl = m.fileUrl; // from "file_url"
        final String? contentType =
            m.metadata?.contentType; // from "metadata.content_type"

        // 1) MEDIA MESSAGE (image, audio or document)
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
            historyMessages.add(
              ChatMessage.image(
                path: fullUrl,
                isGuru: isGuru,
                caption: m.content,
              ),
            );
            continue;
          }

          if (contentType.startsWith('audio/')) {
            historyMessages.add(
              ChatMessage.audio(
                path: fullUrl,
                isGuru: isGuru,
                transcript: ChatMessage.transcriptFromMetadata(_metadata(raw)),
              ),
            );
            continue;
          }

          if (m.messageType == 'file') {
            historyMessages.add(
              ChatMessage.document(
                path: fullUrl,
                fileName: m.metadata?.originalName ?? p.basename(fileUrl),
                isGuru: isGuru,
                caption: m.content,
              ),
            );
            continue;
          }
        }

        // 2) TEXT MESSAGE (fallback)
        if (isGuru) {
          historyMessages.add(
            raw != null
                ? _assistantMessage(raw)
                : ChatMessage.text(
                  text: cleanAiContent(m.content),
                  isGuru: true,
                ),
          );
        } else if (m.messageType == 'file') {
          // A file the server declined: show its name, there's no copy.
          historyMessages.add(
            ChatMessage.document(
              path: '',
              fileName: m.metadata?.originalName ?? 'file',
              isGuru: false,
              caption: m.content,
            ),
          );
        } else {
          historyMessages.add(
            ChatMessage.text(text: m.content ?? '', isGuru: false),
          );
        }
      }

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
