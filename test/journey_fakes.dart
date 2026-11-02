import 'dart:convert';

import 'package:kumbha_path/src/modules/journey/data/journey_repository.dart';
import 'package:kumbha_path/src/modules/journey/models/journey_models.dart';

/// In-memory stand-in for `/api/journeys/`. Plans are kept as backend-shaped
/// JSON and parsed with the real models, so parsing is exercised too.
/// Plain JSON types (`Map<String, dynamic>`, `List<dynamic>`), like a decoded
/// response, so tests can merge request bodies into stored rows.
T _norm<T>(T value) => jsonDecode(jsonEncode(value)) as T;

class FakeJourneyRepository implements JourneyRepository {
  final Map<String, Map<String, dynamic>> plans = {};
  final List<String> calls = [];
  final List<Map<String, dynamic>> sent = [];

  /// Thrown (once) by the next call when set.
  JourneyException? failNext;

  /// Page size for [list], to exercise "Load more".
  int pageSize = 10;

  int _ids = 0;
  int _rowIds = 100;

  void _call(String name, [Map<String, dynamic>? body]) {
    calls.add(name);
    if (body != null) sent.add(body);
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  /// Adds a plan directly (test setup). Returns its id.
  String seed({
    String title = 'Family Kumbh trip',
    String status = 'planned',
    DateTime? arrival,
    int days = 3,
    bool itinerary = true,
    String? budget = '20000',
  }) {
    final id = 'plan-${++_ids}';
    final start = arrival ?? DateTime.now().add(const Duration(days: 30));
    plans[id] = {
      'id': id,
      'title': title,
      'status': status,
      'origin_city': 'Pune',
      'origin_state': 'Maharashtra',
      'arrival_date': isoDate(start),
      'departure_date': isoDate(start.add(Duration(days: days - 1))),
      'adults': 2,
      'children': 1,
      'seniors': 1,
      'transport_mode': 'train',
      'budget_amount': budget,
      'budget_basis': 'total',
      'accommodation_preference': 'dharamshala',
      'interests': ['bathing', 'temples'],
      'notes': '',
      'language': 'en',
      'days': <Map<String, dynamic>>[],
      'checklist': <Map<String, dynamic>>[],
      'references': <Map<String, dynamic>>[],
      'recommended_days': 4,
    };
    plans[id] = _norm(plans[id]!);
    if (itinerary) _build(plans[id]!);
    return id;
  }

  Map<String, dynamic> _plan(String id) =>
      plans[id] ?? (throw const JourneyException(JourneyFailure.notFound));

  JourneyPlan _parse(Map<String, dynamic> json) {
    final days = json['days'] as List;
    json['day_count'] =
        days.isNotEmpty ? days.length : (json['duration_days'] ?? 0);
    final budget = double.tryParse('${json['budget_amount'] ?? ''}');
    json['budget_plan'] =
        budget == null
            ? null
            : {
              'total': budget.round().toString(),
              'per_person': (budget / 4).round().toString(),
              'assumption': 'split',
              'lines': [
                for (final (c, p) in [
                  ('travel', 35),
                  ('stay', 30),
                  ('food', 15),
                  ('local_transport', 10),
                  ('offerings_misc', 10),
                ])
                  {
                    'category': c,
                    'label': c,
                    'percent': p,
                    'amount': (budget * p / 100).round().toString(),
                  },
              ],
            };
    return JourneyPlan.fromJson(json)!;
  }

  void _build(Map<String, dynamic> json) {
    final arrival = DateTime.tryParse('${json['arrival_date']}');
    final departure = DateTime.tryParse('${json['departure_date']}');
    final count =
        arrival != null && departure != null
            ? departure.difference(arrival).inDays + 1
            : (json['duration_days'] as int? ?? 3);
    final kept = <Map<String, dynamic>>[
      for (final d in (json['days'] as List? ?? const []))
        for (final i in (d['items'] as List))
          if (i['source'] == 'user' || i['is_edited'] == true)
            i as Map<String, dynamic>,
    ];
    json['days'] = [
      for (var n = 1; n <= count; n++)
        {
          'day_number': n,
          'date':
              arrival == null
                  ? null
                  : isoDate(arrival.add(Duration(days: n - 1))),
          'title': n == 1 ? 'Arrival in Nashik' : 'Temples and ghats',
          'items': [
            {
              'id': ++_rowIds,
              'title':
                  n == 1
                      ? 'Reach Nashik and check in'
                      : 'Darshan at Kalaram Temple',
              'details': '',
              'period': n == 1 ? 'afternoon' : 'morning',
              'kind': n == 1 ? 'travel' : 'temple',
              'source': 'suggested',
              'is_edited': false,
              'is_done': false,
            },
            {
              'id': ++_rowIds,
              'title': 'Rest break',
              'details': '',
              'period': 'afternoon',
              'kind': 'rest',
              'source': 'suggested',
              'is_edited': false,
              'is_done': false,
            },
            if (n == count) ...kept,
          ],
        },
    ];
    final checklist =
        (json['checklist'] as List? ?? const []).cast<Map<String, dynamic>>();
    if (checklist.isEmpty) {
      checklist.addAll([
        {
          'id': ++_rowIds,
          'text': 'ID card for every traveller',
          'category': 'documents',
          'is_done': false,
          'source': 'suggested',
        },
        {
          'id': ++_rowIds,
          'text': 'Basic medicines',
          'category': 'health',
          'is_done': false,
          'source': 'suggested',
        },
      ]);
    }
    json['checklist'] = _norm<Object?>(checklist);
    json['days'] = _norm<Object?>(json['days']);
    json['status'] = json['status'] == 'completed' ? 'completed' : 'planned';
    json['itinerary_generated_at'] = DateTime.now().toIso8601String();
  }

  Map<String, dynamic>? _item(Map<String, dynamic> plan, int itemId) {
    for (final d in plan['days'] as List) {
      for (final i in d['items'] as List) {
        if (i['id'] == itemId) return i as Map<String, dynamic>;
      }
    }
    return null;
  }

  @override
  Future<JourneyPage> list({
    String? status,
    String ordering = 'arrival',
    int page = 1,
  }) async {
    _call('list:${status ?? 'all'}:$page');
    final all = [
      for (final p in plans.values)
        if (status == null || p['status'] == status) _parse(p),
    ];
    final start = (page - 1) * pageSize;
    final slice = all.skip(start).take(pageSize).toList();
    return JourneyPage(
      items: [
        for (final p in slice)
          JourneySummary(
            id: p.id,
            title: p.title,
            status: p.status,
            originCity: p.originCity,
            originState: p.originState,
            arrivalDate: p.arrivalDate,
            departureDate: p.departureDate,
            travellers: p.travellers,
            dayCount: p.dayCount,
            checklistDone: p.checklistDone,
            checklistTotal: p.checklist.length,
          ),
      ],
      count: all.length,
      page: page,
      hasNext: start + pageSize < all.length,
    );
  }

  @override
  Future<JourneyPlan> get(String id) async {
    _call('get');
    return _parse(_plan(id));
  }

  @override
  Future<JourneyPlan> create(
    Map<String, dynamic> data, {
    bool generate = false,
  }) async {
    _call(generate ? 'create:generate' : 'create', data);
    final id = 'plan-${++_ids}';
    final json = <String, dynamic>{
      ...data,
      'id': id,
      'status': 'draft',
      'days': <Map<String, dynamic>>[],
      'checklist': <Map<String, dynamic>>[],
      'references': <Map<String, dynamic>>[],
      'recommended_days': 3,
    };
    plans[id] = _norm(json);
    if (generate) _build(plans[id]!);
    return _parse(plans[id]!);
  }

  @override
  Future<JourneyPlan> update(String id, Map<String, dynamic> data) async {
    _call('update', data);
    final json = _plan(id)..addAll(data);
    return _parse(json);
  }

  @override
  Future<void> delete(String id) async {
    _call('delete');
    plans.remove(id);
  }

  @override
  Future<JourneyPlan> generate(String id, {String? language}) async {
    _call('generate:$language');
    final json = _plan(id);
    _build(json);
    return _parse(json);
  }

  @override
  Future<JourneyPlan> duplicate(String id) async {
    _call('duplicate');
    final copy = 'plan-${++_ids}';
    plans[copy] = {
      ..._plan(id),
      'id': copy,
      'title': '${_plan(id)['title']} (copy)',
      'status': 'draft',
      'references': <Map<String, dynamic>>[],
    };
    return _parse(plans[copy]!);
  }

  @override
  Future<String> exportText(String id) async {
    _call('export');
    return '${_plan(id)['title']}\n\nPlanned with KumbhaPath.';
  }

  @override
  Future<void> addItem(
    String id,
    int dayNumber,
    Map<String, dynamic> data,
  ) async {
    _call('addItem', data);
    final day = (_plan(id)['days'] as List).firstWhere(
      (d) => d['day_number'] == dayNumber,
    );
    (day['items'] as List).add({
      ...data,
      'id': ++_rowIds,
      'source': 'user',
      'is_edited': false,
      'is_done': false,
    });
  }

  @override
  Future<void> updateItem(
    String id,
    int itemId,
    Map<String, dynamic> data,
  ) async {
    _call('updateItem', data);
    final plan = _plan(id);
    final item = _item(plan, itemId)!;
    final target = data['day_number'];
    item.addAll({...data}..remove('day_number'));
    if (target is int) {
      for (final d in plan['days'] as List) {
        (d['items'] as List).remove(item);
      }
      final day = (plan['days'] as List).firstWhere(
        (d) => d['day_number'] == target,
      );
      (day['items'] as List).add(item);
    }
  }

  @override
  Future<void> deleteItem(String id, int itemId) async {
    _call('deleteItem');
    for (final d in _plan(id)['days'] as List) {
      (d['items'] as List).removeWhere((i) => i['id'] == itemId);
    }
  }

  @override
  Future<void> reorderDay(String id, int dayNumber, List<int> itemIds) async {
    _call('reorder:${itemIds.join(',')}');
    final day = (_plan(id)['days'] as List).firstWhere(
      (d) => d['day_number'] == dayNumber,
    );
    final items = {for (final i in day['items'] as List) i['id']: i};
    day['items'] = [for (final i in itemIds) items[i]];
  }

  @override
  Future<void> addChecklist(String id, Map<String, dynamic> data) async {
    _call('addChecklist', data);
    (_plan(id)['checklist'] as List).add({
      ...data,
      'id': ++_rowIds,
      'is_done': false,
      'source': 'user',
    });
  }

  @override
  Future<void> updateChecklist(
    String id,
    int itemId,
    Map<String, dynamic> data,
  ) async {
    _call('updateChecklist', data);
    (_plan(id)['checklist'] as List)
        .firstWhere((c) => c['id'] == itemId)
        .addAll(data);
  }

  @override
  Future<void> deleteChecklist(String id, int itemId) async {
    _call('deleteChecklist');
    (_plan(id)['checklist'] as List).removeWhere((c) => c['id'] == itemId);
  }

  @override
  Future<void> addReference(String id, Map<String, dynamic> data) async {
    _call('addReference', data);
    (_plan(id)['references'] as List).add({...data, 'id': ++_rowIds});
  }

  @override
  Future<void> updateReference(
    String id,
    int refId,
    Map<String, dynamic> data,
  ) async {
    _call('updateReference', data);
    (_plan(id)['references'] as List)
        .firstWhere((r) => r['id'] == refId)
        .addAll(data);
  }

  @override
  Future<void> deleteReference(String id, int refId) async {
    _call('deleteReference');
    (_plan(id)['references'] as List).removeWhere((r) => r['id'] == refId);
  }

  @override
  Future<PlanningGuide> guide(String language) async {
    _call('guide:$language');
    return PlanningGuide.fromJson(
      sampleGuide(DateTime.now().add(const Duration(days: 31))),
    );
  }
}

Map<String, dynamic> _source(String title, String url) => {
  'title': title,
  'url': url,
  'organization': 'Indian Railways',
  'status': 'official',
  'checked_on': '2026-10-29',
  'reachable': true,
};

/// Backend-shaped `/api/journeys/guide/` payload with one bathing day.
Map<String, dynamic> sampleGuide(DateTime bathDay) => {
  'checked_on': '2026-10-29',
  'transport': [
    {
      'mode': 'train',
      'title': 'Train',
      'note': 'Special trains will be announced by Indian Railways.',
      'status': 'official_announcement',
      'links': [
        _source(
          'NTES train enquiry',
          'https://enquiry.indianrail.gov.in/ntes/',
        ),
      ],
    },
    {
      'mode': 'bus',
      'title': 'Bus',
      'note': 'MSRTC runs buses to Nashik.',
      'status': 'official',
      'links': [_source('MSRTC', 'https://msrtc.maharashtra.gov.in/')],
    },
  ],
  'accommodation': {
    'disclaimer': 'KumbhaPath does not list or verify any stay.',
    'categories': [
      {
        'category': 'dharamshala',
        'title': 'Dharamshala',
        'note': 'Confirm rooms directly.',
      },
    ],
    'links': [
      _source('Maharashtra Tourism', 'https://www.maharashtratourism.gov.in/'),
    ],
  },
  'contacts': {
    'note': 'Call 112 in any emergency.',
    'items': [
      {
        'label': 'Emergency',
        'phone': '112',
        'source': _source('ERSS', 'https://112.gov.in/'),
      },
    ],
  },
  'important_dates': {
    'note': 'Dates come from the KumbhaPath events list.',
    'items': [
      {
        'name': 'First Amrit Snan',
        'date': isoDate(bathDay),
        'location': 'Ramkund',
        'last_checked': '2026-10-20T10:00:00Z',
      },
    ],
  },
};
