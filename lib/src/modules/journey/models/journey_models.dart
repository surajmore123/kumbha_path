/// Data for Plan Your Kumbh Journey, matching `/api/journeys/` responses.
/// Unknown or malformed values are dropped, never guessed.
library;

String? _str(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

int _int(Object? v, [int fallback = 0]) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? fallback);

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

List<Map<String, dynamic>> _maps(Object? v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

enum JourneyStatus { draft, planned, completed }

JourneyStatus _status(Object? v) => switch (v) {
  'planned' => JourneyStatus.planned,
  'completed' => JourneyStatus.completed,
  _ => JourneyStatus.draft,
};

/// The values the backend accepts for choice fields.
abstract final class JourneyChoices {
  static const transport = ['train', 'bus', 'flight', 'private', 'undecided'];
  static const stays = [
    'hotel',
    'dharamshala',
    'ashram',
    'budget',
    'family',
    'undecided',
  ];
  static const interests = [
    'bathing',
    'temples',
    'learning',
    'akhadas',
    'sightseeing',
  ];
  static const periods = [
    'early_morning',
    'morning',
    'afternoon',
    'evening',
    'night',
    'anytime',
  ];
  static const kinds = [
    'travel',
    'temple',
    'ghat',
    'bathing',
    'event',
    'rest',
    'meal',
    'akhada',
    'sightseeing',
    'note',
  ];
  static const checklistCategories = [
    'documents',
    'health',
    'packing',
    'travel',
    'family',
    'other',
  ];
  static const maxDays = 15;
  static const maxTravellers = 50;
}

class JourneySummary {
  const JourneySummary({
    required this.id,
    required this.title,
    required this.status,
    this.originCity,
    this.originState,
    this.arrivalDate,
    this.departureDate,
    this.travellers = 1,
    this.dayCount = 0,
    this.checklistDone = 0,
    this.checklistTotal = 0,
    this.updatedAt,
  });

  final String id;
  final String title;
  final JourneyStatus status;
  final String? originCity;
  final String? originState;
  final DateTime? arrivalDate;
  final DateTime? departureDate;
  final int travellers;
  final int dayCount;
  final int checklistDone;
  final int checklistTotal;
  final DateTime? updatedAt;

  String? get origin =>
      [originCity, originState].whereType<String>().join(', ').trim().isEmpty
          ? null
          : [originCity, originState].whereType<String>().join(', ');

  static JourneySummary? fromJson(Map<String, dynamic> json) {
    final id = _str(json['id']);
    final title = _str(json['title']);
    if (id == null || title == null) return null;
    return JourneySummary(
      id: id,
      title: title,
      status: _status(json['status']),
      originCity: _str(json['origin_city']),
      originState: _str(json['origin_state']),
      arrivalDate: _date(json['arrival_date']),
      departureDate: _date(json['departure_date']),
      travellers: _int(json['travellers'], 1),
      dayCount: _int(json['day_count']),
      checklistDone: _int(json['checklist_done']),
      checklistTotal: _int(json['checklist_total']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

class JourneyPage {
  const JourneyPage({
    required this.items,
    required this.count,
    required this.page,
    required this.hasNext,
  });

  final List<JourneySummary> items;
  final int count;
  final int page;
  final bool hasNext;

  factory JourneyPage.fromJson(Map<String, dynamic> json) => JourneyPage(
    items:
        _maps(
          json['results'],
        ).map(JourneySummary.fromJson).whereType<JourneySummary>().toList(),
    count: _int(json['count']),
    page: _int(json['page'], 1),
    hasNext: json['has_next'] == true,
  );
}

class JourneyItem {
  const JourneyItem({
    required this.id,
    required this.title,
    this.details = '',
    this.period = 'anytime',
    this.kind = 'note',
    this.templeName,
    this.eventName,
    this.eventDate,
    this.isSuggested = false,
    this.isEdited = false,
    this.isDone = false,
  });

  final int id;
  final String title;
  final String details;
  final String period;
  final String kind;
  final String? templeName;
  final String? eventName;
  final DateTime? eventDate;
  final bool isSuggested;
  final bool isEdited;
  final bool isDone;

  static JourneyItem? fromJson(Map<String, dynamic> json) {
    final title = _str(json['title']);
    if (json['id'] is! int || title == null) return null;
    return JourneyItem(
      id: json['id'] as int,
      title: title,
      details: _str(json['details']) ?? '',
      period: _str(json['period']) ?? 'anytime',
      kind: _str(json['kind']) ?? 'note',
      templeName: _str(json['temple_name']),
      eventName: _str(json['event_name']),
      eventDate: _date(json['event_date']),
      isSuggested: json['source'] == 'suggested',
      isEdited: json['is_edited'] == true,
      isDone: json['is_done'] == true,
    );
  }
}

class JourneyDay {
  const JourneyDay({
    required this.number,
    this.date,
    this.title = '',
    this.items = const [],
  });

  final int number;
  final DateTime? date;
  final String title;
  final List<JourneyItem> items;

  factory JourneyDay.fromJson(Map<String, dynamic> json) => JourneyDay(
    number: _int(json['day_number'], 1),
    date: _date(json['date']),
    title: _str(json['title']) ?? '',
    items:
        _maps(
          json['items'],
        ).map(JourneyItem.fromJson).whereType<JourneyItem>().toList(),
  );
}

class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.text,
    this.category = 'other',
    this.isDone = false,
    this.isSuggested = false,
  });

  final int id;
  final String text;
  final String category;
  final bool isDone;
  final bool isSuggested;

  static ChecklistItem? fromJson(Map<String, dynamic> json) {
    final text = _str(json['text']);
    if (json['id'] is! int || text == null) return null;
    return ChecklistItem(
      id: json['id'] as int,
      text: text,
      category: _str(json['category']) ?? 'other',
      isDone: json['is_done'] == true,
      isSuggested: json['source'] == 'suggested',
    );
  }
}

/// Transport or stay details the user entered (not a booking we made).
class JourneyReference {
  const JourneyReference({
    required this.id,
    required this.kind,
    required this.title,
    this.provider,
    this.bookingReference,
    this.url,
    this.startDate,
    this.endDate,
    this.notes,
  });

  final int id;
  final String kind; // transport | accommodation
  final String title;
  final String? provider;
  final String? bookingReference;
  final String? url;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;

  static JourneyReference? fromJson(Map<String, dynamic> json) {
    final title = _str(json['title']);
    final kind = _str(json['kind']);
    if (json['id'] is! int || title == null || kind == null) return null;
    final url = _str(json['url']);
    return JourneyReference(
      id: json['id'] as int,
      kind: kind,
      title: title,
      provider: _str(json['provider']),
      bookingReference: _str(json['booking_reference']),
      url: url != null && url.startsWith('https://') ? url : null,
      startDate: _date(json['start_date']),
      endDate: _date(json['end_date']),
      notes: _str(json['notes']),
    );
  }
}

class BudgetLine {
  const BudgetLine(this.category, this.label, this.percent, this.amount);

  final String category;
  final String label;
  final int percent;
  final String amount;
}

class BudgetPlan {
  const BudgetPlan({
    required this.total,
    required this.perPerson,
    required this.assumption,
    required this.lines,
  });

  final String total;
  final String perPerson;
  final String assumption;
  final List<BudgetLine> lines;

  static BudgetPlan? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return BudgetPlan(
      total: '${json['total'] ?? ''}',
      perPerson: '${json['per_person'] ?? ''}',
      assumption: _str(json['assumption']) ?? '',
      lines: [
        for (final l in _maps(json['lines']))
          BudgetLine(
            '${l['category']}',
            _str(l['label']) ?? '${l['category']}',
            _int(l['percent']),
            '${l['amount'] ?? ''}',
          ),
      ],
    );
  }
}

/// A full plan: what the user entered plus the itinerary and lists.
class JourneyPlan {
  const JourneyPlan({
    required this.id,
    required this.title,
    required this.status,
    this.originCity = '',
    this.originState = '',
    this.arrivalDate,
    this.departureDate,
    this.durationDays,
    this.flexible = false,
    this.adults = 1,
    this.children = 0,
    this.seniors = 0,
    this.needsAccessibility = false,
    this.accessibilityNotes = '',
    this.transportMode = 'undecided',
    this.budgetAmount,
    this.budgetPerPerson = false,
    this.accommodation = 'undecided',
    this.interests = const [],
    this.dietaryNotes = '',
    this.notes = '',
    this.language = 'en',
    this.dayCount = 0,
    this.recommendedDays = 3,
    this.budget,
    this.generatedAt,
    this.days = const [],
    this.checklist = const [],
    this.references = const [],
  });

  final String id;
  final String title;
  final JourneyStatus status;
  final String originCity;
  final String originState;
  final DateTime? arrivalDate;
  final DateTime? departureDate;
  final int? durationDays;
  final bool flexible;
  final int adults;
  final int children;
  final int seniors;
  final bool needsAccessibility;
  final String accessibilityNotes;
  final String transportMode;
  final String? budgetAmount;
  final bool budgetPerPerson;
  final String accommodation;
  final List<String> interests;
  final String dietaryNotes;
  final String notes;
  final String language;
  final int dayCount;
  final int recommendedDays;
  final BudgetPlan? budget;
  final DateTime? generatedAt;
  final List<JourneyDay> days;
  final List<ChecklistItem> checklist;
  final List<JourneyReference> references;

  int get travellers => adults + children + seniors;
  bool get hasItinerary => days.isNotEmpty;
  int get checklistDone => checklist.where((c) => c.isDone).length;

  static JourneyPlan? fromJson(Map<String, dynamic> json) {
    final id = _str(json['id']);
    final title = _str(json['title']);
    if (id == null || title == null) return null;
    final budget = json['budget_amount'];
    return JourneyPlan(
      id: id,
      title: title,
      status: _status(json['status']),
      originCity: _str(json['origin_city']) ?? '',
      originState: _str(json['origin_state']) ?? '',
      arrivalDate: _date(json['arrival_date']),
      departureDate: _date(json['departure_date']),
      durationDays:
          json['duration_days'] is int ? json['duration_days'] as int : null,
      flexible: json['date_flexibility'] == 'flexible',
      adults: _int(json['adults'], 1),
      children: _int(json['children']),
      seniors: _int(json['seniors']),
      needsAccessibility: json['needs_accessibility'] == true,
      accessibilityNotes: _str(json['accessibility_notes']) ?? '',
      transportMode: _str(json['transport_mode']) ?? 'undecided',
      budgetAmount: budget == null ? null : '$budget',
      budgetPerPerson: json['budget_basis'] == 'per_person',
      accommodation: _str(json['accommodation_preference']) ?? 'undecided',
      interests:
          (json['interests'] is List)
              ? (json['interests'] as List).whereType<String>().toList()
              : const [],
      dietaryNotes: _str(json['dietary_notes']) ?? '',
      notes: (json['notes'] is String) ? json['notes'] as String : '',
      language: _str(json['language']) ?? 'en',
      dayCount: _int(json['day_count']),
      recommendedDays: _int(json['recommended_days'], 3),
      budget: BudgetPlan.fromJson(json['budget_plan']),
      generatedAt: _date(json['itinerary_generated_at']),
      days: _maps(json['days']).map(JourneyDay.fromJson).toList(),
      checklist:
          _maps(
            json['checklist'],
          ).map(ChecklistItem.fromJson).whereType<ChecklistItem>().toList(),
      references:
          _maps(json['references'])
              .map(JourneyReference.fromJson)
              .whereType<JourneyReference>()
              .toList(),
    );
  }
}

/// An official or reference link with provenance.
class GuideSource {
  const GuideSource({
    required this.title,
    required this.url,
    required this.organization,
    required this.status,
    required this.checkedOn,
    required this.reachable,
  });

  final String title;
  final String url;
  final String organization;
  final String status; // official | official_announcement | guidance
  final String checkedOn;
  final bool reachable;

  static GuideSource? fromJson(Map<String, dynamic> json) {
    final title = _str(json['title']);
    final url = _str(json['url']);
    if (title == null || url == null || !url.startsWith('https://')) {
      return null;
    }
    return GuideSource(
      title: title,
      url: url,
      organization: _str(json['organization']) ?? '',
      status: _str(json['status']) ?? 'guidance',
      checkedOn: _str(json['checked_on']) ?? '',
      reachable: json['reachable'] != false,
    );
  }
}

class GuideTransport {
  const GuideTransport(
    this.mode,
    this.title,
    this.note,
    this.status,
    this.links,
  );

  final String mode;
  final String title;
  final String note;
  final String status;
  final List<GuideSource> links;
}

class GuideStay {
  const GuideStay(this.category, this.title, this.note);

  final String category;
  final String title;
  final String note;
}

class GuideContact {
  const GuideContact(this.label, this.phone, this.email, this.source);

  final String label;
  final String? phone;
  final String? email;
  final GuideSource? source;
}

class GuideDate {
  const GuideDate(this.name, this.date, this.location, this.lastChecked);

  final String name;
  final DateTime date;
  final String? location;
  final DateTime? lastChecked;
}

class PlanningGuide {
  const PlanningGuide({
    required this.checkedOn,
    required this.transport,
    required this.stayNote,
    required this.stays,
    required this.stayLinks,
    required this.contactsNote,
    required this.contacts,
    required this.datesNote,
    required this.dates,
  });

  final String checkedOn;
  final List<GuideTransport> transport;
  final String stayNote;
  final List<GuideStay> stays;
  final List<GuideSource> stayLinks;
  final String contactsNote;
  final List<GuideContact> contacts;
  final String datesNote;
  final List<GuideDate> dates;

  factory PlanningGuide.fromJson(Map<String, dynamic> json) {
    List<GuideSource> sources(Object? v) =>
        _maps(v).map(GuideSource.fromJson).whereType<GuideSource>().toList();
    final stay =
        json['accommodation'] is Map<String, dynamic>
            ? json['accommodation'] as Map<String, dynamic>
            : const <String, dynamic>{};
    final contacts =
        json['contacts'] is Map<String, dynamic>
            ? json['contacts'] as Map<String, dynamic>
            : const <String, dynamic>{};
    final dates =
        json['important_dates'] is Map<String, dynamic>
            ? json['important_dates'] as Map<String, dynamic>
            : const <String, dynamic>{};
    return PlanningGuide(
      checkedOn: _str(json['checked_on']) ?? '',
      transport: [
        for (final t in _maps(json['transport']))
          GuideTransport(
            '${t['mode']}',
            _str(t['title']) ?? '',
            _str(t['note']) ?? '',
            _str(t['status']) ?? 'guidance',
            sources(t['links']),
          ),
      ],
      stayNote: _str(stay['disclaimer']) ?? '',
      stays: [
        for (final s in _maps(stay['categories']))
          GuideStay(
            '${s['category']}',
            _str(s['title']) ?? '',
            _str(s['note']) ?? '',
          ),
      ],
      stayLinks: sources(stay['links']),
      contactsNote: _str(contacts['note']) ?? '',
      contacts: [
        for (final c in _maps(contacts['items']))
          GuideContact(
            _str(c['label']) ?? '',
            _str(c['phone']),
            _str(c['email']),
            c['source'] is Map<String, dynamic>
                ? GuideSource.fromJson(c['source'] as Map<String, dynamic>)
                : null,
          ),
      ],
      datesNote: _str(dates['note']) ?? '',
      dates: [
        for (final d in _maps(dates['items']))
          if (_date(d['date']) != null)
            GuideDate(
              _str(d['name']) ?? '',
              _date(d['date'])!,
              _str(d['location']),
              _date(d['last_checked']),
            ),
      ],
    );
  }
}
