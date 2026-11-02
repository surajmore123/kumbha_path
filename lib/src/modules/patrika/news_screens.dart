import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/akhada/akhada_controllers.dart';
import 'package:kumbha_path/src/modules/akhada/data/akhada_repository.dart';
import 'package:kumbha_path/src/modules/akhada/models/akhada_models.dart';
import 'package:kumbha_path/src/modules/patrika/data/patrika_repository.dart';
import 'package:kumbha_path/src/modules/patrika/models/patrika_models.dart';
import 'package:kumbha_path/src/modules/patrika/widgets/patrika_parts.dart';
import 'package:share_plus/share_plus.dart';

/// `/kumbhNews`: the front page of the journal.
class KumbhNewsScreen extends StatefulWidget {
  const KumbhNewsScreen({super.key, this.repository});

  final PatrikaRepository? repository;

  @override
  State<KumbhNewsScreen> createState() => _KumbhNewsScreenState();
}

class _KumbhNewsScreenState extends State<KumbhNewsScreen> {
  late final PatrikaRepository _repo =
      widget.repository ?? PatrikaServices.repository;
  late final ContentListController<NewsStory> _feed = ContentListController(
    (page) => _repo.news(language: _language!, category: _category, page: page),
  );
  NewsHome? _home;
  AkhadaException? _error;
  String? _language;
  String? _category;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = journeyLanguage(context);
    if (language != _language) {
      _language = language;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final feed = _feed.load();
    try {
      final home = await _repo.newsHome(_language!);
      if (mounted) setState(() => _home = home);
    } on AkhadaException catch (e) {
      if (mounted) setState(() => _error = e);
    }
    await feed;
  }

  void _selectCategory(String? slug) {
    if (slug == _category) return;
    setState(() => _category = slug);
    _feed.load();
  }

  @override
  void dispose() {
    _feed.dispose();
    super.dispose();
  }

  List<DaySection> _days(List<NewsStory> stories) {
    final groups = <DateTime, List<NewsStory>>{};
    for (final s in stories) {
      final d = s.publishedAt;
      groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(s);
    }
    return [
      for (final e in groups.entries)
        DaySection(key: ValueKey(e.key), day: e.key, stories: e.value),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final home = _home;
    final dateline = [
      patrikaDate(context, DateTime.now(), 'EEEE, d MMMM'),
      'pt_place'.tr(),
    ].join('  ·  ');
    final masthead = Masthead(
      title: 'pt_journal'.tr(),
      dateline: dateline,
      actions: [
        IconButton(
          tooltip: 'pt_search'.tr(),
          icon: const Icon(Icons.search_rounded),
          onPressed: () => Navigator.pushNamed(context, '/newsSearch'),
        ),
        IconButton(
          tooltip: 'pt_saved'.tr(),
          icon: const Icon(Icons.bookmark_border),
          onPressed: () => Navigator.pushNamed(context, '/patrikaSaved'),
        ),
      ],
    );

    return MainLayout(
      ctx: 0,
      showDefaultBottom: true,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListenableBuilder(
          listenable: _feed,
          builder: (context, _) {
            final slivers = <Widget>[
              SliverToBoxAdapter(child: masthead),
              if (home == null && _error == null)
                const SliverToBoxAdapter(child: FrontPageSkeleton())
              else if (home == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: PatrikaMessage(
                      title: akhadaErrorText(_error),
                      actionLabel: 'common_retry'.tr(),
                      onAction: _load,
                    ),
                  ),
                )
              else if (home.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: PatrikaMessage(
                      title: 'pt_no_stories'.tr(),
                      body: 'pt_no_stories_body'.tr(),
                    ),
                  ),
                )
              else
                ..._front(home),
            ];
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: slivers,
            );
          },
        ),
      ),
    );
  }

  List<Widget> _front(NewsHome home) {
    final shown = {
      if (_category == null) home.lead?.slug,
      if (_category == null) ...home.announcements.map((n) => n.slug),
    };
    final stories = _feed.items.where((s) => !shown.contains(s.slug)).toList();
    return [
      if (home.isSavedCopy)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              editorialMargin,
              AppSpacing.md,
              editorialMargin,
              0,
            ),
            child: Text('ak_saved_copy'.tr(), style: context.editorial.meta),
          ),
        ),
      if (home.announcements.isNotEmpty)
        SliverToBoxAdapter(
          child: OfficialNoticePanel(notices: home.announcements),
        ),
      if (home.lead != null)
        SliverPadding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: LeadStoryView(
              story: home.lead!,
              onTap: () => openStory(context, home.lead!.slug),
            ),
          ),
        ),
      if (home.categories.isNotEmpty)
        SliverPersistentHeader(
          pinned: true,
          delegate: _RailDelegate(
            height:
                MediaQuery.textScalerOf(context).scale(20) +
                AppSpacing.minTouchTarget -
                AppSpacing.xl +
                AppSpacing.md,
            child: CategoryRail(
              categories: home.categories,
              selected: _category,
              onSelect: _selectCategory,
            ),
          ),
        ),
      if (_feed.loading && _feed.items.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(editorialMargin),
            child: Column(
              children: [
                SkeletonLine(height: 160),
                SkeletonLine(),
                SkeletonLine(),
              ],
            ),
          ),
        )
      else if (_feed.error != null)
        SliverToBoxAdapter(
          child: PatrikaMessage(
            title: akhadaErrorText(_feed.error),
            actionLabel: 'common_retry'.tr(),
            onAction: _feed.load,
          ),
        )
      else if (stories.isEmpty)
        SliverToBoxAdapter(
          child: PatrikaMessage(title: 'pt_no_stories_here'.tr()),
        )
      else
        SliverList.list(children: _days(stories)),
      if (_feed.hasNext)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(editorialMargin),
            child:
                _feed.loadingMore
                    ? const AppLoading.compact()
                    : AppButton.outlined(
                      label: 'pt_older_stories'.tr(),
                      onPressed: _feed.loadMore,
                    ),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.huge)),
    ];
  }
}

