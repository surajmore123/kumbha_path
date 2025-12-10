import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_bloc.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_event.dart';
import 'package:kumbha_path/src/bloc/webhook_bloc/webhook_state.dart';
import 'package:kumbha_path/src/components/chat_screen/chat_bubble.dart';
import 'package:kumbha_path/src/components/chat_screen/chat_input.dart';
import 'package:kumbha_path/src/components/chat_screen/send_label.dart';
import 'package:kumbha_path/src/components/chat_screen/typing_indicator.dart';
import 'package:kumbha_path/src/constant/config.dart';

class AskGuruAiScreen extends StatefulWidget {
  const AskGuruAiScreen({super.key});

  @override
  State<AskGuruAiScreen> createState() => _AskGuruAiScreenState();
}

class _AskGuruAiScreenState extends State<AskGuruAiScreen> {
  final ScrollController _scrollController = ScrollController();

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

  Future<void> _loadInitialHistory() async {
    String? sessionId = await storage.read(key: 'session_id');
    // final sessionId = await storage.read(key: 'chat_session_id');

    if (!mounted) return;

    if (sessionId != null && sessionId.isNotEmpty) {
      context.read<WebhookBloc>().add(
        ChatBothistoryEvent(sessionId: sessionId, limit: 10, isLoadMore: false),
      );
    }
  }

  void _onScroll() async {
    String? sessionId = await storage.read(key: 'session_id');
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 40) {
      final bloc = context.read<WebhookBloc>();
      final state = bloc.state;
      final session = state.chatSessionModel;

      if (session != null &&
          session.hasMore == true &&
          state.status != WebhookStatus.loading &&
          (session.nextCursor ?? 0) > 0) {
        bloc.add(
          ChatBothistoryEvent(
            sessionId: sessionId ?? '',
            cursor: session.nextCursor,
            limit: 10,
            isLoadMore: true,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return MainLayout(
      ctx: 1,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE7B5),
        actions: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFBDDB6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.more_vert, color: Color(0xFFFFF2D8)),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: BlocConsumer<WebhookBloc, WebhookState>(
        listener: (context, state) {
          // auto-scroll when:
          // - user sends message (sending)
          // - AI replies (success)
          if (state.status == WebhookStatus.sending ||
              state.status == WebhookStatus.success) {
            _scrollToBottom();
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: const Color(0xFFFBDDB6),
            body: SafeArea(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFF0CF),
                      Color(0xFFFFE7B5),
                      Color(0xFFFFF2D8),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Ask Guru AI',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB35C00),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Seek. Learn. Reflect.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFFCC8B40),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount:
                            state.messages.length +
                            1, // +1 for initial guru greeting
                        itemBuilder: (context, index) {
                          // First item: static welcome message from Guru AI
                          if (index == 0) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                SenderLabel(name: 'Guru AI'),
                                SizedBox(height: 8),
                                ChatBubble(
                                  isGuru: true,
                                  avatarImage: 'assets/images/austrologer.jpg',
                                  text: 'Namaste! How may I guide you today?',
                                ), //on your spiritual path
                                SizedBox(height: 16),
                              ],
                            );
                          }

                          final msg = state.messages[index - 1];

                          Widget content;
                          if (msg.type == ChatPayloadType.text) {
                            // normal text bubble
                            content = ChatBubble(
                              isGuru: msg.isGuru,
                              avatarImage:
                                  msg.isGuru
                                      ? 'assets/images/austrologer.jpg'
                                      : null,
                              text: msg.text ?? '',
                            );
                          } else if (msg.type == ChatPayloadType.image) {
                            content = _ImageBubble(
                              isGuru: msg.isGuru,
                              imagePath: msg.mediaPath!,
                            );
                          } else {
                            content = _AudioBubble(
                              isGuru: msg.isGuru,
                              audioPath: msg.mediaPath!,
                            );
                          }

                          return Column(
                            crossAxisAlignment:
                                msg.isGuru
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.end,
                            children: [
                              SenderLabel(
                                name: msg.isGuru ? 'Guru AI' : 'You',
                                isGuru: msg.isGuru,
                              ),
                              const SizedBox(height: 4),
                              content,
                              const SizedBox(height: 12),
                            ],
                          );
                        },
                      ),
                    ),

                    // Typing indicator just above input
                    if (state.status == WebhookStatus.sending)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: TypingIndicatorRow(
                          avatars: const ['assets/images/austrologer.jpg'],
                        ),
                      ),

                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        isMobile ? 16 : 20,
                      ),
                      child: ChatInputBar(
                        onMessageSent: _scrollToBottom,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImageBubble extends StatelessWidget {
  final bool isGuru;
  final String imagePath;

  const _ImageBubble({Key? key, required this.isGuru, required this.imagePath})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isGuru ? 4 : 18),
      bottomRight: Radius.circular(isGuru ? 18 : 4),
    );

    // 👇 Decide whether it's a local file or a URL
    final bool isNetwork = imagePath.startsWith('http');

    final Widget imageWidget =
        isNetwork
            ? Image.network(imagePath, width: 220, fit: BoxFit.cover)
            : Image.file(File(imagePath), width: 220, fit: BoxFit.cover);

    return Align(
      alignment: isGuru ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        decoration: BoxDecoration(
          // color: isGuru ? const Color(0xFFFFF2D8) : const Color(0xFFFFC72C),
          borderRadius: radius,
        ),
        padding: const EdgeInsets.all(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imageWidget,
        ),
      ),
    );
  }
}

class _AudioBubble extends StatelessWidget {
  final bool isGuru;
  final String audioPath;

  const _AudioBubble({Key? key, required this.isGuru, required this.audioPath})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isGuru ? 4 : 18),
      bottomRight: Radius.circular(isGuru ? 18 : 4),
    );

    return Align(
      alignment: isGuru ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        decoration: BoxDecoration(
          color: isGuru ? const Color(0xFFFFF2D8) : const Color(0xFFFFC72C),
          borderRadius: radius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.mic, size: 20, color: Color(0xFF6C4A00)),
            SizedBox(width: 8),
            Text(
              'Audio message',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6C4A00),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
