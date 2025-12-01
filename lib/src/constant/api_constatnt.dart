import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConst {
  static final String protocol = dotenv.env['API_PROTOCOL'] ?? 'http';
  static final String host = dotenv.env['API_HOST'] ?? 'localhost';
  static final String apiRoot = dotenv.env['API_ROOT'] ?? '/api';

  static String get baseUrl => '$protocol://$host';
}
