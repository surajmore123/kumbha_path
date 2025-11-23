import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';

class ShahiEvents extends StatelessWidget {
  const ShahiEvents({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      showDefaultBottom: true,
      ctx: 2,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,

        title: Text(
          // LanguageHelper.t('dashboard_title'),
          'Upcoming Snans & Events',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(child: Text('Events')),
    );
  }
}
