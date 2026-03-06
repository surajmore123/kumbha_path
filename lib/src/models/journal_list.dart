import 'package:equatable/equatable.dart';

class JournalEntryListModel extends Equatable {
  final int? count;
  final String? next;
  final String? previous;
  final List<JournalEntryModel> results;

  const JournalEntryListModel({
    this.count,
    this.next,
    this.previous,
    this.results = const [],
  });

  @override
  List<Object?> get props => [count, next, previous, results];

  JournalEntryListModel copyWith({
    int? count,
    String? next,
    String? previous,
    List<JournalEntryModel>? results,
  }) {
    return JournalEntryListModel(
      count: count ?? this.count,
      next: next ?? this.next,
      previous: previous ?? this.previous,
      results: results ?? this.results,
    );
  }

  factory JournalEntryListModel.fromJson(Map<String, dynamic> json) {
    return JournalEntryListModel(
      count: json['count'] ?? 0,
      next: json['next'],
      previous: json['previous'],
      results:
          (json['results'] as List<dynamic>?)
              ?.map((e) => JournalEntryModel.fromJson(e))
              .toList() ??
          [],
    );
  }

  static const empty = JournalEntryListModel(
    count: 0,
    next: null,
    previous: null,
    results: [],
  );

  @override
  String toString() => '{count:$count, next:$next, results:${results.length}}';
}

class JournalEntryModel extends Equatable {
  final int? id;
  final String? title;
  final String? notes;
  final String? aiPrompt;
  final String? aiReflection;
  final String? mood;
  final String? photo;
  final String? createdAt;

  const JournalEntryModel({
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

  JournalEntryModel copyWith({
    int? id,
    String? title,
    String? notes,
    String? aiPrompt,
    String? aiReflection,
    String? mood,
    String? photo,
    String? createdAt,
  }) {
    return JournalEntryModel(
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

  factory JournalEntryModel.fromJson(Map<String, dynamic> json) {
    return JournalEntryModel(
      id: json['id'],
      title: json['title'] ?? "",
      notes: json['notes'] ?? "",
      aiPrompt: json['ai_prompt'],
      aiReflection: json['ai_reflection'] ?? "",
      mood: json['mood'] ?? "",
      photo: json['photo'], // can be null
      createdAt: json['created_at'] ?? "",
    );
  }

  static const empty = JournalEntryModel(
    id: 0,
    title: "",
    notes: "",
    aiPrompt: '',
    aiReflection: "",
    mood: "",
    photo: null,
    createdAt: "",
  );

  @override
  String toString() =>
      '{id:$id, title:$title, mood:$mood, createdAt:$createdAt}';
}
