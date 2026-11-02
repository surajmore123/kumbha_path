import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/akhada/data/akhada_repository.dart';
import 'package:kumbha_path/src/modules/akhada/models/akhada_models.dart';
import 'package:kumbha_path/src/modules/akhada/widgets/akhada_ui.dart'
    show akhadaErrorText, journeyLanguage;
import 'package:kumbha_path/src/modules/patrika/data/patrika_repository.dart';
import 'package:kumbha_path/src/modules/patrika/models/patrika_models.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show openExternal;

export 'package:kumbha_path/src/modules/akhada/widgets/akhada_ui.dart'
    show akhadaErrorText, journeyLanguage;
export 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show openExternal, showJourneySnack;

String patrikaDate(BuildContext context, DateTime d, String pattern) {
  try {
    return intl.DateFormat(pattern, context.locale.toLanguageTag()).format(d);
  } catch (_) {
    return intl.DateFormat(pattern, 'en').format(d);
  }
}

String storyDate(BuildContext context, DateTime d) =>
    patrikaDate(context, d, 'd MMM yyyy');

Future<void> openStory(BuildContext context, String slug) =>
    Navigator.pushNamed(context, '/newsArticle', arguments: slug);

Future<void> openArticle(BuildContext context, String slug) =>
    Navigator.pushNamed(context, '/learnArticle', arguments: slug);

/// The journal's title block: name, dateline and a stepped rule.
class Masthead extends StatelessWidget {
  const Masthead({
    super.key,
    required this.title,
    required this.dateline,
    this.actions = const [],
  });

  final String title;
  final String dateline;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (canPop) const BackButton() else AppSpacing.gapLg,
                const Spacer(),
                ...actions,
                AppSpacing.gapXs,
              ],
            ),
            Padding(
              padding: editorialPage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: e.masthead),
                  ),
                  Text(dateline, style: e.meta),
                ],
              ),
            ),
            AppSpacing.gapMd,
            const GhatRule(),
          ],
        ),
      ),
    );
  }
}

/// The front-page story: a large image ending in ghat steps, then the
/// headline on the page itself, where serif type reads best.
class LeadStoryView extends StatelessWidget {
  const LeadStoryView({super.key, required this.story, required this.onTap});

  final NewsStory story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final s = story;
    final height = MediaQuery.sizeOf(context).height * 0.42;
    return Pressable(
      onTap: onTap,
      label: s.headline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Hero(
            tag: 'story-${s.slug}',
            child: ClipPath(
              clipper: const GhatEdgeClipper(),
              child: SizedBox(
                height: height.clamp(240.0, 420.0),
                child: EditorialImage(
                  url: s.image?.url,
                  fallbackIcon: Icons.auto_stories_outlined,
                ),
              ),
            ),
          ),
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
                if (s.category != null) ...[
                  Kicker(s.category!.name),
                  AppSpacing.gapSm,
                ],
                Text(s.headline, style: e.lead),
                if (s.summary.isNotEmpty) ...[
                  AppSpacing.gapSm,
                  Text(
                    s.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: e.dek,
                  ),
                ],
                AppSpacing.gapMd,
                MetaLine([s.publisher.name, storyDate(context, s.publishedAt)]),
                AppSpacing.gapSm,
                Row(
                  children: [
                    Text(
                      'pt_read_more'.tr(),
                      style: e.kicker.copyWith(letterSpacing: 0),
                    ),
                    AppSpacing.gapXs,
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: context.colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Official notices, deliberately unlike any story: a seal on Godavari blue.
class OfficialNoticePanel extends StatelessWidget {
  const OfficialNoticePanel({super.key, required this.notices});

  final List<NewsStory> notices;

  @override
  Widget build(BuildContext context) {
    final s = context.semanticColors;
    final e = context.editorial;
    final fg = s.onInfoContainer;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        editorialMargin,
        AppSpacing.lg,
        editorialMargin,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: s.infoContainer,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: fg),
                ),
                child: Icon(
                  Icons.account_balance_outlined,
                  size: 16,
                  color: fg,
                ),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Text(
                  'pt_official_notice'.tr(),
                  style: e.kicker.copyWith(color: fg),
                ),
              ),
            ],
          ),
          for (final notice in notices)
            Pressable(
              onTap: () => openStory(context, notice.slug),
              label: notice.headline,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notice.headline, style: e.title.copyWith(color: fg)),
                    AppSpacing.gapXs,
                    MetaLine([
                      notice.publisher.name,
                      storyDate(context, notice.publishedAt),
                    ], color: fg),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A story given room: a wide image above a serif headline.
class FeatureStoryRow extends StatelessWidget {
  const FeatureStoryRow({super.key, required this.story});

