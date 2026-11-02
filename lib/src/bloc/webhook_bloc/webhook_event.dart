import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';

class WebhookEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ChatBotEvent extends WebhookEvent {
  final ChatPayloadType type;
  final String? message; // text, or a caption sent with a photo/document
  final File? file;      // for image/audio/document

  ChatBotEvent.text({required this.message})
      : type = ChatPayloadType.text,
        file = null;

  ChatBotEvent.image({required this.file, this.message})
      : type = ChatPayloadType.image;

  ChatBotEvent.audio({required this.file})
      : type = ChatPayloadType.audio,
        message = null;

  ChatBotEvent.document({required this.file, this.message})
      : type = ChatPayloadType.document;
}


class ChatBothistoryEvent extends WebhookEvent {
  final String? sessionId;
  final int? cursor;       // for pagination
  final int limit;         // default 10
  final bool isLoadMore;
  final WebhookStatus? status;

  ChatBothistoryEvent({
     this.sessionId,
    this.cursor,
    this.limit = 10,
    this.isLoadMore = false,
    this.status
  });

  @override
  List<Object?> get props => [sessionId, cursor, limit, isLoadMore];
}
