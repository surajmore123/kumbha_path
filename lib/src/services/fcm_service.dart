import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:kumbha_path/src/constant/config.dart';

/// The device's FCM token and its registration with the backend
/// (`POST /api/auth/fcm/register/`, which ties the token to the signed-in
/// user). The token is registered on every start while signed in and
/// whenever Firebase rotates it, not only at login, so the backend always
/// has the current one. Tokens are never logged.
class FcmService {
  static String? _cachedToken;

  static String get deviceType => Platform.isIOS ? 'IOS' : 'ANDROID';

  static Future<void> init() async {
    try {
      _cachedToken = await FirebaseMessaging.instance.getToken();
    } catch (_) {
      // No network or Play services at start-up; the stored token is used.
      _cachedToken = null;
    }
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      await userAuthentication.saveFcmToken(_cachedToken!);
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      _cachedToken = token;
      await userAuthentication.saveFcmToken(token);
      await registerWithBackend();
    });
  }

  static Future<String?> getToken() async {
    return _cachedToken ?? await userAuthentication.getFcmToken();
  }

  /// Registers the token for the signed-in user. Does nothing when
  /// signed out (the login flow registers it after OTP verification).
  static Future<bool> registerWithBackend() async {
    final accessToken = await storage.read(key: 'access_token');
    final token = await getToken();
    if (accessToken == null || token == null || token.isEmpty) return false;
    final result = await userRepository.registerFcm({
      'access_token': accessToken,
      'token': token,
      'device_type': deviceType,
    });
    final ok = result is Map && result['status'] == 'success';
    if (!ok && kDebugMode) debugPrint('FCM token registration failed.');
    return ok;
  }

  /// On logout: invalidate this device's token so the signed-out user stops
  /// receiving notifications, and get a fresh one for the next login.
  static Future<void> resetForLogout() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
      await userAuthentication.clearFcmToken();
      _cachedToken = await FirebaseMessaging.instance.getToken();
      if (_cachedToken != null) {
        await userAuthentication.saveFcmToken(_cachedToken!);
      }
    } catch (_) {
      // Offline: the backend deactivates the old token once FCM rejects it.
    }
  }
}
