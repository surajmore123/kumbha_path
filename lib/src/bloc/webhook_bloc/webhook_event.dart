import 'package:equatable/equatable.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';

class WebhookEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ChatBotEvent extends WebhookEvent {
  final String message;

  ChatBotEvent({required this.message});
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
