import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

/// Small speaker name above a message group.
class SenderLabel extends StatelessWidget {
  final String name;
  final bool isGuru;

  const SenderLabel({super.key, required this.name, this.isGuru = true});

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      style: context.textTheme.labelMedium?.copyWith(
        color:
            isGuru
                ? context.colorScheme.tertiary
                : context.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
