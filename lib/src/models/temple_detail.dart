import 'package:equatable/equatable.dart';

class TempleDetailsModel extends Equatable {
  final String? templeId;
  final String? name;
  final String? description;
  final String? latitude;
  final String? longitude;
  final String? imageUrl;
  final String? city;
  final String? state;
  final String? crowdLevel;
  final String? crowdMessage;
  final String? createdAt;

  const TempleDetailsModel({
    this.templeId,
    this.name,
    this.description,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.city,
    this.state,
    this.crowdLevel,
    this.crowdMessage,
    this.createdAt,
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
        state,
        crowdLevel,
        crowdMessage,
        createdAt,
      ];

  TempleDetailsModel copyWith({
    String? templeId,
    String? name,
    String? description,
    String? latitude,
    String? longitude,
    String? imageUrl,
    String? city,
    String? state,
    String? crowdLevel,
    String? crowdMessage,
    String? createdAt,
  }) {
    return TempleDetailsModel(
      templeId: templeId ?? this.templeId,
      name: name ?? this.name,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      city: city ?? this.city,
      state: state ?? this.state,
      crowdLevel: crowdLevel ?? this.crowdLevel,
      crowdMessage: crowdMessage ?? this.crowdMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory TempleDetailsModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;

    return TempleDetailsModel(
      templeId: data['temple_id'] ?? "",
      name: data['name'] ?? "",
      description: data['description'] ?? "",
      latitude: data['latitude']?.toString() ?? "",
      longitude: data['longitude']?.toString() ?? "",
      imageUrl: data['image_url'] ?? "",
      city: data['city'] ?? "",
      state: data['state'] ?? "",
      crowdLevel: data['crowd_level'] ?? "",
      crowdMessage: data['crowd_message'] ?? "",
      createdAt: data['created_at'] ?? "",
    );
  }

  static const empty = TempleDetailsModel(
    templeId: "",
    name: "",
    description: "",
    latitude: "",
    longitude: "",
    imageUrl: "",
    city: "",
    state: "",
    crowdLevel: "",
    crowdMessage: "",
    createdAt: "",
  );

  @override
  String toString() =>
      '{templeId:$templeId, name:$name, city:$city, state:$state, crowdLevel:$crowdLevel, createdAt:$createdAt}';
}
