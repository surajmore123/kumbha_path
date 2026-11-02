import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/booking/data/booking_repository.dart';
import 'package:kumbha_path/src/modules/booking/models/booking_models.dart';
import 'package:kumbha_path/src/modules/booking/widgets/booking_parts.dart';
import 'package:kumbha_path/src/modules/patrika/widgets/patrika_parts.dart'
    show Masthead;

/// `/myBookings`: the pilgrim's own reservations, like tickets in a wallet.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key, this.repository});

  final BookingRepository? repository;

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late final BookingRepository _repo =
      widget.repository ?? BookingServices.repository;
  List<SavedBooking>? _upcoming;
  List<SavedBooking> _past = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final upcoming = await _repo.saved(when: 'upcoming');
      final past = await _repo.saved(when: 'past');
      if (mounted) {
        setState(() {
          _upcoming = upcoming.items;
          _past = past.items;
        });
      }
    } on JourneyException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _add() async {
    final saved = await Navigator.pushNamed(context, '/bookingForm');
    if (saved != null && mounted) _load();
  }

  Future<void> _open(SavedBooking booking) async {
    await Navigator.pushNamed(context, '/bookingDetail', arguments: booking.id);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _upcoming;
    final stays = upcoming?.where((b) => b.isStay).toList() ?? const [];
    final travel = upcoming?.where((b) => !b.isStay).toList() ?? const [];
    return MainLayout(
      ctx: 0,
      showDefaultBottom: true,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Masthead(
                  title: 'bk_my_bookings'.tr(),
                  dateline: 'bk_my_bookings_line'.tr(),
                ),
                if (_error != null)
                  BookingMessage(
                    title: bookingErrorText(_error),
                    actionLabel: 'common_retry'.tr(),
                    onAction: _load,
                  )
                else if (upcoming == null)
                  const Padding(
                    padding: EdgeInsets.all(editorialMargin),
                    child: Column(
                      children: [
                        SkeletonLine(height: 130),
                        SkeletonLine(height: 130),
                      ],
                    ),
                  )
                else if (upcoming.isEmpty && _past.isEmpty)
                  BookingMessage(
                    title: 'bk_no_bookings'.tr(),
                    body: 'bk_no_bookings_body'.tr(),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(editorialMargin),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (travel.isNotEmpty) ...[
                          BookingSectionTitle('bk_section_travel'.tr()),
                          for (final b in travel)
                            BookingTicket(booking: b, onTap: () => _open(b)),
                          AppSpacing.gapMd,
                        ],
                        if (stays.isNotEmpty) ...[
                          BookingSectionTitle('bk_section_stays'.tr()),
                          for (final b in stays)
                            BookingTicket(booking: b, onTap: () => _open(b)),
                          AppSpacing.gapMd,
                        ],
                        if (_past.isNotEmpty) ...[
                          BookingSectionTitle('bk_section_past'.tr()),
                          for (final b in _past)
                            BookingTicket(booking: b, onTap: () => _open(b)),
                        ],
                      ],
                    ),
                  ),
                Padding(
                  padding: editorialPage,
                  child: Text(
                    'bk_status_note'.tr(),
                    style: context.editorial.meta,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: FloatingActionButton.extended(
              heroTag: 'booking_new',
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: Text('bk_add'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

/// `/bookingDetail` (argument: id): the ticket, with the reference large.
class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key, required this.id, this.repository});

  final String id;
  final BookingRepository? repository;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late final BookingRepository _repo =
      widget.repository ?? BookingServices.repository;
  SavedBooking? _booking;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final booking = await _repo.savedOne(widget.id);
      if (mounted) setState(() => _booking = booking);
    } on JourneyException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmJourneyAction(
      context,
      title: 'bk_delete_title'.tr(),
      message: 'bk_delete_body'.tr(),
      confirm: 'bk_delete'.tr(),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _repo.delete(widget.id);
      if (mounted) Navigator.pop(context, true);
    } on JourneyException catch (e) {
      if (mounted) showJourneySnack(context, bookingErrorText(e));
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.pushNamed(
      context,
      '/bookingForm',
      arguments: _booking,
    );
    if (saved != null && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    final e = context.editorial;
    return MainLayout(
      ctx: 0,
      appBar: AppAppBar(
        title: 'bk_booking'.tr(),
        actions: [
          if (b != null) ...[
            IconButton(
              tooltip: 'bk_edit'.tr(),
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'bk_delete'.tr(),
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ],
      ),
      body:
          _error != null
              ? BookingMessage(
                title: bookingErrorText(_error),
                actionLabel: 'common_retry'.tr(),
                onAction: _load,
              )
              : b == null
              ? const AppLoading()
              : ListView(
                padding: const EdgeInsets.all(editorialMargin),
                children: [
                  BookingTicket(booking: b),
                  if (b.reference.isNotEmpty) ...[
                    AppSpacing.gapMd,
                    Text('bk_field_reference'.tr(), style: e.kicker),
                    Row(
                      children: [
                        Expanded(child: Text(b.reference, style: e.lead)),
                        IconButton(
                          tooltip: 'bk_copy'.tr(),
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: b.reference));
                            showJourneySnack(context, 'bk_copied'.tr());
                          },
                        ),
                      ],
                    ),
                  ],
                  AppSpacing.gapMd,
                  for (final (label, value) in [
                    ('bk_field_people', 'bk_guests_count'.plural(b.people)),
                    ('bk_field_names', b.travellerNames),
                    ('bk_field_time', b.startTime),
                    (
                      'bk_field_amount',
                      b.amountPaid == null
                          ? ''
                          : rupees(double.tryParse(b.amountPaid!) ?? 0),
                    ),
                    ('bk_field_notes', b.notes),
                  ])
                    if (value.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label.tr(), style: e.meta),
                            Text(value, style: e.title),
                          ],
                        ),
                      ),
                  if (b.bookingUrl != null)
                    AppButton.outlined(
                      label: 'bk_open_booking'.tr(),
                      trailingIcon: Icons.open_in_new_rounded,
                      onPressed: () => openExternal(context, b.bookingUrl!),
                    ),
                  AppSpacing.gapLg,
                  Text('bk_status_note'.tr(), style: e.meta),
                ],
              ),
    );
  }
}

