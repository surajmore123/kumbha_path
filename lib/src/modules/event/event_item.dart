import 'package:flutter/foundation.dart';
import 'package:kumbha_path/src/constant/display_format.dart';
import 'package:kumbha_path/src/models/featured_model.dart';
import 'package:kumbha_path/src/models/upcoming_events.dart';

export 'package:kumbha_path/src/constant/display_format.dart' show prettifyCode;

/// Where an event sits relative to now. Derived only from `event_date`,
/// `start_time`, `end_time` and `is_all_day`, read as device-local time.
enum EventPhase {
  upcoming,

  /// Today, but the times don't say whether it has started or finished.
  today,

  /// Today and the current time is within start–end (or it's all day).
  ongoing,
  past,

  /// No usable date.
  unknown,
}

/// Read-only view of an event from either the featured endpoint
/// ([EventDetailsModel]) or the upcoming endpoint ([EventSummaryModel]).
/// Both carry the same fields; this only normalizes them for display.
@immutable
class EventItem {
  const EventItem({
    required this.id,
    required this.name,
    this.shortDescription,
    this.description,
    this.category,
    this.subtype,
    this.date,
    this.startTime,
    this.endTime,
    this.isAllDay = false,
    this.locationType,
    this.locationName,
    this.expectedCrowdLevel,
  });

  factory EventItem.fromFeatured(EventDetailsModel e) => EventItem(
    id: (e.eventId ?? '').trim(),
    name: (e.eventName ?? '').trim(),
    shortDescription: _clean(e.shortDescription),
    description: _clean(e.description),
    category: _clean(e.eventCategory),
    subtype: _clean(e.eventSubtype),
    date: _clean(e.eventDate),
    startTime: _clean(e.startTime),
    endTime: _clean(e.endTime),
    isAllDay: e.isAllDay == true,
    locationType: _clean(e.locationType),
    locationName: _clean(e.locationName),
    expectedCrowdLevel: _clean(e.expectedCrowdLevel),
  );

  factory EventItem.fromSummary(EventSummaryModel e) => EventItem(
    id: (e.eventId ?? '').trim(),
    name: (e.eventName ?? '').trim(),
    shortDescription: _clean(e.shortDescription),
    description: _clean(e.description),
    category: _clean(e.eventCategory),
    subtype: _clean(e.eventSubtype),
    date: _clean(e.eventDate),
    startTime: _clean(e.startTime),
    endTime: _clean(e.endTime),
    isAllDay: e.isAllDay == true,
    locationType: _clean(e.locationType),
    locationName: _clean(e.locationName),
    expectedCrowdLevel: _clean(e.expectedCrowdLevel),
  );

  static String? _clean(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty ? null : t;
  }

  final String id;
  final String name;
  final String? shortDescription;
  final String? description;
  final String? category;
  final String? subtype;
  final String? date;
  final String? startTime;
  final String? endTime;
  final bool isAllDay;
  final String? locationType;
  final String? locationName;
  final String? expectedCrowdLevel;

  bool get hasName => name.isNotEmpty;

  /// Can the reminder toggle API be called for this event?
  bool get canRemind => id.isNotEmpty;

  DateTime? get day => parseEventDate(date);

  /// Short text for lists: the short description, else the description.
  String? get summary => shortDescription ?? description;

  /// Longest text for the detail view.
  String? get fullDescription => description ?? shortDescription;

  /// Backend category for display, e.g. `SHAHI_SNAN` → `Shahi Snan`.
  /// Prefers the more specific subtype.
  String? get categoryLabel => prettifyCode(subtype ?? category);

  /// Category used for filtering (the broad one).
  String? get filterCategory => prettifyCode(category);

  DateTime? _at(String? time) {
    final d = day, t = parseEventTime(time);
    if (d == null || t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  DateTime? get startsAt => isAllDay ? null : _at(startTime);
  DateTime? get endsAt => isAllDay ? null : _at(endTime);

  EventPhase phaseAt(DateTime now) {
    final d = day;
    if (d == null) return EventPhase.unknown;
    final today = DateTime(now.year, now.month, now.day);
    if (d.isBefore(today)) return EventPhase.past;
    if (d.isAfter(today)) return EventPhase.upcoming;
    if (isAllDay) return EventPhase.ongoing;
    final start = startsAt, end = endsAt;
    if (start != null && now.isBefore(start)) return EventPhase.upcoming;
    if (start != null && end != null && end.isAfter(start)) {
      return now.isAfter(end) ? EventPhase.past : EventPhase.ongoing;
    }
    return EventPhase.today;
  }
}

/// Chronological order: by date, all-day before timed, then start time.
/// Events without a usable date go last. Stable for equal keys, so the
/// API's own order is kept where the data doesn't decide.
List<EventItem> sortChronologically(List<EventItem> events) {
  final indexed = events.indexed.toList();
  int minutes(EventItem e) {
    if (e.isAllDay) return -1;
    final t = parseEventTime(e.startTime);
    return t == null ? 24 * 60 : t.hour * 60 + t.minute;
  }

  indexed.sort((a, b) {
    final da = a.$2.day, db = b.$2.day;
    if (da == null || db == null) {
      if (da == null && db == null) return a.$1.compareTo(b.$1);
      return da == null ? 1 : -1;
    }
    final byDay = da.compareTo(db);
    if (byDay != 0) return byDay;
    final byTime = minutes(a.$2).compareTo(minutes(b.$2));
    return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
  });
  return [for (final (_, e) in indexed) e];
}

/// Drops unnamed rows, repeated ids, and the featured event (shown above).
List<EventItem> dedupeEvents(List<EventItem> events, {String? excludeId}) {
  final seen = <String>{};
  final out = <EventItem>[];
  for (final e in events) {
    if (!e.hasName) continue;
    final key = e.id.isNotEmpty ? 'id:${e.id}' : 'n:${e.name}|${e.date}';
    if (excludeId != null && excludeId.isNotEmpty && e.id == excludeId) {
      continue;
    }
    if (seen.add(key)) out.add(e);
  }
  return out;
}
