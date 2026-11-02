List<Map<String, dynamic>> _maps(Object? value) =>
    (value as List? ?? const []).cast<Map<String, dynamic>>();

List<String> _strings(Object? value) =>
    (value as List? ?? const []).whereType<String>().toList();

/// A machine translation, shown beside the original and never instead of it.
class CaseTranslation {
  const CaseTranslation({
    required this.id,
    required this.sourceRef,
    required this.sourceText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.text,
    required this.review,
    this.isUncertain = false,
    this.isStale = false,
  });

  factory CaseTranslation.fromJson(Map<String, dynamic> json) =>
      CaseTranslation(
        id: json['id'] as String,
        sourceRef: json['source_ref'] as String? ?? '',
        sourceText: json['source_text'] as String? ?? '',
        sourceLanguage: json['source_language'] as String? ?? 'unknown',
        targetLanguage: json['target_language'] as String? ?? '',
        text: json['text'] as String? ?? '',
        review: json['review'] as String? ?? 'ai',
        isUncertain: json['is_uncertain'] as bool? ?? false,
        isStale: json['is_stale'] as bool? ?? false,
      );

  final String id;
  final String sourceRef;
  final String sourceText;
  final String sourceLanguage;
  final String targetLanguage;
  final String text;

  /// `ai`, `accepted` or `corrected`.
  final String review;
  final bool isUncertain;
  final bool isStale;
}

/// Details read out of a report. They aren't on the case: the matcher uses them
/// only after a person accepts them.
class CaseExtraction {
  const CaseExtraction({
    required this.review,
    this.machine = const {},
    this.reviewed = const {},
    this.missing = const [],
  });

  factory CaseExtraction.fromJson(Map<String, dynamic> json) => CaseExtraction(
    review: json['review'] as String? ?? 'ai',
    machine: (json['machine_fields'] as Map<String, dynamic>? ?? const {}).map(
      (name, entry) =>
          MapEntry(name, (entry as Map<String, dynamic>)['value'] as Object),
    ),
    reviewed: json['reviewed_fields'] as Map<String, dynamic>? ?? const {},
    missing: _strings(json['missing']),
  );

  /// `ai`, `accepted` or `rejected`.
  final String review;
  final Map<String, Object> machine;
  final Map<String, dynamic> reviewed;
  final List<String> missing;

  Map<String, dynamic> get shown => review == 'accepted' ? reviewed : machine;
}

class CaseAi {
  const CaseAi({
    this.available = false,
    this.translations = const [],
    this.extraction,
  });

  factory CaseAi.fromJson(Map<String, dynamic> json) => CaseAi(
    available: json['available'] as bool? ?? false,
    translations:
        _maps(json['translations']).map(CaseTranslation.fromJson).toList(),
    extraction:
        json['extraction'] == null
            ? null
            : CaseExtraction.fromJson(
              json['extraction'] as Map<String, dynamic>,
            ),
  );

  final bool available;
  final List<CaseTranslation> translations;
  final CaseExtraction? extraction;
}

/// Why a pair was suggested. A confidence level orders staff's review and says
/// nothing about who anyone is.
class MatchExplanation {
  const MatchExplanation({
    this.confidence = 'low',
    this.matching = const [],
    this.conflicting = const [],
    this.missing = const [],
    this.usesReviewedAi = false,
  });

  factory MatchExplanation.fromJson(Map<String, dynamic>? json) =>
      json == null
          ? const MatchExplanation()
          : MatchExplanation(
            confidence: json['confidence'] as String? ?? 'low',
            matching: _strings(json['matching']),
            conflicting: _strings(json['conflicting']),
            missing: _strings(json['missing']),
            usesReviewedAi: json['uses_reviewed_ai'] as bool? ?? false,
          );

  final String confidence;
  final List<String> matching;
  final List<String> conflicting;
  final List<String> missing;
  final bool usesReviewedAi;
}