/// `/bookingForm`: add or edit. Argument: a [BookingDraft], or the
/// [SavedBooking] being edited.
class BookingFormScreen extends StatefulWidget {
  const BookingFormScreen({
    super.key,
    this.draft,
    this.existing,
    this.repository,
  });

  final BookingDraft? draft;
  final SavedBooking? existing;
  final BookingRepository? repository;

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  late final BookingRepository _repo =
      widget.repository ?? BookingServices.repository;
  final _form = GlobalKey<FormState>();
  late final SavedBooking? _b = widget.existing;
  late final BookingDraft? _d = widget.draft;
  late final _title = TextEditingController(text: _b?.title ?? _d?.title ?? '');
  late final _provider = TextEditingController(
    text: _b?.provider ?? _d?.provider ?? '',
  );
  late final _reference = TextEditingController(text: _b?.reference ?? '');
  late final _from = TextEditingController(
    text: _b?.fromPlace ?? _d?.fromPlace ?? '',
  );
  late final _to = TextEditingController(
    text: _b?.toPlace ?? _d?.toPlace ?? '',
  );
  late final _names = TextEditingController(text: _b?.travellerNames ?? '');
  late final _amount = TextEditingController(text: _b?.amountPaid ?? '');
  late final _url = TextEditingController(
    text: _b?.bookingUrl ?? _d?.url ?? '',
  );
  late final _notes = TextEditingController(text: _b?.notes ?? '');
  late String _category = _b?.category ?? _d?.category ?? 'stay';
  late BookingStatus _status = _b?.status ?? BookingStatus.saved;
  late DateTime? _start = _b?.startDate ?? _d?.start;
  late DateTime? _end = _b?.endDate ?? _d?.end;
  late int _people = _b?.people ?? _d?.people ?? 1;
  bool _saving = false;
  Map<String, String> _errors = const {};
  String? _error;

  static const _categories = ['stay', 'train', 'bus', 'flight', 'taxi'];

