import 'package:equatable/equatable.dart';

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

class WebhookState extends Equatable{
  final WebhookStatus status;

  const WebhookState({
   
     this.status = WebhookStatus.initial});
  
  @override

  List<Object?> get props =>[status];

  WebhookState copyWith({
    WebhookStatus? status
  }){
    return WebhookState(status: status ?? this.status);
  }

}