import 'package:equatable/equatable.dart';

class NearbyTemplesModel extends Equatable {
  final double? radiusKm;
  final int? count;
  final List<TempleModel>? temples;
  final bool? hasMore;
  final String? nextCursor;

  const NearbyTemplesModel({
    this.radiusKm,
    this.count,
    this.temples,
    this.hasMore,
    this.nextCursor,
  });

  @override
  List<Object?> get props => [
        radiusKm,
        count,
        temples,
        hasMore,
        nextCursor,
      ];

  NearbyTemplesModel copyWith({
    double? radiusKm,
    int? count,
    List<TempleModel>? temples,
    bool? hasMore,
    String? nextCursor,
  }) {
    return NearbyTemplesModel(
      radiusKm: radiusKm ?? this.radiusKm,
      count: count ?? this.count,
      temples: temples ?? this.temples,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
    );
  }

  factory NearbyTemplesModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;

    return NearbyTemplesModel(
      radiusKm: (data['radius_km'] as num?)?.toDouble(),
      count: data['count'] ?? 0,
      temples: (data['temples'] as List<dynamic>?)
              ?.map((e) => TempleModel.fromJson(e))
              .toList() ??
          [],
      hasMore: data['has_more'] ?? false,
      nextCursor: data['next_cursor'],
    );
  }

  static const empty = NearbyTemplesModel(
    radiusKm: 0,
    count: 0,
    temples: [],
    hasMore: false,
    nextCursor: null,
  );

  @override
  String toString() =>
      '{radiusKm: $radiusKm, count: $count, temples: $temples, hasMore: $hasMore, nextCursor: $nextCursor}';
}




class TempleModel extends Equatable {
  final String? templeId;
  final String? name;
  final String? description;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final String? city;
  final String? crowdLevel;
  final String? crowdMessage;
  final double? distanceKm;

  const TempleModel({
    this.templeId,
    this.name,
    this.description,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.city,
    this.crowdLevel,
    this.crowdMessage,
    this.distanceKm,
  });

  @override
  List<Object?> get props => [
        templeId,
        name,
        description,
        latitude,
        longitude,
        imageUrl,
        city,
        crowdLevel,
        crowdMessage,
        distanceKm,
      ];

  TempleModel copyWith({
    String? templeId,
    String? name,
    String? description,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? city,
    String? crowdLevel,
    String? crowdMessage,
    double? distanceKm,
  }) {
    return TempleModel(
      templeId: templeId ?? this.templeId,
      name: name ?? this.name,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      city: city ?? this.city,
      crowdLevel: crowdLevel ?? this.crowdLevel,
      crowdMessage: crowdMessage ?? this.crowdMessage,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  factory TempleModel.fromJson(Map<String, dynamic> json) {
    return TempleModel(
      templeId: json['temple_id'],
      name: json['name'],
      description: json['description'],
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      imageUrl: json['image_url'],
      city: json['city'],
      crowdLevel: json['crowd_level'],
      crowdMessage: json['crowd_message'],
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() =>
      '{templeId: $templeId, name: $name, city: $city, distanceKm: $distanceKm}';
}
