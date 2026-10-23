import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/constant/api_constatnt.dart';

/// A website API call that failed: no connection, timeout, non-2xx status or
/// a body that isn't JSON. [message] is the backend's own text when it sent
/// one (`{"error": {"message": ...}}`).
class WebsiteApiException implements Exception {
  WebsiteApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'WebsiteApiException($statusCode): $message';
}

/// Client for the website's public `/api/v1/` endpoints. These need no
/// sign-in, so no token is sent.
class WebsiteApi {
  WebsiteApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl;

  final http.Client _client;
  final String? _baseUrl;

  static const Duration timeout = Duration(seconds: 20);

  String get baseUrl => _baseUrl ?? ApiConst.websiteApiBase;

  /// `GET /announcements`: published notices inside their date window,
  /// pinned first (at most 10).
  Future<List<dynamic>> getAnnouncements() async {
    final body = await _get('announcements');
    if (body is! List) throw WebsiteApiException('Unexpected response');
    return body;
  }

  /// `GET /listings`: one page of published listings, cheapest first.
  Future<Map<String, dynamic>> getListings({
    String? category,
    int size = 100,
  }) async {
    final body = await _get(
      'listings',
      query: {if (category != null) 'category': category, 'size': '$size'},
    );
    if (body is! Map) throw WebsiteApiException('Unexpected response');
    return body.cast<String, dynamic>();
  }

  /// `GET /content/<page>`: edited CMS values for one page.
  Future<Map<String, dynamic>> getPageContent(String page) async {
    final body = await _get('content/${Uri.encodeComponent(page)}');
    if (body is! Map) throw WebsiteApiException('Unexpected response');
    return body.cast<String, dynamic>();
  }

  Future<Object?> _get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse(
      '$baseUrl/$path',
    ).replace(queryParameters: query?.isEmpty ?? true ? null : query);
    final http.Response res;
    try {
      res = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
    } on TimeoutException {
      throw WebsiteApiException('Request timed out');
    } catch (e) {
      throw WebsiteApiException('Network error: $e');
    }

    Object? decoded;
    try {
      decoded = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      decoded = null;
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = decoded is Map ? decoded['error'] : null;
      final message =
          error is Map && error['message'] is String
              ? error['message'] as String
              : 'HTTP ${res.statusCode}';
      throw WebsiteApiException(message, statusCode: res.statusCode);
    }
    if (decoded == null) throw WebsiteApiException('Empty response');
    return decoded;
  }
}
