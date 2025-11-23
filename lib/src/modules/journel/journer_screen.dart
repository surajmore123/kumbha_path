import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';

class JournerScreen extends StatelessWidget {
  const JournerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      showDefaultBottom: true,
      ctx: 3,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,

        title: Text(
          // LanguageHelper.t('dashboard_title'),
          'My Kumbh Journal',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(child: Text('Journal')),
    );
  }
}