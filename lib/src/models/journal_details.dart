import 'package:equatable/equatable.dart';

class JournalDetailsModel extends Equatable {
  final String? id;
  final String? title;
  final String? notes;
   final String? aiPrompt;
  final String? aiReflection;
  final String? mood;
  final String? photo;
  final String? createdAt;

  const JournalDetailsModel({
    this.id,
    this.title,
    this.notes,
    this.aiPrompt,
    this.aiReflection,
    this.mood,
    this.photo,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        notes,
        aiPrompt,
        aiReflection,
        mood,
        photo,
        createdAt,
      ];

  JournalDetailsModel copyWith({
    String? id,
    String? title,
    String? notes,
    String? aiPrompt,
    String? aiReflection,
    String? mood,
    String? photo,
    String? createdAt,
  }) {
    return JournalDetailsModel(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      aiPrompt: aiPrompt?? this.aiPrompt,
      aiReflection: aiReflection ?? this.aiReflection,
      mood: mood ?? this.mood,
      photo: photo ?? this.photo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory JournalDetailsModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;

    return JournalDetailsModel(
      id: data['id']?.toString() ?? "",
      title: data['title'] ?? "",
      notes: data['notes'] ?? "",
      aiPrompt: data['ai_prompt']??"",
      aiReflection: data['ai_reflection'] ?? "",
      mood: data['mood'] ?? "",
      photo: data['photo'] ?? "",
      createdAt: data['created_at'] ?? "",
    );
  }

  static const empty = JournalDetailsModel(
    id: "",
    title: "",
    notes: "",
    aiPrompt: "",
    aiReflection: "",
    mood: "",
    photo: "",
    createdAt: "",
  );

  @override
  String toString() =>
      '{id:$id, title:$title, mood:$mood, createdAt:$createdAt}';
}