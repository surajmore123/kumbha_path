import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_bloc.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_event.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/location_service.dart';
import 'package:kumbha_path/src/constant/place_format.dart';
import 'package:kumbha_path/src/models/near_temple.dart';
import 'package:kumbha_path/src/modules/temple_explorer/temple_detail_screen.dart';
import 'package:kumbha_path/src/modules/temple_explorer/widgets/temple_card.dart';
import 'package:kumbha_path/src/modules/temple_explorer/widgets/temple_map.dart';

/// `/nearTemples`: temples around the user from the nearby-temples API.
///
/// Arguments (optional, as sent by the dashboard): `{'lat': .., 'lng': ..}`.
/// Without them the screen checks location permission and, only when the
/// user taps "Allow location", shows the system prompt.
///
/// The only filter the API supports is the search radius; there is no
/// search or category parameter, so none is shown.
class NearTemples extends StatefulWidget {
  const NearTemples({super.key, this.location});

  /// Injected in tests.
  final LocationGateway? location;

  @override
  State<NearTemples> createState() => _NearTemplesState();
}

class _NearTemplesState extends State<NearTemples> with WidgetsBindingObserver {
  static const List<int> radiusOptions = [2, 5, 10];
  static const int pageSize = 5;

  late final LocationGateway _location =
      widget.location ?? const LocationGateway();

  int selectedRadius = 5;
  bool _initialized = false;
  double? userLat;
  double? userLng;

  /// `null` while checking; meaningful only when coordinates are missing.
  LocationAccess? _access;
  bool _loadingMore = false;