  final NewsStory story;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final s = story;
    return Pressable(
      onTap: () => openStory(context, s.slug),
      label: s.headline,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'story-${s.slug}',
              child: ClipRRect(
                borderRadius: AppRadius.mdAll,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: EditorialImage(
                    url: s.image?.url,
                    fallbackIcon: Icons.auto_stories_outlined,
                  ),
                ),
              ),
            ),
            AppSpacing.gapMd,
            if (s.category != null) ...[
              Kicker(s.category!.name),
              AppSpacing.gapXs,
            ],
            Text(s.headline, style: e.headline),
            AppSpacing.gapXs,
            Text(
              s.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.gapSm,
            MetaLine([s.publisher.name]),
          ],
        ),
      ),
    );
  }
}

/// A quieter story: headline beside a small image.
class CompactStoryRow extends StatelessWidget {
  const CompactStoryRow({
    super.key,
    required this.story,
    this.showDate = false,
  });

  final NewsStory story;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final s = story;
    return Pressable(
      onTap: () => openStory(context, s.slug),
      label: s.headline,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (s.category != null)
                    Text(s.category!.name, style: context.editorial.kicker),
                  AppSpacing.gapXs,
                  Text(s.headline, style: context.editorial.title),
                  AppSpacing.gapXs,
                  MetaLine([
                    s.publisher.name,
                    if (showDate) storyDate(context, s.publishedAt),
                  ]),
                ],
              ),
            ),
            AppSpacing.gapMd,
            ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: SizedBox.square(
                dimension: 84,
                child: EditorialImage(url: s.image?.url),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The quietest story: a headline alone, under a hairline.
class TextStoryRow extends StatelessWidget {
  const TextStoryRow({super.key, required this.story});

  final NewsStory story;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: () => openStory(context, story.slug),
    label: story.headline,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.semanticColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(story.headline, style: context.editorial.title),
          AppSpacing.gapXs,
          MetaLine([story.publisher.name]),
        ],
      ),
    ),
  );
}

/// Stories of one day. The first is large, the next two compact, the rest
/// text alone, so the page has a rhythm and not a stack of equal cards.
class DaySection extends StatelessWidget {
  const DaySection({super.key, required this.day, required this.stories});

  final DateTime day;
  final List<NewsStory> stories;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        editorialMargin,
        AppSpacing.lg,
        editorialMargin,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                patrikaDate(context, day, 'd'),
                style: e.masthead.copyWith(
                  color: context.semanticColors.gold,
                  height: 1,
                ),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Text(
                  patrikaDate(context, day, 'MMMM yyyy'),
                  style: e.meta,
                ),
              ),
            ],
          ),
          AppSpacing.gapMd,
          for (var i = 0; i < stories.length; i++)
            switch (i) {
              0 => FeatureStoryRow(story: stories[i]),
              1 || 2 => CompactStoryRow(story: stories[i]),
              _ => TextStoryRow(story: stories[i]),
            },
        ],
      ),
    );
  }
}

