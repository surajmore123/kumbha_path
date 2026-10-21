import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_bloc.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_event.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';
import 'package:kumbha_path/src/components/chat_screen/chat_bubble.dart';
import 'package:kumbha_path/src/components/chat_screen/chat_input.dart';
import 'package:kumbha_path/src/components/chat_screen/typing_indicator.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/models/chat_messages.dart';
import 'package:kumbha_path/src/modules/ai_chat/widgets/chat_parts.dart';
import 'package:kumbha_path/src/modules/ai_chat/widgets/mantra_mandala_background.dart';

/// `/aichat`: conversation with AI Guru through the existing [WebhookBloc]
/// (`api/chat/chat-send/` and `api/chat/chat-history/`).
///
/// Replies arrive complete (no streaming), so the screen shows a thinking
/// indicator while one is pending. The list is reversed, which keeps the
/// newest message at the bottom and the reading position stable when
/// older history is prepended.
class AskGuruAiScreen extends StatefulWidget {
  const AskGuruAiScreen({super.key, this.readSessionId});

  /// Reads the stored chat session id. Defaults to secure storage
  /// (`session_id`), as before; injected in tests.
  final Future<String?> Function()? readSessionId;

  @override
  State<AskGuruAiScreen> createState() => _AskGuruAiScreenState();
}

class _AskGuruAiScreenState extends State<AskGuruAiScreen> {
  final ScrollController _scrollController = ScrollController();

  /// A message this screen sent is waiting for its reply.
  bool _awaitingReply = false;
  ChatBotEvent? _lastSent;

  /// Index (in bloc messages) of the user message whose request failed.
  int? _failedIndex;

  /// Failed messages that were retried. The bloc appends a fresh copy on
  /// retry, so the failed original is hidden to avoid showing it twice.
  final Set<int> _superseded = {};

  bool _historyLoaded = false;
  bool _historyFailed = false;
  bool _loadingOlder = false;
  bool _showJump = false;

  static const double _maxWidth = 760;

