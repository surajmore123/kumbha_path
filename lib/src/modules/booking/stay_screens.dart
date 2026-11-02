import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/akhada/models/akhada_models.dart';
import 'package:kumbha_path/src/modules/booking/data/booking_repository.dart';
import 'package:kumbha_path/src/modules/booking/models/booking_models.dart';
import 'package:kumbha_path/src/modules/booking/widgets/booking_parts.dart';
import 'package:kumbha_path/src/modules/temple_explorer/temple_detail_screen.dart'
    show TempleDetailArgs;

/// `/stays` (argument: [StaySearch]).
class StayResultsScreen extends StatefulWidget {
  const StayResultsScreen({super.key, this.search, this.repository});

  final StaySearch? search;
  final BookingRepository? repository;

  @override
  State<StayResultsScreen> createState() => _StayResultsScreenState();
}

class _StayResultsScreenState extends State<StayResultsScreen> {
  late final BookingRepository _repo =
      widget.repository ?? BookingServices.repository;
  late final StaySearch _search = widget.search ?? StaySearch();
  final List<StaySummary> _items = [];
  StayFilters _filters = const StayFilters();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasNext = false;
  bool _savedCopy = false;
  int _page = 1;
  int _request = 0;
  Object? _error;
  String? _language;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = journeyLanguage(context);
    if (language == _language) return;
    _language = language;
    _load();
    _repo
        .stayFilters(language)
        .then((f) {
          if (mounted) setState(() => _filters = f);
        })
        .catchError((Object _) {});
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repo.stays(_search, language: _language!);
      if (!mounted || request != _request) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _hasNext = page.hasNext;
        _savedCopy = page.isSavedCopy;
        _page = 1;
        _loading = false;
      });
    } on JourneyException catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _more() async {
    setState(() => _loadingMore = true);
    try {
      final page = await _repo.stays(
        _search,
        language: _language!,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasNext = page.hasNext;
        _page++;
        _loadingMore = false;
      });
    } on JourneyException catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      showJourneySnack(context, bookingErrorText(e));
    }
  }

  Future<void> _openFilters() async {
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(search: _search, filters: _filters),
    );
    if (apply == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final s = _search;
    final area = _filters.areas.where((a) => a.slug == s.area).firstOrNull;
    final summary = [
      area?.name ?? 'bk_anywhere'.tr(),
      if (s.checkIn != null) dateSpan(context, s.checkIn, s.checkOut),
      'bk_guests_count'.plural(s.guests),
    ].join(' · ');
    return MainLayout(
      ctx: 0,
      showDefaultBottom: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const BackButton(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('bk_stays'.tr(), style: e.title),
                      Text(summary, style: e.meta),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _openFilters,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(
                    s.activeFilters > 0
                        ? 'bk_filters_count'.tr(args: ['${s.activeFilters}'])
                        : 'bk_filters'.tr(),
                  ),
                ),
              ],
            ),
            const GhatRule(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(editorialMargin),
        children: const [StaySkeleton(), SizedBox(height: 32), StaySkeleton()],
      );
    }
    if (_error != null) {
      return BookingMessage(
        title: bookingErrorText(_error),
        actionLabel: 'common_retry'.tr(),
        onAction: _load,
      );
    }
    if (_items.isEmpty) {
      return BookingMessage(
        title: 'bk_no_stays'.tr(),
        body: 'bk_no_stays_body'.tr(),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(editorialMargin),
        children: [
          if (_savedCopy) ...[
            Text('ak_saved_copy'.tr(), style: context.editorial.meta),
            AppSpacing.gapMd,
          ],
          for (final stay in _items) StayCard(stay: stay),
          if (_hasNext)
            _loadingMore
                ? const AppLoading.compact()
                : AppButton.outlined(
                  label: 'bk_show_more'.tr(),
                  onPressed: _more,
                ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.search, required this.filters});

  final StaySearch search;
  final StayFilters filters;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TextEditingController _min = TextEditingController(
    text: widget.search.minPrice?.toString() ?? '',
  );
  late final TextEditingController _max = TextEditingController(
    text: widget.search.maxPrice?.toString() ?? '',
  );

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.search;
    final e = context.editorial;
    Widget toggle(String label, bool value, ValueChanged<bool> onChanged) =>
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: value,
          onChanged: (v) => setState(() => onChanged(v)),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        editorialMargin,
        0,
        editorialMargin,
        MediaQuery.viewInsetsOf(context).bottom + editorialMargin,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('bk_filters'.tr(), style: e.headline),
            AppSpacing.gapMd,
            Text('bk_budget'.tr(), style: e.kicker),
            AppSpacing.gapSm,
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _min,
                    label: 'bk_min'.tr(),
                    prefixText: '₹ ',
                    keyboardType: TextInputType.number,
                  ),
                ),
                AppSpacing.gapMd,
                Expanded(
                  child: AppTextField(
                    controller: _max,
                    label: 'bk_max'.tr(),
                    prefixText: '₹ ',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            AppSpacing.gapSm,
            Text('bk_budget_note'.tr(), style: e.meta),
            AppSpacing.gapLg,
            Text('bk_facilities'.tr(), style: e.kicker),
            AppSpacing.gapSm,
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final a in widget.filters.amenities)
                  FilterChip(
                    avatar: Icon(amenityIcon(a.slug), size: 16),
                    label: Text(a.name),
                    selected: s.amenities.contains(a.slug),
                    onSelected:
                        (on) => setState(
                          () =>
                              on
                                  ? s.amenities.add(a.slug)
                                  : s.amenities.remove(a.slug),
                        ),
                  ),
              ],
            ),
            AppSpacing.gapMd,
            toggle('bk_family'.tr(), s.family, (v) => s.family = v),
            toggle('bk_seniors'.tr(), s.seniors, (v) => s.seniors = v),
            toggle('bk_accessible'.tr(), s.accessible, (v) => s.accessible = v),
            toggle(
              'bk_available_only'.tr(),
              s.availableOnly,
              (v) => s.availableOnly = v,
            ),
            AppSpacing.gapSm,
            Text('bk_sort'.tr(), style: e.kicker),
            AppSpacing.gapSm,
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final sort in const ['recommended', 'price', 'distance'])
                  ChoiceChip(
                    label: Text('bk_sort_$sort'.tr()),
                    selected: s.sort == sort,
                    onSelected: (_) => setState(() => s.sort = sort),
                  ),
              ],
            ),
            AppSpacing.gapLg,
            AppButton(
              label: 'bk_apply'.tr(),
              onPressed: () {
                s.minPrice = int.tryParse(_min.text.trim());
                s.maxPrice = int.tryParse(_max.text.trim());
                Navigator.pop(context, true);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// `/stayDetail` (argument: listing id).
class StayDetailScreen extends StatefulWidget {
  const StayDetailScreen({super.key, required this.id, this.repository});

  final String id;
  final BookingRepository? repository;

  @override
  State<StayDetailScreen> createState() => _StayDetailScreenState();
}

class _StayDetailScreenState extends State<StayDetailScreen> {
  late final BookingRepository _repo =
      widget.repository ?? BookingServices.repository;
  Future<Fetched<StayDetail>>? _future;
  String? _language;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = journeyLanguage(context);
    if (language != _language) {
      _language = language;
      _future = _repo.stay(widget.id, language);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      ctx: 0,
      body: FutureBuilder<Fetched<StayDetail>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(editorialMargin),
                child: StaySkeleton(),
              ),
            );
          }
          final data = snap.data;
          if (data == null) {
            return SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BackButton(),
                  Expanded(
                    child: Center(
                      child: BookingMessage(
                        title: bookingErrorText(snap.error),
                        actionLabel: 'common_retry'.tr(),
                        onAction: () {
                          setState(() {
                            _future = _repo.stay(widget.id, _language!);
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return _detail(context, data);
        },
      ),
    );
  }

  Widget _detail(BuildContext context, Fetched<StayDetail> result) {
    final d = result.value;
    final s = d.summary;
    final e = context.editorial;
    final fallback =
        d.contentLanguage != null &&
        d.contentLanguage != journeyLanguage(context);
    final gallery =
        d.images.isNotEmpty ? d.images : [if (s.image != null) s.image!];
    final actionUrl = d.bookingUrl ?? d.websiteUrl;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 150),
          children: [
            _Gallery(images: gallery, fallback: stayTypeIcon(s.stayType)),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                editorialMargin,
                AppSpacing.md,
                editorialMargin,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (s.image?.representative ?? false) ...[
                    Text(
                      'bk_area_photo_note'.tr(args: [s.image!.credit]),
                      style: e.meta,
                    ),
                    AppSpacing.gapMd,
                  ],
                  Text('bk_type_${s.stayType}'.tr(), style: e.kicker),
                  AppSpacing.gapXs,
                  Text(s.name, style: e.lead),
                  if (d.address != null) ...[
                    AppSpacing.gapXs,
                    Text(d.address!, style: e.meta),
                  ],
                  AppSpacing.gapSm,
                  TrustLine(verified: s.verified, date: s.lastVerified),
                  if (result.isSavedCopy) ...[
                    AppSpacing.gapSm,
                    Text('ak_saved_copy'.tr(), style: e.meta),
                  ],
                  if (fallback) ...[
                    AppSpacing.gapSm,
                    Text('ak_english_only'.tr(), style: e.meta),
                  ],
                  AppSpacing.gapLg,
                  const GhatRule(padding: EdgeInsets.zero),
                  AppSpacing.gapLg,
                  PriceBlock(stay: s, large: true),
                  if (d.priceNote.isNotEmpty) ...[
                    AppSpacing.gapXs,
                    Text(d.priceNote, style: e.meta),
                  ],
                  if (d.overview.isNotEmpty) ...[
                    AppSpacing.gapLg,
                    Text(d.overview, style: e.dek),
                  ],
                  if (d.rooms.isNotEmpty) ...[
                    AppSpacing.gapXl,
                    BookingSectionTitle('bk_rooms_title'.tr()),
                    for (final room in d.rooms)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: context.semanticColors.divider,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(room.name, style: e.title)),
                            if (room.price != null)
                              Text(rupees(room.price!), style: e.title),
                          ],
                        ),
                      ),
                  ],
                  if (s.amenities.isNotEmpty ||
                      s.accessible ||
                      s.familyFriendly ||
                      s.seniorFriendly) ...[
                    AppSpacing.gapXl,
                    BookingSectionTitle('bk_facilities'.tr()),
                    Wrap(
                      spacing: AppSpacing.xl,
                      runSpacing: AppSpacing.md,
                      children: [
                        for (final a in s.amenities)
                          _Facility(amenityIcon(a.slug), a.name),
                        if (s.familyFriendly)
                          _Facility(
                            Icons.family_restroom_rounded,
                            'bk_family'.tr(),
                          ),
                        if (s.seniorFriendly)
                          _Facility(Icons.elderly_rounded, 'bk_seniors'.tr()),
                        if (s.accessible)
                          _Facility(
                            Icons.accessible_rounded,
                            'bk_accessible'.tr(),
                          ),
                      ],
                    ),
                  ],
                  if (d.landmarks.isNotEmpty || d.temples.isNotEmpty) ...[
                    AppSpacing.gapXl,
                    BookingSectionTitle('bk_nearby'.tr()),
                    for (final l in d.landmarks) _Distance(place: l),
                    for (final t in d.temples)
                      _Distance(
                        place: t,
                        onTap:
                            () => Navigator.pushNamed(
                              context,
                              '/templeDetail',
                              arguments: TempleDetailArgs(
                                templeId: t.templeId!,
                                latitude: '',
                                longitude: '',
                              ),
                            ),
                      ),
                    AppSpacing.gapSm,
                    Text('bk_straight_line'.tr(), style: e.meta),
                  ],
                  if (d.latitude != null && d.longitude != null) ...[
                    AppSpacing.gapMd,
                    AppButton.outlined(
                      label: 'bk_open_map'.tr(),
                      leadingIcon: Icons.map_outlined,
                      onPressed:
                          () => openExternal(
                            context,
                            'https://www.google.com/maps/search/?api=1&query=${d.latitude},${d.longitude}',
                          ),
                    ),
                  ],
                  if (d.bookingInstructions.isNotEmpty) ...[
                    AppSpacing.gapXl,
                    BookingSectionTitle('bk_how_to_book'.tr()),
                    Text(d.bookingInstructions, style: e.reading),
                  ],
                  if (d.cancellationPolicy.isNotEmpty) ...[
                    AppSpacing.gapXl,
                    BookingSectionTitle('bk_cancellation'.tr()),
                    Text(d.cancellationPolicy, style: e.reading),
                  ],
                  if (d.phone != null || d.email != null) ...[
                    AppSpacing.gapXl,
                    BookingSectionTitle('bk_contact'.tr()),
                    if (d.phone != null)
                      TextButton.icon(
                        onPressed:
                            () => openExternal(context, 'tel:${d.phone}'),
                        icon: const Icon(Icons.call_outlined, size: 18),
                        label: Text(d.phone!),
                      ),
                    if (d.email != null)
                      TextButton.icon(
                        onPressed:
                            () => openExternal(context, 'mailto:${d.email}'),
                        icon: const Icon(Icons.mail_outline_rounded, size: 18),
                        label: Text(d.email!),
                      ),
                  ],
                  if (d.sources.isNotEmpty) ...[
                    AppSpacing.gapXl,
                    Text('ak_sources'.tr(), style: e.kicker),
                    AppSpacing.gapSm,
                    for (final source in d.sources)
                      InkWell(
                        onTap:
                            source.url == null
                                ? null
                                : () => openExternal(context, source.url!),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          child: Text(source.title, style: e.meta),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
        Positioned(
          left: AppSpacing.sm,
          top: 0,
          child: SafeArea(
            child: ImageIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Material(
            color: context.colorScheme.surface,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (actionUrl != null)
                      AppButton(
                        label:
                            (d.bookingUrl != null
                                    ? 'bk_book_on_site'
                                    : 'bk_visit_site')
                                .tr(),
                        trailingIcon: Icons.open_in_new_rounded,
                        onPressed: () => openExternal(context, actionUrl),
                      ),
                    TextButton(
                      onPressed:
                          () => Navigator.pushNamed(
                            context,
                            '/bookingForm',
                            arguments: BookingDraft(
                              title: s.name,
                              provider: d.provider ?? s.name,
                              url: d.bookingUrl,
                              stayId: s.id,
                            ),
                          ),
                      child: Text('bk_save_booking'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.images, required this.fallback});

  final List<ContentImage> images;
  final IconData fallback;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final height = (MediaQuery.sizeOf(context).height * 0.38).clamp(
      220.0,
      380.0,
    );
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: const GhatEdgeClipper(),
              child:
                  images.isEmpty
                      ? EditorialImage(url: null, fallbackIcon: widget.fallback)
                      : PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder:
                            (_, i) => EditorialImage(url: images[i].url),
                      ),
            ),
          ),
          if (images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 64,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < images.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: context.semanticColors.onImage,
                          borderRadius: AppRadius.mdAll,
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
}

class _Facility extends StatelessWidget {
  const _Facility(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20, color: context.colorScheme.primary),
      AppSpacing.gapSm,
      Flexible(child: Text(label, style: context.textTheme.bodyMedium)),
    ],
  );
}

class _Distance extends StatelessWidget {
  const _Distance({required this.place, this.onTap});

  final Landmark place;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
        child: Row(
          children: [
            Expanded(child: Text(place.name, style: e.title)),
            Text(
              'bk_km'.tr(args: [place.distanceKm.toStringAsFixed(1)]),
              style: e.title.copyWith(color: context.semanticColors.gold),
            ),
          ],
        ),
      ),
    );
  }
}