/// Words with a growing underline. The rail pins under the masthead.
class CategoryRail extends StatelessWidget {
  const CategoryRail({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<NewsCategory> categories;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget item(String? slug, String label) {
      final active = selected == slug;
      final colors = context.colorScheme;
      return Semantics(
        button: true,
        selected: active,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => onSelect(slug),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      style: context.textTheme.labelLarge?.copyWith(
                        color:
                            active ? colors.onSurface : colors.onSurfaceVariant,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AnimatedContainer(
                      duration:
                          reduceMotion(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                      height: 2,
                      color: active ? colors.primary : Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          item(null, 'pt_all_stories'.tr()),
          for (final c in categories) item(c.slug, c.name),
        ],
      ),
    );
  }
}

/// Plain, kind words for empty and error states.
class PatrikaMessage extends StatelessWidget {
  const PatrikaMessage({
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
    padding: const EdgeInsets.all(AppSpacing.xxxl),
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

/// Skeleton in the shape of a front page.
class FrontPageSkeleton extends StatelessWidget {
  const FrontPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipPath(
          clipper: const GhatEdgeClipper(),
          child: Container(
            height: 280,
            color: context.colorScheme.surfaceContainerHigh,
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(editorialMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLine(width: 96, height: 10),
              SkeletonLine(height: 26),
              SkeletonLine(width: 220, height: 26),
              SkeletonLine(height: 12),
              SkeletonLine(width: 180, height: 12),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Loads one record for the app's language. Retries, and reloads when the
/// language changes.
class PatrikaLoader<T> extends StatefulWidget {
  const PatrikaLoader({super.key, required this.load, required this.builder});

  final Future<Fetched<T>> Function(String language) load;
  final Widget Function(BuildContext context, Fetched<T> result) builder;

  @override
  State<PatrikaLoader<T>> createState() => _PatrikaLoaderState<T>();
}

class _PatrikaLoaderState<T> extends State<PatrikaLoader<T>> {
  Future<Fetched<T>>? _future;
  String? _language;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = journeyLanguage(context);
    if (language != _language) {
      _language = language;
      _future = widget.load(language);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Fetched<T>>(
    future: _future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const SingleChildScrollView(child: FrontPageSkeleton());
      }
      final data = snap.data;
      if (data == null) {
        final error = snap.error;
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackButton(),
              Expanded(
                child: Center(
                  child: PatrikaMessage(
                    title: akhadaErrorText(
                      error is AkhadaException ? error : null,
                    ),
                    actionLabel: 'common_retry'.tr(),
                    onAction: () {
                      setState(() {
                        _future = widget.load(_language!);
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return widget.builder(context, data);
    },
  );
}

/// Attribution under an image, linked to where its licence can be checked.
class ImageCredit extends StatelessWidget {
  const ImageCredit({
    super.key,
    required this.image,
    this.illustrative = false,
  });

  final ContentImage image;

  /// The image shows the topic, not this particular story.
  final bool illustrative;

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.labelSmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: InkWell(
        onTap:
            image.sourceUrl == null
                ? null
                : () => openExternal(context, image.sourceUrl!),
        child: Text(
          [
            if (illustrative) 'pt_illustrative'.tr(),
            'ak_image_credit'.tr(args: [image.credit]),
          ].join(' '),
          style: style,
        ),
      ),
    );
  }
}

/// The save toggle, reading from the on-device bookmarks.
class SaveButton extends StatelessWidget {
  const SaveButton({super.key, required this.item, this.onImage = false});

  final SavedItem item;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final bookmarks = PatrikaServices.bookmarks;
    return ListenableBuilder(
      listenable: bookmarks,
      builder: (context, _) {
        final saved = bookmarks.isSaved(item.id);
        final icon = saved ? Icons.bookmark_rounded : Icons.bookmark_border;
        final tooltip = (saved ? 'pt_unsave' : 'pt_save').tr();
        return onImage
            ? ImageIconButton(
              icon: icon,
              tooltip: tooltip,
              selected: saved,
              onPressed: () => bookmarks.toggle(item),
            )
            : IconButton(
              icon: Icon(icon),
              tooltip: tooltip,
              onPressed: () => bookmarks.toggle(item),
            );
      },
    );
  }
}
