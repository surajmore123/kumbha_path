/// Data for Booking & Stay, matching `/api/bookings/`. Unknown or malformed
/// values are dropped, never guessed.
library;

import 'package:kumbha_path/src/modules/akhada/models/akhada_models.dart';

String? _str(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

String? _https(Object? v) {
  final s = _str(v);
  return s != null && s.startsWith('https://') ? s : null;
}

double? _double(Object? v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

List<T> _list<T>(Object? v, T? Function(Map<String, dynamic>) parse) =>
    v is List
        ? v.whereType<Map<String, dynamic>>().map(parse).whereType<T>().toList()
        : <T>[];

String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

enum PriceStatus { verified, estimated, onRequest }

class Named {
  const Named(this.slug, this.name);

  final String slug;
  final String name;

  static Named? fromJson(Map<String, dynamic> json) {
    final slug = _str(json['slug']);
    final name = _str(json['name']);
    return slug == null || name == null ? null : Named(slug, name);
  }
}

class StayArea extends Named {
  const StayArea(super.slug, super.name, this.image);

  final ContentImage? image;

  static StayArea? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final slug = _str(json['slug']);
    final name = _str(json['name']);
    if (slug == null || name == null) return null;
    return StayArea(slug, name, ContentImage.fromJson(json['image']));
  }
}

class StaySummary {
  const StaySummary({
    required this.id,
    required this.name,
    required this.stayType,
    this.area,
    this.amenities = const [],
    this.image,
    this.priceFrom,
    this.priceUnit = '',
    this.priceStatus = PriceStatus.onRequest,
    this.availabilityVerified = false,
    this.accessible = false,
    this.familyFriendly = false,
    this.seniorFriendly = false,
    this.verified = false,
    this.lastVerified,
    this.distanceKm,
  });

  final String id;
  final String name;
  final String stayType;
  final StayArea? area;
  final List<Named> amenities;
  final ContentImage? image;
  final int? priceFrom;
  final String priceUnit;
  final PriceStatus priceStatus;
  final bool availabilityVerified;
  final bool accessible;
  final bool familyFriendly;
  final bool seniorFriendly;
  final bool verified;
  final DateTime? lastVerified;
  final double? distanceKm;

  static StaySummary? fromJson(Map<String, dynamic> json) {
    final id = _str(json['id']);
    final name = _str(json['name']);
    if (id == null || name == null) return null;
    final price = _int(json['price_from']);
    return StaySummary(
      id: id,
      name: name,
      stayType: _str(json['stay_type']) ?? 'other',
      area: StayArea.fromJson(json['area']),
      amenities: _list(json['amenities'], Named.fromJson),
      image: ContentImage.fromJson(json['image']),
      priceFrom: price != null && price > 0 ? price : null,
      priceUnit: _str(json['price_unit']) ?? '',
      priceStatus: switch (json['price_status']) {
        'verified' => PriceStatus.verified,
        'estimated' => PriceStatus.estimated,
        _ => PriceStatus.onRequest,
      },
      availabilityVerified: json['availability_verified'] == true,
      accessible: json['accessible'] == true,
      familyFriendly: json['family_friendly'] == true,
      seniorFriendly: json['senior_friendly'] == true,
      verified: json['verification_status'] == 'verified',
      lastVerified: _date(json['last_verified_on']),
      distanceKm: _double(json['distance_km']),
    );
  }
}

class StayRoom {
  const StayRoom(this.name, this.price);

  final String name;
  final int? price;

  static StayRoom? fromJson(Map<String, dynamic> json) {
    final name = _str(json['name']);
    return name == null ? null : StayRoom(name, _int(json['price']));
  }
}

class Landmark {
  const Landmark(this.name, this.distanceKm, {this.templeId});

  final String name;
  final double distanceKm;
  final String? templeId;

  static Landmark? fromJson(Map<String, dynamic> json) {
    final name = _str(json['name']);
    final km = _double(json['distance_km']);
    if (name == null || km == null) return null;
    return Landmark(name, km, templeId: _str(json['id']));
  }
}

class StayDetail {
  const StayDetail({
    required this.summary,
    this.address,
    this.latitude,
    this.longitude,
    this.phone,
    this.email,
    this.websiteUrl,
    this.bookingUrl,
    this.provider,
    this.rooms = const [],
    this.images = const [],
    this.sources = const [],
    this.landmarks = const [],
    this.temples = const [],
    this.overview = '',
    this.bookingInstructions = '',
    this.cancellationPolicy = '',
    this.priceNote = '',
    this.contentLanguage,
  });

  final StaySummary summary;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? email;
  final String? websiteUrl;
  final String? bookingUrl;
  final String? provider;
  final List<StayRoom> rooms;
  final List<ContentImage> images;
  final List<ContentSource> sources;
  final List<Landmark> landmarks;
  final List<Landmark> temples;
  final String overview;
  final String bookingInstructions;
  final String cancellationPolicy;
  final String priceNote;
  final String? contentLanguage;

  static StayDetail? fromJson(Map<String, dynamic> json) {
    final summary = StaySummary.fromJson(json);
    if (summary == null) return null;
    final text =
        json['text'] is Map<String, dynamic>
            ? json['text'] as Map<String, dynamic>
            : const <String, dynamic>{};
    return StayDetail(
      summary: summary,
      address: _str(json['address']),
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
      phone: _str(json['phone']),
      email: _str(json['email']),
      websiteUrl: _https(json['website_url']),
      bookingUrl: _https(json['booking_url']),
      provider: _str(json['provider']),
      rooms: _list(json['rooms'], StayRoom.fromJson),
      images: _list(json['images'], ContentImage.fromJson),
      sources: _list(json['sources'], ContentSource.fromJson),
      landmarks: _list(json['landmarks'], Landmark.fromJson),
      temples: _list(json['temples'], Landmark.fromJson),
      overview: _str(text['overview']) ?? '',
      bookingInstructions: _str(text['booking_instructions']) ?? '',
      cancellationPolicy: _str(text['cancellation_policy']) ?? '',
      priceNote: _str(text['price_note']) ?? '',
      contentLanguage: _str(text['content_language']),
    );
  }
}

class StayFilters {
  const StayFilters({this.areas = const [], this.amenities = const []});

  final List<StayArea> areas;
  final List<Named> amenities;

  factory StayFilters.fromJson(Map<String, dynamic> json) => StayFilters(
    areas: _list(json['areas'], StayArea.fromJson),
    amenities: _list(json['amenities'], Named.fromJson),
  );
}

/// What a pilgrim is looking for. Dates and guests help them plan and carry
/// into the booking note; they aren't an availability check.
class StaySearch {
  StaySearch({
    this.area,
    this.type,
    this.checkIn,
    this.checkOut,
    this.guests = 2,
    this.rooms = 1,
    this.minPrice,
    this.maxPrice,
    Set<String>? amenities,
    this.family = false,
    this.seniors = false,
    this.accessible = false,
    this.availableOnly = false,
    this.sort = 'recommended',
  }) : amenities = amenities ?? {};

  String? area;
  String? type;
  DateTime? checkIn;
  DateTime? checkOut;
  int guests;
  int rooms;
  int? minPrice;
  int? maxPrice;
  Set<String> amenities;
  bool family;
  bool seniors;
  bool accessible;
  bool availableOnly;
  String sort;

  int get activeFilters =>
      (minPrice != null ? 1 : 0) +
      (maxPrice != null ? 1 : 0) +
      amenities.length +
      (family ? 1 : 0) +
      (seniors ? 1 : 0) +
      (accessible ? 1 : 0) +
      (availableOnly ? 1 : 0);

  Map<String, dynamic> toQuery() => {
    if (area != null) 'area': area,
    if (area != null) 'near': area,
    if (type != null) 'type': type,
    if (minPrice != null) 'min_price': '$minPrice',
    if (maxPrice != null) 'max_price': '$maxPrice',
    if (amenities.isNotEmpty) 'amenity': amenities.toList(),
    if (family) 'family': 'true',
    if (seniors) 'seniors': 'true',
    if (accessible) 'accessible': 'true',
    if (availableOnly) 'available': 'true',
    'sort': sort,
  };
}

/// Pre-fills the search from a saved journey.
class JourneyPrefill {
  const JourneyPrefill({
    this.title,
    this.arrival,
    this.departure,
    this.travellers,
    this.origin,
    this.transportMode,
  });

  final String? title;
  final DateTime? arrival;
  final DateTime? departure;
  final int? travellers;
  final String? origin;
  final String? transportMode;
}

class TransportProvider {
  const TransportProvider({
    required this.slug,
    required this.mode,
    required this.name,
    required this.url,
    this.isOfficial = false,
    this.canBook = false,
    this.note = '',
  });

  final String slug;
  final String mode;
  final String name;
  final String url;
  final bool isOfficial;
  final bool canBook;
  final String note;

  static TransportProvider? fromJson(Map<String, dynamic> json) {
    final slug = _str(json['slug']);
    final name = _str(json['name']);
    final url = _https(json['url']);
    if (slug == null || name == null || url == null) return null;
    return TransportProvider(
      slug: slug,
      mode: _str(json['mode']) ?? 'local',
      name: name,
      url: url,
      isOfficial: json['is_official'] == true,
      canBook: json['can_book'] == true,
      note: _str(json['note']) ?? '',
    );
  }
}

/// One option from an authorized provider. None exist yet.
class TransportResult {
  const TransportResult({
    required this.provider,
    this.departs,
    this.arrives,
    this.duration,
    this.price,
    this.availability,
    this.url,
  });

  final String provider;
  final String? departs;
  final String? arrives;
  final String? duration;
  final int? price;
  final String? availability;
  final String? url;

  static TransportResult? fromJson(Map<String, dynamic> json) {
    final provider = _str(json['provider']);
    if (provider == null) return null;
    return TransportResult(
      provider: provider,
      departs: _str(json['departs']),
      arrives: _str(json['arrives']),
      duration: _str(json['duration']),
      price: _int(json['price']),
      availability: _str(json['availability']),
      url: _https(json['url']),
    );
  }
}

class TransportSearchResult {
  const TransportSearchResult({
    this.live = false,
    this.results = const [],
    this.providers = const [],
  });

  final bool live;
  final List<TransportResult> results;
  final List<TransportProvider> providers;

  factory TransportSearchResult.fromJson(Map<String, dynamic> json) =>
      TransportSearchResult(
        live: json['live'] == true,
        results: _list(json['results'], TransportResult.fromJson),
        providers: _list(json['providers'], TransportProvider.fromJson),
      );
}

enum BookingStatus { saved, pending, confirmed, cancelled, completed }

class SavedBooking {
  const SavedBooking({
    required this.id,
    required this.category,
    required this.title,
    this.status = BookingStatus.saved,
    this.provider = '',
    this.reference = '',
    this.startDate,
    this.endDate,
    this.startTime = '',
    this.fromPlace = '',
    this.toPlace = '',
    this.people = 1,
    this.travellerNames = '',
    this.amountPaid,
    this.bookingUrl,
    this.notes = '',
  });

  final String id;
  final String category;
  final String title;
  final BookingStatus status;
  final String provider;
  final String reference;
  final DateTime? startDate;
  final DateTime? endDate;
  final String startTime;
  final String fromPlace;
  final String toPlace;
  final int people;
  final String travellerNames;
  final String? amountPaid;
  final String? bookingUrl;
  final String notes;

  bool get isStay => category == 'stay';

  static SavedBooking? fromJson(Map<String, dynamic> json) {
    final id = _str(json['id']);
    final title = _str(json['title']);
    final category = _str(json['category']);
    if (id == null || title == null || category == null) return null;
    return SavedBooking(
      id: id,
      category: category,
      title: title,
      status: BookingStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => BookingStatus.saved,
      ),
      provider: _str(json['provider']) ?? '',
      reference: _str(json['reference']) ?? '',
      startDate: _date(json['start_date']),
      endDate: _date(json['end_date']),
      startTime: _str(json['start_time']) ?? '',
      fromPlace: _str(json['from_place']) ?? '',
      toPlace: _str(json['to_place']) ?? '',
      people: _int(json['people']) ?? 1,
      travellerNames: _str(json['traveller_names']) ?? '',
      amountPaid: _str(json['amount_paid']),
      bookingUrl: _https(json['booking_url']),
      notes: _str(json['notes']) ?? '',
    );
  }
}

/// Pre-fills the booking form from a stay or provider.
class BookingDraft {
  const BookingDraft({
    this.category = 'stay',
    this.title = '',
    this.provider = '',
    this.url,
    this.start,
    this.end,
    this.people,
    this.stayId,
    this.fromPlace = '',
    this.toPlace = '',
  });

  final String category;
  final String title;
  final String provider;
  final String? url;
  final DateTime? start;
  final DateTime? end;
  final int? people;
  final String? stayId;
  final String fromPlace;
  final String toPlace;
}
