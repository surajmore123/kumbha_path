import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/booking/data/booking_repository.dart';
import 'package:kumbha_path/src/modules/booking/models/booking_models.dart';
import 'package:kumbha_path/src/modules/booking/widgets/booking_parts.dart';
import 'package:kumbha_path/src/modules/journey/data/journey_repository.dart'
    show JourneyServices;

const _stayTypes = [
  'hotel',
  'budget',
  'dharamshala',
  'ashram',
  'guest_house',
  'tent',
  'family',
  'other',
];

/// `/booking`: a hero, then one search panel that overlaps it and switches
/// between stays and transport. Argument: an optional [JourneyPrefill].
class BookingHomeScreen extends StatefulWidget {
  const BookingHomeScreen({super.key, this.prefill, this.repository});

  final JourneyPrefill? prefill;
  final BookingRepository? repository;

  @override
  State<BookingHomeScreen> createState() => _BookingHomeScreenState();
}

class _BookingHomeScreenState extends State<BookingHomeScreen> {
  late final BookingRepository _repo =
      widget.repository ?? BookingServices.repository;
  final _search = StaySearch();
  StayFilters _filters = const StayFilters();
  JourneyPrefill? _journey;
  bool _transport = false;
  int _upcoming = 0;

  @override
  void initState() {
    super.initState();
    _journey = widget.prefill;
    _applyJourney();
    if (_journey == null) _loadJourney();
    _loadUpcoming();
  }

  void _applyJourney() {
    final j = _journey;
    if (j == null) return;
    _search.checkIn = j.arrival;
    _search.checkOut = j.departure;
    if (j.travellers != null) _search.guests = j.travellers!;
  }

  Future<void> _loadJourney() async {
    try {
      final page = await JourneyServices.repository.list(status: 'planned');
      final next = page.items.where((j) => j.arrivalDate != null).firstOrNull;
      if (next == null || !mounted) return;
      setState(() {
        _journey = JourneyPrefill(
          title: next.title,
          arrival: next.arrivalDate,
          departure: next.departureDate,
          travellers: next.travellers,
          origin: next.originCity,
        );
      });
    } catch (_) {
      // The search works without a saved journey.
    }
  }

  Future<void> _loadUpcoming() async {
    try {
      final page = await _repo.saved(when: 'upcoming');
      if (mounted) setState(() => _upcoming = page.items.length);
    } catch (_) {
      // Signed out or offline: the shortcut just shows no count.
    }
  }

