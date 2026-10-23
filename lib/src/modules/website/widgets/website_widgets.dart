import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/display_format.dart';
import 'package:kumbha_path/src/models/website_models.dart';
import 'package:kumbha_path/src/repository/repository/website_repository.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [uri] in the browser; shows a snackbar when it can't.
Future<void> openExternal(BuildContext context, Uri uri) async {
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('web_open_failed'.tr())));
  }
}

/// Colors, icon and label for an announcement kind.
({Color fg, Color bg, IconData icon, String label}) announcementStyle(
  BuildContext context,
  AnnouncementKind kind,
) {
  final s = context.semanticColors;
  final c = context.colorScheme;
  return switch (kind) {
    AnnouncementKind.alert => (
      fg: c.onErrorContainer,
      bg: c.errorContainer,
      icon: Icons.warning_amber_rounded,
      label: 'web_ann_kind_alert'.tr(),
    ),
    AnnouncementKind.official => (
      fg: s.onInfoContainer,
      bg: s.infoContainer,
      icon: Icons.verified_outlined,
      label: 'web_ann_kind_official'.tr(),
    ),
    AnnouncementKind.info => (
      fg: c.onSecondaryContainer,
      bg: c.secondaryContainer,
      icon: Icons.campaign_outlined,
      label: 'web_ann_kind_info'.tr(),
    ),
  };
}

/// One admin announcement. Long text folds to four lines with an animated
/// "Read more".
class AnnouncementCard extends StatefulWidget {
  const AnnouncementCard({
    super.key,
    required this.announcement,
    required this.locale,
  });

  final Announcement announcement;
  final String locale;