  bool get _hasPosition => userLat != null && userLng != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Returning from system settings may have fixed location access.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_hasPosition) _checkAccess();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final bloc = context.read<AppBloc>();
    final loadedRadius = bloc.state.nearbyTemples.radiusKm?.round();
    if (radiusOptions.contains(loadedRadius)) selectedRadius = loadedRadius!;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['lat'] != null && args['lng'] != null) {
      userLat = double.tryParse(args['lat'].toString());
      userLng = double.tryParse(args['lng'].toString());
    } else if (bloc.state.lastUserLat != null &&
        bloc.state.lastUserLng != null) {
      userLat = double.tryParse(bloc.state.lastUserLat!);
      userLng = double.tryParse(bloc.state.lastUserLng!);
    }

    if (_hasPosition) {
      // The dashboard has normally loaded these already; don't refetch.
      if (bloc.state.status == AppStatus.initial) _load();
    } else {
      _checkAccess();
    }
  }

  Future<void> _checkAccess() async {
    final access = await _location.currentAccess();
    if (!mounted) return;
    if (access == LocationAccess.available) {
      await _requestPosition();
    } else {
      setState(() => _access = access);
    }
  }

  /// May show the system permission prompt (user-initiated, or when
  /// permission is already granted).
  Future<void> _requestPosition() async {
    setState(() => _access = null);
    try {
      final position = await _location.currentPosition();
      if (!mounted) return;
      setState(() {
        userLat = position.latitude;
        userLng = position.longitude;
      });
      _load();
    } catch (_) {
      final access = await _location.currentAccess();
      if (!mounted) return;
      setState(
        () =>
            _access =
                access == LocationAccess.available
                    ? LocationAccess.needsPermission
                    : access,
      );
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('dash_location_error'.tr())));
    }
  }

  /// Same event and parameters as before (limit 5, cursor for "more").
  void _load({bool more = false}) {
    if (!_hasPosition) return;
    if (more) setState(() => _loadingMore = true);
    context.read<AppBloc>().add(
      GetNearbyTemplesEvent(
        latitude: userLat.toString(),
        longitude: userLng.toString(),
        radius: selectedRadius.toString(),
        limit: pageSize,
        isLoadMore: more,
      ),
    );
  }

  void _changeRadius(int radius) {
    if (radius == selectedRadius) return;
    setState(() => selectedRadius = radius);
    _load();
  }

  /// Same flow as before: request the detail into the shared
  /// AppDetailsBloc, then open `/templeDetail`. The arguments are new and
  /// optional; they let the detail screen retry a failed load.
  void _openTemple(TempleModel temple) {
    final id = temple.templeId.toString();
    final lat = userLat?.toString() ?? '';
    final lng = userLng?.toString() ?? '';
    context.read<AppDetailsBloc>().add(
      GetTempleDetail(templeId: id, latitude: lat, longitude: lng),
    );
    Navigator.pushNamed(
      context,
      '/templeDetail',
      arguments: TempleDetailArgs(templeId: id, latitude: lat, longitude: lng),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale =
        EasyLocalization.of(context)?.locale.languageCode ??
        Localizations.localeOf(context).languageCode;

    return MainLayout(
      showDefaultBottom: true,
      ctx: 0,
      appBar: AppAppBar(title: 'temple_explorer_title'.tr()),
      body: BlocConsumer<AppBloc, AppState>(
        listenWhen:
            (prev, next) =>
                prev.status != next.status ||
                prev.nearbyTemples != next.nearbyTemples,
        listener: (context, state) {
          if (_loadingMore && state.status != AppStatus.loading) {
            setState(() => _loadingMore = false);
          }
        },
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () async {
              if (!_hasPosition) return _checkAccess();
              final done = context.read<AppBloc>().stream.firstWhere(
                (s) => s.status != AppStatus.loading,
              );
              _load();
              await done.timeout(
                const Duration(seconds: 30),
                onTimeout: () => state,
              );
            },
            child: LayoutBuilder(
              builder:
                  (context, constraints) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.pageGutter,
                      AppSpacing.sm,
                      AppSpacing.pageGutter,
                      AppSpacing.huge,
                    ),
                    children: [
                      Text(
                        'temple_intro'.tr(),
                        style: context.textTheme.bodyLarge?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      AppSpacing.gapLg,
                      ..._content(state, locale, constraints.maxWidth),
                    ],
                  ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _content(AppState state, String locale, double width) {
    if (!_hasPosition) {
      return [
        switch (_access) {
          null => const _ListSkeleton(),
          LocationAccess.unavailable => AppCard(
            padding: EdgeInsets.zero,
            child: AppEmptyState(
              compact: true,
              icon: Icons.location_disabled_outlined,
              title: 'temple_location_title'.tr(),
              message: 'temple_location_off'.tr(),
              actionLabel: 'temple_open_settings'.tr(),
              actionIcon: Icons.settings_outlined,
              onAction: _location.openSettings,
            ),
          ),
          _ => AppCard(
            padding: EdgeInsets.zero,
            child: AppEmptyState(
              compact: true,
              icon: Icons.near_me_outlined,
              title: 'temple_location_title'.tr(),
              message: 'temple_location_message'.tr(),
              actionLabel: 'dash_location_allow'.tr(),
              actionIcon: Icons.my_location,
              onAction: _requestPosition,
            ),
          ),
        },
      ];
    }

    final temples = state.nearbyTemples.temples ?? const <TempleModel>[];
    final total = state.nearbyTemples.count ?? temples.length;
    final loading = state.status == AppStatus.loading && !_loadingMore;

    final header = <Widget>[
      _RadiusSelector(
        selected: selectedRadius,
        options: radiusOptions,
        enabled: !loading,
        onSelected: _changeRadius,
      ),
      AppSpacing.gapLg,
    ];

    if (loading || state.status == AppStatus.initial) {
      return [...header, const _ListSkeleton()];
    }
    if (state.status == AppStatus.failure) {
      return [
        ...header,
        AppCard(
          padding: EdgeInsets.zero,
          child: AppErrorView(compact: true, onRetry: _load),
        ),
      ];
    }
    if (temples.isEmpty) {
      final wider = radiusOptions.where((r) => r > selectedRadius);
      return [
        ...header,
        AppCard(
          padding: EdgeInsets.zero,
          child: AppEmptyState(
            compact: true,
            icon: Icons.temple_hindu_outlined,
            title: 'temple_empty_title'.tr(args: ['$selectedRadius']),
            message: wider.isEmpty ? null : 'temple_empty_message'.tr(),
            actionLabel:
                wider.isEmpty
                    ? null
                    : 'temple_widen_radius'.tr(args: ['${wider.first}']),
            onAction: wider.isEmpty ? null : () => _changeRadius(wider.first),
          ),
        ),
      ];
    }

    return [
      ...header,
      _TempleMapPreview(
        temples: temples,
        user: LatLng(userLat!, userLng!),
        radiusKm: selectedRadius,
        locale: locale,
        onOpenTemple: _openTemple,
      ),
      AppSpacing.gapLg,
      Text(
        'temple_showing'.tr(
          namedArgs: {
            'shown': '${temples.length}',
            'total': '${total < temples.length ? temples.length : total}',
            'radius': '$selectedRadius',
          },
        ),
        style: context.textTheme.labelLarge?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
      AppSpacing.gapMd,
      _TempleGrid(
        temples: temples,
        width: width - AppSpacing.pageGutter * 2,
        locale: locale,
        onOpen: _openTemple,
      ),
      // Same condition as before for offering the next page.
      if (temples.length < (state.nearbyTemples.count ?? 0)) ...[
        AppSpacing.gapLg,
        Center(
          child: AppButton.outlined(
            label: 'temple_load_more'.tr(),
            leadingIcon: Icons.expand_more_rounded,
            isLoading: _loadingMore,
            expand: false,
            onPressed: () => _load(more: true),
          ),
        ),
      ],
    ];
  }
}

class _RadiusSelector extends StatelessWidget {
  const _RadiusSelector({
    required this.selected,
    required this.options,
    required this.enabled,
    required this.onSelected,
  });

  final int selected;
  final List<int> options;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('temple_radius_label'.tr(), style: context.textTheme.titleSmall),
        AppSpacing.gapSm,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final km in options)
              ChoiceChip(
                label: Text('temple_radius_km'.tr(args: ['$km'])),
                selected: km == selected,
                onSelected: enabled ? (_) => onSelected(km) : null,
              ),
          ],
        ),
      ],
    );
  }
}

