import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';

class AskGuruAiScreen extends StatelessWidget {
  const AskGuruAiScreen({super.key});

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
      body: Scaffold(
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
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      const SizedBox(height: 8),

       
                      const _SenderLabel(name: 'Guru AI'),

                      const SizedBox(height: 8),

                      _ChatBubble(
                        isGuru: true,
                        avatarImage: 'assets/images/austrologer.jpg', 
                        text:
                            'Namaste! How may I guide you on your spiritual path today?',
                      ),

                      const SizedBox(height: 16),

                      // User message
                      const _SenderLabel(name: 'You', isGuru: false),
                      const SizedBox(height: 8),
                      _ChatBubble(
                        isGuru: false,
                        avatarImage: null,
                        text: 'What is the significance of the Kumbh Mela?',
                      ),

                      const SizedBox(height: 24),

                      // Guru label
                      const _SenderLabel(name: 'Guru AI'),

                      const SizedBox(height: 8),

                      // Guru long message
                      _ChatBubble(
                        isGuru: true,
                        avatarImage: 'assets/images/austrologer.jpg', 
                        text:
                            'The Kumbh Mela is a sacred Hindu pilgrimage and festival, celebrated in a cycle of approximately 12 years. It represents a time for spiritual cleansing and renewal at four holy river-bank pilgrimage sites.',
                        showCornerBadge: true,
                      ),

                      const SizedBox(height: 16),

                      // Typing indicator row
                      _TypingIndicatorRow(
                        avatars: const [
                          'assets/images/austrologer.jpg',
                          'assets/images/austrologer.jpg',
                        ],
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),

                // BOTTOM INPUT BAR
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, isMobile ? 16 : 20),
                  child: _ChatInputBar(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SenderLabel extends StatelessWidget {
  final String name;
  final bool isGuru;

  const _SenderLabel({required this.name, this.isGuru = true});

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color:
            isGuru
                ? const Color(0xFFDA8A2A) // orange-ish
                : const Color(0xFF1B7A4A), // green-ish
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isGuru;
  final String? avatarImage;
  final String text;
  final bool showCornerBadge;

  const _ChatBubble({
    required this.isGuru,
    required this.text,
    this.avatarImage,
    this.showCornerBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        isGuru
            ? const Color(0xFFFFF7E8) // guru: cream
            : const Color(0xFFBFFBE8); // user: mint

    final alignment =
        isGuru ? CrossAxisAlignment.start : CrossAxisAlignment.end;

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isGuru ? 4 : 20),
      bottomRight: Radius.circular(isGuru ? 20 : 4),
    );

    Widget bubble = Container(
      decoration: BoxDecoration(color: bubbleColor, borderRadius: borderRadius),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          height: 1.4,
          color: Color(0xFF333333),
        ),
      ),
    );

    if (showCornerBadge) {
      bubble = Stack(
        children: [
          bubble,
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'ॐ',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:
          isGuru ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        if (isGuru && avatarImage != null) ...[
          CircleAvatar(radius: 18, backgroundImage: AssetImage(avatarImage!)),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Column(crossAxisAlignment: alignment, children: [bubble]),
        ),
        if (!isGuru) const SizedBox(width: 8),
      ],
    );
  }
}

class _TypingIndicatorRow extends StatelessWidget {
  final List<String> avatars;

  const _TypingIndicatorRow({required this.avatars});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // stacked avatars vertically
        Column(
          children:
              avatars
                  .map(
                    (path) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundImage: AssetImage(path),
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E8),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _Dot(),
              SizedBox(width: 4),
              _Dot(),
              SizedBox(width: 4),
              _Dot(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: const Color(0xFFE0B76F),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Ask a question or share your thoughts.',
                hintStyle: TextStyle(color: Color(0xFFB0B5C0), fontSize: 14),
                border: InputBorder.none,
              ),
              minLines: 1,
              maxLines: 3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFFFC72C),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic, size: 20, color: Color(0xFF6C4A00)),
          ),
        ],
      ),
    );
  }
}