  @override
  void dispose() {
    for (final c in [
      _title,
      _provider,
      _reference,
      _from,
      _to,
      _names,
      _amount,
      _url,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030, 12, 31),
      initialDate: (start ? _start : _end ?? _start) ?? DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_start != null && _end != null && _end!.isBefore(_start!)) {
      setState(() => _error = 'bk_err_dates'.tr());
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _errors = const {};
    });
    final amount = _amount.text.trim();
    final data = <String, dynamic>{
      'category': _category,
      'status': _status.name,
      'title': _title.text.trim(),
      'provider': _provider.text.trim(),
      'reference': _reference.text.trim(),
      'start_date': _start == null ? null : isoDay(_start!),
      'end_date': _end == null ? null : isoDay(_end!),
      'from_place': _from.text.trim(),
      'to_place': _to.text.trim(),
      'people': _people,
      'traveller_names': _names.text.trim(),
      'amount_paid': amount.isEmpty ? null : amount,
      'booking_url': _url.text.trim(),
      'notes': _notes.text.trim(),
      if (widget.draft?.stayId != null) 'stay_listing': widget.draft!.stayId,
    };
    try {
      final saved =
          _b == null
              ? await _repo.create(data)
              : await _repo.update(_b.id, data);
      if (mounted) Navigator.pop(context, saved);
    } on JourneyException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errors = e.fieldErrors;
        _error = bookingErrorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final isStay = _category == 'stay';
    return MainLayout(
      ctx: 0,
      appBar: AppAppBar(
        title: (_b == null ? 'bk_add_title' : 'bk_edit_title').tr(),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(editorialMargin),
          children: [
            Text('bk_form_note'.tr(), style: e.meta),
            AppSpacing.gapMd,
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final c in _categories)
                  ChoiceChip(
                    avatar: Icon(categoryIcon(c), size: 16),
                    label: Text('bk_cat_$c'.tr()),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            AppSpacing.gapMd,
            AppTextField(
              controller: _title,
              label: 'bk_field_title'.tr(),
              maxLength: 120,
              errorText: _errors['title'],
              validator:
                  (v) =>
                      (v ?? '').trim().isEmpty ? 'bk_err_required'.tr() : null,
            ),
            AppTextField(
              controller: _provider,
              label: 'bk_field_provider'.tr(),
              maxLength: 100,
            ),
            AppTextField(
              controller: _reference,
              label: 'bk_field_reference'.tr(),
              maxLength: 40,
              errorText: _errors['reference'],
            ),
            if (!isStay) ...[
              AppTextField(
                controller: _from,
                label: 'bk_from'.tr(),
                maxLength: 100,
              ),
              AppTextField(
                controller: _to,
                label: 'bk_to'.tr(),
                maxLength: 100,
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pick(start: true),
                    child: Text(
                      _start == null
                          ? (isStay ? 'bk_check_in' : 'bk_travel_date').tr()
                          : shortDate(context, _start!),
                    ),
                  ),
                ),
                AppSpacing.gapSm,
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pick(start: false),
                    child: Text(
                      _end == null
                          ? (isStay ? 'bk_check_out' : 'bk_return_date').tr()
                          : shortDate(context, _end!),
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.gapMd,
            Row(
              children: [
                Expanded(child: Text('bk_field_people'.tr(), style: e.title)),
                IconButton(
                  tooltip: 'bk_fewer'.tr(args: ['bk_field_people'.tr()]),
                  onPressed:
                      _people > 1 ? () => setState(() => _people--) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Text('$_people', style: e.title),
                IconButton(
                  tooltip: 'bk_more'.tr(args: ['bk_field_people'.tr()]),
                  onPressed:
                      _people < 50 ? () => setState(() => _people++) : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            AppTextField(
              controller: _names,
              label: 'bk_field_names'.tr(),
              maxLength: 200,
            ),
            AppTextField(
              controller: _amount,
              label: 'bk_field_amount'.tr(),
              prefixText: '₹ ',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              errorText: _errors['amount_paid'],
            ),
            AppSpacing.gapSm,
            DropdownButtonFormField<BookingStatus>(
              initialValue: _status,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'bk_field_status'.tr()),
              items: [
                for (final s in BookingStatus.values)
                  DropdownMenuItem(
                    value: s,
                    child: Text('bk_status_${s.name}'.tr()),
                  ),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            AppSpacing.gapXs,
            Text('bk_status_note'.tr(), style: e.meta),
            AppSpacing.gapMd,
            AppTextField(
              controller: _url,
              label: 'bk_field_url'.tr(),
              hint: 'https://',
              maxLength: 300,
              keyboardType: TextInputType.url,
              errorText: _errors['booking_url'],
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return null;
                final uri = Uri.tryParse(value);
                return uri == null || uri.scheme != 'https' || uri.host.isEmpty
                    ? 'bk_err_https'.tr()
                    : null;
              },
            ),
            AppTextField(
              controller: _notes,
              label: 'bk_field_notes'.tr(),
              maxLength: 500,
              maxLines: 3,
              minLines: 2,
              errorText: _errors['notes'],
            ),
            if (_error != null) ...[
              Text(
                _error!,
                style: e.meta.copyWith(color: context.colorScheme.error),
              ),
              AppSpacing.gapSm,
            ],
            AppButton(
              label: 'bk_save'.tr(),
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