/// Non-interactive overview: the user, the search radius and each temple
/// that has coordinates. Tapping a marker's label opens that temple.
class _TempleMapPreview extends StatelessWidget {
  const _TempleMapPreview({
    required this.temples,
    required this.user,
    required this.radiusKm,
    required this.locale,
    required this.onOpenTemple,
  });

  final List<TempleModel> temples;
  final LatLng user;
  final int radiusKm;
  final String locale;
  final ValueChanged<TempleModel> onOpenTemple;

  static const double _height = 200;

  static double zoomForRadius(int km) => switch (km) {
    2 => 13.5,
    5 => 12.2,
    _ => 11.2,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('user'),
        position: user,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        zIndexInt: 1,
      ),
      for (final t in temples)
        if (parseTempleLatLng(t.latitude, t.longitude) case final pos?)
          Marker(
            markerId: MarkerId('temple-${t.templeId}'),
            position: pos,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: t.name,
              snippet:
                  formatDistanceKm(t.distanceKm, locale) == null
                      ? null
                      : 'dash_km_away'.tr(
                        args: [formatDistanceKm(t.distanceKm, locale)!],
                      ),
              onTap: () => onOpenTemple(t),
            ),
          ),
    };

    return Semantics(
      label: 'temple_map_preview'.tr(),
      child: ClipRRect(
        borderRadius: AppRadius.cardAll,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardAll,
            border: Border.all(color: context.semanticColors.border),
          ),
          child: SizedBox(
            height: _height,
            child: TempleMap(
              config: TempleMapConfig(
                target: user,
                zoom: zoomForRadius(radiusKm),
                interactive: false,
                markers: markers,
                circles: {
                  Circle(
                    circleId: const CircleId('radius'),
                    center: user,
                    radius: radiusKm * 1000.0,
                    fillColor: colors.primary.withValues(alpha: 0.08),
                    strokeColor: colors.primary.withValues(alpha: 0.45),
                    strokeWidth: 1,
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 1 column on phones, 2 on tablets, 3 on wide screens.
class _TempleGrid extends StatelessWidget {
  const _TempleGrid({
    required this.temples,
    required this.width,
    required this.locale,
    required this.onOpen,
  });

  final List<TempleModel> temples;
  final double width;
  final String locale;
  final ValueChanged<TempleModel> onOpen;

  @override
  Widget build(BuildContext context) {
    final columns =
        width >= 960
            ? 3
            : width >= 560
            ? 2
            : 1;
    final rows = <Widget>[];
    for (var i = 0; i < temples.length; i += columns) {
      if (rows.isNotEmpty) rows.add(AppSpacing.gapLg);
      final slice = temples.skip(i).take(columns).toList();
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < columns; j++) ...[
              if (j > 0) AppSpacing.gapLg,
              Expanded(
                child:
                    j < slice.length
                        ? TempleCard(
                          temple: slice[j],
                          locale: locale,
                          onTap: () => onOpen(slice[j]),
                        )
                        : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double h) => Container(
      height: h,
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.cardAll,
      ),
    );
    return Semantics(
      label: 'common_loading'.tr(),
      child: Column(
        children: [
          block(200),
          AppSpacing.gapLg,
          block(240),
          AppSpacing.gapLg,
          block(240),
        ],
      ),
    );
  }
}