  Future<String?> _sessionId() =>
      (widget.readSessionId ?? () => storage.read(key: 'session_id'))();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialHistory();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Same request as before: the stored session's latest 10 messages.
  Future<void> _loadInitialHistory() async {
    String? sessionId;
    try {
      sessionId = await _sessionId();
    } catch (_) {
      sessionId = null;
    }
    if (!mounted) return;
    setState(() => _historyFailed = false);
    if (sessionId != null && sessionId.isNotEmpty) {
      context.read<WebhookBloc>().add(
        ChatBothistoryEvent(sessionId: sessionId, limit: 10, isLoadMore: false),
      );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final showJump = position.pixels > 400;
    if (showJump != _showJump) setState(() => _showJump = showJump);
    // Reversed list: the oldest messages are at the max extent.
    if (position.pixels >= position.maxScrollExtent - 80) _loadOlder();
  }

  /// Existing pagination: same conditions and `isLoadMore` request.
  Future<void> _loadOlder() async {
    if (_loadingOlder) return;
    final bloc = context.read<WebhookBloc>();
    final state = bloc.state;
    final session = state.chatSessionModel;
    if (session == null ||
        session.hasMore != true ||
        state.status == WebhookStatus.loading ||
        (session.nextCursor ?? 0) <= 0) {
      return;
    }
    _loadingOlder = true;
    String? sessionId;
    try {
      sessionId = await _sessionId();
    } catch (_) {
      sessionId = null;
    }
    if (!mounted) return;
    bloc.add(
      ChatBothistoryEvent(
        sessionId: sessionId ?? '',
        cursor: session.nextCursor,
        limit: 10,
        isLoadMore: true,
      ),
    );
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _send(ChatBotEvent event) {
    if (_awaitingReply) return; // one request at a time
    setState(() {
      _awaitingReply = true;
      _lastSent = event;
      _failedIndex = null;
    });
    context.read<WebhookBloc>().add(event);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  void _retry() {
    final event = _lastSent;
    final failed = _failedIndex;
    if (event == null || failed == null) return;
    setState(() => _superseded.add(failed));
    _send(event);
  }

  void _onState(BuildContext context, WebhookState state) {
    if (state.status == WebhookStatus.loading) return;
    if (_loadingOlder &&
        (state.status == WebhookStatus.success ||
            state.status == WebhookStatus.failure)) {
      _loadingOlder = false;
    }
    if (_awaitingReply) {
      if (state.status == WebhookStatus.success) {
        setState(() => _awaitingReply = false);
        _scrollToLatest();
      } else if (state.status == WebhookStatus.failure) {
        setState(() {
          _awaitingReply = false;
          _failedIndex = state.messages.length - 1;
        });
      }
      return;
    }
    if (state.status == WebhookStatus.success) {
      setState(() {
        _historyLoaded = true;
        _historyFailed = false;
      });
    } else if (state.status == WebhookStatus.failure && !_historyLoaded) {
      setState(() => _historyFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      ctx: 1,
      showDefaultBottom: false,
      appBar: AppAppBar(titleWidget: const _Header()),
      body: BlocConsumer<WebhookBloc, WebhookState>(
        listener: _onState,
        builder: (context, state) {
          final visible = <int>[
            for (var i = 0; i < state.messages.length; i++)
              if (!_superseded.contains(i)) i,
          ];
          final initialLoading =
              state.status == WebhookStatus.loading &&
              state.messages.isEmpty &&
              !_awaitingReply;

          final Widget conversation;
          if (initialLoading) {
            conversation = const AppLoading();
          } else if (visible.isEmpty && !_awaitingReply) {
            conversation = ChatWelcome(
              onSuggestion: (text) => _send(ChatBotEvent.text(message: text)),
              historyError:
                  _historyFailed
                      ? ChatHistoryError(onRetry: _loadInitialHistory)
                      : null,
            );
          } else {
            conversation = _ConversationList(
              controller: _scrollController,
              messages: state.messages,
              visible: visible,
              awaitingReply: _awaitingReply,
              failedIndex: _failedIndex,
              loadingOlder:
                  state.status == WebhookStatus.loading &&
                  state.messages.isNotEmpty,
              onRetry: _awaitingReply ? null : _retry,
              onAskAgain: (text) => _send(ChatBotEvent.text(message: text)),
            );
          }

          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    const Positioned.fill(child: MantraMandalaBackground()),
                    Positioned.fill(child: conversation),
                    if (_showJump)
                      PositionedDirectional(
                        end: AppSpacing.lg,
                        bottom: AppSpacing.md,
                        child: Material(
                          color: context.semanticColors.dialogSurface,
                          shape: const CircleBorder(),
                          elevation: AppElevation.level2,
                          child: AppIconButton(
                            icon: Icons.arrow_downward_rounded,
                            tooltip: 'ai_jump_latest'.tr(),
                            onPressed: _scrollToLatest,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxWidth),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      child: ChatInputBar(
                        isSending: _awaitingReply,
                        onSubmit: _send,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AiGuruAvatar(size: 36),
        AppSpacing.gapMd,
        Flexible(
          child: MediaQuery.withClampedTextScaling(
            // Fixed toolbar height; two lines must fit.
            maxScaleFactor: 1.3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ai_guru'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'ai_subtitle'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Reversed conversation list: index 0 is the bottom (newest).
class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.controller,
    required this.messages,
    required this.visible,
    required this.awaitingReply,
    required this.failedIndex,
    required this.loadingOlder,
    required this.onRetry,
    required this.onAskAgain,
  });

  final ScrollController controller;
  final List<ChatMessage> messages;
  final List<int> visible;
  final bool awaitingReply;
  final int? failedIndex;
  final bool loadingOlder;
  final VoidCallback? onRetry;
  final ValueChanged<String> onAskAgain;

  static const double _maxWidth = 760;

  /// The user's text question that an assistant reply answers.
  String? _questionBefore(int index) {
    for (var i = index - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.isGuru) return null;
      if (m.type == ChatPayloadType.text && (m.text ?? '').trim().isNotEmpty) {
        return m.text!.trim();
      }
    }
    return null;
  }

  Widget _message(BuildContext context, int index) {
    final m = messages[index];
    final previous = visible.indexOf(index) - 1;
    final prevIsSameSender =
        previous >= 0 && messages[visible[previous]].isGuru == m.isGuru;
    final Widget body = switch (m.type) {
      ChatPayloadType.text when m.isGuru && (m.text ?? '').trim().isEmpty =>
        ChatEmptyReply(
          onAskAgain:
              awaitingReply || _questionBefore(index) == null
                  ? null
                  : () => onAskAgain(_questionBefore(index)!),
        ),
      ChatPayloadType.text => ChatBubble(
        isGuru: m.isGuru,
        text: m.text ?? '',
        showAvatar: !prevIsSameSender,
      ),
      ChatPayloadType.image => ChatImageBubble(
        isGuru: m.isGuru,
        imagePath: m.mediaPath ?? '',
      ),
      ChatPayloadType.audio => ChatAudioBubble(isGuru: m.isGuru),
    };
    return Padding(
      padding: EdgeInsets.only(
        top: prevIsSameSender ? AppSpacing.xs : AppSpacing.lg,
      ),
      child: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Bottom-to-top: thinking indicator, then newest → oldest messages
    // (each failed message preceded by its failure row), then the
    // "loading older" indicator at the top.
    final items = <Widget Function(BuildContext)>[
      if (awaitingReply)
        (_) => const Padding(
          padding: EdgeInsets.only(top: AppSpacing.lg),
          child: TypingIndicatorRow(),
        ),
      for (final i in visible.reversed) ...[
        if (i == failedIndex && !awaitingReply)
          (_) => Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: ChatFailureRow(onRetry: onRetry),
          ),
        (c) => _message(c, i),
      ],
      if (loadingOlder)
        (_) => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            constraints.maxWidth > _maxWidth
                ? (constraints.maxWidth - _maxWidth) / 2
                : AppSpacing.pageGutter;
        return ListView.builder(
          controller: controller,
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            side,
            AppSpacing.md,
            side,
            AppSpacing.md,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => items[index](context),
        );
      },
    );
  }
}
