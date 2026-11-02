import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/emergency/widgets/sos_parts.dart'
    show askForText;
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show showJourneySnack;
import 'package:kumbha_path/src/modules/lostfound/data/lf_repository.dart';
import 'package:kumbha_path/src/modules/lostfound/models/lf_ai_models.dart';

const _languages = ['en', 'hi', 'mr'];
const _fieldOrder = [
  'category',
  'approx_age',
  'clothing',
  'belongings',
  'last_known_location',
];

class CaseAiField {
  const CaseAiField(this.ref, this.label, this.text);

  final String ref;
  final String label;
  final String text;
}

String _shownValue(String name, Object? value) => switch (name) {
  'category' => 'lf_ai_category_$value'.tr(),
  _ when value is List => value.join(', '),
  _ => '$value',
};

/// Optional help for reading a case. The originals stay on the screen above it,
/// so losing this panel never costs anyone anything: a failure is one quiet line.
class CaseAiPanel extends StatefulWidget {
  const CaseAiPanel({
    super.key,
    required this.caseId,
    required this.fields,
    required this.repository,
    this.canReview = false,
  });

  final String caseId;
  final List<CaseAiField> fields;
  final LostFoundRepository repository;

  /// Whether this person may extract details and review results. The server
  /// checks this again on every call.
  final bool canReview;

  @override
  State<CaseAiPanel> createState() => _CaseAiPanelState();
}

