import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/booking/data/booking_repository.dart';
import 'package:kumbha_path/src/modules/booking/models/booking_models.dart';
import 'package:kumbha_path/src/modules/booking/widgets/booking_parts.dart';
import 'package:kumbha_path/src/modules/patrika/widgets/patrika_parts.dart'
    show Masthead;

const _modes = ['train', 'bus', 'flight', 'taxi', 'local'];

/// `/transport` (argument: `(mode, JourneyPrefill?)`). Each mode has its own
/// layout, because a train ticket and a cab aren't the same thing.
class TransportScreen extends StatefulWidget {
  const TransportScreen({
    super.key,
    this.mode = 'train',
    this.prefill,
    this.repository,
  });

  final String mode;
  final JourneyPrefill? prefill;
  final BookingRepository? repository;

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  late final BookingRepository _repo =
      widget.repository ?? BookingServices.repository;
  late String _mode = widget.mode;
  late final _from = TextEditingController(text: widget.prefill?.origin ?? '');
  final _to = TextEditingController(text: 'Nashik');
  late DateTime? _date = widget.prefill?.arrival;
  late int _passengers = widget.prefill?.travellers ?? 1;
  TransportSearchResult? _result;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _search();
    });
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repo.transport(
        language: journeyLanguage(context),
        from: _from.text.trim().isEmpty ? null : _from.text.trim(),
        to: _to.text.trim().isEmpty ? null : _to.text.trim(),
        date: _date,
        mode: _mode,
        passengers: _passengers,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });
      }
    } on JourneyException catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  void _swap() {
    final from = _from.text;
    _from.text = _to.text;
    _to.text = from;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      initialDate: _date != null && !_date!.isBefore(now) ? _date! : now,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  void _saveBooking(TransportProvider provider) => Navigator.pushNamed(
    context,
    '/bookingForm',
    arguments: BookingDraft(
      category: provider.mode == 'local' ? 'taxi' : provider.mode,
      title: 'bk_trip_title'.tr(args: [_from.text, _to.text]),
      provider: provider.name,
      url: provider.url,
      start: _date,
      people: _passengers,
      fromPlace: _from.text.trim(),
      toPlace: _to.text.trim(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    return MainLayout(
      ctx: 0,
      showDefaultBottom: true,
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.huge),
        children: [
          Masthead(
            title: 'bk_transport'.tr(),
            dateline: 'bk_transport_line'.tr(),
          ),
          AppSpacing.gapMd,
          Padding(
            padding: editorialPage,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _from,
                        label: 'bk_from'.tr(),
                        prefixIcon: Icons.trip_origin_rounded,
                      ),
                      AppSpacing.gapSm,
                      AppTextField(
                        controller: _to,
                        label: 'bk_to'.tr(),
                        prefixIcon: Icons.place_outlined,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'bk_swap'.tr(),
                  onPressed: _swap,
                  icon: const Icon(Icons.swap_vert_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: editorialPage,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.md,
              children: [
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text(
                    _date == null
                        ? 'bk_any_date'.tr()
                        : fullDate(context, _date!),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'bk_fewer'.tr(args: ['bk_passengers'.tr()]),
                      onPressed:
                          _passengers > 1
                              ? () => setState(() => _passengers--)
                              : null,
                      icon: const Icon(Icons.remove_rounded, size: 18),
                    ),
                    Flexible(
                      child: Text(
                        'bk_passengers_count'.plural(_passengers),
                        style: e.meta,
                      ),
                    ),
                    IconButton(
                      tooltip: 'bk_more'.tr(args: ['bk_passengers'.tr()]),
                      onPressed:
                          _passengers < 50
                              ? () => setState(() => _passengers++)
                              : null,
                      icon: const Icon(Icons.add_rounded, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: editorialPage,
            child: Row(
              children: [
                for (final mode in _modes)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      avatar: Icon(categoryIcon(mode), size: 18),
                      label: Text('bk_mode_$mode'.tr()),
                      selected: _mode == mode,
                      onSelected: (_) {
                        setState(() => _mode = mode);
                        _search();
                      },
                    ),
                  ),
              ],
            ),
          ),
          AppSpacing.gapMd,
          Padding(
            padding: editorialPage,
            child: AppButton(
              label: 'bk_check_options'.tr(),
              onPressed: _search,
            ),
          ),
          AppSpacing.gapLg,
          const GhatRule(),
          Padding(
            padding: const EdgeInsets.all(editorialMargin),
            child: _results(context),
          ),
        ],
      ),
    );
  }

  Widget _results(BuildContext context) {
    if (_loading) {
      return const Column(
        children: [SkeletonLine(height: 110), SkeletonLine(height: 110)],
      );
    }
    if (_error != null) {
      return BookingMessage(
        title: bookingErrorText(_error),
        actionLabel: 'common_retry'.tr(),
        onAction: _search,
      );
    }
    final r = _result;
    if (r == null) return const SizedBox.shrink();
    final e = context.editorial;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (r.live)
          for (final option in r.results) _LiveOption(option: option)
        else
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.semanticColors.infoContainer,
              borderRadius: AppRadius.lgAll,
            ),
            child: Text(
              'bk_no_live'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.semanticColors.onInfoContainer,
              ),
            ),
          ),
        Text('bk_where_to_check'.tr(), style: e.kicker),
        AppSpacing.gapMd,
        if (r.providers.isEmpty)
          BookingMessage(title: 'bk_no_providers'.tr())
        else if (_mode == 'taxi')
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in r.providers)
                Expanded(child: _CabTile(provider: p)),
            ],
          )
        else
          for (final p in r.providers)
            switch (_mode) {
              'train' => _RailProvider(
                provider: p,
                from: _from.text,
                to: _to.text,
                date: _date,
                onSave: () => _saveBooking(p),
              ),
              'bus' => _RouteProvider(
                provider: p,
                from: _from.text,
                to: _to.text,
                onSave: () => _saveBooking(p),
              ),
              _ => _PlainProvider(provider: p),
            },
      ],
    );
  }
}

