import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/booking/data/booking_repository.dart';
import 'package:kumbha_path/src/modules/booking/models/booking_models.dart';

export 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show journeyLanguage, openExternal, showJourneySnack, confirmJourneyAction;

String bookingErrorText(Object? error) {
  if (error is! JourneyException) return 'bk_error_generic'.tr();
  return switch (error.kind) {
    JourneyFailure.offline => 'bk_error_offline'.tr(),
    JourneyFailure.unauthorized => 'bk_error_signin'.tr(),
    JourneyFailure.notFound => 'bk_error_not_found'.tr(),
    JourneyFailure.invalid => error.message ?? 'bk_error_generic'.tr(),
    JourneyFailure.server => 'bk_error_generic'.tr(),
  };
}

String rupees(num value) =>
    '₹${intl.NumberFormat.decimalPattern('en_IN').format(value)}';

String shortDate(BuildContext context, DateTime d) {
  try {
    return intl.DateFormat('d MMM', context.locale.toLanguageTag()).format(d);
  } catch (_) {
    return intl.DateFormat('d MMM', 'en').format(d);
  }
}

String fullDate(BuildContext context, DateTime d) {
  try {
    return intl.DateFormat(
      'EEE, d MMM yyyy',
      context.locale.toLanguageTag(),
    ).format(d);
  } catch (_) {
    return intl.DateFormat('EEE, d MMM yyyy', 'en').format(d);
  }
}

String dateSpan(BuildContext context, DateTime? a, DateTime? b) {
  if (a == null) return 'bk_dates_open'.tr();
  if (b == null || b == a) return shortDate(context, a);
  return '${shortDate(context, a)} – ${shortDate(context, b)}';
}

IconData categoryIcon(String category) => switch (category) {
  'stay' => Icons.bed_outlined,
  'train' => Icons.train_outlined,
  'bus' => Icons.directions_bus_outlined,
  'flight' => Icons.flight_outlined,
  'taxi' => Icons.local_taxi_outlined,
  'local' => Icons.directions_walk_rounded,
  _ => Icons.confirmation_number_outlined,
};

IconData stayTypeIcon(String type) => switch (type) {
  'hotel' => Icons.hotel_outlined,
  'budget' => Icons.savings_outlined,
  'dharamshala' => Icons.temple_hindu_outlined,
  'ashram' => Icons.self_improvement_rounded,
  'guest_house' => Icons.cottage_outlined,
  'tent' => Icons.holiday_village_outlined,
  'family' => Icons.family_restroom_rounded,
  _ => Icons.night_shelter_outlined,
};

IconData amenityIcon(String slug) => switch (slug) {
  'hot-water' => Icons.hot_tub_outlined,
  'attached-bath' => Icons.bathtub_outlined,
  'ac' => Icons.ac_unit_rounded,
  'parking' => Icons.local_parking_rounded,
  'food' => Icons.restaurant_outlined,
  _ => Icons.check_rounded,
};

/// A paper ticket: two semicircle notches at the perforation line.
class TicketShape extends ShapeBorder {
  const TicketShape({
    required this.stubHeight,
    this.notch = 9,
    this.radius = AppRadius.lg,
  });

