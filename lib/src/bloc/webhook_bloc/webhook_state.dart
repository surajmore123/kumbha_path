import 'package:equatable/equatable.dart';
import 'package:kumbha_path/src/models/chat_messages.dart';
import 'package:kumbha_path/src/models/chat_session.dart';

enum WebhookStatus {
  initial,
  loading,
  failure,
  sending,
  updated,
  success,
  singleLoadedForView,
  deleting,
  deleted,
}
enum ChatPayloadType { text, image, audio }


class WebhookState extends Equatable {
  final WebhookStatus status;
  final List<ChatMessage> messages;
  int? cursor;
  int? limit;
  ChatSessionModel? chatSessionModel;

  WebhookState({
    this.status = WebhookStatus.initial,
    this.messages = const [],
    this.cursor,
    this.limit,
    this.chatSessionModel = ChatSessionModel.empty,
  });

  @override
  List<Object?> get props => [
    status,
    messages,
    cursor,
    limit,
    chatSessionModel,
  ];

  WebhookState copyWith({
    WebhookStatus? status,
    List<ChatMessage>? messages,
    int? cursor,
    int? limit,
    ChatSessionModel? chatSessionModel,
  }) {
    return WebhookState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      cursor: cursor ?? this.cursor,
      limit: limit ?? this.limit,
      chatSessionModel: chatSessionModel ?? this.chatSessionModel,
    );
  }
}
