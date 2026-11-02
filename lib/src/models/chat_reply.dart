/// Structured data the chat API returns with an assistant reply
/// (`messages[].metadata` of the assistant message). Everything is
/// optional: unknown or malformed values are dropped, never guessed.
library;

String? _str(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _num(Object? value) => value is num ? value.toDouble() : null;

/// Only https links are opened from replies.
String? _https(Object? value) {
  final url = _str(value);
  final uri = url == null ? null : Uri.tryParse(url);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
      ? url
      : null;
}

List<Map> _maps(Object? value) =>
    value is List ? value.whereType<Map>().toList() : const [];

class ReplyTemple {
  const ReplyTemple({
    required this.id,
    required this.name,
    this.city,
    this.imageUrl,
    this.advisoryLevel,
    this.advisoryMessage,
    this.distanceKm,
    this.directionsUrl,
    this.mapUrl,
  });

  final String id;
  final String name;
  final String? city;
  final String? imageUrl;

  /// Admin-set advisory (`Temple.crowd_level`), not a live measurement.
  final String? advisoryLevel;
  final String? advisoryMessage;
  final double? distanceKm;
  final String? directionsUrl;
  final String? mapUrl;

  static ReplyTemple? fromJson(Map json) {
    final id = _str(json['id']);
    final name = _str(json['name']);
    if (id == null || name == null) return null;
    return ReplyTemple(
      id: id,
      name: name,
      city: _str(json['city']),
      imageUrl: _https(json['image_url']),
      advisoryLevel: _str(json['crowd_level']),
      advisoryMessage: _str(json['crowd_message']),
      distanceKm: _num(json['distance_km']),
      directionsUrl: _https(json['directions_url']),
      mapUrl: _https(json['map_url']),
    );
  }
}

class ReplyEvent {
  const ReplyEvent({
    required this.id,
    required this.name,
    required this.date,
    this.startTime,
    this.endTime,
    this.isAllDay = false,
    this.location,
    this.category,
    this.directionsUrl,
  });

  final String id;
  final String name;
  final String date; // yyyy-mm-dd
  final String? startTime;
  final String? endTime;
  final bool isAllDay;
  final String? location;
  final String? category;
  final String? directionsUrl;

  static ReplyEvent? fromJson(Map json) {
    final id = _str(json['id']);
    final name = _str(json['name']);
    final date = _str(json['date']);
    if (id == null || name == null || date == null) return null;
    return ReplyEvent(
      id: id,
      name: name,
      date: date,
      startTime: _str(json['start_time']),
      endTime: _str(json['end_time']),
      isAllDay: json['is_all_day'] == true,
      location: _str(json['location']),
      category: _str(json['category']),
      directionsUrl: _https(json['directions_url']),
    );
  }
}

class ReplyZone {
  const ReplyZone({
    required this.name,
    this.status,
    this.occupancyPercent,
    this.calculatedAt,
    this.stale = true,
  });

  final String name;
  final String? status;
  final double? occupancyPercent;
  final String? calculatedAt;
  final bool stale;

  bool get hasReading => calculatedAt != null;

  static ReplyZone? fromJson(Map json) {
    final name = _str(json['name']);
    if (name == null) return null;
    return ReplyZone(
      name: name,
      status: _str(json['status']),
      occupancyPercent: _num(json['occupancy_percent']),
      calculatedAt: _str(json['calculated_at']),
      stale: json['stale'] != false,
    );
  }
}

class ReplyIncident {
  const ReplyIncident({
    required this.title,
    this.zone,
    this.type,
    this.severity,
  });

  final String title;
  final String? zone;
  final String? type;
  final String? severity;

  static ReplyIncident? fromJson(Map json) {
    final title = _str(json['title']);
    if (title == null) return null;
    return ReplyIncident(
      title: title,
      zone: _str(json['zone']),
      type: _str(json['type']),
      severity: _str(json['severity']),
    );
  }
}

class ReplySource {
  const ReplySource({required this.label, this.url, this.unverified = false});

  final String label;
  final String? url;
  final bool unverified;
}

class ChatReplyData {
  const ChatReplyData({
    this.temples = const [],
    this.templeMode,
    this.events = const [],
    this.eventMode,
    this.zones = const [],
    this.incidents = const [],
    this.crowdUpdatedAt,
    this.crowdStale = false,
    this.sources = const [],
    this.partial = false,
  });

  final List<ReplyTemple> temples;

  /// matched | context | nearby | list (which temples these are).
  final String? templeMode;
  final List<ReplyEvent> events;

  /// upcoming | recent | context.
  final String? eventMode;
  final List<ReplyZone> zones;
  final List<ReplyIncident> incidents;
  final String? crowdUpdatedAt;
  final bool crowdStale;
  final List<ReplySource> sources;

  /// Some data source failed, so the answer may be incomplete.
  final bool partial;

  bool get hasCrowd => zones.isNotEmpty || incidents.isNotEmpty;

  bool get isEmpty =>
      temples.isEmpty &&
      events.isEmpty &&
      !hasCrowd &&
      sources.isEmpty &&
      !partial;

  static const empty = ChatReplyData();

  factory ChatReplyData.fromMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return empty;
    final crowd = metadata['crowd'] is Map ? metadata['crowd'] as Map : null;
    final freshness =
        crowd?['freshness'] is Map ? crowd!['freshness'] as Map : null;
    final warnings = metadata['warnings'];
    return ChatReplyData(
      temples:
          _maps(
            metadata['temples'],
          ).map(ReplyTemple.fromJson).whereType<ReplyTemple>().toList(),
      templeMode: _str(metadata['temple_mode']),
      events:
          _maps(
            metadata['events'],
          ).map(ReplyEvent.fromJson).whereType<ReplyEvent>().toList(),
      eventMode: _str(metadata['event_mode']),
      zones:
          _maps(
            crowd?['zones'],
          ).map(ReplyZone.fromJson).whereType<ReplyZone>().toList(),
      incidents:
          _maps(
            crowd?['incidents'],
          ).map(ReplyIncident.fromJson).whereType<ReplyIncident>().toList(),
      crowdUpdatedAt: _str(freshness?['calculated_at']),
      crowdStale: freshness?['stale'] == true,
      sources: _sources(metadata['citations']),
      partial:
          metadata['status'] == 'degraded' ||
          (warnings is List && warnings.isNotEmpty),
    );
  }

  /// Knowledge-base and document references. Temples, events and crowd
  /// data already have their own cards, so they aren't repeated here.
  static List<ReplySource> _sources(Object? citations) {
    final sources = <ReplySource>[];
    final seen = <String>{};
    for (final c in _maps(citations)) {
      final ReplySource? source = switch (c['type']) {
        'knowledge' => _knowledge(c),
        'document' => _document(c),
        _ => null,
      };
      if (source != null && seen.add(source.label)) sources.add(source);
    }
    return sources.take(6).toList();
  }

  static ReplySource? _knowledge(Map c) {
    final label = _str(c['title']) ?? _str(c['source']);
    if (label == null) return null;
    return ReplySource(
      label: label,
      url: _https(c['source_url']) ?? _https(c['source']),
      unverified: c['verification_status'] != 'verified',
    );
  }

  static ReplySource? _document(Map c) {
    final name = _str(c['name']);
    if (name == null) return null;
    final location = _str(c['location']);
    return ReplySource(label: location == null ? name : '$name · $location');
  }
}
