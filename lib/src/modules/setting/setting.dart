import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_bloc.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_event.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_state.dart';
import 'package:kumbha_path/src/components/image_upload/profile_pic.dart';
import 'package:kumbha_path/src/components/loader/center_loader.dart';
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/constant/app_color.dart';

import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/constant/theme_provider.dart';
import 'package:provider/provider.dart';

class Setting extends StatefulWidget {
  const Setting({super.key});

  @override
  State<Setting> createState() => _Setting();
}

// enum AppThemeOption { light, dark, system }

class _Setting extends State<Setting> {
  bool isSelected = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _realTimeAlerts = true;
  bool _dailyGuidance = true;
  bool _communityNews = false;
  bool _appUpdates = true;

  AppThemeOption _selectedTheme = AppThemeOption.light;

  XFile profileImage = XFile('');
  bool isLoading = false;
  String profileUrl = "";

  void initState() {
    super.initState();
    context.read<UserBloc>().add(
      ProfileGetEvent(status: UserStatus.profileLoaded),
    );
  }

  assignValues(UserState state) {
    _nameController.text = state.profileData!.fullName.toString();
    _emailController.text = state.profileData!.email.toString();
    profileUrl = state.profileData!.profileUrl.toString();

    print('profilee full ${ApiConst.baseUrl}/$profileUrl');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isDesktop = context.isDesktop;
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    // Use the shared gradient builder so light shows orange, dark uses cs.primary -> cs.primaryContainer
    final gradient = buildThemeGradient(context, isPrimary: true);

    return MainLayout(
      showDefaultBottom: false,
      ctx: 0,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? cs.surface,
        elevation: 0,

        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          LanguageHelper.t('settings_title'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: cs.onBackground,
          ),
        ),
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: LanguageHelper.currentLang,
        builder: (context, lang, _) {
          final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: isMobile ? 14 : 15,
            fontWeight: FontWeight.w600,
            color: cs.onBackground,
          );

          final hintStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: isMobile ? 13.5 : 14,
            color: cs.onBackground.withOpacity(0.55),
          );

