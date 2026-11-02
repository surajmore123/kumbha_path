import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kumbha_path/src/services/notification_router.dart';

/// Local notifications: the Android channels the backend sends to, and
/// showing a push while the app is open (Android and iOS don't display
/// FCM notifications for a foreground app on their own).
///
/// Channel ids must match `utils/push_notifications.py` in the backend.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String crowdChannelId = 'crowd_alerts';
  static const String eventChannelId = 'event_reminders';
  static const String emergencyChannelId = 'emergency_sos';

  /// White silhouette in `android/app/src/main/res/drawable-*`; the status
  /// bar shows only an icon's alpha, so the full-colour launcher icon
  /// would appear as a white square.
  static const String _icon = '@drawable/ic_stat_notification';

  static const List<AndroidNotificationChannel> _channels = [
    AndroidNotificationChannel(
      crowdChannelId,
      'Crowd Alerts',
      description: 'High priority crowd notifications',
      importance: Importance.max,
    ),
    AndroidNotificationChannel(
      eventChannelId,
      'Event Reminders',
      description: 'Reminders for events you follow',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      emergencyChannelId,
      'Emergency SOS',
      description: 'A family member needs help',
      importance: Importance.max,
    ),
  ];

  static Future<void> init() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings(_icon),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    for (final channel in _channels) {
      await android?.createNotificationChannel(channel);
    }

    // Android 13+ permission
    if (Platform.isAndroid) {
      await android?.requestNotificationsPermission();
    }

    // The app was closed and started by tapping one of our notifications.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final response = launch!.notificationResponse;
      if (response != null) _onNotificationTap(response);
    }
  }

  /// Picks the channel for a push: the one the backend named, else by type.
  static String channelFor(String? channelId, Map<String, dynamic> data) {
    if (channelId == crowdChannelId || channelId == eventChannelId) {
      return channelId!;
    }
    const eventTypes = {'event_reminder', 'event_update', 'new_event'};
    return eventTypes.contains(data['type']) ? eventChannelId : crowdChannelId;
  }

  static Future<void> show({
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
    String? channelId,
  }) async {
    final channel = _channels.firstWhere(
      (c) => c.id == channelFor(channelId, data),
    );
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: Priority.high,
        icon: _icon,
        // Lock screens show that something arrived, not what it says.
        visibility:
            channel.id == emergencyChannelId
                ? NotificationVisibility.private
                : null,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: jsonEncode(data),
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic>) NotificationRouter.open(data);
    } catch (_) {
      // Old notifications carried a bare zone id; there's nothing to open.
      if (kDebugMode) debugPrint('Notification payload not understood.');
    }
  }
}
