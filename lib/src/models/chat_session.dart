import 'package:equatable/equatable.dart';

class ChatSessionModel extends Equatable {
  final String? sessionId;
  final List<ChatMessageModel>? messages;
  final bool? hasMore;
  final int? nextCursor;

  const ChatSessionModel({
    this.sessionId,
    this.messages,
    this.hasMore,
    this.nextCursor,
  });

  @override
  List<Object?> get props => [sessionId, messages, hasMore, nextCursor];

  ChatSessionModel copyWith({
    String? sessionId,
    List<ChatMessageModel>? messages,
    bool? hasMore,
    int? nextCursor,
  }) {
    return ChatSessionModel(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
    );
  }

  factory ChatSessionModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;

    return ChatSessionModel(
      sessionId: data['session_id'] ?? '',
      messages:
          (data['messages'] as List<dynamic>?)
              ?.map((e) => ChatMessageModel.fromJson(e))
              .toList() ??
          [],
      hasMore: data['has_more'] ?? false,
      nextCursor: data['next_cursor'] ?? 0,
    );
  }

  static const empty = ChatSessionModel(
    sessionId: '',
    messages: [],
    hasMore: false,
    nextCursor: 0,
  );

  @override
  String toString() =>
      '{sessionId: $sessionId, messages: $messages, hasMore: $hasMore, nextCursor: $nextCursor}';
}

class ChatMessageModel extends Equatable {
  final int? messageId;
  final String? role;
  final String? content;
  final String? createdAt;

  const ChatMessageModel({
    this.messageId,
    this.role,
    this.content,
    this.createdAt,
  });

  ChatMessageModel copyWith({
    int? messageId,
    String? role,
    String? content,
    String? createdAt,
  }) {
    return ChatMessageModel(
      messageId: messageId ?? this.messageId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      messageId: json['message_id'] ?? 0,
      role: json['role'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  @override
  List<Object?> get props => [messageId, role, content, createdAt];

  @override
  String toString() =>
      '{messageId: $messageId, role: $role, content: $content, createdAt: $createdAt}';
}
