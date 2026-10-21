import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/place_format.dart';
import 'package:kumbha_path/src/models/near_temple.dart';

/// Temple photo from the API's `image_url`, falling back to the bundled
/// placeholder when missing or unloadable.
class TempleImage extends StatelessWidget {
  const TempleImage({super.key, required this.url, this.decodeWidth});

  final String? url;

  /// Logical width the image is shown at, to decode at display size.
  final double? decodeWidth;

  static const String placeholder = 'assets/images/placeholder.jpg';

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cache = decodeWidth == null ? null : (decodeWidth! * dpr).round();
    final fallback = Image.asset(
      placeholder,
      fit: BoxFit.cover,
      cacheWidth: cache,
      excludeFromSemantics: true,
    );
    final src = (url ?? '').trim();
    if (src.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: src,
      fit: BoxFit.cover,
      memCacheWidth: cache,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder:
          (_, __) =>
              ColoredBox(color: context.colorScheme.surfaceContainerHigh),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

/// Crowd level from the API as a pill; nothing when the API sent none.
class TempleCrowdPill extends StatelessWidget {
  const TempleCrowdPill({super.key, required this.crowdLevel});

  final String? crowdLevel;

  @override
  Widget build(BuildContext context) {
    final level = crowdLevelOf(crowdLevel);
    if (level == CrowdLevel.unknown) return const SizedBox.shrink();
    final style = crowdStyle(context, level, crowdLevel);
    return StatusPill(
      label: style.label,
      icon: Icons.groups_outlined,
      foreground: style.fg,
      background: style.bg,
    );
  }
}

/// One temple in the Explorer list: photo first, then name and the
/// location details the API provides.
class TempleCard extends StatelessWidget {
  const TempleCard({
    super.key,
    required this.temple,
    required this.locale,
    required this.onTap,
  });

  final TempleModel temple;
  final String locale;
  final VoidCallback onTap;

  static const double _imageAspect = 16 / 9;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colorScheme;
    final name = (temple.name ?? '').trim();
    final city = (temple.city ?? '').trim();
    final distance = formatDistanceKm(temple.distanceKm, locale);
    final meta = [
      if (distance != null) 'dash_km_away'.tr(args: [distance]),
      if (city.isNotEmpty) city,
    ];
    final message = (temple.crowdMessage ?? '').trim();

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      semanticLabel: [name, ...meta].join(', '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder:
                (context, constraints) => AspectRatio(
                  aspectRatio: _imageAspect,
                  child: TempleImage(
                    url: temple.imageUrl,
                    decodeWidth: constraints.maxWidth,
                  ),
                ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
                if (meta.isNotEmpty) ...[
                  AppSpacing.gapXs,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      AppSpacing.gapXs,
                      Expanded(
                        child: Text(meta.join(' · '), style: text.bodySmall),
                      ),
                    ],
                  ),
                ],
                if (crowdLevelOf(temple.crowdLevel) != CrowdLevel.unknown ||
                    message.isNotEmpty) ...[
                  AppSpacing.gapSm,
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TempleCrowdPill(crowdLevel: temple.crowdLevel),
                      if (message.isNotEmpty)
                        Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
