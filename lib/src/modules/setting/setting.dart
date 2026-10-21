import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_bloc.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_event.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/models/user_profile.dart';
import 'package:kumbha_path/src/modules/journel/widgets/journal_widgets.dart'
    show JournalPhoto;
import 'package:permission_handler/permission_handler.dart';

/// Whether the OS allows notifications for the app: true, false, or null
/// when it can't be determined.
typedef NotificationStatusCheck = Future<bool?> Function();

Future<bool?> _defaultNotificationStatus() async {
  try {
    return (await Permission.notification.status).isGranted;
  } catch (_) {
    return null;
  }
}

/// `/setting`: profile, appearance, language, notifications and account.
///
/// Every control is backed by existing functionality:
/// * Theme and text size: the global [ThemeProvider] (applied instantly,
///   saved across restarts).
/// * Language: easy_localization via [LanguageHelper.setAppLanguage]
///   (saved), kept in sync with [LanguageHelper].
/// * Notifications: the OS permission state, with a shortcut to system
///   settings. Event reminders stay per event.
/// * Profile and logout: the existing [UserBloc] events and token removal.
class Setting extends StatefulWidget {
  const Setting({
    super.key,
    this.notificationStatus,
    this.openSystemSettings,
    this.deleteToken,
    this.pickImage,
  });

  /// Injected in tests.
  final NotificationStatusCheck? notificationStatus;
  final Future<bool> Function()? openSystemSettings;
  final Future<void> Function()? deleteToken;
  final Future<XFile?> Function(ImageSource source)? pickImage;

  @override
  State<Setting> createState() => _Setting();
}

enum _ProfilePending { none, load, save, photo }

class _Setting extends State<Setting> with WidgetsBindingObserver {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _editing = false;
  _ProfilePending _pending = _ProfilePending.none;
  Timer? _timeout;
  bool _profileFailed = false;
  String? _localPhoto;
  bool? _notificationsAllowed;
  bool _notificationsChecked = false;

