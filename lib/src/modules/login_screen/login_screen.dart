import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_bloc.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_event.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/modules/login_screen/widgets/auth_widgets.dart';

/// `/loginScreen`: mobile number entry. Sends `UserCreateEvent`
/// (send-mobile-otp) and, on `otpsended`, opens `/verifyOtpScreen` with the
/// number as the route argument, exactly as before.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _phoneFocus = FocusNode();
  final _submitKey = GlobalKey();

  static const int phoneLength = 10;

  /// True only for a request this screen started, so state changes caused
  /// by other screens (e.g. Resend on the OTP screen, which reuses the same
  /// event) don't push a second OTP screen.
  bool _awaitingOtp = false;
  String? _error;
  Timer? _timeout;
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(_keepSubmitVisible);
  }

  /// When the keyboard opens, keep the primary action on screen too.
  void _keepSubmitVisible() {
    if (!_phoneFocus.hasFocus) return;
    _revealTimer?.cancel();
    // Wait for the keyboard inset to apply before scrolling.
    _revealTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final target = _submitKey.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 200),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  String? _validatePhone(String? value) {
    final digits = (value ?? '').trim();
    if (digits.isEmpty) return 'phone_required'.tr();
    if (digits.length != phoneLength) return 'auth_phone_invalid'.tr();
    return null;
  }

  void _submit() {
    if (_awaitingOtp) return;
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _awaitingOtp = true);
    _timeout?.cancel();
    _timeout = Timer(kAuthRequestTimeout, () {
      if (!mounted) return;
      setState(() {
        _awaitingOtp = false;
        _error = 'auth_network_error'.tr();
      });
    });
    context.read<UserBloc>().add(
      UserCreateEvent(phoneNumber: _phoneNumberController.text.trim()),
    );
  }

  void _onUserState(BuildContext context, UserState state) {
    if (!_awaitingOtp) return;
    if (state.status == UserStatus.otpsended) {
      _timeout?.cancel();
      setState(() => _awaitingOtp = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('otp_success'.tr())));
      Navigator.pushNamed(
        context,
        '/verifyOtpScreen',
        arguments: _phoneNumberController.text.trim(),
      );
    } else if (state.status == UserStatus.otpsendingfail) {
      _timeout?.cancel();
      setState(() {
        _awaitingOtp = false;
        _error = 'otp_failed'.tr();
      });
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _revealTimer?.cancel();
    _phoneFocus.removeListener(_keepSubmitVisible);
    _phoneFocus.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colorScheme;

    return BlocListener<UserBloc, UserState>(
      listener: _onUserState,
      child: Scaffold(
        appBar: const AppAppBar(
          showBackButton: false,
          actions: [LanguageIconButton(), SizedBox(width: AppSpacing.xs)],
        ),
        body: AuthLayout(
          banner: const AuthBanner(),
          form: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'auth_welcome_title'.tr(),
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AppSpacing.gapSm,
                  Text(
                    'enter_mobile'.tr(),
                    style: text.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  AppSpacing.gapXxl,
                  AppTextField(
                    controller: _phoneNumberController,
                    focusNode: _phoneFocus,
                    label: 'mobile_number'.tr(),
                    hint: 'enter_number_hint'.tr(),
                    prefixIcon: Icons.phone_iphone_rounded,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [
                      AutofillHints.telephoneNumberNational,
                    ],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(phoneLength),
                    ],
                    enabled: !_awaitingOtp,
                    validator: _validatePhone,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    AppSpacing.gapMd,
                    AuthMessage(message: _error!),
                  ],
                  AppSpacing.gapXl,
                  KeyedSubtree(
                    key: _submitKey,
                    child: AppButton(
                      label: 'get_otp'.tr(),
                      trailingIcon: Icons.arrow_forward_rounded,
                      isLoading: _awaitingOtp,
                      onPressed: _submit,
                    ),
                  ),
                  AppSpacing.gapLg,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      AppSpacing.gapSm,
                      Expanded(
                        child: Text('otp_info'.tr(), style: text.bodySmall),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
