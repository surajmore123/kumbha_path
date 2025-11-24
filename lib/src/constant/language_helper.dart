

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

      'verify_your_number': {
  'en': 'Verify Your Number',
  'hi': 'अपने नंबर की पुष्टि करें',
  'mr': 'आपला नंबर सत्यापित करा',
},
'otp_verify_message': {
  'en': 'Enter the 6-digit code sent to your mobile number.',
  'hi': 'अपने मोबाइल नंबर पर भेजा गया 6 अंकों का कोड दर्ज करें।',
  'mr': 'तुमच्या मोबाइल क्रमांकावर पाठवलेला ६ अंकी कोड टाका.',
},
'verify_button': {
  'en': 'Verify',
  'hi': 'पुष्टि करें',
  'mr': 'सत्यापित करा',
},
'resend_in_prefix': {
  'en': 'Resend code in',
  'hi': 'कोड पुनः भेजें',
  'mr': 'कोड पुन्हा पाठवा',
},
'didnt_receive_resend': {
  'en': "Didn't receive code? Resend",
  'hi': 'कोड नहीं मिला? फिर से भेजें',
  'mr': 'कोड मिळाला नाही? पुन्हा पाठवा',
},

'dashboard_title': {
  'en': 'Sadhana Path',
  'hi': 'साधना पथ',
  'mr': 'साधना पथ',
},
'dashboard_greeting': {
  'en': 'Namaste, Suraj',
  'hi': 'नमस्ते, सूरज',
  'mr': 'नमस्ते, सूरज',
},
'dashboard_quote': {
  'en': '"The journey of a thousand miles begins with a\nsingle step." - Lao Tzu',
  'hi': '"हजार मील की यात्रा एक छोटे से कदम से शुरू होती है।"\n- लाओ त्ज़ु',
  'mr': '"हजारो मैलांचा प्रवास एका छोट्या पावलाने सुरू होतो."\n- लाओ त्सू',
},
'ai_guru_title': {
  'en': 'AI Guru Chat',
  'hi': 'एआई गुरु चैट',
  'mr': 'एआय गुरु चॅट',
},
'ai_guru_subtitle': {
  'en': 'Seek spiritual guidance',
  'hi': 'आध्यात्मिक मार्गदर्शन प्राप्त करें',
  'mr': 'आध्यात्मिक मार्गदर्शन मिळवा',
},
'temple_explorer_title': {
  'en': 'Temple Explorer',
  'hi': 'मंदिर एक्सप्लोरर',
  'mr': 'मंदिर एक्सप्लोरर',
},
'temple_explorer_subtitle': {
  'en': 'Discover sacred places',
  'hi': 'पवित्र स्थान खोजें',
  'mr': 'पवित्र स्थळे शोधा',
},
'live_crowd_title': {
  'en': 'Live Crowd Map & Alerts',
  'hi': 'लाइव भीड़ मानचित्र और अलर्ट',
  'mr': 'लाइव्ह गर्दी नकाशा आणि सूचना',
},
'live_crowd_subtitle': {
  'en': 'Real-time updates & safety',
  'hi': 'रीयल-टाइम अपडेट और सुरक्षा',
  'mr': 'रिअल-टाईम अपडेट्स आणि सुरक्षा',
},
'journal_home_title': {
  'en': 'My Kumbh Journal Home',
  'hi': 'मेरा कुंभ जर्नल होम',
  'mr': 'माझा कुंभ जर्नल होम',
},
'journal_home_subtitle': {
  'en': 'Reflect on your journey',
  'hi': 'अपनी यात्रा पर चिंतन करें',
  'mr': 'तुमच्या प्रवासाचा विचार करा',
},

