import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/operations/data/ops_repository.dart';
import 'package:kumbha_path/src/services/fcm_service.dart';

/// `/opsSignIn`: sign-in for approved volunteers and staff, reached from the
/// normal login screen. Their accounts reach sensitive case data, so they use a
/// password set with a one-time code from an administrator, not an OTP.
class OpsSignInScreen extends StatefulWidget {
  const OpsSignInScreen({super.key, this.repository, this.saveToken});

  final OpsRepository? repository;

  /// Injected in tests.
  final Future<void> Function(String token)? saveToken;

  @override
  State<OpsSignInScreen> createState() => _OpsSignInScreenState();
}

class _OpsSignInScreenState extends State<OpsSignInScreen> {
  late final OpsRepository _repo = widget.repository ?? OpsServices.repository;
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _firstTime = false;
  bool _hidden = true;
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save(String token) async {
    final save = widget.saveToken;
    if (save != null) return save(token);
    await storage.write(key: 'access_token', value: token);
    await FcmService.registerWithBackend();
  }

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    final password = _password.text;
    final code = _code.text.trim();
    if (phone.isEmpty || password.isEmpty || (_firstTime && code.isEmpty)) {
      setState(() => _problem = 'ops_sign_in_incomplete'.tr());
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final token =
          _firstTime
              ? await _repo.completeSetup(phone, code, password)
              : await _repo.signIn(phone, password);
      await _save(token);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboardScreen',
        (route) => false,
      );
    } on FamilyException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = switch (e.kind) {
          FamilyFailure.signedOut => 'ops_sign_in_failed'.tr(),
          FamilyFailure.invalid =>
            e.fieldErrors['password'] ?? 'ops_password_weak'.tr(),
          _ => familyErrorText(e),
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    return Scaffold(
      appBar: AppBar(title: Text('ops_sign_in_title'.tr())),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(editorialMargin),
          children: [
            Semantics(
              header: true,
              child: Text(
                (_firstTime ? 'ops_setup_heading' : 'ops_sign_in_heading').tr(),
                style: e.headline,
              ),
            ),
            AppSpacing.gapXs,
            Text((_firstTime ? 'ops_setup_intro' : 'ops_sign_in_intro').tr()),
            AppSpacing.gapLg,
            AppTextField(
              label: 'ops_phone'.tr(),
              controller: _phone,
              keyboardType: TextInputType.phone,
            ),
            if (_firstTime) ...[
              AppSpacing.gapSm,
              AppTextField(label: 'ops_setup_code'.tr(), controller: _code),
            ],
            AppSpacing.gapSm,
            TextField(
              controller: _password,
              obscureText: _hidden,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText:
                    (_firstTime ? 'ops_new_password' : 'ops_password').tr(),
                suffixIcon: IconButton(
                  tooltip: (_hidden ? 'ops_show' : 'ops_hide').tr(),
                  icon: Icon(
                    _hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _hidden = !_hidden),
                ),
              ),
            ),
            if (_problem != null) ...[
              AppSpacing.gapSm,
              Text(
                _problem!,
                style: TextStyle(color: context.colorScheme.error),
              ),
            ],
            AppSpacing.gapMd,
            AppButton(
              label: (_firstTime ? 'ops_set_password' : 'ops_sign_in').tr(),
              isLoading: _busy,
              onPressed: _busy ? null : _submit,
            ),
            AppSpacing.gapSm,
            TextButton(
              onPressed:
                  () => setState(() {
                    _firstTime = !_firstTime;
                    _problem = null;
                  }),
              child: Text(
                (_firstTime ? 'ops_have_password' : 'ops_first_time').tr(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
