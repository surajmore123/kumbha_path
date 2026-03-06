import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';


import 'package:kumbha_path/src/bloc/user_bloc/user_bloc.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_event.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_state.dart';
import 'package:kumbha_path/src/components/loader/center_loader.dart';
import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
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
        automaticallyImplyLeading: false,
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

          return BlocConsumer<UserBloc, UserState>(
            listener: (context, state) {
              if (state.status == UserStatus.success) {
                CenterLoader.hide();
                  final phone = _phoneNumberController.text.trim();
                Fluttertoast.showToast(
                  msg: "Otp Send Successfully",
                  backgroundColor: Colors.amberAccent,
                  toastLength: Toast.LENGTH_SHORT,
                );
              

                Navigator.pushNamed(context, '/verifyOtpScreen',arguments: phone);
              } else if (state.status == UserStatus.sending) {
                CenterLoader.show(context);
              } else if (state.status == UserStatus.failure) {
                CenterLoader.hide();
                Fluttertoast.showToast(
                  msg: "Otp send Failed",
                  backgroundColor: Colors.red,
                  toastLength: Toast.LENGTH_SHORT,
                );
              }
            },
            builder: (context, state) {
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
                child: Form(
                     key: _formKey,
                  child: ConstrainedBox(
                 
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 420 : 500,
                    ),
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
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          keyboardType: TextInputType.phone,
                          controller: _phoneNumberController,
                          maxLength: 10,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Phone Number is required";
                            }
                            return null;
                          },

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
                              // final isValid = _formKey.currentState?.validate()?? false;
                              // if(isValid){
                              context.read<UserBloc>().add(
                                UserCreateEvent(
                                  phoneNumber:
                                      _phoneNumberController.text.toString(),
                                ),
                              );
                         
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