          return BlocConsumer<UserBloc, UserState>(
            listener: (context, state) {
              if (state.status == UserStatus.profileLoaded) {
                assignValues(state);
              }
              if (state.status == UserStatus.profileUpdatedSuccess) {
                CenterLoader.hide();
                Fluttertoast.showToast(
                  msg: "Profile Updated Successfully",
                  backgroundColor: cs.primaryContainer,
                  toastLength: Toast.LENGTH_SHORT,
                );

                // Navigator.pushNamed(context, '/settingScreen');
              } else if (state.status == UserStatus.sending) {
                CenterLoader.show(context);
              } else if (state.status == UserStatus.profileUpdatedFailure) {
                CenterLoader.hide();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Profile Update failed',
                      style: TextStyle(color: cs.onError),
                    ),
                    backgroundColor: cs.error,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            builder: (context, state) {
              return Container(
                color: theme.scaffoldBackgroundColor,
                // color: const Color(0xFFFFF7E9),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        isMobile
                            ? 16
                            : isTablet
                            ? 32
                            : 56,
                    vertical: isMobile ? 16 : 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 520 : 480,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LanguageHelper.t('settings_my_profile'),
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: isMobile ? 16 : 18,
                                color: cs.onBackground,
                              ),
                            ),
                            const SizedBox(height: 16),
                        
                            // ========== PROFILE ROW ==========
                            Row(
                              children: [
                                ProfilePic(
                                  takeImage: takeImage,
                                  imageFile: profileImage,
                                  existedImageUrl:
                                      '${ApiConst.baseUrl}/$profileUrl',
                                ),
                        
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _nameController.text,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: cs.onBackground,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () {
                                          // TODO: change profile picture
                                        },
                                        child: Text(
                                          LanguageHelper.t(
                                            'settings_edit_profile_picture',
                                          ),
                                          style: labelStyle,
                                          // style: TextStyle(
                                          //   fontSize: 13,
                                          //   fontWeight: FontWeight.w600,
                                          //   color: cs.primary,
                                          // ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                        
                            GestureDetector(
                              onTap:
                                  () => setState(
                                    () => isSelected = !isSelected,
                                  ),
                              child: Opacity(
                                opacity: isSelected ? 0.6 : 1.0,
                                child: Container(
                                  width: isMobile ? 80 : 100,
                                  height: isMobile ? 40 : 46,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(32),
                                    gradient: buildThemeGradient(
                                      context,
                                      isPrimary: true,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            brightness == Brightness.dark
                                                ? cs.primary.withOpacity(0.18)
                                                : cs.primary.withOpacity(
                                                  0.18,
                                                ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                        
                                  // decoration: BoxDecoration(
                                  //   gradient: LinearGradient(
                                  //     colors: [
                                  //       cs.primary,
                                  //       cs.primaryContainer,
                                  //     ],
                                  //   ),
                                  //   boxShadow: [
                                  //     BoxShadow(
                                  //       color: cs.primary.withOpacity(0.22),
                                  //       blurRadius: 8,
                                  //       offset: const Offset(0, 3),
                                  //     ),
                                  //   ],
                                  //   borderRadius: BorderRadius.circular(28),
                                  // ),
                                  child: Center(
                                    child: Text(
                                      'Edit',
                                      style: TextStyle(color: cs.onPrimary),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        
                            const SizedBox(height: 20),
                        
                            // ========== FULL NAME FIELD ==========
                            Text(
                              LanguageHelper.t('settings_full_name'),
                              style: labelStyle,
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                hintText: LanguageHelper.t(
                                  'settings_full_name_hint',
                                ),
                                filled: true,
                                fillColor: theme.cardColor,
                        
                                // labelStyle: TextStyle(
                                //   color:
                                //       isSelected
                                //           ? textColor
                                //           : lightblackColor,
                                // ),
                                hintStyle: hintStyle,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                        
                            const SizedBox(height: 14),
                        
                            // ========== EMAIL FIELD ==========
                            Text(
                              LanguageHelper.t('settings_email'),
                              style: labelStyle,
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: LanguageHelper.t(
                                  'settings_email_hint',
                                ),
                                filled: true,
                                fillColor: theme.cardColor,
                        
                                // labelStyle: TextStyle(
                                //   color:
                                //       isSelected
                                //           ? textColor
                                //           : lightblackColor,
                                // ),
                                hintStyle: hintStyle,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                        
                            const SizedBox(height: 18),
                        
                            GestureDetector(
                              onTap:
                                  isSelected
                                      ? () {
                                        BlocProvider.of<UserBloc>(
                                          context,
                                        ).add(
                                          UserProfileCreateEvent(
                                            email:
                                                _emailController.text.trim(),
                                            fullName:
                                                _nameController.text.trim(),
                                          ),
                                        );
                                      }
                                      : null,
                              // () {
                        
                              // },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  gradient: buildThemeGradient(
                                    context,
                                    isPrimary: true,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          brightness == Brightness.dark
                                              ? cs.primary.withOpacity(0.18)
                                              : cs.primary.withOpacity(0.18),
                                      blurRadius: 10,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                // decoration: BoxDecoration(
                                //   borderRadius: BorderRadius.circular(28),
                                // gradient: LinearGradient(colors: [cs.primary, cs.primaryContainer]),
                                //   boxShadow: [
                                //     BoxShadow(
                                //       color: cs.primary.withOpacity(0.22),
                                //       blurRadius: 8,
                                //       offset: const Offset(0, 3),
                                //     ),
                                //   ],
                                // ),
                                child: Center(
                                  child: Text(
                                    LanguageHelper.t('settings_save_changes'),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: cs.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        
                            const SizedBox(height: 20),
                          ],
                        ),

                        Divider(
                          height: 32,
                          thickness: 0.6,
                          color: cs.outline.withOpacity(0.9),
                        ),

                        Text(
                          LanguageHelper.t('settings_notification_preferences'),
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: isMobile ? 16 : 18,
                            color: cs.onBackground,
                          ),
                        ),

                        const SizedBox(height: 12),

                        _SettingsToggleRow(
                          labelKey: 'settings_realtime_alerts',
                          value: _realTimeAlerts,
                          onChanged: (val) {
                            setState(() => _realTimeAlerts = val);
                          },
                        ),
                        _SettingsToggleRow(
                          labelKey: 'settings_daily_guidance',
                          value: _dailyGuidance,
                          onChanged: (val) {
                            setState(() => _dailyGuidance = val);
                          },
                        ),
                        _SettingsToggleRow(
                          labelKey: 'settings_community_news',
                          value: _communityNews,
                          onChanged: (val) {
                            setState(() => _communityNews = val);
                          },
                        ),
                        _SettingsToggleRow(
                          labelKey: 'settings_app_updates',
                          value: _appUpdates,
                          onChanged: (val) {
                            setState(() => _appUpdates = val);
                          },
                        ),

                        const SizedBox(height: 16),
                        Divider(
                          height: 32,
                          thickness: 0.6,
                          color: cs.outline.withOpacity(0.9),
                        ),

                        // ========== APP THEME ==========
                        Text(
                          LanguageHelper.t('settings_app_theme'),
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: isMobile ? 16 : 18,
                            color: cs.onBackground,
                          ),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: _ThemeOptionCard(
                                icon: Icons.wb_sunny_outlined,
                                labelKey: 'settings_theme_light',
                                isSelected:
                                    _selectedTheme == AppThemeOption.light,
                                onTap: () {
                                  setState(
                                    () => _selectedTheme = AppThemeOption.light,
                                  );
                                  themeProvider.setTheme(AppThemeOption.light);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ThemeOptionCard(
                                icon: Icons.nightlight_round,
                                labelKey: 'settings_theme_dark',
                                isSelected:
                                    _selectedTheme == AppThemeOption.dark,
                                onTap: () {
                                  setState(
                                    () => _selectedTheme = AppThemeOption.dark,
                                  );
                                  themeProvider.setTheme(AppThemeOption.dark);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ThemeOptionCard(
                                icon: Icons.settings_suggest_outlined,
                                labelKey: 'settings_theme_system',
                                isSelected:
                                    _selectedTheme == AppThemeOption.system,
                                onTap: () {
                                  setState(
                                    () =>
                                        _selectedTheme = AppThemeOption.system,
                                  );
                                  themeProvider.setTheme(AppThemeOption.system);
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        Divider(
                          height: 32,
                          thickness: 0.6,
                          color: cs.outline.withOpacity(0.9),
                        ),

                        const SizedBox(height: 8),

                        // ========== LOGOUT BUTTON ==========
                        GestureDetector(
                          onTap: () async {
                            await storage.delete(key: 'access_token');
                            Navigator.pushReplacementNamed(
                              context,
                              '/loginScreen',
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: cs.error, width: 1.5),
                              color: Colors.transparent,
                            ),
                            child: Center(
                              child: Text(
                                LanguageHelper.t('settings_logout'),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: cs.error,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
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

  Future<void> takeImage(BuildContext context) async {
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final pickedFile = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 25,
                  );
                  if (pickedFile != null) {
                    setState(() {
                      profileImage = XFile(pickedFile.path);
                      isLoading = true;
                    });

                    context.read<UserBloc>().add(
                      ImageAddEvent(image: profileImage.path),
                    );

                    await Future.delayed(const Duration(seconds: 1));
                    setState(() {
                      isLoading = false;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final pickedFile = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 25,
                  );
                  if (pickedFile != null) {
                    setState(() {
                      profileImage = XFile(pickedFile.path);
                      isLoading = true;
                    });

                    context.read<UserBloc>().add(
                      ImageAddEvent(image: profileImage.path),
                    );

                    await Future.delayed(const Duration(seconds: 1));
                    setState(() {
                      isLoading = false;
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  final String labelKey;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleRow({
    required this.labelKey,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              LanguageHelper.t(labelKey),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                // fontSize: isMobile ? 16 : 18,
                color: cs.onBackground,
              ),
            ),
          ),

          GestureDetector(
  onTap: () => onChanged(!value),
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    width: 42,
    height: 24,
    padding: const EdgeInsets.symmetric(horizontal: 3),
    decoration: BoxDecoration(
      color: value
          ? getAccentColor(context) 
          : cs.surfaceVariant,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Align(
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: value
            ? Icon(
                Icons.check,
                size: 12,
                color: getAccentColor(context), // 🔥 FIX
              )
            : null,
      ),
    ),
  ),
),

          // GestureDetector(
          //   onTap: () => onChanged(!value),
          //   child: AnimatedContainer(
          //     duration: const Duration(milliseconds: 160),
          //     width: 42,
          //     height: 24,
          //     padding: const EdgeInsets.symmetric(horizontal: 3),
          //     decoration: BoxDecoration(
          //       color: value ? cs.primary : cs.surfaceVariant,
          //       borderRadius: BorderRadius.circular(24),
          //     ),
          //     child: Align(
          //       alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          //       child: Container(
          //         width: 18,
          //         height: 18,
          //         decoration: BoxDecoration(
          //           color: Colors.white,
          //           shape: BoxShape.circle,
          //           boxShadow: [
          //             BoxShadow(
          //               color: Colors.black.withOpacity(0.12),
          //               blurRadius: 4,
          //               offset: const Offset(0, 2),
          //             ),
          //           ],
          //         ),
          //         child:
          //             value
          //                 ? Icon(Icons.check, size: 12, color: cs.primary)
          //                 : null,
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final IconData icon;
  final String labelKey;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    required this.icon,
    required this.labelKey,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = LanguageHelper.t(labelKey);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          gradient:
              isSelected ? buildThemeGradient(context, isPrimary: true) : null,
          color: isSelected ? null : cs.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color:
                isSelected
                    ? (isDark ? cs.primary : const Color(0xFFFFA726))
                    : cs.outline.withOpacity(0.6),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 44,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isSelected ? Colors.transparent : cs.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isSelected ? cs.onPrimary : cs.onBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? cs.onPrimary : cs.onBackground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
Color getAccentColor(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return isDark ? cs.primary : const Color(0xFFFFA726);
}
