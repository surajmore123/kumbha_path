import 'package:flutter/material.dart';

class SenderLabel extends StatelessWidget {
  final String name;
  final bool isGuru;

  const SenderLabel({super.key, required this.name, this.isGuru = true});

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