  String? _language;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = journeyLanguage(context);
    if (language == _language) return;
    _language = language;
    _repo
        .stayFilters(language)
        .then((f) {
          if (mounted) setState(() => _filters = f);
        })
        .catchError((Object _) {});
  }

  void _openStays({String? type, String? area}) {
    if (type != null) _search.type = type;
    if (area != null) _search.area = area;
    Navigator.pushNamed(context, '/stays', arguments: _search);
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final start = _search.checkIn;
    final end = _search.checkOut;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      initialDateRange:
          start != null && end != null && !start.isBefore(now)
              ? DateTimeRange(start: start, end: end)
              : null,
    );
    if (picked != null && mounted) {
      setState(() {
        _search.checkIn = picked.start;
        _search.checkOut = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final s = context.semanticColors;
    final hero = _filters.areas.where((a) => a.slug == 'trimbakeshwar');
    final heroImage =
        hero.firstOrNull?.image ?? _filters.areas.firstOrNull?.image;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    // Room for the title and tabs to grow with the font size.
    final scale = MediaQuery.textScalerOf(context);
    final tabs = scale.scale(20) + AppSpacing.xxl + AppSpacing.md;
    final heroHeight = 220 + scale.scale(90) + tabs;

    return MainLayout(
      ctx: 0,
      showDefaultBottom: true,
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.huge),
        children: [
          SizedBox(
            height: heroHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  bottom: tabs / 2,
                  child: ClipPath(
                    clipper: const GhatEdgeClipper(),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        EditorialImage(url: heroImage?.url),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                s.imageScrim,
                                s.imageScrim.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xs,
                      AppSpacing.xs,
                      editorialMargin,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (canPop)
                          BackButton(color: s.onImage)
                        else
                          const SizedBox(height: AppSpacing.minTouchTarget),
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  'bk_title'.tr(),
                                  style: e.masthead.copyWith(color: s.onImage),
                                ),
                              ),
                              Text(
                                'bk_subtitle'.tr(),
                                style: e.meta.copyWith(color: s.onImage),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: editorialMargin,
                  right: editorialMargin,
                  bottom: 0,
                  child: _SwitchTabs(
                    transport: _transport,
                    onChanged: (v) => setState(() => _transport = v),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              editorialMargin,
              AppSpacing.md,
              editorialMargin,
              0,
            ),
            child: AnimatedSwitcher(
              duration:
                  reduceMotion(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
              child:
                  _transport
                      ? _TransportPrompt(
                        key: const ValueKey('transport'),
                        journey: _journey,
                      )
                      : _stayPanel(context),
            ),
          ),
          if (_journey?.title != null) _journeyStrip(context),
          _section(
            'bk_where'.tr(),
            SizedBox(
              height: 190,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: editorialPage,
                children: [
                  for (final area in _filters.areas)
                    _AreaCard(
                      area: area,
                      onTap: () => _openStays(area: area.slug),
                    ),
                ],
              ),
            ),
          ),
          _section(
            'bk_kinds'.tr(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: editorialPage,
              child: Row(
                children: [
                  for (final type in _stayTypes)
                    Pressable(
                      onTap: () => _openStays(type: type),
                      label: 'bk_type_$type'.tr(),
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.lg),
                        child: SizedBox(
                          width: 72,
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color:
                                      context.colorScheme.surfaceContainerHigh,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  stayTypeIcon(type),
                                  color: context.colorScheme.primary,
                                ),
                              ),
                              AppSpacing.gapXs,
                              Text(
                                'bk_type_$type'.tr(),
                                textAlign: TextAlign.center,
                                style: e.meta,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              editorialMargin,
              AppSpacing.xl,
              editorialMargin,
              0,
            ),
            child: Pressable(
              onTap: () => Navigator.pushNamed(context, '/myBookings'),
              label: 'bk_my_bookings'.tr(),
              child: TicketCard(
                body: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Icon(
                        Icons.confirmation_number_outlined,
                        color: context.colorScheme.primary,
                      ),
                      AppSpacing.gapMd,
                      Expanded(
                        child: Text('bk_my_bookings'.tr(), style: e.title),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
                stub: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    _upcoming > 0
                        ? 'bk_upcoming_count'.plural(_upcoming)
                        : 'bk_keep_together'.tr(),
                    style: e.meta,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              editorialMargin,
              AppSpacing.xl,
              editorialMargin,
              0,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: s.warningContainer,
                borderRadius: AppRadius.lgAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'bk_before_you_pay'.tr(),
                    style: e.title.copyWith(color: s.onWarningContainer),
                  ),
                  AppSpacing.gapXs,
                  Text(
                    'bk_before_you_pay_body'.tr(),
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: s.onWarningContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          editorialMargin,
          AppSpacing.xl,
          editorialMargin,
          0,
        ),
        child: BookingSectionTitle(title),
      ),
      child,
    ],
  );

  Widget _journeyStrip(BuildContext context) {
    final j = _journey!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        editorialMargin,
        AppSpacing.md,
        editorialMargin,
        0,
      ),
      child: Row(
        children: [
          Icon(
            Icons.route_outlined,
            size: 16,
            color: context.semanticColors.gold,
          ),
          AppSpacing.gapSm,
          Expanded(
            child: Text(
              'bk_from_journey'.tr(
                args: [j.title!, dateSpan(context, j.arrival, j.departure)],
              ),
              style: context.editorial.meta,
            ),
          ),
          TextButton(
            onPressed: () => setState(_applyJourney),
            child: Text('bk_use_dates'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _stayPanel(BuildContext context) {
    final e = context.editorial;
    final s = _search;
    return Column(
      key: const ValueKey('stay'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          label: 'bk_field_where'.tr(),
          value:
              _filters.areas.where((a) => a.slug == s.area).firstOrNull?.name ??
              'bk_anywhere'.tr(),
          icon: Icons.place_outlined,
          onTap: () async {
            final picked = await showModalBottomSheet<String?>(
              context: context,
              showDragHandle: true,
              builder:
                  (ctx) => SafeArea(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          title: Text('bk_anywhere'.tr()),
                          onTap: () => Navigator.pop(ctx, ''),
                        ),
                        for (final a in _filters.areas)
                          ListTile(
                            title: Text(a.name),
                            onTap: () => Navigator.pop(ctx, a.slug),
                          ),
                      ],
                    ),
                  ),
            );
            if (picked != null) {
              setState(() => s.area = picked.isEmpty ? null : picked);
            }
          },
        ),
        const Divider(height: 1),
        _Field(
          label: 'bk_field_dates'.tr(),
          value: dateSpan(context, s.checkIn, s.checkOut),
          icon: Icons.calendar_month_outlined,
          onTap: _pickDates,
        ),
        const Divider(height: 1),
        Row(
          children: [
            Expanded(
              child: _Stepper(
                label: 'bk_guests'.tr(),
                value: s.guests,
                onChanged: (v) => setState(() => s.guests = v),
              ),
            ),
            Expanded(
              child: _Stepper(
                label: 'bk_rooms'.tr(),
                value: s.rooms,
                onChanged: (v) => setState(() => s.rooms = v),
              ),
            ),
          ],
        ),
        AppSpacing.gapMd,
        AppButton(label: 'bk_find_stay'.tr(), onPressed: _openStays),
        AppSpacing.gapSm,
        Text(
          'bk_no_availability_note'.tr(),
          textAlign: TextAlign.center,
          style: e.meta,
        ),
      ],
    );
  }
}

class _SwitchTabs extends StatelessWidget {
  const _SwitchTabs({required this.transport, required this.onChanged});

  final bool transport;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    Widget tab(String label, IconData icon, bool value) {
      final active = transport == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          child: InkWell(
            borderRadius: AppRadius.lgAll,
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration:
                  reduceMotion(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
              constraints: const BoxConstraints(
                minHeight: AppSpacing.minTouchTarget,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? colors.primary : Colors.transparent,
                borderRadius: AppRadius.lgAll,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: active ? colors.onPrimary : colors.onSurfaceVariant,
                  ),
                  AppSpacing.gapSm,
                  Flexible(
                    child: Text(
                      label,
                      style: context.textTheme.labelLarge?.copyWith(
                        color:
                            active ? colors.onPrimary : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        children: [
          tab('bk_tab_stay'.tr(), Icons.bed_outlined, false),
          tab('bk_tab_transport'.tr(), Icons.train_outlined, true),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colorScheme.primary),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.editorial.meta),
                Text(value, style: context.editorial.title),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.editorial.meta),
        Row(
          children: [
            IconButton(
              tooltip: 'bk_fewer'.tr(args: [label]),
              onPressed: value > 1 ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            Text('$value', style: context.editorial.title),
            IconButton(
              tooltip: 'bk_more'.tr(args: [label]),
              onPressed: value < 50 ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ],
    ),
  );
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.area, required this.onTap});

  final StayArea area;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.semanticColors;
    return Pressable(
      onTap: onTap,
      label: area.name,
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.md),
        child: ClipRRect(
          borderRadius: AppRadius.lgAll,
          child: SizedBox(
            width: 140,
            child: Stack(
              fit: StackFit.expand,
              children: [
                EditorialImage(url: area.image?.url),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.4, 1],
                      colors: [s.imageScrim.withValues(alpha: 0), s.imageScrim],
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: Text(
                    area.name,
                    style: context.editorial.title.copyWith(color: s.onImage),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransportPrompt extends StatelessWidget {
  const _TransportPrompt({super.key, this.journey});

  final JourneyPrefill? journey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (mode, key) in const [
          ('train', 'bk_mode_train'),
          ('bus', 'bk_mode_bus'),
          ('flight', 'bk_mode_flight'),
          ('taxi', 'bk_mode_taxi'),
        ])
          InkWell(
            onTap:
                () => Navigator.pushNamed(
                  context,
                  '/transport',
                  arguments: (mode, journey),
                ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  Icon(categoryIcon(mode), color: context.colorScheme.primary),
                  AppSpacing.gapMd,
                  Expanded(
                    child: Text(key.tr(), style: context.editorial.title),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