  static const double _maxWidth = 720;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNotifications();
    // After the first frame so the listener below sees the result.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProfile();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeout?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Returning from system settings may have changed the permission.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkNotifications();
  }

  Future<void> _checkNotifications() async {
    final allowed =
        await (widget.notificationStatus ?? _defaultNotificationStatus)();
    if (!mounted) return;
    setState(() {
      _notificationsAllowed = allowed;
      _notificationsChecked = true;
    });
  }

  // ---------------- profile ----------------

  void _start(_ProfilePending kind, UserEvent event) {
    if (_pending != _ProfilePending.none) return;
    _timeout?.cancel();
    setState(() {
      _pending = kind;
      if (kind == _ProfilePending.load) _profileFailed = false;
    });
    _timeout = Timer(const Duration(seconds: 30), () => _finish(false));
    context.read<UserBloc>().add(event);
  }

  void _loadProfile() => _start(
    _ProfilePending.load,
    // Same request as before.
    ProfileGetEvent(status: UserStatus.profileLoaded),
  );

  void _finish(bool ok) {
    if (!mounted || _pending == _ProfilePending.none) return;
    final kind = _pending;
    _timeout?.cancel();
    setState(() {
      _pending = _ProfilePending.none;
      switch (kind) {
        case _ProfilePending.load:
          _profileFailed = !ok;
        case _ProfilePending.save:
          if (ok) _editing = false;
        case _ProfilePending.photo:
          if (!ok) _localPhoto = null;
        case _ProfilePending.none:
          break;
      }
    });
    final message = switch ((kind, ok)) {
      (_ProfilePending.save, true) => 'set_profile_saved'.tr(),
      (_ProfilePending.save, false) => 'set_profile_failed'.tr(),
      (_ProfilePending.photo, true) => 'set_photo_saved'.tr(),
      (_ProfilePending.photo, false) => 'set_photo_failed'.tr(),
      _ => null,
    };
    if (message != null) _snack(message);
    // Show the saved values.
    if (ok && kind == _ProfilePending.save) _loadProfile();
  }

  void _onUserState(BuildContext context, UserState state) {
    switch ((_pending, state.status)) {
      case (_ProfilePending.load, UserStatus.profileLoaded):
        _fillFields(state.profileData ?? UserData.empty);
        _finish(true);
      case (_ProfilePending.load, UserStatus.failure):
        _finish(false);
      case (_ProfilePending.save, UserStatus.profileUpdatedSuccess):
        _finish(true);
      case (_ProfilePending.save, UserStatus.profileUpdatedFailure):
        _finish(false);
      case (_ProfilePending.photo, UserStatus.profileImageUploadSuccess):
        _finish(true);
      case (_ProfilePending.photo, UserStatus.profileImageUploadFailure):
        _finish(false);
      default:
        break;
    }
  }

  void _fillFields(UserData data) {
    if (_editing) return; // don't overwrite what's being typed
    _nameController.text = data.fullName;
    _emailController.text = data.email;
  }

  void _save() {
    FocusScope.of(context).unfocus();
    _start(
      _ProfilePending.save,
      UserProfileCreateEvent(
        email: _emailController.text.trim(),
        fullName: _nameController.text.trim(),
      ),
    );
  }

  void _cancelEdit(UserData data) {
    setState(() => _editing = false);
    _fillFields(data);
  }

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder:
          (sheet) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: Text('ai_camera'.tr()),
                  onTap: () => Navigator.pop(sheet, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text('ai_gallery'.tr()),
                  onTap: () => Navigator.pop(sheet, ImageSource.gallery),
                ),
                AppSpacing.gapSm,
              ],
            ),
          ),
    );
    if (source == null || !mounted) return;
    XFile? picked;
    try {
      picked = await (widget.pickImage ??
          (s) => ImagePicker().pickImage(source: s, imageQuality: 25))(source);
    } catch (_) {
      if (mounted) _snack('ai_image_failed'.tr());
      return;
    }
    if (picked == null || !mounted) return;
    setState(() => _localPhoto = picked!.path);
    // Same upload as before.
    _start(_ProfilePending.photo, ImageAddEvent(image: picked.path));
  }

  // ---------------- logout ----------------

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialog) => AlertDialog(
            title: Text('set_logout_title'.tr()),
            content: Text('set_logout_body'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text('set_cancel'.tr()),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: dialog.colorScheme.error,
                ),
                onPressed: () => Navigator.pop(dialog, true),
                child: Text('set_logout'.tr()),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    // Same session removal as before.
    await (widget.deleteToken ?? () => storage.delete(key: 'access_token'))();
    if (!mounted) return;
    // Clear the stack so Back can't return into the signed-in app.
    Navigator.pushNamedAndRemoveUntil(context, '/loginScreen', (_) => false);
  }

  void _snack(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final language = context.locale.languageCode;

    return MainLayout(
      showDefaultBottom: false,
      ctx: 4,
      appBar: AppAppBar(title: 'set_title'.tr()),
      body: BlocConsumer<UserBloc, UserState>(
        listener: _onUserState,
        buildWhen: (a, b) => a.profileData != b.profileData,
        builder: (context, state) {
          final profile = state.profileData ?? UserData.empty;
          return LayoutBuilder(
            builder: (context, constraints) {
              final side = math.max(
                AppSpacing.pageGutter,
                (constraints.maxWidth - _maxWidth) / 2,
              );
              return ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  side,
                  AppSpacing.md,
                  side,
                  AppSpacing.huge,
                ),
                children: [
                  _section('set_profile'.tr(), [_profileCard(profile)]),
                  _section('set_appearance'.tr(), [
                    _ThemeSelector(
                      selected: theme.currentTheme,
                      onSelected: theme.setTheme,
                    ),
                    AppSpacing.gapXl,
                    _TextSizeSelector(
                      selected: theme.fontScalePreset,
                      onSelected: theme.setFontScale,
                    ),
                  ]),
                  _section('set_language'.tr(), [
                    _LanguageSelector(
                      selected: language,
                      onSelected:
                          (code) =>
                              LanguageHelper.setAppLanguage(context, code),
                    ),
                  ]),
                  _section('set_notifications'.tr(), [_notificationsCard()]),
                  _section('set_account'.tr(), [
                    AppButton.outlined(
                      label: 'set_logout'.tr(),
                      leadingIcon: Icons.logout_rounded,
                      onPressed: _logout,
                    ),
                  ]),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(title: title),
          AppSpacing.gapMd,
          ...children,
        ],
      ),
    );
  }

  Widget _profileCard(UserData profile) {
    final text = context.textTheme;
    final colors = context.colorScheme;
    final loading = _pending == _ProfilePending.load;
    final saving = _pending == _ProfilePending.save;
    final name = profile.fullName.trim();

    if (_profileFailed && profile.userId.isEmpty && !loading) {
      return AppCard(
        padding: EdgeInsets.zero,
        child: AppErrorView(
          compact: true,
          title: 'set_profile_load_failed'.tr(),
          onRetry: _loadProfile,
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Avatar(
                localPath: _localPhoto,
                url:
                    profile.profileUrl.trim().isEmpty
                        ? null
                        : '${ApiConst.baseUrl}/${profile.profileUrl}',
                uploading: _pending == _ProfilePending.photo,
                onChange:
                    _pending == _ProfilePending.none ? _changePhoto : null,
              ),
              AppSpacing.gapLg,
              Expanded(
                child:
                    loading && profile.userId.isEmpty
                        ? const LinearProgressIndicator()
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'set_no_name'.tr() : name,
                              style: text.titleMedium?.copyWith(
                                fontStyle:
                                    name.isEmpty ? FontStyle.italic : null,
                              ),
                            ),
                            if (profile.phoneNumber.trim().isNotEmpty)
                              Text(
                                profile.phoneNumber,
                                style: text.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            if (profile.email.trim().isNotEmpty)
                              Text(profile.email, style: text.bodySmall),
                          ],
                        ),
              ),
            ],
          ),
          AppSpacing.gapLg,
          if (!_editing)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton.secondary(
                label: 'set_edit_profile'.tr(),
                leadingIcon: Icons.edit_outlined,
                expand: false,
                onPressed:
                    _pending == _ProfilePending.none
                        ? () => setState(() => _editing = true)
                        : null,
              ),
            )
          else ...[
            AppTextField(
              controller: _nameController,
              label: 'set_full_name'.tr(),
              hint: 'set_full_name_hint'.tr(),
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              textInputAction: TextInputAction.next,
              enabled: !saving,
            ),
            AppSpacing.gapLg,
            AppTextField(
              controller: _emailController,
              label: 'set_email'.tr(),
              hint: 'set_email_hint'.tr(),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              enabled: !saving,
              onFieldSubmitted: (_) => _save(),
            ),
            AppSpacing.gapLg,
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                AppButton(
                  label: 'set_save'.tr(),
                  leadingIcon: Icons.check_rounded,
                  expand: false,
                  isLoading: saving,
                  onPressed: _save,
                ),
                AppButton.outlined(
                  label: 'set_cancel'.tr(),
                  expand: false,
                  onPressed: saving ? null : () => _cancelEdit(profile),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _notificationsCard() {
    final text = context.textTheme;
    final semantic = context.semanticColors;
    final colors = context.colorScheme;
    final allowed = _notificationsAllowed;
    final (String label, Color fg, Color bg, IconData icon) = switch (allowed) {
      true => (
        'set_notif_allowed'.tr(),
        semantic.onSuccessContainer,
        semantic.successContainer,
        Icons.notifications_active_outlined,
      ),
      false => (
        'set_notif_off'.tr(),
        colors.onErrorContainer,
        colors.errorContainer,
        Icons.notifications_off_outlined,
      ),
      null => (
        'set_notif_unknown'.tr(),
        colors.onSurfaceVariant,
        colors.surfaceContainerHigh,
        Icons.help_outline,
      ),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('set_notif_status'.tr(), style: text.titleSmall),
              if (_notificationsChecked)
                StatusPill(
                  label: label,
                  icon: icon,
                  foreground: fg,
                  background: bg,
                ),
            ],
          ),
          AppSpacing.gapXs,
          Text('set_notif_desc'.tr(), style: text.bodySmall),
          AppSpacing.gapMd,
          AppButton.outlined(
            label: 'temple_open_settings'.tr(),
            leadingIcon: Icons.settings_outlined,
            expand: false,
            onPressed: () => (widget.openSystemSettings ?? openAppSettings)(),
          ),
          const Divider(height: AppSpacing.xxl),
          Text('set_notif_reminders'.tr(), style: text.bodyMedium),
          AppSpacing.gapXs,
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/shahiEvents'),
            icon: const Icon(Icons.event_outlined),
            label: Text('set_open_events'.tr()),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.localPath,
    required this.url,
    required this.uploading,
    required this.onChange,
  });

  final String? localPath;
  final String? url;
  final bool uploading;
  final VoidCallback? onChange;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final Widget image;
    if (localPath != null) {
      image = JournalPhoto(
        source: localPath!,
        width: _size,
        height: _size,
        radius: BorderRadius.circular(_size),
      );
    } else if (url != null) {
      image = ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _placeholder(colors),
          placeholder: (_, __) => _placeholder(colors),
        ),
      );
    } else {
      image = _placeholder(colors);
    }

    return SizedBox.square(
      dimension: _size + AppSpacing.sm,
      child: Stack(
        children: [
          image,
          if (uploading)
            const Positioned.fill(
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          PositionedDirectional(
            end: -AppSpacing.sm,
            bottom: -AppSpacing.sm,
            child: AppIconButton(
              icon: Icons.photo_camera_outlined,
              tooltip: 'set_change_photo'.tr(),
              variant: AppIconButtonVariant.tonal,
              onPressed: onChange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme colors) => Container(
    width: _size,
    height: _size,
    decoration: BoxDecoration(
      color: colors.primaryContainer,
      shape: BoxShape.circle,
    ),
    child: Icon(
      Icons.person_outline,
      size: 36,
      color: colors.onPrimaryContainer,
    ),
  );
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.selected, required this.onSelected});

  final AppThemeOption selected;
  final ValueChanged<AppThemeOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('set_theme'.tr(), style: context.textTheme.titleSmall),
        AppSpacing.gapSm,
        SegmentedButton<AppThemeOption>(
          segments: [
            ButtonSegment(
              value: AppThemeOption.light,
              icon: const Icon(Icons.light_mode_outlined),
              label: Text('set_theme_light'.tr()),
            ),
            ButtonSegment(
              value: AppThemeOption.dark,
              icon: const Icon(Icons.dark_mode_outlined),
              label: Text('set_theme_dark'.tr()),
            ),
            ButtonSegment(
              value: AppThemeOption.system,
              icon: const Icon(Icons.brightness_auto_outlined),
              label: Text('set_theme_system'.tr()),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (s) => onSelected(s.first),
        ),
        AppSpacing.gapXs,
        Text('set_theme_system_hint'.tr(), style: context.textTheme.bodySmall),
      ],
    );
  }
}

class _TextSizeSelector extends StatelessWidget {
  const _TextSizeSelector({required this.selected, required this.onSelected});

  final AppFontScale selected;
  final ValueChanged<AppFontScale> onSelected;

  static String labelKey(AppFontScale s) => switch (s) {
    AppFontScale.small => 'set_text_small',
    AppFontScale.standard => 'set_text_default',
    AppFontScale.large => 'set_text_large',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('set_text_size'.tr(), style: context.textTheme.titleSmall),
        AppSpacing.gapSm,
        SegmentedButton<AppFontScale>(
          segments: [
            for (final s in AppFontScale.values)
              ButtonSegment(value: s, label: Text(labelKey(s).tr())),
          ],
          selected: {selected},
          onSelectionChanged: (s) => onSelected(s.first),
        ),
        AppSpacing.gapMd,
        // Live preview: the whole app already uses the chosen size, so the
        // preview is ordinary themed text.
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: AppRadius.mdAll,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('set_text_preview'.tr(), style: context.textTheme.bodyLarge),
              AppSpacing.gapXs,
              Text('set_text_hint'.tr(), style: context.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: RadioGroup<String>(
        groupValue: selected,
        onChanged: (code) {
          if (code != null) onSelected(code);
        },
        child: Column(
          children: [
            for (final MapEntry(key: code, value: name)
                in LanguageHelper.languages.entries)
              RadioListTile<String>(
                value: code,
                title: Text(name),
                activeColor: colors.primary,
                // Native name read in its own language.
                secondary: code == selected ? const Icon(Icons.check) : null,
              ),
          ],
        ),
      ),
    );
  }
}
