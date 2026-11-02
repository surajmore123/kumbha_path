import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/journey/data/journey_repository.dart';
import 'package:kumbha_path/src/modules/journey/models/journey_models.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart';

/// `/journeyForm`: create a plan in four short steps, or edit one
/// (pass the [JourneyPlan] as the route argument). Pops with the saved plan.
class JourneyFormScreen extends StatefulWidget {
  const JourneyFormScreen({
    super.key,
    this.initial,
    this.repository,
    this.today,
  });

  final JourneyPlan? initial;
  final JourneyRepository? repository;

  /// Injectable for tests; defaults to the device date.
  final DateTime? today;

  @override
  State<JourneyFormScreen> createState() => _JourneyFormScreenState();
}

class _JourneyFormScreenState extends State<JourneyFormScreen> {
  static const _stepCount = 4;
  static const _stepTitles = [
    'jp_step_basics',
    'jp_step_dates',
    'jp_step_travellers',
    'jp_step_preferences',
  ];

  late final JourneyRepository _repo =
      widget.repository ?? JourneyServices.repository;
  final _formKeys = List.generate(_stepCount, (_) => GlobalKey<FormState>());

  late final TextEditingController _title;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _accessNotes;
  late final TextEditingController _budget;
  late final TextEditingController _diet;
  late final TextEditingController _notes;

  int _step = 0;
  bool _saving = false;
  String? _formError;
  Map<String, String> _serverErrors = const {};

  DateTime? _arrival;
  DateTime? _departure;
  bool _datesUndecided = false;
  int _duration = 3;
  bool _flexible = false;
  int _adults = 1;
  int _children = 0;
  int _seniors = 0;
  bool _accessibility = false;
  String _transport = 'undecided';
  String _stay = 'undecided';
  bool _perPerson = false;
  final Set<String> _interests = {};

  bool get _editing => widget.initial != null;

  DateTime get _today {
    final now = widget.today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _title = TextEditingController(text: p?.title ?? '');
    _city = TextEditingController(text: p?.originCity ?? '');
    _state = TextEditingController(text: p?.originState ?? '');
    _accessNotes = TextEditingController(text: p?.accessibilityNotes ?? '');
    _budget = TextEditingController(text: _budgetText(p?.budgetAmount));
    _diet = TextEditingController(text: p?.dietaryNotes ?? '');
    _notes = TextEditingController(text: p?.notes ?? '');
    if (p != null) {
      _arrival = p.arrivalDate;
      _departure = p.departureDate;
      _datesUndecided = p.arrivalDate == null;
      _duration = p.durationDays ?? (p.dayCount > 0 ? p.dayCount : 3);
      _flexible = p.flexible;
      _adults = p.adults;
      _children = p.children;
      _seniors = p.seniors;
      _accessibility = p.needsAccessibility;
      _transport = p.transportMode;
      _stay = p.accommodation;
      _perPerson = p.budgetPerPerson;
      _interests.addAll(p.interests);
    }
  }

