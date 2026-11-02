import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbha_path/src/modules/lostfound/data/lf_repository.dart';
import 'package:kumbha_path/src/modules/lostfound/models/lf_models.dart';
import 'package:kumbha_path/src/modules/lostfound/widgets/case_ai_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_test.dart' as t;

const unavailable = FamilyException(FamilyFailure.server);

class FakeAi implements LostFoundRepository {
  FakeAi(this.ai);

  CaseAi ai;
  Object? failure;
  Object? actionFailure;
  final calls = <String>[];

  @override
  Future<CaseAi> caseAi(String id) async {
    if (failure != null) throw failure!;
    return ai;
  }

  void _act(String name) {
    calls.add(name);
    if (actionFailure != null) throw actionFailure!;
  }

  @override
  Future<void> translateCase(String id, String field, String language) async =>
      _act('translate:$field:$language');

  @override
  Future<void> reviewTranslation(String translationId, String text) async =>
      _act('review:$text');

  @override
  Future<void> extractCase(String id) async => _act('extract');

  @override
  Future<void> reviewExtraction(
    String id,
    bool accept, {
    Map<String, Object?> corrections = const {},
  }) async => _act('details:$accept:$corrections');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CaseTranslation row({
  String review = 'ai',
  bool uncertain = false,
  bool stale = false,
}) => CaseTranslation(
  id: 't1',
  sourceRef: 'clothing_description',
  sourceText: 'blue shirt',
  sourceLanguage: 'en',
  targetLanguage: 'en',
  text: 'Translated blue shirt',
  review: review,
  isUncertain: uncertain,
  isStale: stale,
);

const details = CaseExtraction(
  review: 'ai',
  machine: {
    'approx_age': 8,
    'clothing': ['blue shirt', 'black shorts'],
  },
  missing: ['belongings'],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> show(
    WidgetTester tester,
    FakeAi repo, {
    bool canReview = true,
  }) async {
    await t.pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: CaseAiPanel(
            caseId: 'c1',
            repository: repo,
            canReview: canReview,
            fields: const [
              CaseAiField('clothing_description', 'Clothing', 'blue shirt'),
              CaseAiField('identifying_marks', 'Marks', ''),
            ],
          ),
        ),
      ),
    );
    await t.settle(tester);
  }

  testWidgets('says plainly when AI is off, and blocks nothing', (
    tester,
  ) async {
    await show(tester, FakeAi(const CaseAi()));
    expect(find.text('lf_ai_unavailable'.tr()), findsOneWidget);
    expect(find.text('lf_ai_translate'.tr()), findsNothing);
    expect(find.text('lf_ai_try_again'.tr()), findsNothing);
  });

  testWidgets('a failed load offers a retry that works', (tester) async {
    final repo = FakeAi(const CaseAi(available: true))..failure = unavailable;
    await show(tester, repo);
    expect(find.text('lf_ai_unavailable'.tr()), findsOneWidget);

    repo.failure = null;
    await tester.tap(find.text('lf_ai_try_again'.tr()));
    await t.settle(tester);
    expect(find.text('lf_ai_translate'.tr()), findsOneWidget);
  });

  testWidgets('a failed translation stays quiet and leaves the panel usable', (
    tester,
  ) async {
    final repo = FakeAi(const CaseAi(available: true))
      ..actionFailure = unavailable;
    await show(tester, repo);
    await tester.tap(find.text('lf_ai_translate'.tr()));
    await t.settle(tester);
    expect(find.text('lf_ai_unavailable'.tr()), findsOneWidget);
    expect(find.text('lf_ai_translate'.tr()), findsOneWidget);
  });

  testWidgets('translates only fields with text, in the chosen language', (
    tester,
  ) async {
    final repo = FakeAi(const CaseAi(available: true));
    await show(tester, repo);
    await tester.tap(find.text('मराठी'));
    await t.settle(tester);
    await tester.tap(find.text('lf_ai_translate'.tr()));
    await t.settle(tester);
    expect(repo.calls, ['translate:clothing_description:mr']);
  });

  testWidgets('marks AI text, and warns when it may be wrong', (tester) async {
    final repo = FakeAi(
      CaseAi(available: true, translations: [row(uncertain: true, stale: true)]),
    );
    await show(tester, repo);
    expect(find.text('Translated blue shirt'), findsOneWidget);
    expect(find.text('lf_ai_translated'.tr()), findsOneWidget);
    expect(find.text('lf_ai_uncertain'.tr()), findsOneWidget);
    expect(find.text('lf_ai_stale'.tr()), findsOneWidget);
  });

  testWidgets('a person can check or correct a translation', (tester) async {
    final repo = FakeAi(CaseAi(available: true, translations: [row()]));
    await show(tester, repo);
    await tester.tap(find.text('lf_ai_accept'.tr()));
    await t.settle(tester);
    expect(repo.calls, ['review:']);

    await tester.tap(find.text('lf_ai_correct'.tr()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Better text');
    await tester.tap(find.text('lf_ai_save'.tr()));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'review:Better text');
  });

  testWidgets('a corrected translation says a person wrote it', (tester) async {
    await show(
      tester,
      FakeAi(CaseAi(available: true, translations: [row(review: 'corrected')])),
    );
    expect(find.text('lf_ai_corrected'.tr()), findsOneWidget);
    expect(find.text('lf_ai_translated'.tr()), findsNothing);
    expect(find.text('lf_ai_accept'.tr()), findsNothing);
  });

  testWidgets('a volunteer can read but not review or extract', (tester) async {
    final repo = FakeAi(CaseAi(available: true, translations: [row()]));
    await show(tester, repo, canReview: false);
    expect(find.text('Translated blue shirt'), findsOneWidget);
    expect(find.text('lf_ai_translate'.tr()), findsOneWidget);
    expect(find.text('lf_ai_correct'.tr()), findsNothing);
    expect(find.text('lf_ai_accept'.tr()), findsNothing);
    expect(find.text('lf_ai_extract'.tr()), findsNothing);
  });

  testWidgets('extracted details are marked and need accepting', (
    tester,
  ) async {
    final repo = FakeAi(const CaseAi(available: true, extraction: details));
    await show(tester, repo);
    expect(find.text('lf_ai_details_generated'.tr()), findsOneWidget);
    expect(find.text('blue shirt, black shorts'), findsOneWidget);
    expect(find.textContaining('lf_ai_field_belongings'.tr()), findsOneWidget);

    await tester.ensureVisible(find.text('lf_ai_accept_details'.tr()));
    await tester.tap(find.text('lf_ai_accept_details'.tr()));
    await t.settle(tester);
    expect(repo.calls, ['details:true:{}']);
  });

  testWidgets('a person can correct a detail, and bad ages are ignored', (
    tester,
  ) async {
    final repo = FakeAi(const CaseAi(available: true, extraction: details));
    await show(tester, repo);
    final edit = find.byIcon(Icons.edit_outlined).first;

    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'nine');
    await tester.tap(find.text('lf_ai_save'.tr()));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);

    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '9');
    await tester.tap(find.text('lf_ai_save'.tr()));
    await tester.pumpAndSettle();
    expect(repo.calls, ['details:true:{approx_age: 9}']);
  });

  testWidgets('rejected details are no longer shown', (tester) async {
    await show(
      tester,
      FakeAi(
        const CaseAi(
          available: true,
          extraction: CaseExtraction(
            review: 'rejected',
            machine: {'approx_age': 8},
          ),
        ),
      ),
    );
    expect(find.text('lf_ai_details_rejected'.tr()), findsOneWidget);
    expect(find.text('8'), findsNothing);
  });

  test('explanations read safely from the server', () {
    const empty = MatchExplanation();
    expect(MatchExplanation.fromJson(null).confidence, empty.confidence);
    final full = MatchExplanation.fromJson({
      'confidence': 'medium',
      'matching': ['age'],
      'conflicting': ['time'],
      'missing': ['location'],
      'uses_reviewed_ai': true,
    });
    expect(full.conflicting, ['time']);
    expect(full.usesReviewedAi, isTrue);
  });
}
