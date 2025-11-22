import 'package:flutter/material.dart';

import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/modules/login_screen/otp_verify_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isDesktop = context.isDesktop;

    final imageSize =
        isMobile
            ? context.w(0.4)
            : isTablet
            ? context.w(0.25)
            : context.w(0.18);

    return Scaffold(
      appBar: AppBar(
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: LanguageIconButton(),
          ),
        ],
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: LanguageHelper.currentLang,
        builder: (context, lang, _) {
          final titleStyle = Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize:
                isMobile
                    ? 20
                    : isTablet
                    ? 26
                    : 30,
          );

          final subtitleStyle = Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontSize: isMobile ? 14 : 16, color: Colors.grey[700]);

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal:
                  isMobile
                      ? 24
                      : isTablet
                      ? 40
                      : 56,
              vertical: isMobile ? 16 : 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 420 : 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icons/login_screen.png',
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    LanguageHelper.t('welcome'),
                    style: titleStyle,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    LanguageHelper.t('enter_mobile'),
                    style: subtitleStyle,
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: isMobile ? 24 : 32),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      LanguageHelper.t('mobile_number'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: LanguageHelper.t('enter_number_hint'),
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14.0,
                        horizontal: 16.0,
                      ),
                    ),
                  ),

                  SizedBox(height: isMobile ? 30 : 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 14 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>OtpVerifyScreen() ));
                      },
                      child: Text(
                        LanguageHelper.t('get_otp'),
                        style: TextStyle(
                          fontSize: isMobile ? 15 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: isMobile ? 16 : 20),

                  Text(
                    LanguageHelper.t('otp_info'),
                    style: subtitleStyle,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
