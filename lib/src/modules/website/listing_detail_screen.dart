import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/models/website_models.dart';
import 'package:kumbha_path/src/modules/website/widgets/website_widgets.dart';

/// `/listingDetail`: one listing from Services. The photo flies in from the
/// card (shared Hero); the details follow with a staggered entrance.
/// Enquiries are made on the website, which has the enquiry form.
class ListingDetailScreen extends StatelessWidget {
  const ListingDetailScreen({super.key, required this.listing});

  final Listing listing;

  static const double _maxWidth = 760;

  Uri get _websiteUri =>
      Uri.parse('${ApiConst.websiteUrl}/services/${listing.category.name}');

  @override
  Widget build(BuildContext context) {
    final l = listing;
    final text = context.textTheme;
    final colors = context.colorScheme;
    final place = [l.area, l.town].where((s) => s.isNotEmpty).join(' · ');

    final facts = <(IconData, String)>[
      if (place.isNotEmpty) (Icons.place_outlined, place),
      if (l.distance != null) (Icons.straighten_outlined, l.distance!),
      if (l.duration != null) (Icons.schedule_outlined, l.duration!),
    ];

    var i = 0;
    Widget step(Widget child) => FadeSlideIn(index: i++, child: child);

    return MainLayout(
      appBar: AppAppBar(title: l.name),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.huge),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Hero(
                  tag: listingHeroTag(l),
                  child: ListingImage(listing: l),
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  AppSpacing.lg,
                  AppSpacing.pageGutter,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    step(
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: listingBadges(context, l),
                      ),
                    ),
                    AppSpacing.gapMd,
                    step(Text(l.name, style: text.headlineSmall)),
                    if (l.type.isNotEmpty)
                      step(
                        Text(
                          l.type,
                          style: text.titleSmall?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ),
                    AppSpacing.gapLg,
                    step(
                      AppCard(
                        variant: AppCardVariant.filled,
                        child: Row(
                          children: [
                            Icon(
                              Icons.currency_rupee_rounded,
                              color: colors.primary,
                            ),
                            AppSpacing.gapSm,
                            Expanded(
                              child: Text(
                                listingPriceLabel(l),
                                style: text.titleMedium?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (final (icon, label) in facts) ...[
                      AppSpacing.gapMd,
                      step(
                        Row(
                          children: [
                            Icon(
                              icon,
                              size: 20,
                              color: colors.onSurfaceVariant,
                            ),
                            AppSpacing.gapSm,
                            Expanded(
                              child: Text(label, style: text.bodyMedium),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (l.highlights.isNotEmpty) ...[
                      AppSpacing.gapXl,
                      step(
                        AppSectionHeader(title: 'web_listing_highlights'.tr()),
                      ),
                      AppSpacing.gapSm,
                      for (final h in l.highlights)
                        step(
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 20,
                                  color: context.semanticColors.success,
                                ),
                                AppSpacing.gapSm,
                                Expanded(
                                  child: Text(h, style: text.bodyMedium),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                    AppSpacing.gapXl,
                    step(
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => openExternal(context, _websiteUri),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: Text('web_listing_enquire'.tr()),
                        ),
                      ),
                    ),
                    AppSpacing.gapSm,
                    Text(
                      'web_listing_enquire_note'.tr(),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
