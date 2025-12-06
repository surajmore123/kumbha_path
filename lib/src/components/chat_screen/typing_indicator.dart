import 'package:flutter/material.dart';

class TypingIndicatorRow extends StatefulWidget {
  final List<String> avatars;

  const TypingIndicatorRow({required this.avatars, Key? key}) : super(key: key);

  @override
  State<TypingIndicatorRow> createState() => TypingIndicatorRowState();
}

class TypingIndicatorRowState extends State<TypingIndicatorRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _dot1;
  late Animation<double> _dot2;
  late Animation<double> _dot3;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Staggered animations for the 3 dots
    _dot1 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
    );

    _dot2 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.75, curve: Curves.easeInOut),
    );

    _dot3 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.9, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // stacked avatars vertically
        Column(
          children:
              widget.avatars
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
            children: [
              _AnimatedDot(animation: _dot1),
              const SizedBox(width: 4),
              _AnimatedDot(animation: _dot2),
              const SizedBox(width: 4),
              _AnimatedDot(animation: _dot3),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnimatedDot extends StatelessWidget {
  final Animation<double> animation;

  const _AnimatedDot({required this.animation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.6, end: 1.0).animate(animation),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: const Color(0xFFE0B76F),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