class _RailDelegate extends SliverPersistentHeaderDelegate {
  const _RailDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double offset, bool overlaps) => Container(
    color: Theme.of(context).scaffoldBackgroundColor,
    alignment: Alignment.centerLeft,
    child: child,
  );

  @override
  bool shouldRebuild(_RailDelegate old) =>
      old.child != child || old.height != height;
}

/// `/newsArticle` (argument: slug). Our own short summary with clear credit,
/// and the publisher's original one tap away. Full articles aren't copied.
class NewsArticleScreen extends StatefulWidget {
  const NewsArticleScreen({
    super.key,
    required this.slug,
    this.repository,
    this.share,
  });

  final String slug;
  final PatrikaRepository? repository;

  /// Injectable for tests; defaults to the system share sheet.
  final Future<void> Function(String text)? share;

  @override
  State<NewsArticleScreen> createState() => _NewsArticleScreenState();
}

class _NewsArticleScreenState extends State<NewsArticleScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    PatrikaServices.bookmarks.load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository ?? PatrikaServices.repository;
    return MainLayout(
      ctx: 0,
      body: PatrikaLoader<NewsDetail>(
        load: (language) => repo.story(widget.slug, language),
        builder: (context, result) => _article(context, result),
      ),
    );
  }

  Widget _article(BuildContext context, Fetched<NewsDetail> result) {
    final s = result.value.story;
    final e = context.editorial;
    final imageHeight = (MediaQuery.sizeOf(context).height * 0.46).clamp(
      260.0,
      460.0,
    );
    final saved = SavedItem(
      kind: 'story',
      slug: s.slug,
      title: s.headline,
      subtitle: s.publisher.name,
      imageUrl: s.image?.url,
    );
    final fallback =
        s.contentLanguage != null &&
        s.contentLanguage != journeyLanguage(context);

    return Stack(
      children: [
        CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: _ParallaxImage(
                controller: _scroll,
                height: imageHeight,
                heroTag: 'story-${s.slug}',
                url: s.image?.url,
              ),
            ),
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: editorialMaxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      editorialMargin,
                      AppSpacing.md,
                      editorialMargin,
                      AppSpacing.huge,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (s.image != null)
                          ImageCredit(
                            image: s.image!,
                            illustrative: s.image!.representative,
                          ),
                        AppSpacing.gapLg,
                        if (s.isOfficial)
                          Kicker(
                            'pt_official_notice'.tr(),
                            color: context.semanticColors.info,
                          )
                        else if (s.category != null)
                          Kicker(s.category!.name),
                        AppSpacing.gapSm,
                        Text(s.headline, style: e.lead),
                        AppSpacing.gapMd,
                        MetaLine([
                          s.publisher.name,
                          storyDate(context, s.publishedAt),
                        ]),
                        AppSpacing.gapMd,
                        const GhatRule(padding: EdgeInsets.zero),
                        AppSpacing.gapLg,
                        if (result.isSavedCopy) ...[
                          Text('ak_saved_copy'.tr(), style: e.meta),
                          AppSpacing.gapSm,
                        ],
                        if (fallback) ...[
                          Text('ak_english_only'.tr(), style: e.meta),
                          AppSpacing.gapSm,
                        ],
                        Text('pt_what_we_know'.tr(), style: e.kicker),
                        AppSpacing.gapSm,
                        Text(s.summary, style: e.reading),
                        AppSpacing.gapXl,
                        _SourceCard(story: s),
                        if (result.value.related.isNotEmpty) ...[
                          AppSpacing.gapXxl,
                          Text('pt_more_on_this'.tr(), style: e.headline),
                          AppSpacing.gapMd,
                          for (final r in result.value.related)
                            TextStoryRow(story: r),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                ImageIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.maybePop(context),
                ),
                const Spacer(),
                SaveButton(item: saved, onImage: true),
                AppSpacing.gapSm,
                ImageIconButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: 'pt_share'.tr(),
                  onPressed: () {
                    final text = '${s.headline}\n${s.originalUrl}';
                    final share = widget.share;
                    if (share != null) {
                      share(text);
                    } else {
                      Share.share(text);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A photograph that drifts slower than the page and ends in ghat steps.
class _ParallaxImage extends StatelessWidget {
  const _ParallaxImage({
    required this.controller,
    required this.height,
    required this.heroTag,
    required this.url,
  });

  final ScrollController controller;
  final double height;
  final String heroTag;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return ClipPath(
      clipper: const GhatEdgeClipper(),
      child: SizedBox(
        height: height,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final offset =
                still || !controller.hasClients ? 0.0 : controller.offset;
            return Transform.translate(
              offset: Offset(0, offset.clamp(0.0, height) * 0.4),
              child: child,
            );
          },
          child: Hero(
            tag: heroTag,
            child: EditorialImage(
              url: url,
              fallbackIcon: Icons.auto_stories_outlined,
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.story});

  final NewsStory story;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final colors = context.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('pt_originally_by'.tr(), style: e.meta),
          AppSpacing.gapXs,
          Text(story.publisher.name, style: e.headline),
          if (story.attribution != null) ...[
            AppSpacing.gapXs,
            Text(story.attribution!, style: e.meta),
          ],
          AppSpacing.gapMd,
          AppButton(
            label: 'pt_read_original'.tr(),
            trailingIcon: Icons.open_in_new_rounded,
            onPressed: () => openExternal(context, story.originalUrl),
          ),
          AppSpacing.gapSm,
          Text('pt_summary_note'.tr(), style: e.meta),
        ],
      ),
    );
  }
}

/// `/newsSearch`
class NewsSearchScreen extends StatefulWidget {
  const NewsSearchScreen({super.key, this.repository});

  final PatrikaRepository? repository;

  @override
  State<NewsSearchScreen> createState() => _NewsSearchScreenState();
}

class _NewsSearchScreenState extends State<NewsSearchScreen> {
  late final PatrikaRepository _repo =
      widget.repository ?? PatrikaServices.repository;
  late final ContentListController<NewsStory> _results = ContentListController(
    (page) => _repo.news(
      language: journeyLanguage(context),
      query: _query,
      publisher: _publisher,
      dateFrom: _range?.start,
      dateTo: _range?.end,
      relevant: _relevant,
      page: page,
    ),
  );
  final _field = TextEditingController();
  Timer? _timer;
  String _query = '';
  String? _publisher;
  DateTimeRange? _range;
  bool _relevant = false;
  List<NewsPublisher> _publishers = const [];
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _repo
        .newsHome(journeyLanguage(context))
        .then((home) {
          if (mounted) setState(() => _publishers = home.publishers);
        })
        .catchError((Object _) {});
  }

  void _search() {
    if (_query.isEmpty && _publisher == null && _range == null) {
      setState(() {
        _results.items.clear();
      });
      return;
    }
    _results.load();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () {
      _query = value.trim();
      _search();
    });
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked == null || !mounted) return;
    setState(() => _range = picked);
    _search();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _field.dispose();
    _results.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    Widget filter(String label, bool active, VoidCallback onTap) => TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor:
            active
                ? context.colorScheme.primary
                : context.colorScheme.onSurfaceVariant,
      ),
      child: Text(label),
    );
    return MainLayout(
      ctx: 0,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const BackButton(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: editorialMargin),
                    child: TextField(
                      controller: _field,
                      autofocus: true,
                      style: e.title,
                      textInputAction: TextInputAction.search,
                      onChanged: _onChanged,
                      decoration: InputDecoration(
                        hintText: 'pt_search_hint'.tr(),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const GhatRule(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  filter(
                    _range == null
                        ? 'pt_any_date'.tr()
                        : '${storyDate(context, _range!.start)} – '
                            '${storyDate(context, _range!.end)}',
                    _range != null,
                    _pickDates,
                  ),
                  filter(
                    (_relevant ? 'pt_sort_relevant' : 'pt_sort_latest').tr(),
                    _relevant,
                    () {
                      setState(() => _relevant = !_relevant);
                      _search();
                    },
                  ),
                  for (final p in _publishers)
                    filter(p.name, _publisher == p.slug, () {
                      setState(
                        () => _publisher = _publisher == p.slug ? null : p.slug,
                      );
                      _search();
                    }),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _results,
                builder: (context, _) => _list(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    final r = _results;
    if (r.loading && r.items.isEmpty) return const AppLoading.compact();
    if (r.error != null) {
      return PatrikaMessage(
        title: akhadaErrorText(r.error),
        actionLabel: 'common_retry'.tr(),
        onAction: r.load,
      );
    }
    if (r.items.isEmpty) {
      return PatrikaMessage(
        title: r.loaded ? 'pt_no_results'.tr() : 'pt_search_prompt'.tr(),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(editorialMargin),
      itemCount: r.items.length + (r.hasNext ? 1 : 0),
      itemBuilder: (context, i) {
        if (i < r.items.length) {
          return CompactStoryRow(story: r.items[i], showDate: true);
        }
        return AppButton.outlined(
          label: 'pt_older_stories'.tr(),
          onPressed: r.loadMore,
        );
      },
    );
  }
}
