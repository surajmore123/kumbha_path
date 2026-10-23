import 'package:flutter_dotenv/flutter_dotenv.dart';

// class ApiConst {
//   static final String protocol = dotenv.env['API_PROTOCOL'] ?? 'http';
//   static final String host = dotenv.env['API_HOST'] ?? 'localhost';
//   static final String apiRoot = dotenv.env['API_ROOT'] ?? '/api';

//   static String get baseUrl => '$protocol://$host';
// }


class ApiConst {
  static final String protocol =
      dotenv.env['API_PROTOCOL'] ?? 'http';

  static final String host =
      dotenv.env['API_HOST'] ?? 'localhost';

  static final String apiRoot =
      dotenv.env['API_ROOT'] ?? '/api';

  static final String googleMapsKey =
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  /// Public website, for listing photos (`/images/photos/<id>.webp`) and
  /// relative announcement links.
  static final String websiteUrl =
      (dotenv.env['WEBSITE_URL'] ?? 'https://kumbhapath.in').replaceAll(
        RegExp(r'/+$'),
        '',
      );

  static String get baseUrl => '$protocol://$host';
  static String get apiBase => '$baseUrl$apiRoot';

  /// The website's API (announcements, CMS content, listings), served by the
  /// same backend under `/api/v1`.
  static String get websiteApiBase => '$apiBase/v1';
}
