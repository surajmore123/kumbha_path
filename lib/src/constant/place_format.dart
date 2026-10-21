import 'package:intl/intl.dart';

/// Formatting for place data shared by features (Dashboard, Temple
/// Explorer). Never invents values: unusable input returns `null` / unknown.

/// Crowd status as reported by the crowd APIs (`LOW`, `MEDIUM`, `HIGH`,
/// `CRITICAL`, the values the live crowd map has always handled). Other
/// non-empty values are kept as [other] so a new backend status is shown
/// verbatim, never guessed.
enum CrowdLevel { low, medium, high, critical, other, unknown }

CrowdLevel crowdLevelOf(String? status) {
  final value = (status ?? '').trim().toUpperCase();
  return switch (value) {
    'LOW' => CrowdLevel.low,
    'MEDIUM' || 'MODERATE' => CrowdLevel.medium,
    'HIGH' => CrowdLevel.high,
    'CRITICAL' => CrowdLevel.critical,
    '' => CrowdLevel.unknown,
    _ => CrowdLevel.other,
  };
}

/// Formats a km distance from the API. `null` when the API gave none.
String? formatDistanceKm(double? km, String locale) {
  if (km == null || km.isNaN || km < 0) return null;
  final digits = km < 10 ? 1 : 0;
  for (final l in [locale, 'en']) {
    try {
      return NumberFormat.decimalPatternDigits(
        locale: l,
        decimalDigits: digits,
      ).format(km);
    } catch (_) {
      // Number symbols for this locale unavailable; try the next option.
    }
  }
  return km.toStringAsFixed(digits);
}