class _CaseAiPanelState extends State<CaseAiPanel> {
  CaseAi? _ai;
  bool _failed = false;
  bool _busy = false;
  String? _language;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final code = context.locale.languageCode;
    _language ??= _languages.contains(code) ? code : 'en';
  }

  Future<void> _load() async {
    try {
      final ai = await widget.repository.caseAi(widget.caseId);
      if (mounted) setState(() => (_ai = ai, _failed = false));
    } on FamilyException {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } on FamilyException {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _translateAll() => _run(() async {
    for (final field in widget.fields.where((f) => f.text.trim().isNotEmpty)) {
      await widget.repository.translateCase(
        widget.caseId,
        field.ref,
        _language!,
      );
    }
  });

  Future<void> _correct(CaseTranslation row) async {
    final text = await askForText(
      context,
      title: 'lf_ai_correct'.tr(),
      hint: 'lf_ai_correct_label'.tr(),
      confirm: 'lf_ai_save'.tr(),
      initial: row.text,
    );
    if (text == null || text.trim().isEmpty) return;
    await _run(() => widget.repository.reviewTranslation(row.id, text));
  }

  Future<void> _reviewDetails({required bool accept}) async {
    await _run(() => widget.repository.reviewExtraction(widget.caseId, accept));
    if (mounted) {
      showJourneySnack(
        context,
        (accept ? 'lf_ai_accepted' : 'lf_ai_rejected').tr(),
      );
    }
  }

  Future<void> _correctDetail(String name, Object? value) async {
    final isList = value is List;
    final text = await askForText(
      context,
      title: 'lf_ai_field_$name'.tr(),
      hint: 'lf_ai_correct_label'.tr(),
      confirm: 'lf_ai_save'.tr(),
      initial: isList ? value.join(', ') : '${value ?? ''}',
    );
    if (text == null) return;
    final trimmed = text.trim();
    if (name == 'approx_age' && int.tryParse(trimmed) == null) return;
    final Object? corrected = switch (name) {
      'approx_age' => int.tryParse(trimmed),
      _ when isList =>
        trimmed
            .split(',')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList(),
      _ => trimmed,
    };
    await _run(
      () => widget.repository.reviewExtraction(
        widget.caseId,
        true,
        corrections: {name: corrected},
      ),
    );
  }

  Widget _tag(String label, {bool warn = false}) {
    final semantic = context.semanticColors;
    return Text(
      label,
      style: context.editorial.meta.copyWith(
        color: warn ? semantic.warning : null,
      ),
    );
  }

  Widget _translation(CaseAiField field, CaseTranslation row) {
    final tag =
        row.review == 'corrected'
            ? 'lf_ai_corrected'.tr()
            : row.review == 'accepted'
            ? 'lf_ai_reviewed'.tr()
            : 'lf_ai_translated'.tr();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.label, style: context.editorial.meta),
          AppSpacing.gapXs,
          Text(row.text),
          AppSpacing.gapXs,
          _tag(tag),
          if (row.isUncertain) _tag('lf_ai_uncertain'.tr(), warn: true),
          if (row.isStale) _tag('lf_ai_stale'.tr(), warn: true),
          if (widget.canReview)
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => _correct(row),
                  child: Text('lf_ai_correct'.tr()),
                ),
                if (row.review == 'ai')
                  TextButton(
                    onPressed:
                        _busy
                            ? null
                            : () => _run(
                              () => widget.repository.reviewTranslation(
                                row.id,
                                '',
                              ),
                            ),
                    child: Text('lf_ai_accept'.tr()),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _details(CaseExtraction extraction) {
    final shown = extraction.shown;
    final rows = [
      for (final name in _fieldOrder)
        if (shown[name] != null) name,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('lf_ai_details'.tr(), style: context.editorial.headline),
        AppSpacing.gapXs,
        _tag(
          switch (extraction.review) {
            'accepted' => 'lf_ai_details_accepted'.tr(),
            'rejected' => 'lf_ai_details_rejected'.tr(),
            _ => 'lf_ai_details_generated'.tr(),
          },
        ),
        AppSpacing.gapSm,
        if (extraction.review != 'rejected')
          for (final name in rows)
            FactRow(
              label: 'lf_ai_field_$name'.tr(),
              value: _shownValue(name, shown[name]),
              trailing: IconButton(
                tooltip: 'lf_ai_correct'.tr(),
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed:
                    _busy || name == 'category'
                        ? null
                        : () => _correctDetail(name, shown[name]),
              ),
            ),
        if (extraction.missing.isNotEmpty)
          Text(
            'lf_ai_not_stated'.tr(
              args: [
                extraction.missing
                    .map((name) => 'lf_ai_field_$name'.tr())
                    .join(', '),
              ],
            ),
            style: context.editorial.meta,
          ),
        AppSpacing.gapSm,
        if (extraction.review == 'ai') ...[
          AppButton(
            label: 'lf_ai_accept_details'.tr(),
            isLoading: _busy,
            onPressed: _busy ? null : () => _reviewDetails(accept: true),
          ),
          AppSpacing.gapSm,
          AppButton.secondary(
            label: 'lf_ai_reject_details'.tr(),
            onPressed: _busy ? null : () => _reviewDetails(accept: false),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ai = _ai;
    if (ai == null && !_failed) return const SizedBox.shrink();
    final retry = TextButton(
      onPressed:
          _busy
              ? null
              : () {
                setState(() => _failed = false);
                _load();
              },
      child: Text('lf_ai_try_again'.tr()),
    );
    if (ai == null || !ai.available) {
      return FamilyNote(
        text: 'lf_ai_unavailable'.tr(),
        trailing: [if (ai == null) retry],
      );
    }

    final rows = {
      for (final row in ai.translations.where(
        (row) => row.targetLanguage == _language,
      ))
        row.sourceRef: row,
    };
    final extraction = ai.extraction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('lf_ai_title'.tr(), style: context.editorial.headline),
        AppSpacing.gapXs,
        Text('lf_ai_note'.tr(), style: context.editorial.meta),
        if (_failed) ...[
          AppSpacing.gapSm,
          FamilyNote(text: 'lf_ai_unavailable'.tr(), trailing: [retry]),
        ],
        AppSpacing.gapSm,
        PillChoices(
          values: _languages,
          labelOf: (code) => 'lf_ai_language_$code'.tr(),
          selected: _language,
          onChanged: (code) => setState(() => _language = code),
        ),
        AppSpacing.gapSm,
        for (final field in widget.fields)
          if (rows[field.ref] != null) _translation(field, rows[field.ref]!),
        AppButton.secondary(
          label: 'lf_ai_translate'.tr(),
          onPressed: _busy ? null : _translateAll,
        ),
        if (widget.canReview) ...[
          AppSpacing.gapLg,
          if (extraction != null)
            _details(extraction)
          else
            AppButton.secondary(
              label: 'lf_ai_extract'.tr(),
              onPressed:
                  _busy
                      ? null
                      : () => _run(
                        () => widget.repository.extractCase(widget.caseId),
                      ),
            ),
        ],
      ],
    );
  }
}
