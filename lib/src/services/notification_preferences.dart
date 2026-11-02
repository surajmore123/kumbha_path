import 'package:kumbha_path/src/constant/config.dart';

/// Push notification categories the user can turn on or off. The keys
/// match the backend (`NotificationPreference.CATEGORIES`); the server
/// enforces them, so a muted category is never sent.
enum NotificationCategory {
  eventReminders('event_reminders'),
  eventUpdates('event_updates'),
  newEvents('new_events'),
  crowdAlerts('crowd_alerts'),
  safetyAlerts('safety_alerts'),
  familyLocation('family_location'),
  reunification('reunification');

  const NotificationCategory(this.key);

  final String key;
}

/// Reads and saves the user's notification categories
/// (`/api/auth/notification-preferences/`). Injected in tests.
class NotificationPreferencesApi {
  const NotificationPreferencesApi();

  /// The saved choices, or null when they couldn't be loaded.
  Future<Map<NotificationCategory, bool>?> load() async {
    final token = await storage.read(key: 'access_token');
    if (token == null) return null;
    final result = await userRepository.getNotificationPreferences({
      'access_token': token,
    });
    return _parse(result);
  }

  /// Saves one category; returns the saved choices, or null on failure.
  Future<Map<NotificationCategory, bool>?> update(
    NotificationCategory category,
    bool enabled,
  ) async {
    final token = await storage.read(key: 'access_token');
    if (token == null) return null;
    final result = await userRepository.updateNotificationPreferences({
      'access_token': token,
      category.key: enabled,
    });
    return _parse(result);
  }

  static Map<NotificationCategory, bool>? _parse(dynamic result) {
    if (result is! Map || result['status'] != 'success') return null;
    final data = result['data'];
    if (data is! Map) return null;
    return {
      for (final category in NotificationCategory.values)
        category: data[category.key] != false,
    };
  }
}