  @override
  State<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<AnnouncementCard> {
  static const int _foldedLines = 4;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;
    final text = context.textTheme;
    final colors = context.colorScheme;
    final style = announcementStyle(context, a.kind);
    final body = a.body ?? '';
    final date = formatEventDate(
      a.createdAt?.toIso8601String(),
      widget.locale,
    );
    final link = WebsiteRepository.announcementLink(a.link);
    final isAlert = a.kind == AnnouncementKind.alert;

    return AppCard(
      variant: isAlert ? AppCardVariant.filled : AppCardVariant.outlined,
      color: isAlert ? colors.errorContainer.withValues(alpha: 0.35) : null,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: style.label,
                foreground: style.fg,
                background: style.bg,
                icon: style.icon,
              ),
              const Spacer(),
              if (a.pinned)
                Tooltip(
                  message: 'web_ann_pinned'.tr(),
                  child: Icon(
                    Icons.push_pin_rounded,
                    size: 18,
                    color: colors.primary,
                  ),
                ),
            ],
          ),
          AppSpacing.gapMd,
          Text(a.title, style: text.titleMedium),
          if (body.isNotEmpty) ...[
            AppSpacing.gapXs,
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Text(
                body,
                maxLines: _expanded ? null : _foldedLines,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final painter = TextPainter(
                  text: TextSpan(text: body, style: text.bodyMedium),
                  maxLines: _foldedLines,
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: constraints.maxWidth);
                final overflows = painter.didExceedMaxLines;
                painter.dispose();
                if (!overflows) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      (_expanded ? 'web_read_less' : 'web_read_more').tr(),
                    ),
                  ),
                );
              },
            ),
          ],
          if (date != null || link != null) ...[
            AppSpacing.gapSm,
            Row(
              children: [
                if (date != null)
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                        AppSpacing.gapXs,
                        Flexible(
                          child: Text(
                            date,
                            style: text.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                if (link != null)
                  TextButton.icon(
                    onPressed: () => openExternal(context, link),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text('web_ann_open_link'.tr()),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact dashboard banner for the top announcement; the icon pulses
/// gently for alerts (not with "reduce motion" on).
class AnnouncementBanner extends StatelessWidget {
  const AnnouncementBanner({
    super.key,
    required this.announcement,
    required this.onTap,
    this.more = 0,
  });

  final Announcement announcement;
  final VoidCallback onTap;

  /// How many other announcements are on show.
  final int more;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final style = announcementStyle(context, a.kind);
    final text = context.textTheme;
    return PressScale(
      onTap: onTap,
      child: AppCard(
        variant: AppCardVariant.filled,
        color: style.bg,
        onTap: onTap,
        semanticLabel: a.title,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            _Pulse(
              enabled: a.kind == AnnouncementKind.alert,
              child: Icon(style.icon, color: style.fg),
            ),
            AppSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.label,
                    style: text.labelMedium?.copyWith(color: style.fg),
                  ),
                  Text(
                    a.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(color: style.fg),
                  ),
                  if (more > 0)
                    Text(
                      'web_ann_more'.tr(args: ['$more']),
                      style: text.labelSmall?.copyWith(color: style.fg),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: style.fg),
          ],
        ),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate =
        widget.enabled && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!animate) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 1.18).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

/// "From ₹1,200 / night", or "See official rates" when the price is 0.
String listingPriceLabel(Listing l) {
  if (l.priceFrom <= 0) return 'web_listing_official_rates'.tr();
  String amount;
  try {
    amount = intl.NumberFormat.decimalPattern('en_IN').format(l.priceFrom);
  } catch (_) {
    amount = '${l.priceFrom}';
  }
  final unit = l.unit.isEmpty ? '' : ' / ${l.unit}';
  return 'web_listing_price_from'.tr(args: ['₹$amount$unit']);
}

String listingHeroTag(Listing l) => 'listing-image-${l.id}';

/// The listing's website photo, or a tinted icon placeholder.
class ListingImage extends StatelessWidget {
  const ListingImage({super.key, required this.listing});

  final Listing listing;

  static IconData categoryIcon(ListingCategory c) => switch (c) {
    ListingCategory.hotels => Icons.hotel_outlined,
    ListingCategory.cabs => Icons.local_taxi_outlined,
    ListingCategory.tours => Icons.tour_outlined,
    ListingCategory.packages => Icons.card_travel_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final placeholder = ColoredBox(
      color: colors.primaryContainer,
      child: Center(
        child: Icon(
          categoryIcon(listing.category),
          size: 40,
          color: colors.onPrimaryContainer,
        ),
      ),
    );
    final url = WebsiteRepository.listingImageUrl(listing.image);
    if (url == null) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, __) => ColoredBox(color: colors.surfaceContainerHigh),
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}

/// Small rounded badge used on listing cards and details.
class ListingBadge extends StatelessWidget {
  const ListingBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          AppSpacing.gapXs,
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Trust and accessibility badges for a listing.
List<Widget> listingBadges(BuildContext context, Listing l) {
  final s = context.semanticColors;
  final c = context.colorScheme;
  return [
    if (l.official)
      ListingBadge(
        icon: Icons.account_balance_outlined,
        label: 'web_listing_official'.tr(),
        foreground: s.onInfoContainer,
        background: s.infoContainer,
      )
    else
      ListingBadge(
        icon: Icons.verified_outlined,
        label: 'web_listing_partner'.tr(),
        foreground: s.onSuccessContainer,
        background: s.successContainer,
      ),
    if (l.wheelchair)
      ListingBadge(
        icon: Icons.accessible_rounded,
        label: 'web_listing_wheelchair'.tr(),
        foreground: c.onSecondaryContainer,
        background: c.secondaryContainer,
      ),
    if (l.isSample)
      ListingBadge(
        icon: Icons.info_outline_rounded,
        label: 'web_listing_sample'.tr(),
        foreground: s.onWarningContainer,
        background: s.warningContainer,
      ),
  ];
}

/// One listing in the Services list: photo (shared with the detail screen
/// through a Hero), name, place, price and badges.
class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing, required this.onTap});

  final Listing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    final text = context.textTheme;
    final colors = context.colorScheme;
    final place = [l.area, l.town].where((s) => s.isNotEmpty).join(' · ');
    final extra = [l.distance, l.duration].whereType<String>().join(' · ');

    return PressScale(
      onTap: onTap,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        semanticLabel: l.name,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Hero(
                  tag: listingHeroTag(l),
                  child: ListingImage(listing: l),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: listingBadges(context, l),
                  ),
                  AppSpacing.gapSm,
                  Text(l.name, style: text.titleMedium),
                  if (l.type.isNotEmpty)
                    Text(
                      l.type,
                      style: text.labelMedium?.copyWith(color: colors.primary),
                    ),
                  if (place.isNotEmpty) ...[
                    AppSpacing.gapXs,
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                        AppSpacing.gapXs,
                        Expanded(
                          child: Text(
                            place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (extra.isNotEmpty) ...[
                    AppSpacing.gapXs,
                    Text(extra, style: text.bodySmall),
                  ],
                  AppSpacing.gapMd,
                  Text(
                    listingPriceLabel(l),
                    style: text.titleSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
