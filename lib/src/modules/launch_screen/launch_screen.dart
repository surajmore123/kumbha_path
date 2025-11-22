import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';

class LaunchScreen extends StatelessWidget {
  const LaunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      showDefaultBottom: true,
      body: Center(child: Text('Launch Screen')));
  }
}
