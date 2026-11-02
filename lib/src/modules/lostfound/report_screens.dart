import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart'
    show FamilyRepository, FamilyServices;
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show showJourneySnack;
import 'package:kumbha_path/src/modules/lostfound/data/lf_drafts.dart';
import 'package:kumbha_path/src/modules/lostfound/models/lf_models.dart';
import 'package:kumbha_path/src/modules/lostfound/widgets/lf_parts.dart';

typedef PositionReader = Future<(double, double)?> Function();

/// The shared part of both report flows: the draft, saved as it's written.
abstract class _ReportState<T extends StatefulWidget> extends State<T> {
  final ReportSender sender = LostFoundDrafts.sender;
  final person = TextEditingController();
  final ageLow = TextEditingController();
  final ageHigh = TextEditingController();
  final physical = TextEditingController();
  final clothing = TextEditingController();
  final marks = TextEditingController();
  final place = TextEditingController();
  ReportDraft? draft;
  Uint8List? photo;
  DateTime? when;
  double? latitude;
  double? longitude;
  List<String> vulnerabilities = const [];
  int step = 0;
  bool busy = false;
  String? problem;

  String get kind;
  String? get draftId;
  PositionReader get position;
  PhotoPicker get photoPicker;

  Map<String, dynamic> extraFields();
  void readExtra(Map<String, dynamic> fields);

  @override
  void initState() {
    super.initState();
    _openDraft();
  }

  Future<void> _openDraft() async {
    try {
      final id = draftId;
      final existing = id == null ? null : await sender.draft(id);
      final opened = existing ?? await sender.newDraft(kind);
      if (!mounted) return;
      final f = opened.fields;
      setState(() {
        draft = opened;
        photo = opened.photo;
        person.text = f['person_name'] as String? ?? '';
        ageLow.text = f['age_min']?.toString() ?? '';
        ageHigh.text = f['age_max']?.toString() ?? '';
        physical.text = f['physical_description'] as String? ?? '';
        clothing.text = f['clothing_description'] as String? ?? '';
        marks.text = f['identifying_marks'] as String? ?? '';
        place.text = f['location_text'] as String? ?? '';
        when = DateTime.tryParse(f['event_at'] as String? ?? '')?.toLocal();
        latitude = (f['latitude'] as num?)?.toDouble();
        longitude = (f['longitude'] as num?)?.toDouble();
        vulnerabilities = [
          for (final v in f['vulnerabilities'] as List? ?? const []) '$v',
        ];
        readExtra(f);
      });
    } catch (e) {
      if (mounted) showJourneySnack(context, lfErrorText(e));
    }
  }

