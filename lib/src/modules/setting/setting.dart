import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:flutter/material.dart';
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
import 'package:kumbha_path/src/models/user_profile.dart';

class Setting extends StatefulWidget {
  const Setting({super.key});

  @override
  State<Setting> createState() => _Setting();
}

enum AppThemeOption { light, dark, system }

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
    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isDesktop = context.isDesktop;

    return MainLayout(
      showDefaultBottom: false,
      ctx: 0,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7E9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          LanguageHelper.t('settings_title'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: LanguageHelper.currentLang,
        builder: (context, lang, _) {
          final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: isMobile ? 14 : 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          );

          final hintStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: isMobile ? 13.5 : 14,
            color: const Color(0xFF9CA3AF),
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
                  backgroundColor: Colors.amberAccent,
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
                      style: TextStyle(color: Colors.red),
                    ),
                    backgroundColor: redColor,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            builder: (context, state) {
              return Container(
                color: const Color(0xFFFFF7E9),
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
                        Container(
                          child: Column(
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
                                  color: const Color(0xFF111827),
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
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF111827),
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
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFF59E0B),
                                            ),
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
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFFA726),
                                          Color(0xFFFFC107),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.orange.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Edit',
                                        style: TextStyle(color: Colors.white),
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
                                  fillColor: Colors.white,

                                  labelStyle: TextStyle(
                                    color:
                                        isSelected
                                            ? textColor
                                            : lightblackColor,
                                  ),
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
                                  fillColor: Colors.white,

                                  labelStyle: TextStyle(
                                    color:
                                        isSelected
                                            ? textColor
                                            : lightblackColor,
                                  ),
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
                                // decoration: InputDecoration(
                                //   hintText: LanguageHelper.t('settings_email_hint'),
                                //   hintStyle: hintStyle,
                                //   filled: true,
                                //   fillColor: Colors.white,
                                //   contentPadding: const EdgeInsets.symmetric(
                                //     horizontal: 16,
                                //     vertical: 12,
                                //   ),
                                //   border: OutlineInputBorder(
                                //     borderRadius: BorderRadius.circular(24),
                                //     borderSide: BorderSide.none,
                                //   ),
                                // ),
                              ),

                              const SizedBox(height: 18),

                              // ========== SAVE CHANGES BUTTON ==========
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
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFFA726),
                                        Color(0xFFFFC107),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      LanguageHelper.t('settings_save_changes'),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),

                        // ========== MY PROFILE HEADING ==========
                        const Divider(
                          height: 32,
                          thickness: 0.6,
                          color: Color(0xFFE5E7EB),
                        ),

                        // ========== NOTIFICATION PREFERENCES ==========
                        Text(
                          LanguageHelper.t('settings_notification_preferences'),
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: isMobile ? 16 : 18,
                            color: const Color(0xFF111827),
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
                        const Divider(
                          height: 32,
                          thickness: 0.6,
                          color: Color(0xFFE5E7EB),
                        ),

                        // ========== APP THEME ==========
                        Text(
                          LanguageHelper.t('settings_app_theme'),
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: isMobile ? 16 : 18,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _ThemeOptionCard(
                                icon: Icons.wb_sunny_outlined,
                                labelKey: 'settings_theme_light',
                                isSelected:
                                    _selectedTheme == AppThemeOption.light,
                                onTap: () {
                                  setState(() {
                                    _selectedTheme = AppThemeOption.light;
                                  });
                                  // TODO: apply theme
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
                                darkStyle: true,
                                onTap: () {
                                  setState(() {
                                    _selectedTheme = AppThemeOption.dark;
                                  });
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
                                  setState(() {
                                    _selectedTheme = AppThemeOption.system;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Divider(
                          height: 32,
                          thickness: 0.6,
                          color: Color(0xFFE5E7EB),
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
                              border: Border.all(
                                color: const Color(0xFFEF4444),
                                width: 1.5,
                              ),
                              color: Colors.transparent,
                            ),
                            child: Center(
                              child: Text(
                                LanguageHelper.t('settings_logout'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEF4444),
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

// ================= TOGGLE ROW =================

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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              LanguageHelper.t(labelKey),
              style: const TextStyle(fontSize: 14.5, color: Color(0xFF111827)),
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
                color:
                    value ? const Color(0xFFFFA726) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Align(
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: value ? Colors.white : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child:
                      value
                          ? const Icon(
                            Icons.check,
                            size: 12,
                            color: Color(0xFFF59E0B),
                          )
                          : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final IconData icon;
  final String labelKey;
  final bool isSelected;
  final bool darkStyle;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    required this.icon,
    required this.labelKey,
    required this.isSelected,
    this.darkStyle = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = LanguageHelper.t(labelKey);

    final bgColor = darkStyle ? const Color(0xFF111827) : Colors.white;

    final wrapperColor = isSelected ? const Color(0xFFFFF0C2) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: wrapperColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color:
                isSelected ? const Color(0xFFFFA726) : const Color(0xFFE5E7EB),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 46,
              width: double.infinity,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: darkStyle ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    darkStyle
                        ? const Color(0xFF111827)
                        : const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
