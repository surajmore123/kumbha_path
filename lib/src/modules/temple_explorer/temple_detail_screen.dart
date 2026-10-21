import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/location_service.dart';
import 'package:kumbha_path/src/constant/place_format.dart';
import 'package:kumbha_path/src/models/temple_detail.dart';
import 'package:kumbha_path/src/modules/temple_explorer/temple_navigation_map.dart';
import 'package:kumbha_path/src/modules/temple_explorer/widgets/temple_card.dart';
import 'package:kumbha_path/src/modules/temple_explorer/widgets/temple_map.dart';

/// Optional `/templeDetail` arguments. Callers that push without them
/// (as before) still work; with them, a failed load can be retried and a
/// previous temple's data is never shown for a new one.
@immutable
class TempleDetailArgs {
  const TempleDetailArgs({
    required this.templeId,
    required this.latitude,
    required this.longitude,
  });

  final String templeId;

  /// User position sent with the detail request (may be empty).
  final String latitude;
  final String longitude;
}

/// `/templeDetail`: renders `AppDetailsState.templeDetail`, which the
/// caller requested with `GetTempleDetail` before pushing (unchanged flow).
///
/// Only API fields are shown: name, image, city/state, description, crowd
/// level/message and coordinates. The API has no timings, facilities or
/// fees, so none are displayed.
class TempleDetailsScreen extends StatefulWidget {
  const TempleDetailsScreen({super.key, this.location});

  /// Injected in tests.
  final LocationGateway? location;

  @override
  State<TempleDetailsScreen> createState() => _TempleDetailsScreenState();
}

class _TempleDetailsScreenState extends State<TempleDetailsScreen> {
  late final LocationGateway _location =
      widget.location ?? const LocationGateway();
  bool _openingDirections = false;

  TempleDetailArgs? get _args {
    final a = ModalRoute.of(context)?.settings.arguments;
    return a is TempleDetailArgs ? a : null;
  }

  void _retry(TempleDetailArgs args) {
    context.read<AppDetailsBloc>().add(
      GetTempleDetail(
        templeId: args.templeId,
        latitude: args.latitude,
        longitude: args.longitude,
      ),
    );
  }