  static String _budgetText(String? amount) {
    final v = double.tryParse(amount ?? '');
    return v == null ? '' : v.round().toString();
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _city,
      _state,
      _accessNotes,
      _budget,
      _diet,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _travellers => _adults + _children + _seniors;

  /// Problems with the date step that a field validator can't express.
  /// A draft may leave both dates empty.
  String? _datesError({bool draft = false}) {
    if (_datesUndecided) return null;
    if (draft && _arrival == null && _departure == null) return null;
    if (_arrival == null || _departure == null) {
      return 'jp_err_choose_dates'.tr();
    }
    if (_departure!.isBefore(_arrival!)) return 'jp_err_departure_before'.tr();
    final days = _departure!.difference(_arrival!).inDays + 1;
    if (days > JourneyChoices.maxDays) {
      return 'jp_err_too_long'.tr(args: ['${JourneyChoices.maxDays}']);
    }
    final arrivalChanged = _arrival != widget.initial?.arrivalDate;
    final completed = widget.initial?.status == JourneyStatus.completed;
    if (arrivalChanged && !completed && _arrival!.isBefore(_today)) {
      return 'jp_err_past'.tr();
    }
    return null;
  }

  bool _validateStep(int step) {
    final formOk = _formKeys[step].currentState?.validate() ?? true;
    String? error;
    if (step == 1) error = _datesError();
    if (step == 2 && _travellers > JourneyChoices.maxTravellers) {
      error = 'jp_err_too_many'.tr(args: ['${JourneyChoices.maxTravellers}']);
    }
    setState(() => _formError = error);
    return formOk && error == null;
  }

  void _next() {
    if (!_validateStep(_step)) return;
    setState(() {
      _step++;
      _formError = null;
    });
  }

  void _back() {
    if (_step == 0) {
      Navigator.maybePop(context);
      return;
    }
    setState(() {
      _step--;
      _formError = null;
    });
  }

  Map<String, dynamic> _payload() {
    final budget = _budget.text.trim();
    return {
      'title': _title.text.trim(),
      'origin_city': _city.text.trim(),
      'origin_state': _state.text.trim(),
      'arrival_date':
          _datesUndecided || _arrival == null ? null : isoDate(_arrival!),
      'departure_date':
          _datesUndecided || _departure == null ? null : isoDate(_departure!),
      'duration_days': _datesUndecided ? _duration : null,
      'date_flexibility': _flexible ? 'flexible' : 'fixed',
      'adults': _adults,
      'children': _children,
      'seniors': _seniors,
      'needs_accessibility': _accessibility,
      'accessibility_notes': _accessibility ? _accessNotes.text.trim() : '',
      'transport_mode': _transport,
      'budget_amount': budget.isEmpty ? null : budget,
      'budget_basis': _perPerson ? 'per_person' : 'total',
      'accommodation_preference': _stay,
      'interests': _interests.toList(),
      'dietary_notes': _diet.text.trim(),
      'notes': _notes.text.trim(),
      'language': journeyLanguage(context),
    };
  }

  /// [draft] saves without building an itinerary; it only needs a title.
  Future<void> _save({required bool draft}) async {
    if (_saving) return;
    if (draft) {
      if (!_validateStep(0)) {
        setState(() => _step = 0);
        return;
      }
      final datesError = _datesError(draft: true);
      if (datesError != null) {
        setState(() {
          _step = 1;
          _formError = datesError;
        });
        return;
      }
    } else {
      for (var s = 0; s < _stepCount; s++) {
        if (!_validateStep(s)) {
          setState(() => _step = s);
          return;
        }
      }
    }

    setState(() {
      _saving = true;
      _formError = null;
      _serverErrors = const {};
    });
    try {
      final data = _payload();
      final JourneyPlan saved;
      if (_editing) {
        saved = await _repo.update(widget.initial!.id, data);
      } else {
        saved = await _repo.create(data, generate: !draft);
      }
      if (!mounted) return;
      Navigator.pop(context, saved);
    } on JourneyException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverErrors = e.fieldErrors;
        _formError = journeyErrorText(e);
        final step = _stepOfField(e.fieldErrors.keys);
        if (step != null) _step = step;
      });
    }
  }

  static int? _stepOfField(Iterable<String> fields) {
    const steps = {
      'title': 0,
      'origin_city': 0,
      'origin_state': 0,
      'arrival_date': 1,
      'departure_date': 1,
      'duration_days': 1,
      'adults': 2,
      'children': 2,
      'seniors': 2,
      'accessibility_notes': 2,
    };
    for (final f in fields) {
      if (steps.containsKey(f)) return steps[f];
    }
    return fields.isEmpty || fields.contains('non_field_errors') ? null : 3;
  }

  Future<void> _pickDate({required bool arrival}) async {
    final first = _today;
    final initial = (arrival ? _arrival : (_departure ?? _arrival)) ?? first;
    final picked = await showDatePicker(
      context: context,
      firstDate: initial.isBefore(first) ? initial : first,
      lastDate: DateTime(first.year + 3, 12, 31),
      initialDate: initial,
      helpText: (arrival ? 'jp_arrival' : 'jp_departure').tr(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (arrival) {
        _arrival = picked;
        if (_departure == null || _departure!.isBefore(picked)) {
          _departure = picked.add(Duration(days: _duration - 1));
        }
      } else {
        _departure = picked;
      }
      _formError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return PopScope(
      canPop: !_saving,
      child: MainLayout(
        ctx: 0,
        appBar: AppAppBar(
          title: (_editing ? 'jp_edit_journey' : 'jp_plan_my_journey').tr(),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'jp_step_of'.tr(args: ['${_step + 1}', '$_stepCount']),
                      style: text.labelMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    AppSpacing.gapXs,
                    Text(_stepTitles[_step].tr(), style: text.titleLarge),
                    AppSpacing.gapSm,
                    LinearProgressIndicator(
                      value: (_step + 1) / _stepCount,
                      semanticsLabel: 'jp_step_of'.tr(
                        args: ['${_step + 1}', '$_stepCount'],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ListView(
                      key: ValueKey('journey_step_$_step'),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        Form(key: _formKeys[_step], child: _stepBody(_step)),
                        if (_formError != null) ...[
                          AppSpacing.gapLg,
                          Text(
                            _formError!,
                            key: const ValueKey('journey_form_error'),
                            style: text.bodyMedium?.copyWith(
                              color: context.colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (!_editing)
                TextButton.icon(
                  onPressed: _saving ? null : () => _save(draft: true),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text('jp_save_draft'.tr()),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton.outlined(
                        label: (_step == 0 ? 'jp_cancel' : 'jp_back').tr(),
                        onPressed: _saving ? null : _back,
                      ),
                    ),
                    AppSpacing.gapMd,
                    Expanded(
                      child: AppButton(
                        label:
                            _step < _stepCount - 1
                                ? 'jp_next'.tr()
                                : (_editing
                                        ? 'jp_save_changes'
                                        : 'jp_create_plan')
                                    .tr(),
                        isLoading: _saving,
                        onPressed:
                            _saving
                                ? null
                                : (_step < _stepCount - 1
                                    ? _next
                                    : () => _save(draft: false)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBody(int step) => switch (step) {
    0 => _basics(),
    1 => _dates(),
    2 => _travellersStep(),
    _ => _preferences(),
  };

  Widget _basics() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('jp_basics_intro'.tr(), style: context.textTheme.bodyMedium),
      AppSpacing.gapLg,
      AppTextField(
        controller: _title,
        label: 'jp_field_title'.tr(),
        hint: 'jp_field_title_hint'.tr(),
        maxLength: 120,
        textCapitalization: TextCapitalization.sentences,
        errorText: _serverErrors['title'],
        validator: (v) => (v ?? '').trim().isEmpty ? 'jp_err_title'.tr() : null,
      ),
      AppSpacing.gapMd,
      AppTextField(
        controller: _city,
        label: 'jp_field_city'.tr(),
        hint: 'jp_field_city_hint'.tr(),
        maxLength: 80,
        textCapitalization: TextCapitalization.words,
        prefixIcon: Icons.place_outlined,
      ),
      AppSpacing.gapMd,
      AppTextField(
        controller: _state,
        label: 'jp_field_state'.tr(),
        maxLength: 80,
        textCapitalization: TextCapitalization.words,
      ),
    ],
  );

  Widget _dates() {
    final dayCount =
        _arrival != null &&
                _departure != null &&
                !_departure!.isBefore(_arrival!)
            ? _departure!.difference(_arrival!).inDays + 1
            : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('jp_dates_undecided'.tr()),
          subtitle: Text('jp_dates_undecided_help'.tr()),
          value: _datesUndecided,
          onChanged:
              (v) => setState(() {
                _datesUndecided = v;
                _formError = null;
              }),
        ),
        AppSpacing.gapMd,
        if (_datesUndecided)
          CountField(
            label: 'jp_trip_length'.tr(),
            helper: 'jp_days_count'.plural(_duration),
            value: _duration,
            min: 1,
            max: JourneyChoices.maxDays,
            onChanged: (v) => setState(() => _duration = v),
          )
        else ...[
          _DateTile(
            label: 'jp_arrival'.tr(),
            value: _arrival == null ? null : formatDate(context, _arrival!),
            onTap: () => _pickDate(arrival: true),
          ),
          AppSpacing.gapSm,
          _DateTile(
            label: 'jp_departure'.tr(),
            value: _departure == null ? null : formatDate(context, _departure!),
            onTap: () => _pickDate(arrival: false),
          ),
          if (dayCount != null) ...[
            AppSpacing.gapSm,
            Text(
              'jp_days_count'.plural(dayCount),
              style: context.textTheme.bodyMedium,
            ),
          ],
        ],
        AppSpacing.gapMd,
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('jp_dates_flexible'.tr()),
          value: _flexible,
          onChanged: (v) => setState(() => _flexible = v),
        ),
        AppSpacing.gapSm,
        SourceNote('jp_dates_tip'.tr()),
      ],
    );
  }

  Widget _travellersStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CountField(
        label: 'jp_adults'.tr(),
        helper: 'jp_adults_help'.tr(),
        value: _adults,
        min: 1,
        onChanged: (v) => setState(() => _adults = v),
      ),
      CountField(
        label: 'jp_children'.tr(),
        helper: 'jp_children_help'.tr(),
        value: _children,
        onChanged: (v) => setState(() => _children = v),
      ),
      CountField(
        label: 'jp_seniors'.tr(),
        helper: 'jp_seniors_help'.tr(),
        value: _seniors,
        onChanged: (v) => setState(() => _seniors = v),
      ),
      if (_serverErrors['adults'] != null)
        Text(
          _serverErrors['adults']!,
          style: TextStyle(color: context.colorScheme.error),
        ),
      AppSpacing.gapMd,
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('jp_accessibility'.tr()),
        subtitle: Text('jp_accessibility_help'.tr()),
        value: _accessibility,
        onChanged: (v) => setState(() => _accessibility = v),
      ),
      if (_accessibility)
        AppTextField(
          controller: _accessNotes,
          label: 'jp_accessibility_notes'.tr(),
          maxLength: 300,
          maxLines: 3,
          minLines: 2,
        ),
    ],
  );

  Widget _preferences() {
    final text = context.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('jp_transport'.tr(), style: text.titleSmall),
        AppSpacing.gapSm,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final m in JourneyChoices.transport)
              ChoiceChip(
                avatar: Icon(transportIcon(m), size: 18),
                label: Text('jp_transport_$m'.tr()),
                selected: _transport == m,
                onSelected: (_) => setState(() => _transport = m),
              ),
          ],
        ),
        AppSpacing.gapLg,
        Text('jp_stay'.tr(), style: text.titleSmall),
        AppSpacing.gapSm,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final s in JourneyChoices.stays)
              ChoiceChip(
                label: Text('jp_stay_$s'.tr()),
                selected: _stay == s,
                onSelected: (_) => setState(() => _stay = s),
              ),
          ],
        ),
        AppSpacing.gapLg,
        Text('jp_interests'.tr(), style: text.titleSmall),
        AppSpacing.gapSm,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final i in JourneyChoices.interests)
              FilterChip(
                label: Text('jp_interest_$i'.tr()),
                selected: _interests.contains(i),
                onSelected:
                    (on) => setState(
                      () => on ? _interests.add(i) : _interests.remove(i),
                    ),
              ),
          ],
        ),
        AppSpacing.gapLg,
        AppTextField(
          controller: _budget,
          label: 'jp_budget'.tr(),
          hint: 'jp_budget_hint'.tr(),
          prefixText: '₹ ',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          errorText: _serverErrors['budget_amount'],
        ),
        AppSpacing.gapSm,
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text('jp_budget_total'.tr())),
            ButtonSegment(
              value: true,
              label: Text('jp_budget_per_person'.tr()),
            ),
          ],
          selected: {_perPerson},
          onSelectionChanged: (s) => setState(() => _perPerson = s.first),
        ),
        AppSpacing.gapLg,
        AppTextField(
          controller: _diet,
          label: 'jp_dietary'.tr(),
          hint: 'jp_dietary_hint'.tr(),
          maxLength: 200,
        ),
        AppSpacing.gapMd,
        AppTextField(
          controller: _notes,
          label: 'jp_notes'.tr(),
          maxLength: 4000,
          maxLines: 5,
          minLines: 3,
          errorText: _serverErrors['notes'],
        ),
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    semanticLabel: '$label ${value ?? 'jp_choose_date'.tr()}',
    child: Row(
      children: [
        Icon(Icons.event_rounded, color: context.colorScheme.primary),
        AppSpacing.gapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.textTheme.labelMedium),
              Text(
                value ?? 'jp_choose_date'.tr(),
                style: context.textTheme.titleMedium,
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}
