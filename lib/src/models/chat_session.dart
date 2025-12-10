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
      messages: (data['messages'] as List<dynamic>?)
        ?.map((e) => ChatMessageModel.fromJson(e))
        .toList() ?? [],

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
  final String? fileUrl; // NEW
  final String? messageType; // NEW (text / image / audio)
  final MessageMetadata? metadata; // NEW
  final String? createdAt;

  const ChatMessageModel({
    this.messageId,
    this.role,
    this.content,
    this.fileUrl,
    this.messageType,
    this.metadata,
    this.createdAt,
  });

  ChatMessageModel copyWith({
    int? messageId,
    String? role,
    String? content,
    String? fileUrl,
    String? messageType,
    MessageMetadata? metadata,
    String? createdAt,
  }) {
    return ChatMessageModel(
      messageId: messageId ?? this.messageId,
      role: role ?? this.role,
      content: content ?? this.content,
      fileUrl: fileUrl ?? this.fileUrl,
      messageType: messageType ?? this.messageType,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      messageId: json['message_id'] ?? 0,
      role: json['role'] ?? '',
      content: json['content'], // can be null
      fileUrl: json['file_url'], // may be null
      messageType: json['message_type'], // text/image/audio/null
      metadata:
          json['metadata'] != null
              ? MessageMetadata.fromJson(json['metadata'])
              : null,
      createdAt: json['created_at'] ?? '',
    );
  }

  @override
  List<Object?> get props => [
    messageId,
    role,
    content,
    fileUrl,
    messageType,
    metadata,
    createdAt,
  ];

  @override
  String toString() =>
      '{messageId: $messageId, role: $role, content: $content, fileUrl: $fileUrl, metadata: $metadata, createdAt: $createdAt}';
}

class MessageMetadata extends Equatable {
  final String? originalName;
  final String? contentType;
  final int? size;

  const MessageMetadata({this.originalName, this.contentType, this.size});

  factory MessageMetadata.fromJson(Map<String, dynamic> json) {
    return MessageMetadata(
      originalName: json['original_name'],
      contentType: json['content_type'],
      size: json['size'],
    );
  }

  @override
  List<Object?> get props => [originalName, contentType, size];

  @override
  String toString() =>
      '{originalName: $originalName, contentType: $contentType, size: $size}';
}