  @override
  void dispose() {
    for (final c in [
      person,
      ageLow,
      ageHigh,
      physical,
      clothing,
      marks,
      place,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> fields() {
    final at = when;
    return {
      'person_name': person.text.trim(),
      if (int.tryParse(ageLow.text) != null) 'age_min': int.parse(ageLow.text),
      if (int.tryParse(ageHigh.text) != null)
        'age_max': int.parse(ageHigh.text),
      'physical_description': physical.text.trim(),
      'clothing_description': clothing.text.trim(),
      'identifying_marks': marks.text.trim(),
      'location_text': place.text.trim(),
      if (at != null) 'event_at': at.toUtc().toIso8601String(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'vulnerabilities': vulnerabilities,
      ...extraFields(),
    };
  }

  /// Everything goes to the encrypted store at each step, so a dropped signal
  /// or a closed app loses nothing.
  Future<void> saveDraft() async {
    final current = draft;
    if (current == null) return;
    final updated = current.copyWith(
      fields: fields(),
      photo: photo,
      clearPhoto: photo == null,
      state: DraftState.editing,
    );
    draft = updated;
    await sender.save(updated);
  }

  Future<void> goTo(int next) async {
    await saveDraft();
    if (mounted) {
      setState(() {
        step = next;
        problem = null;
      });
    }
  }

  Future<void> useGps() async {
    final found = await position();
    if (!mounted) return;
    if (found == null) {
      showJourneySnack(context, 'lf_gps_failed'.tr());
      return;
    }
    setState(() {
      latitude = found.$1;
      longitude = found.$2;
    });
  }

  Future<void> addPhoto() async {
    final bytes = await photoPicker();
    if (bytes != null && mounted) setState(() => photo = bytes);
  }

  Future<void> submit() async {
    final current = draft;
    if (current == null) return;
    setState(() => busy = true);
    await saveDraft();
    final result = await sender.submit(draft!);
    if (!mounted) return;
    setState(() => busy = false);
    final refused = result.refused;
    if (refused != null) {
      showJourneySnack(context, lfErrorText(refused));
      return;
    }
    await Navigator.pushReplacementNamed(
      context,
      '/lostFoundDone',
      arguments: result,
    );
  }

  bool hasDescription() =>
      physical.text.trim().isNotEmpty || clothing.text.trim().isNotEmpty;

  Widget ageRow() => Row(
    children: [
      Expanded(
        child: AppTextField(
          controller: ageLow,
          label: 'lf_age_from'.tr(),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
        ),
      ),
      AppSpacing.gapMd,
      Expanded(
        child: AppTextField(
          controller: ageHigh,
          label: 'lf_age_to'.tr(),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
        ),
      ),
    ],
  );

  List<Widget> descriptionFields() => [
    AppTextField(
      controller: physical,
      label: 'lf_field_physical'.tr(),
      helperText: 'lf_field_physical_hint'.tr(),
      maxLength: 1000,
      maxLines: 3,
    ),
    AppSpacing.gapMd,
    AppTextField(
      controller: clothing,
      label: 'lf_field_clothing'.tr(),
      helperText: 'lf_field_clothing_hint'.tr(),
      maxLength: 1000,
      maxLines: 3,
    ),
    AppSpacing.gapMd,
    AppTextField(
      controller: marks,
      label: 'lf_field_marks'.tr(),
      maxLength: 500,
      maxLines: 2,
    ),
    AppSpacing.gapMd,
    Row(
      children: [
        if (photo != null) ...[
          ClipRRect(
            borderRadius: AppRadius.mdAll,
            child: Image.memory(
              photo!,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(width: 64),
            ),
          ),
          AppSpacing.gapMd,
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: addPhoto,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text('lf_add_photo'.tr()),
              ),
              Text('lf_photo_private'.tr(), style: context.editorial.meta),
            ],
          ),
        ),
      ],
    ),
  ];

  List<Widget> placeFields(String whenLabel, String placeLabel) => [
    WhenField(
      label: whenLabel,
      value: when,
      onChanged: (v) => setState(() => when = v),
    ),
    AppSpacing.gapMd,
    AppTextField(
      controller: place,
      label: placeLabel,
      helperText: 'lf_field_place_hint'.tr(),
      maxLength: 240,
    ),
    AppSpacing.gapSm,
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        onPressed: useGps,
        icon: Icon(
          latitude == null ? Icons.my_location_rounded : Icons.check_rounded,
          size: 18,
        ),
        label: Text(latitude == null ? 'lf_add_gps'.tr() : 'lf_gps_added'.tr()),
      ),
    ),
    Text('lf_gps_note'.tr(), style: context.editorial.meta),
  ];
}

/// `/lostFoundReport`: step by step, because this may be filled in by someone
/// frightened, on a poor connection. Argument: a draft id to continue.
class ReportLostScreen extends StatefulWidget {
  const ReportLostScreen({
    super.key,
    this.draftId,
    this.families,
    this.position = readPosition,
    this.photoPicker = pickCasePhoto,
  });

  final String? draftId;
  final FamilyRepository? families;
  final PositionReader position;
  final PhotoPicker photoPicker;

  @override
  State<ReportLostScreen> createState() => _ReportLostScreenState();
}

