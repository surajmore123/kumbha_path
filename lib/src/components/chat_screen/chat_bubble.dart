import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final bool isGuru;
  final String? avatarImage;
  final String text;
  final bool showCornerBadge;

  const ChatBubble({super.key, 
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