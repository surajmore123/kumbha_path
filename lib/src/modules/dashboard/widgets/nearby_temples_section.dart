import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_event.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/models/near_temple.dart';
import 'package:kumbha_path/src/modules/dashboard/dashboard_controller.dart';
import 'package:kumbha_path/src/modules/dashboard/dashboard_formatters.dart';
import 'package:kumbha_path/src/modules/dashboard/widgets/dashboard_section.dart';

/// Up to three temples from the nearby-temples API, closest first as the API
/// returns them. Distances are the API's `distance_km`, computed from the
/// device position; nothing is shown when location isn't available.
class NearbyTemplesSection extends StatelessWidget {
  const NearbyTemplesSection({
    super.key,
    required this.access,
    required this.templesBloc,
    required this.locale,
    required this.onAllowLocation,
    required this.onRetry,
    required this.onOpenTemple,
    required this.onSeeAll,
  });

  final ValueListenable<LocationAccess> access;
  final Bloc<AppEvent, AppState> templesBloc;
  final String locale;
  final VoidCallback onAllowLocation;
  final VoidCallback onRetry;
  final ValueChanged<TempleModel> onOpenTemple;
  final VoidCallback onSeeAll;

  static const int previewCount = 3;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LocationAccess>(
      valueListenable: access,
      builder: (context, access, _) {
        final canSeeAll = access == LocationAccess.available;
        return DashboardSection(
          title: 'dash_nearby_title'.tr(),
          actionLabel: canSeeAll ? 'dash_see_all'.tr() : null,
          onAction: canSeeAll ? onSeeAll : null,
          child: switch (access) {
            LocationAccess.checking => const _TempleSkeleton(),
            LocationAccess.needsPermission => _LocationPrompt(
              onAllow: onAllowLocation,
            ),
            LocationAccess.unavailable => AppCard(
              padding: EdgeInsets.zero,
              child: AppEmptyState(
                compact: true,
                icon: Icons.location_off_outlined,
                title: 'dash_location_needed_title'.tr(),
                message: 'dash_location_unavailable'.tr(),
                actionLabel: 'common_retry'.tr(),
                actionIcon: Icons.refresh_rounded,
                onAction: onAllowLocation,
              ),
            ),
            LocationAccess.available =>
              BlocBuilder<Bloc<AppEvent, AppState>, AppState>(
                bloc: templesBloc,
                builder: (context, state) {
                  return switch (state.status) {
                    AppStatus.initial ||
                    AppStatus.loading => const _TempleSkeleton(),
                    AppStatus.failure => AppCard(
                      padding: EdgeInsets.zero,
                      child: AppErrorView(compact: true, onRetry: onRetry),
                    ),
                    _ => _TempleList(
                      temples:
                          (state.nearbyTemples.temples ?? const [])
                              .take(previewCount)
                              .toList(),
                      locale: locale,
                      onOpen: onOpenTemple,
                    ),
                  };
                },
              ),
          },
        );
      },
    );
  }
}

class _LocationPrompt extends StatelessWidget {
  const _LocationPrompt({required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final text = context.textTheme;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSpacing.minTouchTarget,
            height: AppSpacing.minTouchTarget,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.near_me_outlined,
              color: colors.onPrimaryContainer,
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'dash_location_needed_title'.tr(),
                  style: text.titleMedium,
                ),
                AppSpacing.gapXs,
                Text(
                  'dash_location_needed_message'.tr(),
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                AppSpacing.gapMd,
                AppButton.secondary(
                  label: 'dash_location_allow'.tr(),
                  leadingIcon: Icons.my_location,
                  expand: false,
                  onPressed: onAllow,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TempleList extends StatelessWidget {
  const _TempleList({
    required this.temples,
    required this.locale,
    required this.onOpen,
  });

  final List<TempleModel> temples;
  final String locale;
  final ValueChanged<TempleModel> onOpen;

  @override
  Widget build(BuildContext context) {
    if (temples.isEmpty) {
      return AppCard(
        padding: EdgeInsets.zero,
        child: AppEmptyState(
          compact: true,
          icon: Icons.temple_hindu_outlined,
          title: 'dash_nearby_empty'.tr(),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < temples.length; i++) ...[
          if (i > 0) AppSpacing.gapMd,
          _TempleTile(
            temple: temples[i],
            locale: locale,
            onTap: () => onOpen(temples[i]),
          ),
        ],
      ],
    );
  }
}

class _TempleTile extends StatelessWidget {
  const _TempleTile({
    required this.temple,
    required this.locale,
    required this.onTap,
  });

  final TempleModel temple;
  final String locale;
  final VoidCallback onTap;

  static const double _thumb = 76;
  static const String _placeholder = 'assets/images/placeholder.jpg';

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colorScheme;
    final name = (temple.name ?? '').trim();
    final city = (temple.city ?? '').trim();
    final distance = formatDistanceKm(temple.distanceKm, locale);
    final level = crowdLevelOf(temple.crowdLevel);
    final crowd =
        level == CrowdLevel.unknown
            ? null
            : crowdStyle(context, level, temple.crowdLevel);
    final url = (temple.imageUrl ?? '').trim();
    final dpr = MediaQuery.devicePixelRatioOf(context);

    Widget placeholder() => Image.asset(
      _placeholder,
      fit: BoxFit.cover,
      cacheWidth: (_thumb * dpr).round(),
    );

    return AppCard(
      onTap: onTap,
      semanticLabel: name,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.mdAll,
            child: SizedBox.square(
              dimension: _thumb,
              child:
                  url.isEmpty
                      ? placeholder()
                      : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        memCacheWidth: (_thumb * dpr).round(),
                        placeholder:
                            (_, __) =>
                                ColoredBox(color: colors.surfaceContainerHigh),
                        errorWidget: (_, __, ___) => placeholder(),
                      ),
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
                if (city.isNotEmpty || distance != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(
                      [
                        if (distance != null)
                          'dash_km_away'.tr(args: [distance]),
                        if (city.isNotEmpty) city,
                      ].join(' · '),
                      style: text.bodySmall,
                    ),
                  ),
                if (crowd != null) ...[
                  AppSpacing.gapSm,
                  StatusPill(
                    label: crowd.label,
                    icon: Icons.groups_outlined,
                    foreground: crowd.fg,
                    background: crowd.bg,
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _TempleSkeleton extends StatelessWidget {
  const _TempleSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonBlock(height: 100),
        SizedBox(height: AppSpacing.md),
        SkeletonBlock(height: 100),
      ],
    );
  }
}