  /// Same flow as before: get the user's position, open the navigation map,
  /// then report the navigation with `TempleNavigate`. If the position
  /// can't be obtained the map still opens (it handles that itself), and
  /// `TempleNavigate`, which needs the position, is skipped.
  Future<void> _openDirections(TempleDetailsModel temple, LatLng dest) async {
    if (_openingDirections) return;
    setState(() => _openingDirections = true);
    Position? position;
    try {
      position = await _location.currentPosition();
    } catch (_) {
      position = null;
    }
    if (!mounted) return;
    setState(() => _openingDirections = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => TempleNavigationMap(
              templelat: dest.latitude,
              templelng: dest.longitude,
              templeName: temple.name ?? '',
            ),
      ),
    );
    if (position != null) {
      context.read<AppDetailsBloc>().add(
        TempleNavigate(
          templeId: temple.templeId.toString(),
          latitude: position.latitude.toString(),
          longitude: position.longitude.toString(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = _args;
    return MainLayout(
      showDefaultBottom: false,
      ctx: 0,
      appBar: AppAppBar(title: 'temple_details_title'.tr()),
      body: BlocBuilder<AppDetailsBloc, AppDetailsState>(
        buildWhen:
            (a, b) => a.status != b.status || a.templeDetail != b.templeDetail,
        builder: (context, state) {
          final data = state.templeDetail;
          final id = (data.templeId ?? '').trim();
          final sameTemple = args == null || id.isEmpty || id == args.templeId;
          final hasData = (data.name ?? '').trim().isNotEmpty && sameTemple;
          // Other requests share this bloc's status (e.g. TempleNavigate);
          // keep showing a matching temple while they run.
          final keepContent = hasData && args != null && id == args.templeId;

          final Widget child;
          if ((state.status == AppDetailsStatus.loading && !keepContent) ||
              (state.status == AppDetailsStatus.initial && !hasData)) {
            child = const _DetailSkeleton();
          } else if (hasData) {
            child = _TempleDetailBody(
              temple: data,
              openingDirections: _openingDirections,
              onDirections: _openDirections,
            );
          } else {
            child = Center(
              child: AppErrorView(
                onRetry: args == null ? null : () => _retry(args),
              ),
            );
          }
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(key: ValueKey(child.runtimeType), child: child),
          );
        },
      ),
    );
  }
}

class _TempleDetailBody extends StatelessWidget {
  const _TempleDetailBody({
    required this.temple,
    required this.openingDirections,
    required this.onDirections,
  });

  final TempleDetailsModel temple;
  final bool openingDirections;
  final void Function(TempleDetailsModel, LatLng) onDirections;

  static const double _maxWidth = 760;

  @override
  Widget build(BuildContext context) {
    final position = parseTempleLatLng(temple.latitude, temple.longitude);
    final description = (temple.description ?? '').trim();
    final hasCrowd =
        crowdLevelOf(temple.crowdLevel) != CrowdLevel.unknown ||
        (temple.crowdMessage ?? '').trim().isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            constraints.maxWidth > _maxWidth + AppSpacing.pageGutter * 2
                ? (constraints.maxWidth - _maxWidth) / 2
                : AppSpacing.pageGutter;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            side,
            AppSpacing.sm,
            side,
            AppSpacing.huge,
          ),
          children: [
            _Hero(temple: temple),
            AppSpacing.gapLg,
            AppButton(
              label: 'temple_directions'.tr(),
              leadingIcon: Icons.directions_outlined,
              isLoading: openingDirections,
              onPressed:
                  position == null
                      ? null
                      : () => onDirections(temple, position),
            ),
            if (position == null) ...[
              AppSpacing.gapSm,
              Text(
                'temple_no_coordinates'.tr(),
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall,
              ),
            ],
            if (hasCrowd) ...[
              AppSpacing.gapXxl,
              _Section(
                title: 'temple_crowd_heading'.tr(),
                child: _CrowdInfo(temple: temple),
              ),
            ],
            if (description.isNotEmpty) ...[
              AppSpacing.gapXxl,
              _Section(
                title: 'temple_about'.tr(),
                child: _ExpandableText(text: description),
              ),
            ],
            if (position != null) ...[
              AppSpacing.gapXxl,
              _Section(
                title: 'temple_location_heading'.tr(),
                child: _LocationPreview(
                  temple: temple,
                  position: position,
                  onTap: () => onDirections(temple, position),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

String _place(TempleDetailsModel t) => [
  (t.city ?? '').trim(),
  (t.state ?? '').trim(),
].where((s) => s.isNotEmpty).join(', ');

class _Hero extends StatelessWidget {
  const _Hero({required this.temple});

  final TempleDetailsModel temple;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final text = context.textTheme;
    final place = _place(temple);

    return ClipRRect(
      borderRadius: AppRadius.xlAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 240),
        child: Stack(
          alignment: AlignmentDirectional.bottomStart,
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder:
                    (context, c) => TempleImage(
                      url: temple.imageUrl,
                      decodeWidth: c.maxWidth,
                    ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.35, 1.0],
                    colors: [
                      semantic.imageScrim.withValues(alpha: 0.0),
                      semantic.imageScrim.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.huge * 2,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      temple.name!.trim(),
                      style: text.headlineSmall?.copyWith(
                        color: semantic.onImage,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (place.isNotEmpty) ...[
                    AppSpacing.gapXs,
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: semantic.onImage.withValues(alpha: 0.9),
                        ),
                        AppSpacing.gapXs,
                        Expanded(
                          child: Text(
                            place,
                            style: text.bodyMedium?.copyWith(
                              color: semantic.onImage.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [AppSectionHeader(title: title), AppSpacing.gapMd, child],
    );
  }
}

class _CrowdInfo extends StatelessWidget {
  const _CrowdInfo({required this.temple});

  final TempleDetailsModel temple;

  @override
  Widget build(BuildContext context) {
    final message = (temple.crowdMessage ?? '').trim();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TempleCrowdPill(crowdLevel: temple.crowdLevel),
          if (message.isNotEmpty) ...[
            AppSpacing.gapSm,
            Text(message, style: context.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Long descriptions start collapsed with a "Read more" toggle.
class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  static const int _collapsedLines = 6;
  static const int _longThreshold = 320;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.bodyLarge?.copyWith(height: 1.6);
    final long = widget.text.length > _longThreshold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: Text(
            widget.text,
            style: style,
            maxLines: long && !_expanded ? _collapsedLines : null,
            overflow: long && !_expanded ? TextOverflow.fade : null,
          ),
        ),
        if (long)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'temple_show_less'.tr() : 'temple_read_more'.tr(),
            ),
          ),
      ],
    );
  }
}

class _LocationPreview extends StatelessWidget {
  const _LocationPreview({
    required this.temple,
    required this.position,
    required this.onTap,
  });

  final TempleDetailsModel temple;
  final LatLng position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final place = _place(temple);
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      semanticLabel: 'temple_directions'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 160,
            // Taps go to the card (directions), not the static map.
            child: IgnorePointer(
              child: TempleMap(
                config: TempleMapConfig(
                  target: position,
                  zoom: 15,
                  interactive: false,
                  liteMode: true,
                  markers: {
                    Marker(
                      markerId: const MarkerId('temple'),
                      position: position,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange,
                      ),
                    ),
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: AppSpacing.card,
            child: Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                AppSpacing.gapSm,
                Expanded(
                  child: Text(
                    place.isNotEmpty ? place : (temple.name ?? ''),
                    style: context.textTheme.bodyMedium,
                  ),
                ),
                Icon(
                  Icons.directions_outlined,
                  color: context.colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

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
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageGutter),
        children: [
          block(260),
          AppSpacing.gapLg,
          block(AppSpacing.minTouchTarget),
          AppSpacing.gapXxl,
          block(140),
        ],
      ),
    );
  }
}
