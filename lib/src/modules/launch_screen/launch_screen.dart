import 'package:flutter/material.dart';

import 'package:kumbha_path/src/network/controller/user_authentication.dart';


class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {

  @override
  void initState(){
    super.initState();
    Future.delayed(const Duration(seconds: 3),()async{
      final auth = UserAuthentication();
      final isLogin = await auth.checkLogin();
      if(!mounted) return;

      if(isLogin){
        Navigator.pushReplacementNamed(context, '/dashboardScreen');
      }else{
        Navigator.pushReplacementNamed(context, '/loginScreen');
      }
      
    });
  
    
  }
  @override
  Widget build(BuildContext context) {


    return Scaffold(
      body: Image.asset(
        'assets/icons/launch_screen.png',
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      ),

    );
  }
}