Widget _openButton(BuildContext context, TransportProvider p) => AppButton(
  label: (p.canBook ? 'bk_book_with' : 'bk_open_site').tr(args: [p.name]),
  trailingIcon: Icons.open_in_new_rounded,
  onPressed: () => openExternal(context, p.url),
);

/// A rail provider, drawn as a ticket between the two stations.
class _RailProvider extends StatelessWidget {
  const _RailProvider({
    required this.provider,
    required this.from,
    required this.to,
    required this.date,
    required this.onSave,
  });

  final TransportProvider provider;
  final String from;
  final String to;
  final DateTime? date;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TicketCard(
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(provider.name, style: e.headline)),
                  if (provider.isOfficial)
                    Icon(
                      Icons.verified_outlined,
                      size: 18,
                      color: context.semanticColors.success,
                    ),
                ],
              ),
              if (from.trim().isNotEmpty) ...[
                AppSpacing.gapSm,
                Text('${from.trim()}  →  ${to.trim()}', style: e.title),
              ],
              if (date != null) Text(fullDate(context, date!), style: e.meta),
              AppSpacing.gapSm,
              Text(provider.note, style: e.meta),
            ],
          ),
        ),
        stub: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _openButton(context, provider),
              if (provider.canBook)
                TextButton(
                  onPressed: onSave,
                  child: Text('bk_already_booked'.tr()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bus provider, with the route drawn as a line.
class _RouteProvider extends StatelessWidget {
  const _RouteProvider({
    required this.provider,
    required this.from,
    required this.to,
    required this.onSave,
  });

  final TransportProvider provider;
  final String from;
  final String to;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final primary = context.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(provider.name, style: e.headline),
          AppSpacing.gapSm,
          if (from.trim().isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.circle_outlined, size: 12, color: primary),
                Expanded(child: Container(height: 1.5, color: primary)),
                Icon(Icons.directions_bus_outlined, size: 20, color: primary),
                Expanded(child: Container(height: 1.5, color: primary)),
                Icon(Icons.circle, size: 12, color: primary),
              ],
            ),
            AppSpacing.gapXs,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(from.trim(), style: e.meta)),
                Flexible(child: Text(to.trim(), style: e.meta)),
              ],
            ),
            AppSpacing.gapSm,
          ],
          Text(provider.note, style: context.textTheme.bodyMedium),
          AppSpacing.gapMd,
          _openButton(context, provider),
          if (provider.canBook)
            TextButton(
              onPressed: onSave,
              child: Text('bk_already_booked'.tr()),
            ),
        ],
      ),
    );
  }
}

/// Cabs are chosen by app, so they sit side by side.
class _CabTile extends StatelessWidget {
  const _CabTile({required this.provider});

  final TransportProvider provider;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: () => openExternal(context, provider.url),
    label: provider.name,
    child: Container(
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_taxi_outlined, color: context.colorScheme.primary),
          AppSpacing.gapSm,
          Text(provider.name, style: context.editorial.headline),
          AppSpacing.gapXs,
          Text(provider.note, style: context.editorial.meta),
          AppSpacing.gapSm,
          Icon(
            Icons.open_in_new_rounded,
            size: 16,
            color: context.colorScheme.primary,
          ),
        ],
      ),
    ),
  );
}

/// Flights and local transport are advice with a link.
class _PlainProvider extends StatelessWidget {
  const _PlainProvider({required this.provider});

  final TransportProvider provider;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(provider.name, style: context.editorial.headline),
        AppSpacing.gapXs,
        Text(provider.note, style: context.textTheme.bodyMedium),
        AppSpacing.gapMd,
        AppButton.outlined(
          label: 'bk_open_site'.tr(args: [provider.name]),
          trailingIcon: Icons.open_in_new_rounded,
          onPressed: () => openExternal(context, provider.url),
        ),
      ],
    ),
  );
}

/// Real results from an authorized provider. Shown only when one exists.
class _LiveOption extends StatelessWidget {
  const _LiveOption({required this.option});

  final TransportResult option;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final o = option;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(o.provider, style: e.title),
          Text(
            [
              if (o.departs != null) o.departs!,
              if (o.arrives != null) o.arrives!,
              if (o.duration != null) o.duration!,
              if (o.availability != null) o.availability!,
            ].join(' · '),
            style: e.meta,
          ),
          if (o.price != null) Text(rupees(o.price!), style: e.headline),
          if (o.url != null)
            TextButton(
              onPressed: () => openExternal(context, o.url!),
              child: Text('bk_open_site'.tr(args: [o.provider])),
            ),
        ],
      ),
    );
  }
}