'nearby_temples_title': {
  'en': 'Nearby Temples',
  'hi': 'नज़दीकी मंदिर',
  'mr': 'जवळचे मंदिरे',
},
'temple_kashi_short_name': {
  'en': 'Kashi Vishwanath',
  'hi': 'काशी विश्वनाथ',
  'mr': 'काशी विश्वनाथ',
},
'temple_kashi_distance': {
  'en': '1.2 km away',
  'hi': '1.2 किमी दूर',
  'mr': '1.2 कि.मी. दूर',
},
'temple_kashi_title': {
  'en': 'Kashi Vishwanath Temple',
  'hi': 'काशी विश्वनाथ मंदिर',
  'mr': 'काशी विश्वनाथ मंदिर',
},
'temple_kashi_description': {
  'en': 'A sacred abode of Lord Shiva, on the western bank of the holy river Ganga.',
  'hi': 'भगवान शिव का पवित्र धाम, पवित्र गंगा नदी के पश्चिमी तट पर स्थित।',
  'mr': 'भगवान शिवांचे पवित्र निवासस्थान, पवित्र गंगेच्या पश्चिम काठावर वसलेले.',
},
'temple_mahakal_title': {
  'en': 'Mahakaleshwar Temple',
  'hi': 'महाकालेश्वर मंदिर',
  'mr': 'महाकालेश्वर मंदिर',
},
'temple_mahakal_description': {
  'en': 'One of the twelve Jyotirlingas, this ancient temple is a major pilgrimage site.',
  'hi': 'बारह ज्योतिर्लिंगों में से एक, यह प्राचीन मंदिर एक प्रमुख तीर्थ स्थल है।',
  'mr': 'बारा ज्योतिर्लिंगांपैकी एक, हे प्राचीन मंदिर एक प्रमुख तीर्थक्षेत्र आहे.',
},
'temple_sankat_title': {
  'en': 'Sankat Mochan Temple',
  'hi': 'संकट मोचन मंदिर',
  'mr': 'संकट मोचन मंदिर',
},
'temple_sankat_description': {
  'en': 'Dedicated to Lord Hanuman, known for offering relief from troubles and suffering.',
  'hi': 'भगवान हनुमान को समर्पित, जो संकट और कष्टों से मुक्ति देने के लिए प्रसिद्ध हैं।',
  'mr': 'भगवान हनुमानांना समर्पित, जे संकट आणि दुःखातून मुक्ती देण्यासाठी प्रसिद्ध आहेत.',
},
'temple_learn_more': {
  'en': 'Learn More',
  'hi': 'और जानें',
  'mr': 'अधिक जाणून घ्या',
},



  // =================== Temple Names ===================
  "triambak_title": {
    "en": "Trimbakeshwar Temple",
    "hi": "त्र्यंबकेश्वर मंदिर",
    "mr": "त्र्यंबकेश्वर मंदिर"
  },

  "kashi_title": {
    "en": "Kashi Vishwanath Temple",
    "hi": "काशी विश्वनाथ मंदिर",
    "mr": "काशी विश्वनाथ मंदिर"
  },

  "mahakal_title": {
    "en": "Mahakaleshwar Temple",
    "hi": "महाकालेश्वर मंदिर",
    "mr": "महाकालेश्वर मंदिर"
  },

  "sankat_title": {
    "en": "Sankat Mochan Temple",
    "hi": "संकट मोचन मंदिर",
    "mr": "संकट मोचन मंदिर"
  },

  // =================== Temple Short Names (Map Highlight Card) ===================


  // =================== Temple Descriptions ===================
  "triambak_description": {
    "en": "A sacred abode of Lord Shiva, located at the origin of the holy river Godavari.",
    "hi": "भगवान शिव का पवित्र धाम, पवित्र गोदावरी नदी के उद्गम पर स्थित।",
    "mr": "भगवान शिवांचे पवित्र निवासस्थान, पवित्र गोदावरी नदीच्या उगमस्थानावर स्थित."
  },

  "kashi_description": {
    "en": "A sacred abode of Lord Shiva, on the western bank of the holy river Ganga.",
    "hi": "भगवान शिव का पवित्र धाम, पवित्र गंगा नदी के पश्चिमी तट पर स्थित।",
    "mr": "भगवान शिवांचे पवित्र निवासस्थान, पवित्र गंगेच्या पश्चिम काठावर वसलेले."
  },

  "mahakal_description": {
    "en": "One of the twelve Jyotirlingas, this ancient temple is a major pilgrimage site.",
    "hi": "बारह ज्योतिर्लिंगों में से एक, यह प्राचीन मंदिर एक प्रमुख तीर्थ स्थल है।",
    "mr": "बारा ज्योतिर्लिंगांपैकी एक, हे प्राचीन मंदिर एक प्रमुख तीर्थस्थान आहे."
  },

  "sankat_description": {
    "en": "Dedicated to Lord Hanuman, known for offering relief from troubles and suffering.",
    "hi": "भगवान हनुमान को समर्पित, जो संकट और कष्टों से मुक्ति दिलाने के लिए प्रसिद्ध है।",
    "mr": "भगवान हनुमानांना समर्पित, संकट आणि दुःखातून मुक्ती देण्यासाठी ओळखले जाते."
  },

  "temple_details_appbar_title": {
    "en": "Temple Details",
    "hi": "मंदिर विवरण",
    "mr": "मंदिर माहिती"
  },

  "kashi_details_title": {
    "en": "Kashi Vishwanath Temple",
    "hi": "काशी विश्वनाथ मंदिर",
    "mr": "काशी विश्वनाथ मंदिर"
  },

  "kashi_details_location": {
    "en": "Varanasi, Uttar Pradesh",
    "hi": "वाराणसी, उत्तर प्रदेश",
    "mr": "वाराणसी, उत्तर प्रदेश"
  },

  "temple_about_heading": {
    "en": "About",
    "hi": "विवरण",
    "mr": "माहिती"
  },

  "kashi_details_about": {
    "en":
        "The Kashi Vishwanath Temple is one of the most famous Hindu temples dedicated to Lord Shiva. It is located in Vishwanath Gali of Varanasi, Uttar Pradesh, India. The temple stands on the western bank of the holy river Ganga, and is one of the twelve Jyotirlingas, the holiest of Shiva temples.",
    "hi":
        "काशी विश्वनाथ मंदिर भगवान शिव को समर्पित सबसे प्रसिद्ध हिंदू मंदिरों में से एक है। यह उत्तर प्रदेश के वाराणसी में विश्वनाथ गली में स्थित है। यह मंदिर पवित्र गंगा नदी के पश्चिमी तट पर स्थित है और बारह ज्योतिर्लिंगों में से एक, शिव मंदिरों में सबसे पवित्र माना जाता है।",
    "mr":
        "काशी विश्वनाथ मंदिर हे भगवान शिवांना समर्पित सर्वात प्रसिद्ध हिंदू मंदिरांपैकी एक आहे. हे उत्तर प्रदेशातील वाराणसी येथील विश्वनाथ गल्लीमध्ये स्थित आहे. मंदिर पवित्र गंगानदीच्या पश्चिम काठावर उभे आहे आणि बारा ज्योतिर्लिंगांपैकी एक, शिव मंदिरे यांपैकी सर्वात पवित्र मानले जाते."
  },

  "temple_get_directions_btn": {
    "en": "Get Directions",
    "hi": "मार्गदर्शन प्राप्त करें",
    "mr": "दिशा मिळवा"
  },

  "temple_add_to_journal_btn": {
    "en": "Add to Journal",
    "hi": "जर्नल में जोड़ें",
    "mr": "जर्नलमध्ये जोडा"
  },

  "kashi_details_story": {
    "en":
        "Hindu texts describe a dispute between Brahma (the creator) and Vishnu (the preserver) over their supremacy. To test them, Shiva appeared as an endless pillar of light, the jyotirlinga. Both Brahma and Vishnu failed to find its beginning or end. Kashi Vishwanath is believed to be the site where this divine light manifested.",
    "hi":
        "हिंदू ग्रंथों में ब्रह्मा (सृष्टिकर्ता) और विष्णु (पालनकर्ता) के बीच श्रेष्ठता को लेकर विवाद का वर्णन मिलता है। उनकी परीक्षा लेने के लिए, शिव अनंत प्रकाश स्तंभ यानी ज्योतिर्लिंग के रूप में प्रकट हुए। ब्रह्मा और विष्णु दोनों ही उस प्रकाश का आदि और अंत नहीं खोज सके। काशी विश्वनाथ को उसी दिव्य प्रकाश के प्रकट होने का स्थान माना जाता है।",
    "mr":
        "हिंदू ग्रंथांमध्ये ब्रह्मा (सृष्टीकर्ता) आणि विष्णू (पालनकर्ता) यांच्यातील श्रेष्ठत्वाच्या वादाचे वर्णन आहे. त्यांची परीक्षा घेण्यासाठी शिव अनंत प्रकाशस्तंभ, म्हणजे ज्योतिर्लिंग, म्हणून प्रकट झाले. ब्रह्मा आणि विष्णू दोघांनाही त्या प्रकाशाचा आरंभ किंवा शेवट सापडला नाही. काशी विश्वनाथ हा त्या दैवी प्रकाशाच्या प्रकट होण्याचा स्थान मानला जातो."
  },

  "temple_ai_insight_heading": {
    "en": "AI Insight",
    "hi": "एआई अंतर्दृष्टि",
    "mr": "एआय अंतर्दृष्टी"
  },

  "kashi_details_ai_insight": {
    "en":
        "Our AI analysis suggests that visiting during the early morning 'Mangala Aarti' offers the most profound spiritual experience. Energy patterns recorded here show a significant peak at this time, aligning with ancient scriptures. For a quieter visit, late afternoons on weekdays are ideal. The temple’s architecture reflects multiple reconstructions over centuries, blending diverse styles into a unique spiritual ambience.",
    "hi":
        "हमारे एआई विश्लेषण के अनुसार, सुबह की 'मंगला आरती' के समय दर्शन करना सबसे गहरा आध्यात्मिक अनुभव प्रदान करता है। यहाँ दर्ज की गई ऊर्जा तरंगें इस समय विशेष रूप से उच्च दिखाई देती हैं, जो प्राचीन शास्त्रों के वर्णन से मेल खाती हैं। शांत वातावरण के लिए, सप्ताह के दिनों में देर दोपहर का समय उपयुक्त है। मंदिर की वास्तुकला कई पुनर्निर्माणों का परिणाम है, जो विभिन्न शैलियों को मिलाकर अद्वितीय आध्यात्मिक वातावरण बनाती है।",
    "mr":
        "आमच्या एआय विश्लेषणानुसार, पहाटेची 'मंगला आरती'च्या वेळी दर्शन केल्यास सर्वात गहन आध्यात्मिक अनुभव मिळतो. येथे नोंदवलेले ऊर्जेचे पॅटर्न या वेळी विशेष टोक गाठतात, जे प्राचीन शास्त्रांतील वर्णनांशी सुसंगत आहे. अधिक शांत अनुभवासाठी, आठवड्याच्या दिवशी उशिरा दुपारचा वेळ आदर्श आहे. मंदिराची रचना अनेक पुनर्बांधणीनंतर विकसित झाली असून विविध शैलींचे सुंदर मिश्रण करून एक अद्वितीय आध्यात्मिक वातावरण निर्माण करते."
  }




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
        'assets/icons/internet.png', 
        height: 24,
        width: 24,
      ),
    );
  }
}