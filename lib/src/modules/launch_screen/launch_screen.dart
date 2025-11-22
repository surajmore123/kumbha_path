import 'package:flutter/material.dart';
import 'package:kumbha_path/src/modules/login_screen/login_screen.dart';


class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {

  @override
  void initState(){
    super.initState();
    Future.delayed(const Duration(seconds: 3),(){
      if(!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=> LoginScreen()));
    });
  
    
  }
  @override
  Widget build(BuildContext context) {
    // final isMobile = context.isMobile;
    // final isTablet = context.isTablet;
    // final isDesktop = context.isDesktop;

    // final imageSize = isMobile
    //     ? context.w(0.4)
    //     : isTablet
    //         ? context.w(0.25)
    //         : context.w(0.18);

    // final textStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
    //       fontWeight: FontWeight.w600,
    //       fontSize: isMobile
    //           ? 20
    //           : isTablet
    //               ? 26
    //               : 30,
    //     );

    // final bool useColumn = isMobile;

    return Scaffold(
      body: Image.asset(
        'assets/icons/launch_screen.png',
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      ),

      // Center(
      //   child: ConstrainedBox(
      //     constraints: const BoxConstraints(
      //       maxWidth: 800,
      //     ),
      //     child: Padding(
      //       padding: EdgeInsets.symmetric(
      //         horizontal: isMobile ? 24 : 40,
      //         vertical: isMobile ? 16 : 24,
      //       ),
      //       child: useColumn
      //           ? Column(
      //               mainAxisAlignment: MainAxisAlignment.center,
      //               children: [
      //                 Image.asset(
      //                   'assets/icons/launch.png',
      //                   width: imageSize,
      //                   height: imageSize,
      //                   fit: BoxFit.contain,
      //                 ),
      //                 const SizedBox(height: 16),
      //                 Text(
      //                   'Your Spiritual Journey,\nGuided.',
      //                   textAlign: TextAlign.center,
      //                   style: textStyle,
      //                 ),
      //               ],
      //             )
      //           : Row(
      //               mainAxisAlignment: MainAxisAlignment.center,
      //               children: [
      //                 Image.asset(
      //                   'assets/icons/launch.png',
      //                   width: imageSize,
      //                   height: imageSize,
      //                   fit: BoxFit.contain,
      //                 ),
      //                 SizedBox(width: isDesktop ? 48 : 32),
      //                 Expanded(
      //                   child: Text(
      //                     'Your Spiritual Journey,\nGuided.',
      //                     textAlign: TextAlign.left,
      //                     style: textStyle,
      //                   ),
      //                 ),
      //               ],
      //             ),
      //     ),
      //   ),
      // ),
    );
  }
}



