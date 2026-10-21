import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/login_screen/widgets/auth_widgets.dart';
import 'package:kumbha_path/src/network/controller/user_authentication.dart';

/// First route (`/launchScreen`). Checks for a stored session and replaces
/// itself with `/dashboardScreen` or `/loginScreen`, as before.
///
/// The session check starts immediately. Navigation waits for it to finish
/// and for a short minimum display ([minimumDisplay], previously a fixed
/// 3 s delay before the check even began), so the brand doesn't flash.
class LaunchScreen extends StatefulWidget {
  const LaunchScreen({
    super.key,
    this.checkLogin,
    this.minimumDisplay = const Duration(milliseconds: 1200),
  });

  /// Defaults to [UserAuthentication.checkLogin]. Injected in tests.
  final Future<bool> Function()? checkLogin;
  final Duration minimumDisplay;

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  static Future<bool> _defaultCheck() async =>
      await UserAuthentication().checkLogin() == true;

  @override
  void initState() {
    super.initState();
    _route();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the system "remove animations" setting.
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else if (!_intro.isAnimating && _intro.value == 0) {
      _intro.forward();
    }
  }

  Future<void> _route() async {
    final check = (widget.checkLogin ?? _defaultCheck)().then<bool>(
      (value) => value,
      // Unreadable storage counts as "no session": the user can sign in
      // again instead of being stuck on the splash.
      onError: (Object _) => false,
    );
    final results = await Future.wait<Object?>([
      check,
      Future<void>.delayed(widget.minimumDisplay),
    ]);
    if (!mounted) return;
    final isLogin = results.first == true;
    Navigator.pushReplacementNamed(
      context,
      isLogin ? '/dashboardScreen' : '/loginScreen',
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onImage = context.semanticColors.onImage;
    final text = context.textTheme;
    final fade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);
    final rise = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(fade);

    return Scaffold(
      body: AuthPhoto(
        alignment: const Alignment(0, -0.2),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: FadeTransition(
                opacity: fade,
                child: SlideTransition(
                  position: rise,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AuthBrandMark(size: 104),
                      AppSpacing.gapXl,
                      Semantics(
                        header: true,
                        child: Text(
                          'app_title'.tr(),
                          textAlign: TextAlign.center,
                          style: text.displaySmall?.copyWith(
                            color: onImage,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      AppSpacing.gapSm,
                      Text(
                        'auth_tagline'.tr(),
                        textAlign: TextAlign.center,
                        style: text.titleMedium?.copyWith(
                          color: onImage.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      AppSpacing.gapSm,
                      Text(
                        'dash_hero_place'.tr(),
                        textAlign: TextAlign.center,
                        style: text.labelLarge?.copyWith(
                          color: onImage.withValues(alpha: 0.8),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