class _ReportLostScreenState extends _ReportState<ReportLostScreen> {
  final _relationship = TextEditingController();
  final _circumstances = TextEditingController();
  String _contact = 'app';
  String? _familyId;
  String? _memberId;
  List<(FamilyCircle, FamilyMember)> _people = const [];

  @override
  String get kind => 'lost';
  @override
  String? get draftId => widget.draftId;
  @override
  PositionReader get position => widget.position;
  @override
  PhotoPicker get photoPicker => widget.photoPicker;

  @override
  void initState() {
    super.initState();
    _loadFamily();
  }

  @override
  void dispose() {
    _relationship.dispose();
    _circumstances.dispose();
    super.dispose();
  }

  /// Optional, and offline it's simply not offered.
  Future<void> _loadFamily() async {
    try {
      final repo = widget.families ?? FamilyServices.repository;
      final people = <(FamilyCircle, FamilyMember)>[];
      for (final circle in await repo.circles()) {
        for (final member in await repo.members(circle.id)) {
          if (member.id != circle.myMemberId) people.add((circle, member));
        }
      }
      if (mounted) setState(() => _people = people);
    } catch (_) {
      // Reporting doesn't need a family.
    }
  }

  @override
  Map<String, dynamic> extraFields() => {
    'relationship': _relationship.text.trim(),
    'circumstances': _circumstances.text.trim(),
    'preferred_contact': _contact,
    if (_memberId != null) ...{'member_id': _memberId, 'family_id': _familyId},
  };

  @override
  void readExtra(Map<String, dynamic> fields) {
    _relationship.text = fields['relationship'] as String? ?? '';
    _circumstances.text = fields['circumstances'] as String? ?? '';
    _contact = fields['preferred_contact'] as String? ?? 'app';
    _memberId = fields['member_id'] as String?;
    _familyId = fields['family_id'] as String?;
  }

  void _toggle(String value) => setState(() {
    vulnerabilities =
        vulnerabilities.contains(value)
            ? vulnerabilities.where((v) => v != value).toList()
            : [...vulnerabilities, value];
  });

  void _next(int to, bool valid, String problem) {
    if (!valid) {
      setState(() => this.problem = problem.tr());
      return;
    }
    goTo(to);
  }

