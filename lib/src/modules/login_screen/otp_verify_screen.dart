import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/modules/dashboard/dashboard.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isDesktop = context.isDesktop;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(LanguageHelper.t('verify_your_number')),
      ),

      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, isMobile ? 16 : 24),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context)=>Dashboard()));
            },
            child: Text(
              LanguageHelper.t('verify_button'),
              style: TextStyle(
                fontSize: isMobile ? 15 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
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

          return Center(
            child: SingleChildScrollView(
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
                    Text(
                      LanguageHelper.t('verify_your_number'),
                      style: titleStyle,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      LanguageHelper.t('otp_verify_message'),
                      style: subtitleStyle,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        6,
                        (index) => _buildOtpBox(
                          context,
                          controller: _otpControllers[index],
                          isMobile: isMobile,
                          isLast: index == 5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: subtitleStyle,
                        children: [
                          TextSpan(
                            text: LanguageHelper.t('resend_in_prefix') + ' ',
                          ),
                          TextSpan(
                            text: '01:30',
                            style: subtitleStyle?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: () {},
                      child: Text(
                        LanguageHelper.t('didnt_receive_resend'),
                        style: subtitleStyle?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOtpBox(
    BuildContext context, {
    required TextEditingController controller,
    required bool isMobile,
    required bool isLast,
  }) {
    final double boxWidth = isMobile ? 50 : 55;
    final double boxHeight = isMobile ? 65 : 70;

    return SizedBox(
      width: boxWidth,
      height: boxHeight,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: TextStyle(
          fontSize: isMobile ? 24 : 26,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          counterText: '',
          isDense: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.8,
            ),
          ),
        ),

        onChanged: (value) {
          if (value.length == 1 && !isLast) {
            FocusScope.of(context).nextFocus();
          } else if (value.isEmpty) {
            FocusScope.of(context).previousFocus();
          }
        },
      ),
    );
  }
}
