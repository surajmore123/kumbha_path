

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
  },

  "live_crowd_location": {
    "en": "Prayagraj Mela Area",
    "hi": "प्रयागराज मेला क्षेत्र",
    "mr": "प्रयागराज मेला परिसर"
  },

  "live_crowd_quick_alerts": {
    "en": "Quick Alerts",
    "hi": "तत्काल अलर्ट",
    "mr": "जलद सूचना"
  },

  "live_crowd_next_snan_label": {
    "en": "Next Snan Schedule",
    "hi": "अगला स्नान समय",
    "mr": "पुढील स्नान वेळ"
  },
  "live_crowd_next_snan_value": {
    "en": "04:30 AM - Triveni Sangam",
    "hi": "सुबह 04:30 - त्रिवेणी संगम",
    "mr": "पहाटे ४:३० - त्रिवेणी संगम"
  },

  "live_crowd_traffic_category": {
    "en": "Traffic Alert",
    "hi": "यातायात अलर्ट",
    "mr": "वाहतूक सूचना"
  },
  "live_crowd_traffic_title": {
    "en": "Traffic Congestion on Route A",
    "hi": "रूट A पर भारी ट्रैफिक",
    "mr": "मार्ग अ वर प्रचंड वाहतूक"
  },
  "live_crowd_traffic_description": {
    "en":
        "Heavy traffic near Shastri Bridge. Consider an alternative route.",
    "hi":
        "शास्त्री ब्रिज के पास भारी ट्रैफिक। कृपया वैकल्पिक मार्ग का उपयोग करें।",
    "mr":
        "शास्त्री पुलाजवळ मोठी वाहतूक आहे. कृपया पर्यायी मार्गाचा वापर करा."
  },

  "live_crowd_crowd_category": {
    "en": "Crowd Alert",
    "hi": "भीड़ अलर्ट",
    "mr": "गर्दी सूचना"
  },
  "live_crowd_crowd_title": {
    "en": "High Crowd at Gate No. 3",
    "hi": "गेट नं. 3 पर भारी भीड़",
    "mr": "गेट क्र. ३ येथे मोठी गर्दी"
  },
  "live_crowd_crowd_description": {
    "en":
        "Gate is temporarily closed. Please use Gate No. 4 or 5.",
    "hi":
        "गेट अस्थायी रूप से बंद है। कृपया गेट नं. 4 या 5 का उपयोग करें।",
    "mr":
        "गेट तात्पुरते बंद आहे. कृपया गेट क्र. ४ किंवा ५ वापरा."
  },
  "events_appbar_title": {
    "en": "Upcoming Snans & Events",
    "hi": "आगामी स्नान और कार्यक्रम",
    "mr": "येणारे स्नान आणि कार्यक्रम"
  },

  "shahi_snan_timing": {
    "en": "14th April, 4:00 AM - 6:00 AM",
    "hi": "14 अप्रैल, सुबह 4:00 - 6:00",
    "mr": "१४ एप्रिल, पहाटे ४:०० - ६:००"
  },
  "shahi_snan_title": {
    "en": "Shahi Snan",
    "hi": "शाही स्नान",
    "mr": "शाही स्नान"
  },
  "shahi_snan_location": {
    "en": "Har Ki Pauri Ghat",
    "hi": "हर की पौड़ी घाट",
    "mr": "हर की पौडी घाट"
  },
  "shahi_snan_description": {
    "en": "Join the most auspicious royal bath of the Kumbh Mela.",
    "hi": "कुंभ मेले के सबसे शुभ शाही स्नान में शामिल हों।",
    "mr": "कुंभ मेळ्यातील सर्वात शुभ शाही स्नानात सहभागी व्हा."
  },

  "events_remind_me": {
    "en": "Remind Me",
    "hi": "मुझे याद दिलाएं",
    "mr": "मला स्मरण करा"
  },

  "events_other_key_events": {
    "en": "Other Key Events",
    "hi": "अन्य प्रमुख कार्यक्रम",
    "mr": "इतर महत्त्वाचे कार्यक्रम"
  },

  "event_ganga_aarti_title": {
    "en": "Ganga Aarti",
    "hi": "गंगा आरती",
    "mr": "गंगा आरती"
  },
  "event_ganga_aarti_description": {
    "en": "Daily evening prayer ceremony by the river.",
    "hi": "नदी किनारे होने वाली दैनिक संध्या आरती।",
    "mr": "नदीकाठी दररोज होणारी संध्याकाळची आरती."
  },

  "event_sant_samagam_title": {
    "en": "Sant Samagam",
    "hi": "संत समागम",
    "mr": "संत समागम"
  },
  "event_sant_samagam_description": {
    "en": "Congregation of revered saints and spiritual leaders.",
    "hi": "पूज्य संतों और आध्यात्मिक गुरुओं का संगम।",
    "mr": "पूज्य संत आणि आध्यात्मिक गुरूंची मेळाव्यातील उपस्थिती."
  },

  "event_cultural_evening_title": {
    "en": "Cultural Evening",
    "hi": "सांस्कृतिक संध्या",
    "mr": "सांस्कृतिक संध्या"
  },
  "event_cultural_evening_description": {
    "en": "Celebration of music and dance performances.",
    "hi": "संगीत और नृत्य प्रस्तुतियों का उत्सव।",
    "mr": "संगीत आणि नृत्य सादरीकरणांचा उत्सव."
  },
  "live_updates_title": {
    "en": "Live Updates & Alerts",
    "hi": "लाइव अपडेट और अलर्ट",
    "mr": "थेट अपडेट आणि सूचना"
  },
  "live_updates_tab_all": {
    "en": "All",
    "hi": "सब",
    "mr": "सर्व"
  },
  "live_updates_tab_alerts": {
    "en": "Alerts",
    "hi": "अलर्ट",
    "mr": "सूचना"
  },
  "live_updates_tab_messages": {
    "en": "Messages",
    "hi": "संदेश",
    "mr": "संदेश"
  },

  "live_update_high_crowd_title": {
    "en": "High crowd near Har Ki Pauri",
    "hi": "हर की पौड़ी के पास भारी भीड़",
    "mr": "हर की पौडी जवळ मोठी गर्दी"
  },
  "live_update_next_snan_title": {
    "en": "Next Snan 5:30 AM tomorrow. Prepare early.",
    "hi": "अगला स्नान कल सुबह 5:30 बजे. पहले से तैयारी करें।",
    "mr": "पुढील स्नान उद्या पहाटे ५:३०. आधीच तयारी करा."
  },
  "live_update_shuttle_title": {
    "en": "Shuttle services are now active from the main camp.",
    "hi": "मुख्य शिविर से शटल सेवा अब शुरू हो गई है।",
    "mr": "मुख्य तळावरून शटल सेवा आता सुरू झाली आहे."
  },
  "live_update_gate_closed_title": {
    "en": "Gate no. 3 is temporarily closed for maintenance.",
    "hi": "गेट नंबर 3 रखरखाव के लिए अस्थायी रूप से बंद है।",
    "mr": "गेट क्रमांक ३ देखभालीसाठी तात्पुरते बंद आहे."
  },
  "live_update_evening_aarti_title": {
    "en": "Evening Aarti will commence at 6:00 PM at ghat no. 5.",
    "hi": "सायंकालीन आरती शाम 6 बजे घाट नंबर 5 पर शुरू होगी।",
    "mr": "सायंकाळची आरती सायं ६ वाजता घाट क्रमांक ५ वर सुरू होईल."
  },
  "live_update_light_showers_title": {
    "en": "Light showers expected this evening. Carry an umbrella.",
    "hi": "आज शाम हल्की बारिश की संभावना. छाता साथ रखें।",
    "mr": "आज संध्याकाळी हलक्या सरींची शक्यता. छत्री बाळगा."
  },

  "live_update_5_mins_ago": {
    "en": "5 mins ago",
    "hi": "5 मिनट पहले",
    "mr": "५ मिनिटांपूर्वी"
  },
  "live_update_1_hour_ago": {
    "en": "1 hour ago",
    "hi": "1 घंटा पहले",
    "mr": "१ तासापूर्वी"
  },
  "live_update_2_hours_ago": {
    "en": "2 hours ago",
    "hi": "2 घंटे पहले",
    "mr": "२ तासांपूर्वी"
  },
  "live_update_3_hours_ago": {
    "en": "3 hours ago",
    "hi": "3 घंटे पहले",
    "mr": "३ तासांपूर्वी"
  },
  "live_update_4_hours_ago": {
    "en": "4 hours ago",
    "hi": "4 घंटे पहले",
    "mr": "४ तासांपूर्वी"
  },
  "journal_title": {
    "en": "My Kumbh Journal",
    "hi": "मेरा कुंभ जर्नल",
    "mr": "माझी कुंभ डायरी"
  },
  "journal_ai_reflection": {
    "en": "AI Reflection",
    "hi": "एआई चिंतन",
    "mr": "एआय चिंतन"
  },
  "journal_add_entry": {
    "en": "Add Entry",
    "hi": "नया लेख जोड़ें",
    "mr": "नवीन नोंद जोडा"
  },
  "journal_prompt_title": {
    "en": "What inspired you today?",
    "hi": "आज आपको क्या प्रेरित किया?",
    "mr": "आज तुम्हाला काय प्रेरणा मिळाली?"
  },
  "journal_prompt_subtitle": {
    "en": "Get a personalized prompt to start your reflection.",
    "hi": "अपना चिंतन शुरू करने के लिए एक व्यक्तिगत प्रॉम्प्ट प्राप्त करें।",
    "mr": "स्वतःचा विचार सुरू करण्यासाठी वैयक्तिक प्रॉम्प्ट मिळवा."
  },
  "journal_get_ai_prompt": {
    "en": "Get AI Prompt",
    "hi": "एआई प्रॉम्प्ट लें",
    "mr": "एआय प्रॉम्प्ट घ्या"
  },
  "journal_past_entries": {
    "en": "Past Entries",
    "hi": "पुराने लेख",
    "mr": "मागील नोंदी"
  },

  "journal_entry_1_date": {
    "en": "April 14, 2024",
    "hi": "14 अप्रैल, 2024",
    "mr": "१४ एप्रिल, २०२४"
  },
  "journal_entry_1_text": {
    "en": "Today I witnessed the Ganga Aarti for the first time. The...",
    "hi": "आज मैंने पहली बार गंगा आरती देखी। वह...",
    "mr": "आज मी पहिल्यांदा गंगा आरती पाहिली. ती..."
  },
  "journal_entry_1_mood": {
    "en": "Peaceful",
    "hi": "शांतिपूर्ण",
    "mr": "शांत"
  },

  "journal_entry_2_date": {
    "en": "April 12, 2024",
    "hi": "12 अप्रैल, 2024",
    "mr": "१२ एप्रिल, २०२४"
  },
  "journal_entry_2_text": {
    "en": "A conversation with a Sadhu opened my mind to new...",
    "hi": "एक साधु के साथ बातचीत ने मेरा दृष्टिकोण बदल दिया...",
    "mr": "एका साधूसोबतच्या संवादाने माझा दृष्टीकोन बदलला..."
  },
  "journal_entry_2_mood": {
    "en": "Enlightened",
    "hi": "प्रबुद्ध",
    "mr": "प्रबुद्ध"
  },

  "journal_entry_3_date": {
    "en": "April 10, 2024",
    "hi": "10 अप्रैल, 2024",
    "mr": "१० एप्रिल, २०२४"
  },
  "journal_entry_3_text": {
    "en": "The energy of the crowd during the Shahi Snan was...",
    "hi": "शाही स्नान के दौरान भीड़ की ऊर्जा अद्भुत थी...",
    "mr": "शाही स्नानदरम्यानच्या गर्दीची ऊर्जा अफाट होती..."
  },
  "journal_entry_3_mood": {
    "en": "Joyful",
    "hi": "आनंदित",
    "mr": "आनंदी"
  },
  "journal_new_entry_title": {
    "en": "New Entry",
    "hi": "नई प्रविष्टि",
    "mr": "नवीन नोंद"
  },
  "journal_field_title": {
    "en": "Title",
    "hi": "शीर्षक",
    "mr": "शीर्षक"
  },
  "journal_field_title_hint": {
    "en": "A moment of clarity by the river",
    "hi": "नदी के किनारे मिली स्पष्टता का एक पल",
    "mr": "नदीकाठी मिळालेला स्पष्टतेचा क्षण"
  },
  "journal_add_photo_title": {
    "en": "Add Photo",
    "hi": "फ़ोटो जोड़ें",
    "mr": "फोटो जोडा"
  },
  "journal_add_photo_subtitle": {
    "en": "Add a photo to your memory",
    "hi": "अपनी याद में एक फ़ोटो जोड़ें",
    "mr": "तुमच्या आठवणीत एक फोटो जोडा"
  },
  "journal_add_photo_button": {
    "en": "Upload",
    "hi": "अपलोड",
    "mr": "अपलोड"
  },
  "journal_field_notes": {
    "en": "Notes",
    "hi": "नोट्स",
    "mr": "नोंदी"
  },
  "journal_field_notes_hint": {
    "en": "Write your thoughts and feelings here...",
    "hi": "अपने विचार और भावनाएँ यहाँ लिखें...",
    "mr": "तुमचे विचार आणि भावना येथे लिहा..."
  },
  "journal_how_feeling": {
    "en": "How are you feeling?",
    "hi": "आप कैसा महसूस कर रहे हैं?",
    "mr": "तुम्ही कसे वाटत आहात?"
  },
  "journal_btn_ai_reflection": {
    "en": "Get AI Reflection on this ✨",
    "hi": "इस पर एआई चिंतन प्राप्त करें ✨",
    "mr": "यावर एआय चिंतन मिळवा ✨"
  },
  "journal_btn_save_entry": {
    "en": "Save Entry",
    "hi": "प्रविष्टि सहेजें",
    "mr": "नोंद जतन करा"
  },

  "settings_title": {
    "en": "Settings",
    "hi": "सेटिंग्स",
    "mr": "सेटिंग्ज"
  },

  // --------------------- Profile Section ---------------------
  "settings_my_profile": {
    "en": "My Profile",
    "hi": "मेरा प्रोफाइल",
    "mr": "माझे प्रोफाइल"
  },

  "settings_edit_profile_picture": {
    "en": "Edit Profile Picture",
    "hi": "प्रोफाइल तस्वीर बदलें",
    "mr": "प्रोफाइल फोटो बदला"
  },

  "settings_full_name": {
    "en": "Full Name",
    "hi": "पूरा नाम",
    "mr": "पूर्ण नाव"
  },

  "settings_full_name_hint": {
    "en": "Enter full name",
    "hi": "पूरा नाम दर्ज करें",
    "mr": "पूर्ण नाव टाका"
  },

  "settings_email": {
    "en": "Email Address",
    "hi": "ईमेल पता",
    "mr": "ईमेल पत्ता"
  },

  "settings_email_hint": {
    "en": "Enter email address",
    "hi": "ईमेल पता दर्ज करें",
    "mr": "ईमेल पत्ता टाका"
  },

  "settings_save_changes": {
    "en": "Save Changes",
    "hi": "परिवर्तन सहेजें",
    "mr": "बदल जतन करा"
  },

  // --------------------- Notifications ---------------------
  "settings_notification_preferences": {
    "en": "Notification Preferences",
    "hi": "सूचना वरीयताएँ",
    "mr": "सूचना प्राधान्ये"
  },

  "settings_realtime_alerts": {
    "en": "Real-time Event Alerts",
    "hi": "रियल-टाइम इवेंट अलर्ट",
    "mr": "रिअल-टाइम इव्हेंट अलर्ट"
  },

  "settings_daily_guidance": {
    "en": "Daily Spiritual Guidance",
    "hi": "दैनिक आध्यात्मिक मार्गदर्शन",
    "mr": "दैनिक आध्यात्मिक मार्गदर्शन"
  },

  "settings_community_news": {
    "en": "Community News",
    "hi": "समुदाय समाचार",
    "mr": "समुदाय बातम्या"
  },

  "settings_app_updates": {
    "en": "App Updates",
    "hi": "ऐप अपडेट्स",
    "mr": "अॅप अद्यतने"
  },

  // --------------------- Themes ---------------------
  "settings_app_theme": {
    "en": "App Theme",
    "hi": "ऐप थीम",
    "mr": "अॅप थीम"
  },

  "settings_theme_light": {
    "en": "Light",
    "hi": "लाइट",
    "mr": "लाइट"
  },

  "settings_theme_dark": {
    "en": "Dark",
    "hi": "डार्क",
    "mr": "डार्क"
  },

  "settings_theme_system": {
    "en": "System",
    "hi": "सिस्टम",
    "mr": "सिस्टम"
  },

  // --------------------- Logout ---------------------
  "settings_logout": {
    "en": "Log Out",
    "hi": "लॉग आउट",
    "mr": "लॉग आउट"
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