import 'package:flutter/widgets.dart';
import 'package:kumbha_path/main_layout.dart';

class Dashboard extends StatelessWidget{
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context){
    return MainLayout(showDefaultBottom: true,
    showCurvedAppBar: true,
    body: Center(child: Text('Dashboard')),
    );
  }
}