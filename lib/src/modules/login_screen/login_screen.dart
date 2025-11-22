import 'package:flutter/widgets.dart';
import 'package:kumbha_path/main_layout.dart';

class LoginScreen extends StatelessWidget{
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context){
    return MainLayout(body: Center(child: Text('Login Screen')),);
  }
}