import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_bloc.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_event.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/login_screen/widgets/auth_widgets.dart';
import 'package:pinput/pinput.dart';

/// `/verifyOtpScreen`: 6-digit code entry for [phoneNumber].
///
/// Verify sends `VerifyOtpEvent(phoneNumber, otp)`; on `otpverified` the
/// stack is cleared to `/dashboardScreen`, as before. Resend reuses
/// `UserCreateEvent` after the existing 60-second countdown.
class OtpVerifyScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpVerifyScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

enum _Pending { none, verify, resend }

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final TextEditingController otpController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  static const int otpLength = 6;
  static const int resendSeconds = 60;

  Timer? _countdownTimer;
  int _remainingSeconds = resendSeconds;
  bool _isResendActive = false;

  _Pending _pending = _Pending.none;
  Timer? _timeout;
  String? _error;
  String? _errorDetail;

  bool get _isOtpFilled => otpController.text.length == otpLength;

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
    otpController.addListener(_onOtpChanged);
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _remainingSeconds = resendSeconds;
      _isResendActive = false;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 1) {
          _remainingSeconds--;
        } else {
          _remainingSeconds = 0;
          _isResendActive = true;
          timer.cancel();
        }
      });
    });
  }

  void _onOtpChanged() {
    setState(() {
      // Editing the code clears the previous attempt's error.
      if (_error != null && _pending == _Pending.none) {
        _error = null;
        _errorDetail = null;
      }
    });
  }

  void _startPending(_Pending kind) {
    _timeout?.cancel();
    setState(() {
      _pending = kind;
      _error = null;
      _errorDetail = null;
    });
    _timeout = Timer(kAuthRequestTimeout, () {
      if (!mounted) return;
      setState(() {
        if (_pending == _Pending.resend) _isResendActive = true;
        _pending = _Pending.none;
        _error = 'auth_network_error'.tr();
      });
    });
  }

  void _finishPending() {
    _timeout?.cancel();
    _pending = _Pending.none;
  }

  void _verify() {
    if (!_isOtpFilled || _pending != _Pending.none) return;
    FocusScope.of(context).unfocus();
    _startPending(_Pending.verify);
    context.read<UserBloc>().add(
      VerifyOtpEvent(phoneNumber: widget.phoneNumber, otp: otpController.text),
    );
  }

  void _resendOtp() {
    if (!_isResendActive || _pending != _Pending.none) return;
    otpController.clear();
    _startPending(_Pending.resend);
    context.read<UserBloc>().add(
      UserCreateEvent(phoneNumber: widget.phoneNumber),
    );
    _startCountdownTimer();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onUserState(BuildContext context, UserState state) {
    switch ((_pending, state.status)) {
      case (_Pending.verify, UserStatus.otpverified):
        _finishPending();
        _snack('registration_success'.tr());
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/dashboardScreen',
          (route) => false,
        );
      case (_Pending.verify, UserStatus.otpverifiedfail):
        setState(() {
          _finishPending();
          _error = 'otp_verification_failed'.tr();
          _errorDetail = 'auth_otp_failed_hint'.tr();
        });
        focusNode.requestFocus();
      case (_Pending.resend, UserStatus.otpsended):
        setState(_finishPending);
        _snack('auth_code_resent'.tr());
        focusNode.requestFocus();
      case (_Pending.resend, UserStatus.otpsendingfail):
        _countdownTimer?.cancel();
        setState(() {
          _finishPending();
          _isResendActive = true;
          _error = 'otp_failed'.tr();
        });
      default:
        break;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _timeout?.cancel();
    otpController.removeListener(_onOtpChanged);
    otpController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  String get _countdownLabel {
    final m = _remainingSeconds ~/ 60;
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '${'resend_in_prefix'.tr()} $m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colorScheme;
    final semantic = context.semanticColors;
    final masked = maskPhoneNumber(widget.phoneNumber);
    final verifying = _pending == _Pending.verify;
    final hasError = _error != null;

    return BlocListener<UserBloc, UserState>(
      listener: _onUserState,
      child: Scaffold(
        appBar: AppAppBar(
          title: 'verify_your_number'.tr(),
          showBackButton: true,
        ),
        body: AuthLayout(
          banner: const AuthBanner(),
          form: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'enter_verification_code'.tr(),
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppSpacing.gapSm,
              Text(
                'otp_verify_message'.tr(),
                style: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
              ),
              AppSpacing.gapMd,
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.xs,
                children: [
                  Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Text(
                      'auth_code_sent_to'.tr(args: [masked]),
                      style: text.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed:
                        verifying ? null : () => Navigator.maybePop(context),
                    child: Text('auth_change_number'.tr()),
                  ),
                ],
              ),
              AppSpacing.gapLg,
              LayoutBuilder(
                builder:
                    (context, constraints) => _OtpInput(
                      controller: otpController,
                      focusNode: focusNode,
                      maxWidth: constraints.maxWidth,
                      hasError: hasError && _errorDetail != null,
                      enabled: !verifying,
                      onCompleted: (_) => setState(() {}),
                    ),
              ),
              if (hasError) ...[
                AppSpacing.gapMd,
                AuthMessage(message: _error!, detail: _errorDetail),
              ],
              AppSpacing.gapXl,
              AppButton(
                label: 'verify_button'.tr(),
                isLoading: verifying,
                onPressed: _isOtpFilled ? _verify : null,
              ),
              AppSpacing.gapLg,
              Center(
                child:
                    _isResendActive
                        ? TextButton.icon(
                          onPressed:
                              _pending == _Pending.none ? _resendOtp : null,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text('auth_resend'.tr()),
                        )
                        : Semantics(
                          liveRegion: false,
                          child: Text(
                            _countdownLabel,
                            style: text.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
              ),
              AppSpacing.gapLg,
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: semantic.infoContainer,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 20,
                      color: semantic.onInfoContainer,
                    ),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Text(
                        'code_expire_in'.tr(),
                        style: text.bodySmall?.copyWith(
                          color: semantic.onInfoContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Six themed boxes. Pinput provides paste, the system one-time-code
/// autofill hint and correct focus movement.
class _OtpInput extends StatelessWidget {
  const _OtpInput({
    required this.controller,
    required this.focusNode,
    required this.maxWidth,
    required this.hasError,
    required this.enabled,
    required this.onCompleted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final double maxWidth;
  final bool hasError;
  final bool enabled;
  final ValueChanged<String> onCompleted;

  static const double _gap = AppSpacing.sm;
  static const double _maxBox = 56;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final semantic = context.semanticColors;
    final count = _OtpVerifyScreenState.otpLength;
    final box = ((maxWidth - _gap * (count - 1)) / count).clamp(36.0, _maxBox);
    // Taller than wide so scaled digits keep room.
    final height = box * 1.2;
    final digitStyle = context.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: colors.onSurface,
    );

    PinTheme theme(Color border, {double width = 1, Color? fill}) => PinTheme(
      width: box,
      height: height,
      textStyle: digitStyle,
      decoration: BoxDecoration(
        color: fill ?? semantic.inputFill,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: border, width: width),
      ),
    );

    return Semantics(
      label: 'auth_otp_label'.tr(),
      child: Directionality(
        textDirection: ui.TextDirection.ltr,
        child: Pinput(
          length: count,
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
          enabled: enabled,
          separatorBuilder: (_) => const SizedBox(width: _gap),
          defaultPinTheme: theme(semantic.border),
          focusedPinTheme: theme(colors.primary, width: 2),
          submittedPinTheme: theme(colors.outline),
          errorPinTheme: theme(colors.error, width: 1.5),
          forceErrorState: hasError,
          onCompleted: onCompleted,
          hapticFeedbackType: HapticFeedbackType.lightImpact,
        ),
      ),
    );
  }
}
