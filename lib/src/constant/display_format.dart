import 'package:intl/intl.dart';

/// Date, time and number display helpers shared by features (Dashboard,
/// Events). They never invent data: anything unparseable returns `null` and
/// the UI omits it.

/// Parses `event_date` (ISO `YYYY-MM-DD`, optionally with a time part) to a
/// local calendar date.
DateTime? parseEventDate(String? value) {
  final parsed = DateTime.tryParse((value ?? '').trim());
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// Parses `start_time` / `end_time` in `HH:mm` or `HH:mm:ss` form.
({int hour, int minute})? parseEventTime(String? value) {
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})(?::\d{2})?',
  ).firstMatch((value ?? '').trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return (hour: hour, minute: minute);
}

/// Where an event sits relative to [now], by calendar day.
sealed class EventTiming {
  const EventTiming();
}

class EventToday extends EventTiming {
  const EventToday();
}

class EventTomorrow extends EventTiming {
  const EventTomorrow();
}

class EventInDays extends EventTiming {
  const EventInDays(this.days);
  final int days;
}

class EventPast extends EventTiming {
  const EventPast();
}

EventTiming? eventTiming(String? eventDate, DateTime now) {
  final date = parseEventDate(eventDate);
  if (date == null) return null;
  final today = DateTime(now.year, now.month, now.day);
  // Calendar-day difference, safe across DST changes.
  final days =
      DateTime.utc(
        date.year,
        date.month,
        date.day,
      ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  if (days < 0) return const EventPast();
  if (days == 0) return const EventToday();
  if (days == 1) return const EventTomorrow();
  return EventInDays(days);
}

String _withLocale(
  String locale,
  String Function(String locale) format, {
  required String Function() fallback,
}) {
  for (final l in [locale, 'en']) {
    try {
      return format(l);
    } catch (_) {
      // Date symbols for this locale not loaded; try the next option.
    }
  }
  return fallback();
}

String _two(int n) => n.toString().padLeft(2, '0');

/// "Tue, 14 Apr 2027" style, localized.
String? formatEventDate(String? eventDate, String locale) {
  final date = parseEventDate(eventDate);
  if (date == null) return null;
  return _withLocale(
    locale,
    (l) => DateFormat.yMMMEd(l).format(date),
    fallback: () => '${date.year}-${_two(date.month)}-${_two(date.day)}',
  );
}

/// Short day + month for date badges: (`14`, `Apr`).
({String day, String month})? eventDateBadge(String? eventDate, String locale) {
  final date = parseEventDate(eventDate);
  if (date == null) return null;
  return (
    day: _withLocale(
      locale,
      (l) => DateFormat.d(l).format(date),
      fallback: () => '${date.day}',
    ),
    month: _withLocale(
      locale,
      (l) => DateFormat.MMM(l).format(date),
      fallback: () => _two(date.month),
    ),
  );
}

/// "6:00 AM" or "6:00 AM – 9:30 AM", localized. `null` when no valid time.
String? formatEventTimeRange(
  String? startTime,
  String? endTime,
  String locale,
) {
  final start = parseEventTime(startTime);
  if (start == null) return null;
  String fmt(({int hour, int minute}) t) => _withLocale(
    locale,
    (l) => DateFormat.jm(l).format(DateTime(2000, 1, 1, t.hour, t.minute)),
    fallback: () => '${_two(t.hour)}:${_two(t.minute)}',
  );
  final end = parseEventTime(endTime);
  return end == null ? fmt(start) : '${fmt(start)} – ${fmt(end)}';
}

String formatClockTime(DateTime time, String locale) => _withLocale(
  locale,
  (l) => DateFormat.jm(l).format(time),
  fallback: () => '${_two(time.hour)}:${_two(time.minute)}',
);

/// Occupancy as a whole-number percent string, or `null` if unavailable.
String? formatOccupancy(double? percent, String locale) {
  if (percent == null || percent.isNaN || percent < 0) return null;
  return _withLocale(
    locale,
    (l) => NumberFormat.decimalPatternDigits(
      locale: l,
      decimalDigits: 0,
    ).format(percent),
    fallback: () => percent.toStringAsFixed(0),
  );
}

/// A source timestamp (ISO 8601, e.g. `created_at`, `start_time`) in local
/// time, following the app's existing convention (`DateTime.parse` then
/// `toLocal()`). Callers add "Today" / "Yesterday" wording. `null` when the
/// value can't be parsed, so nothing is shown rather than a guess.
({DateTime local, String time, String date, bool isToday, bool isYesterday})?
describeTimestamp(String? iso, String locale, DateTime now) {
  final parsed = DateTime.tryParse((iso ?? '').trim());
  if (parsed == null) return null;
  final local = parsed.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff =
      DateTime.utc(
        today.year,
        today.month,
        today.day,
      ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
  return (
    local: local,
    time: formatClockTime(local, locale),
    date: _withLocale(
      locale,
      (l) => DateFormat.yMMMd(l).format(local),
      fallback: () => '${local.year}-${_two(local.month)}-${_two(local.day)}',
    ),
    isToday: diff == 0,
    isYesterday: diff == 1,
  );
}

/// `SHAHI_SNAN` / `shahi-snan` → `Shahi Snan`. Mixed-case values (already
/// human-readable) are returned unchanged.
String? prettifyCode(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return null;
  final isCode = v == v.toUpperCase() || v == v.toLowerCase();
  if (!isCode) return v;
  return v
      .split(RegExp(r'[_\-\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}
