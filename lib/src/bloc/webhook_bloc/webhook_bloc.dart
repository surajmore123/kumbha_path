import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_event.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';

class WebhookBloc extends Bloc<WebhookEvent,WebhookState>{
  WebhookBloc(): super(WebhookState());
}