  @override
  Widget build(BuildContext context) {
    final title = 'lf_report_missing'.tr();
    if (draft == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return switch (step) {
      0 => GuidedStep(
        flowTitle: title,
        problem: problem,
        step: 0,
        total: 4,
        title: 'lf_who_title'.tr(),
        subtitle: 'lf_who_hint'.tr(),
        nextLabel: 'fam_continue'.tr(),
        onNext:
            () => _next(
              1,
              _relationship.text.trim().isNotEmpty,
              'lf_need_relationship',
            ),
        children: [
          if (_people.isNotEmpty) ...[
            FieldLabel('lf_from_family'.tr()),
            for (final (circle, member) in _people)
              ChoiceRow(
                title: member.name,
                subtitle: memberRelationLine(member),
                selected: _memberId == member.id,
                onTap:
                    () => setState(() {
                      final same = _memberId == member.id;
                      _memberId = same ? null : member.id;
                      _familyId = same ? null : circle.id;
                      if (!same) person.text = member.name;
                    }),
              ),
          ],
          AppTextField(
            controller: person,
            label: 'lf_field_name'.tr(),
            textCapitalization: TextCapitalization.words,
          ),
          AppSpacing.gapMd,
          ageRow(),
          AppSpacing.gapMd,
          AppTextField(
            controller: _relationship,
            label: 'lf_field_relationship'.tr(),
          ),
          FieldLabel('lf_field_vulnerable'.tr()),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final v in vulnerabilityKinds)
                FilterChip(
                  label: Text('lf_vuln_$v'.tr()),
                  selected: vulnerabilities.contains(v),
                  onSelected: (_) => _toggle(v),
                ),
            ],
          ),
        ],
      ),
      1 => GuidedStep(
        flowTitle: title,
        problem: problem,
        step: 1,
        total: 4,
        title: 'lf_describe_title'.tr(),
        subtitle: 'lf_describe_hint'.tr(),
        nextLabel: 'fam_continue'.tr(),
        onBack: () => goTo(0),
        onNext: () => _next(2, hasDescription(), 'lf_need_description'),
        children: descriptionFields(),
      ),
      2 => GuidedStep(
        flowTitle: title,
        problem: problem,
        step: 2,
        total: 4,
        title: 'lf_seen_title'.tr(),
        nextLabel: 'fam_continue'.tr(),
        onBack: () => goTo(1),
        onNext:
            () => _next(
              3,
              when != null && place.text.trim().isNotEmpty,
              'lf_need_place',
            ),
        children: [
          ...placeFields('lf_field_seen_at'.tr(), 'lf_field_seen_place'.tr()),
          AppSpacing.gapMd,
          AppTextField(
            controller: _circumstances,
            label: 'lf_field_circumstances'.tr(),
            maxLength: 1000,
            maxLines: 3,
          ),
        ],
      ),
      _ => GuidedStep(
        flowTitle: title,
        problem: problem,
        step: 3,
        total: 4,
        title: 'lf_review_title'.tr(),
        nextLabel: 'lf_submit'.tr(),
        busy: busy,
        onBack: () => goTo(2),
        onNext: busy ? null : submit,
        children: [
          if (person.text.trim().isNotEmpty)
            FactRow(label: 'lf_field_name'.tr(), value: person.text.trim()),
          FactRow(label: 'lf_field_seen_place'.tr(), value: place.text.trim()),
          if (when != null)
            FactRow(
              label: 'lf_field_seen_at'.tr(),
              value: dateTimeText(context, when!),
            ),
          FieldLabel('lf_field_contact'.tr()),
          PillChoices(
            values: contactPreferences,
            labelOf: (c) => 'lf_contact_$c'.tr(),
            selected: _contact,
            onChanged: (c) => setState(() => _contact = c),
          ),
          AppSpacing.gapSm,
          Text('lf_contact_private'.tr(), style: context.editorial.meta),
          AppSpacing.gapLg,
          const NotOfficialNote(),
        ],
      ),
    };
  }
}

/// `/lostFoundFound`: for registered helpers. The server checks that too.
class ReportFoundScreen extends StatefulWidget {
  const ReportFoundScreen({
    super.key,
    this.draftId,
    this.position = readPosition,
    this.photoPicker = pickCasePhoto,
  });

  final String? draftId;
  final PositionReader position;
  final PhotoPicker photoPicker;

  @override
  State<ReportFoundScreen> createState() => _ReportFoundScreenState();
}

class _ReportFoundScreenState extends _ReportState<ReportFoundScreen> {
  final _assistance = TextEditingController();
  final _facility = TextEditingController();
  String? _category;

  @override
  String get kind => 'found';
  @override
  String? get draftId => widget.draftId;
  @override
  PositionReader get position => widget.position;
  @override
  PhotoPicker get photoPicker => widget.photoPicker;

  bool get _isChild => _category == 'child_alone';

  @override
  void dispose() {
    _assistance.dispose();
    _facility.dispose();
    super.dispose();
  }

  @override
  Map<String, dynamic> extraFields() => {
    if (_category != null) 'found_category': _category,
    'assistance_needed': _assistance.text.trim(),
    'safe_facility': _facility.text.trim(),
  };

  @override
  void readExtra(Map<String, dynamic> fields) {
    _category = fields['found_category'] as String?;
    _assistance.text = fields['assistance_needed'] as String? ?? '';
    _facility.text = fields['safe_facility'] as String? ?? '';
  }

  void _go(int to, bool valid, String problem) {
    if (!valid) {
      setState(() => this.problem = problem.tr());
      return;
    }
    goTo(to);
  }