  /// Distance of the perforation from the bottom edge.
  final double stubHeight;
  final double notch;
  final double radius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final y = rect.bottom - stubHeight;
    final body =
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final cuts =
        Path()
          ..addOval(
            Rect.fromCircle(center: Offset(rect.left, y), radius: notch),
          )
          ..addOval(
            Rect.fromCircle(center: Offset(rect.right, y), radius: notch),
          );
    return Path.combine(PathOperation.difference, body, cuts);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

/// The perforated line between a ticket's body and its stub.
class Perforation extends StatelessWidget {
  const Perforation({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashPainter(context.semanticColors.divider),
    ),
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, 0), Offset(x + 5, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// A ticket with a body and a stub. The stub's height follows its content
/// (and so the font size), and the notches follow the stub.
class TicketCard extends StatefulWidget {
  const TicketCard({super.key, required this.body, required this.stub});

  final Widget body;
  final Widget stub;

  @override
  State<TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<TicketCard> {
  final _stubKey = GlobalKey();
  double _stubHeight = 64;

  void _measure(_) {
    final height = _stubKey.currentContext?.size?.height;
    if (mounted && height != null && height != _stubHeight) {
      setState(() => _stubHeight = height);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    return Material(
      color: context.colorScheme.surfaceContainerHigh,
      shape: TicketShape(stubHeight: _stubHeight),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.body,
          const Perforation(),
          KeyedSubtree(key: _stubKey, child: widget.stub),
        ],
      ),
    );
  }
}

/// How far a stay's information has been checked.
class TrustLine extends StatelessWidget {
  const TrustLine({super.key, required this.verified, this.date});

  final bool verified;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final s = context.semanticColors;
    final color = verified ? s.success : s.warning;
    final e = context.editorial;
    return Row(
      children: [
        Icon(
          verified ? Icons.verified_outlined : Icons.help_outline_rounded,
          size: 15,
          color: color,
        ),
        AppSpacing.gapXs,
        Expanded(
          child: Text(
            [
              (verified ? 'bk_verified' : 'bk_unverified').tr(),
              if (verified && date != null)
                'bk_checked'.tr(args: [shortDate(context, date!)]),
            ].join(' · '),
            style: e.meta.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// A price set large, always with what kind of price it is.
class PriceBlock extends StatelessWidget {
  const PriceBlock({super.key, required this.stay, this.large = false});

  final StaySummary stay;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final price = stay.priceFrom;
    if (price == null || stay.priceStatus == PriceStatus.onRequest) {
      return Text('bk_price_ask'.tr(), style: e.title);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stay.priceStatus == PriceStatus.estimated
              ? 'bk_price_estimate'.tr()
              : 'bk_price_published'.tr(),
          style: e.meta,
        ),
        Text(rupees(price), style: large ? e.lead : e.headline),
        if (stay.priceUnit.isNotEmpty) Text(stay.priceUnit, style: e.meta),
      ],
    );
  }
}

/// Stay image, or a labelled photo of the area. Never presented as the stay.
class StayPhoto extends StatelessWidget {
  const StayPhoto({super.key, required this.stay, this.aspectRatio = 16 / 10});

  final StaySummary stay;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final image = stay.image;
    final s = context.semanticColors;
    return ClipRRect(
      borderRadius: AppRadius.lgAll,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            EditorialImage(
              url: image?.url,
              fallbackIcon: stayTypeIcon(stay.stayType),
            ),
            if (image?.representative ?? false)
              Positioned(
                left: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: s.imageScrim,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Text(
                    'bk_area_photo'.tr(),
                    style: context.editorial.meta.copyWith(color: s.onImage),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A property result: photo first, then name, place, facilities and price.
class StayCard extends StatelessWidget {
  const StayCard({super.key, required this.stay, this.onTap});

  final StaySummary stay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final muted = context.colorScheme.onSurfaceVariant;
    final s = stay;
    return Pressable(
      onTap:
          onTap ??
          () => Navigator.pushNamed(context, '/stayDetail', arguments: s.id),
      label: s.name,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StayPhoto(stay: s),
            AppSpacing.gapMd,
            Text('bk_type_${s.stayType}'.tr(), style: e.kicker),
            AppSpacing.gapXs,
            Text(s.name, style: e.headline),
            AppSpacing.gapXs,
            Text(
              [
                if (s.area != null) s.area!.name,
                if (s.distanceKm != null)
                  'bk_km'.tr(args: [s.distanceKm!.toStringAsFixed(1)]),
              ].join(' · '),
              style: e.meta,
            ),
            AppSpacing.gapSm,
            TrustLine(verified: s.verified, date: s.lastVerified),
            if (s.amenities.isNotEmpty || s.accessible) ...[
              AppSpacing.gapSm,
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final a in s.amenities)
                    Tooltip(
                      message: a.name,
                      child: Icon(
                        amenityIcon(a.slug),
                        size: 18,
                        color: muted,
                        semanticLabel: a.name,
                      ),
                    ),
                  if (s.accessible)
                    Icon(Icons.accessible_rounded, size: 18, color: muted),
                ],
              ),
            ],
            AppSpacing.gapMd,
            PriceBlock(stay: s),
          ],
        ),
      ),
    );
  }
}

/// A saved booking as a ticket: the trip above the perforation, its reference
/// below, where it's quick to find at a counter.
class BookingTicket extends StatelessWidget {
  const BookingTicket({super.key, required this.booking, this.onTap});

  final SavedBooking booking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final b = booking;
    final colors = context.colorScheme;
    final route = [
      b.fromPlace,
      b.toPlace,
    ].where((p) => p.isNotEmpty).join(' → ');
    return Pressable(
      onTap: onTap,
      label: b.title,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: TicketCard(
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      categoryIcon(b.category),
                      size: 18,
                      color: colors.primary,
                    ),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Text(
                        b.provider.isEmpty
                            ? 'bk_cat_${b.category}'.tr()
                            : b.provider,
                        style: e.meta,
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapSm,
                Text(b.title, style: e.headline),
                if (route.isNotEmpty) Text(route, style: e.meta),
                AppSpacing.gapSm,
                BookingStatusPill(b.status),
              ],
            ),
          ),
          stub: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                Text(dateSpan(context, b.startDate, b.endDate), style: e.title),
                if (b.reference.isNotEmpty)
                  Text(
                    b.reference,
                    style: context.textTheme.labelLarge?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
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

class BookingStatusPill extends StatelessWidget {
  const BookingStatusPill(this.status, {super.key});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final s = context.semanticColors;
    final c = context.colorScheme;
    final (fg, bg) = switch (status) {
      BookingStatus.confirmed => (s.onSuccessContainer, s.successContainer),
      BookingStatus.pending => (s.onWarningContainer, s.warningContainer),
      BookingStatus.cancelled => (c.onErrorContainer, c.errorContainer),
      BookingStatus.completed => (
        c.onSurfaceVariant,
        c.surfaceContainerHighest,
      ),
      BookingStatus.saved => (s.onInfoContainer, s.infoContainer),
    };
    return StatusPill(
      label: 'bk_status_${status.name}'.tr(),
      foreground: fg,
      background: bg,
    );
  }
}

/// A heading used through this module.
class BookingSectionTitle extends StatelessWidget {
  const BookingSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: context.editorial.headline),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

/// Kind words for empty and error states.
class BookingMessage extends StatelessWidget {
  const BookingMessage({
    super.key,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: context.editorial.headline,
        ),
        if (body != null) ...[
          AppSpacing.gapSm,
          Text(
            body!,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (onAction != null) ...[
          AppSpacing.gapMd,
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

/// Placeholder in the shape of a stay result.
class StaySkeleton extends StatelessWidget {
  const StaySkeleton({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonLine(height: 200),
        SkeletonLine(width: 80, height: 10),
        SkeletonLine(width: 220, height: 22),
        SkeletonLine(width: 140),
      ],
    ),
  );
}
