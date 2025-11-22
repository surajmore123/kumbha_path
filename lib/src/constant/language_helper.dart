

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class LanguageHelper {
  // current language code: 'en', 'hi', 'mr'
  static final ValueNotifier<String> currentLang = ValueNotifier<String>('en');

  static void changeLanguage(String code) {
    if (code == 'en' || code == 'hi' || code == 'mr') {
      currentLang.value = code;
    }
  }

  // simple key-based translation
  static String t(String key) {
    const Map<String, Map<String, String>> _translations = {
      'welcome': {
        'en': 'Welcome',
        'hi': 'स्वागत है',
        'mr': 'स्वागत आहे',
      },
      'enter_mobile': {
        'en': 'Enter your mobile number to continue',
        'hi': 'जारी रखने के लिए मोबाइल नंबर दर्ज करें',
        'mr': 'सुरू ठेवण्यासाठी तुमचा मोबाइल क्रमांक टाका',
      },
      'mobile_number': {
        'en': 'Mobile Number',
        'hi': 'मोबाइल नंबर',
        'mr': 'मोबाइल नंबर',
      },
      'enter_number_hint': {
        'en': 'Enter your 10-digit number',
        'hi': 'अपना 10 अंकों का नंबर दर्ज करें',
        'mr': 'तुमचा 10 अंकी क्रमांक टाका',
      },
      'get_otp': {
        'en': 'Get OTP',
        'hi': 'ओटीपी प्राप्त करें',
        'mr': 'ओटीपी मिळवा',
      },
      'otp_info': {
        'en': 'We will send a one-time password (OTP)\n'
            'to this mobile number for verification.',
        'hi': 'हम सत्यापन के लिए इस मोबाइल नंबर पर\nएक ओटीपी भेजेंगे।',
        'mr': 'आम्ही सत्यापनासाठी या मोबाइल क्रमांकावर\nएक ओटीपी पाठवू.',
      },
      'select_language': {
        'en': 'Select Language',
        'hi': 'भाषा चुनें',
        'mr': 'भाषा निवडा',
      },
    };

    final lang = currentLang.value;
    return _translations[key]?[lang] ??
        _translations[key]?['en'] ??
        key;
  }
}



void showLanguageSelectorBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              LanguageHelper.t('select_language'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _LanguageTile(label: 'English', code: 'en'),
            _LanguageTile(label: 'हिंदी', code: 'hi'),
            _LanguageTile(label: 'मराठी', code: 'mr'),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}

class _LanguageTile extends StatelessWidget {
  final String label;
  final String code;

  const _LanguageTile({
    required this.label,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = LanguageHelper.currentLang.value == code;

    return ListTile(
      title: Text(label),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.green)
          : null,
      onTap: () {
        LanguageHelper.changeLanguage(code);
        Navigator.pop(context);
      },
    );
  }
}

/// Reusable icon for AppBar actions
class LanguageIconButton extends StatelessWidget {
  const LanguageIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => showLanguageSelectorBottomSheet(context),
      icon: Image.asset(
        'assets/icons/internet.png', // your language/internet icon
        height: 24,
        width: 24,
      ),
    );
  }
}