  @override
  Widget build(BuildContext context) {
    final title = 'lf_report_found'.tr();
    if (draft == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return switch (step) {
      0 => GuidedStep(
        flowTitle: title,
        problem: problem,
        step: 0,
        total: 3,
        title: 'lf_found_what_title'.tr(),
        nextLabel: 'fam_continue'.tr(),
        onNext: () => _go(1, _category != null, 'lf_need_category'),
        children: [
          for (final c in foundCategories)
            ChoiceRow(
              title: 'lf_found_$c'.tr(),
              selected: _category == c,
              onTap: () => setState(() => _category = c),
            ),
          if (_isChild) ...[
            AppSpacing.gapMd,
            FamilyNote(
              title: 'lf_child_rules_title'.tr(),
              text: 'lf_child_rules_body'.tr(),
            ),
          ],
        ],
      ),
      1 => GuidedStep(
        flowTitle: title,
        problem: problem,
        step: 1,
        total: 3,
        title: 'lf_describe_title'.tr(),
        nextLabel: 'fam_continue'.tr(),
        onBack: () => goTo(0),
        onNext: () => _go(2, hasDescription(), 'lf_need_description'),
        children: [ageRow(), AppSpacing.gapMd, ...descriptionFields()],
      ),
      _ => GuidedStep(
        flowTitle: title,
        problem: problem,
        step: 2,
        total: 3,
        title: 'lf_found_where_title'.tr(),
        nextLabel: 'lf_submit'.tr(),
        busy: busy,
        onBack: () => goTo(1),
        onNext:
            busy
                ? null
                : () {
                  final placed = when != null && place.text.trim().isNotEmpty;
                  if (!placed) {
                    setState(() => problem = 'lf_need_place'.tr());
                  } else if (_isChild && _facility.text.trim().isEmpty) {
                    setState(() => problem = 'lf_need_facility'.tr());
                  } else {
                    submit();
                  }
                },
        children: [
          ...placeFields('lf_field_found_at'.tr(), 'lf_field_found_place'.tr()),
          AppSpacing.gapMd,
          AppTextField(
            controller: _facility,
            label: 'lf_field_facility'.tr(),
            helperText: 'lf_field_facility_hint'.tr(),
            maxLength: 160,
          ),
          AppSpacing.gapMd,
          AppTextField(
            controller: _assistance,
            label: 'lf_field_assistance'.tr(),
            maxLength: 500,
            maxLines: 2,
          ),
        ],
      ),
    };
  }
}

/// `/lostFoundDone`: says exactly where the report is, and never claims it has
/// been submitted until the server has confirmed it.
class ReportDoneScreen extends StatelessWidget {
  const ReportDoneScreen({super.key, required this.result});

  final SubmitResult result;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final waiting = result.waiting;
    final reference = result.reference ?? '';
    return Scaffold(
      appBar: AppBar(title: Text('lf_title'.tr())),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(editorialMargin),
          children: [
            Icon(
              waiting ? Icons.cloud_off_rounded : Icons.check_circle_outline,
              size: 40,
              color:
                  waiting
                      ? context.semanticColors.gold
                      : context.semanticColors.success,
            ),
            AppSpacing.gapMd,
            Semantics(
              header: true,
              child: Text(
                waiting
                    ? 'lf_done_waiting_title'.tr()
                    : result.duplicate
                    ? 'lf_done_duplicate_title'.tr()
                    : 'lf_done_title'.tr(),
                style: e.headline,
              ),
            ),
            AppSpacing.gapSm,
            Text(
              waiting ? 'lf_done_waiting_body'.tr() : 'lf_done_body'.tr(),
              style: e.dek,
            ),
            if (reference.isNotEmpty) ...[
              AppSpacing.gapXl,
              Text('lf_reference'.tr(), style: e.meta),
              SelectableText(
                reference,
                style: e.masthead.copyWith(color: context.colorScheme.primary),
              ),
            ],
            AppSpacing.gapXl,
            Text('lf_next_title'.tr(), style: e.title),
            AppSpacing.gapXs,
            Text('lf_next_body'.tr()),
            AppSpacing.gapLg,
            const NotOfficialNote(),
            AppSpacing.gapXl,
            AppButton(
              label: 'lf_done_back'.tr(),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
