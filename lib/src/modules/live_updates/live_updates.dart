
import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';

class LiveUpdates extends StatelessWidget{
  const LiveUpdates({super.key});

  @override
  Widget build(BuildContext context){
       return MainLayout(
      showDefaultBottom: true,
      ctx: 0,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,

        title: Text(
          // LanguageHelper.t('dashboard_title'),
          'Live Updates & Alerts',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(child: Text('Notifications')),
    );
  }
}