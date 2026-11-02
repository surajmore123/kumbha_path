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
import 'package:kumbha_path/src/modules/temple_explorer/temple_detail_screen.dart'
    show TempleDetailArgs;
import 'package:share_plus/share_plus.dart';

const _numerals = ['१', '२', '३', '४', '५', '६', '७', '८', '९'];

void _openTemple(BuildContext context, TempleLink temple) =>
    Navigator.pushNamed(
      context,
      '/templeDetail',
      arguments: TempleDetailArgs(
        templeId: temple.id,
        latitude: '',
        longitude: '',
      ),
    );

/// `/learn`: the library, laid out like a magazine with numbered chapters.
class LearnHomeScreen extends StatefulWidget {
  const LearnHomeScreen({super.key, this.repository});

  final PatrikaRepository? repository;

  @override
  State<LearnHomeScreen> createState() => _LearnHomeScreenState();
}

class _LearnHomeScreenState extends State<LearnHomeScreen> {
  late final PatrikaRepository _repo =
      widget.repository ?? PatrikaServices.repository;
  LearnHome? _home;
  AkhadaException? _error;
  String? _language;

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
    try {
      final home = await _repo.learnHome(_language!);
      if (mounted) setState(() => _home = home);
    } on AkhadaException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = _home;
    return MainLayout(
      ctx: 0,
      showDefaultBottom: true,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.huge),
          children: [
            Masthead(
              title: 'pt_library'.tr(),
              dateline: 'pt_library_line'.tr(),
              actions: [
                IconButton(
                  tooltip: 'pt_glossary'.tr(),
                  icon: const Icon(Icons.translate_rounded),
                  onPressed: () => Navigator.pushNamed(context, '/glossary'),
                ),
                IconButton(
                  tooltip: 'pt_saved'.tr(),
                  icon: const Icon(Icons.bookmark_border),
                  onPressed:
                      () => Navigator.pushNamed(context, '/patrikaSaved'),
                ),
              ],
            ),
            if (home == null && _error == null)
              const FrontPageSkeleton()
            else if (home == null)
              PatrikaMessage(
                title: akhadaErrorText(_error),
                actionLabel: 'common_retry'.tr(),
                onAction: _load,
              )
            else if (home.isEmpty)
              PatrikaMessage(
                title: 'pt_no_articles'.tr(),
                body: 'pt_no_stories_body'.tr(),
              )
            else ...[
              if (home.isSavedCopy)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    editorialMargin,
                    AppSpacing.md,
                    editorialMargin,
                    0,
                  ),
                  child: Text(
                    'ak_saved_copy'.tr(),
                    style: context.editorial.meta,
                  ),
                ),
              if (home.cover != null) _CoverStory(article: home.cover!),
              for (var i = 0; i < home.sections.length; i++)
                switch (home.sections[i].slug) {
                  'places' => _PlacesShelf(index: i, section: home.sections[i]),
                  'guides' => _GuideList(index: i, section: home.sections[i]),
                  _ => _ChapterShelf(index: i, section: home.sections[i]),
                },
              if (home.term != null) _WordToKnow(entry: home.term!),
            ],
          ],
        ),
      ),
    );
  }
}

/// A tall image with its title set on the photograph, unlike the news lead.
class _CoverStory extends StatelessWidget {
  const _CoverStory({required this.article});

  final LearnArticle article;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final s = context.semanticColors;
    final height = (MediaQuery.sizeOf(context).height * 0.56).clamp(
      320.0,
      560.0,
    );
    return Pressable(
      onTap: () => openArticle(context, article.slug),
      label: article.title,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: ClipPath(
          clipper: const GhatEdgeClipper(),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'article-${article.slug}',
                  child: EditorialImage(url: article.image?.url),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.35, 1],
                      colors: [s.imageScrim.withValues(alpha: 0), s.imageScrim],
                    ),
                  ),
                ),
                Positioned(
                  left: editorialMargin,
                  right: editorialMargin,
                  bottom: AppSpacing.xxxl + AppSpacing.xxl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Kicker('pt_begin_here'.tr(), color: s.onImage),
                      AppSpacing.gapSm,
                      Text(
                        article.title,
                        style: e.lead.copyWith(color: s.onImage),
                      ),
                      AppSpacing.gapXs,
                      Text(
                        article.dek,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: e.dek.copyWith(
                          color: s.onImage.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
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

/// A chapter heading with its number in gold Devanagari.
class _ChapterHeading extends StatelessWidget {
  const _ChapterHeading({required this.index, required this.section});

  final int index;
  final LearnSection section;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        editorialMargin,
        AppSpacing.xxl,
        editorialMargin,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Text(
              _numerals[index % _numerals.length],
              style: e.masthead.copyWith(color: context.semanticColors.gold),
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(section.name, style: e.headline),
                ),
                if (section.tagline.isNotEmpty)
                  Text(section.tagline, style: e.meta),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterShelf extends StatelessWidget {
  const _ChapterShelf({required this.index, required this.section});

  final int index;
  final LearnSection section;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChapterHeading(index: index, section: section),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: editorialPage,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final a in section.articles)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  child: SizedBox(
                    width: 220,
                    child: Pressable(
                      onTap: () => openArticle(context, a.slug),
                      label: a.title,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: AppRadius.mdAll,
                            child: AspectRatio(
                              aspectRatio: 4 / 5,
                              child: EditorialImage(url: a.image?.url),
                            ),
                          ),
                          AppSpacing.gapSm,
                          Text(a.title, style: e.title),
                          AppSpacing.gapXs,
                          MetaLine(['pt_minutes'.plural(a.readingMinutes)]),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Places sit in temple-arch frames.
class _PlacesShelf extends StatelessWidget {
  const _PlacesShelf({required this.index, required this.section});

  final int index;
  final LearnSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChapterHeading(index: index, section: section),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: editorialPage,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final a in section.articles)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  child: SizedBox(
                    width: 150,
                    child: Pressable(
                      onTap: () => openArticle(context, a.slug),
                      label: a.title,
                      child: Column(
                        children: [
                          ClipPath(
                            clipper: const ArchClipper(),
                            child: SizedBox(
                              height: 200,
                              width: 150,
                              child: EditorialImage(url: a.image?.url),
                            ),
                          ),
                          AppSpacing.gapSm,
                          Text(
                            a.title,
                            textAlign: TextAlign.center,
                            style: context.editorial.title,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Guides are practical, so they drop the images and read as a contents page.
class _GuideList extends StatelessWidget {
  const _GuideList({required this.index, required this.section});

  final int index;
  final LearnSection section;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChapterHeading(index: index, section: section),
        Padding(
          padding: editorialPage,
          child: Column(
            children: [
              for (final a in section.articles)
                Pressable(
                  onTap: () => openArticle(context, a.slug),
                  label: a.title,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: context.semanticColors.divider),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title, style: e.title),
                              Text(a.dek, style: e.meta),
                            ],
                          ),
                        ),
                        AppSpacing.gapMd,
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: context.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One word set large, as an invitation to the glossary.
class _WordToKnow extends StatelessWidget {
  const _WordToKnow({required this.entry});

  final GlossaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        editorialMargin,
        AppSpacing.xxl,
        editorialMargin,
        0,
      ),
      child: Pressable(
        onTap: () => Navigator.pushNamed(context, '/glossary'),
        label: 'pt_glossary'.tr(),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHigh,
            borderRadius: AppRadius.lgAll,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('pt_word_to_know'.tr(), style: e.kicker),
              AppSpacing.gapSm,
              Text(entry.term, style: e.masthead),
              AppSpacing.gapXs,
              Text(entry.simple, style: e.dek),
              AppSpacing.gapMd,
              Text(
                'pt_open_glossary'.tr(),
                style: e.kicker.copyWith(letterSpacing: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `/learnArticle` (argument: slug): the reader.
class LearnReaderScreen extends StatefulWidget {
  const LearnReaderScreen({
    super.key,
    required this.slug,
    this.repository,
    this.share,
  });

  final String slug;
  final PatrikaRepository? repository;
  final Future<void> Function(String text)? share;

  @override
  State<LearnReaderScreen> createState() => _LearnReaderScreenState();
}

class _LearnReaderScreenState extends State<LearnReaderScreen> {
  final _scroll = ScrollController();
  final _progress = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    PatrikaServices.bookmarks.load();
    _scroll.addListener(() {
      final position = _scroll.position;
      if (position.maxScrollExtent > 0) {
        _progress.value = (position.pixels / position.maxScrollExtent).clamp(
          0.0,
          1.0,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository ?? PatrikaServices.repository;
    return MainLayout(
      ctx: 0,
      body: PatrikaLoader<LearnArticleDetail>(
        load: (language) => repo.article(widget.slug, language),
        builder: (context, result) => _reader(context, result),
      ),
    );
  }

  Widget _reader(BuildContext context, Fetched<LearnArticleDetail> result) {
    final d = result.value;
    final a = d.article;
    final e = context.editorial;
    final height = (MediaQuery.sizeOf(context).height * 0.42).clamp(
      240.0,
      420.0,
    );
    final saved = SavedItem(
      kind: 'article',
      slug: a.slug,
      title: a.title,
      subtitle: a.dek,
      imageUrl: a.image?.url,
    );
    final fallback =
        a.contentLanguage != null &&
        a.contentLanguage != journeyLanguage(context);
    final firstParagraph = d.blocks.indexWhere((b) => b is ParagraphBlock);

    return Stack(
      children: [
        ListView(
          controller: _scroll,
          padding: EdgeInsets.zero,
          children: [
            ClipPath(
              clipper: const GhatEdgeClipper(),
              child: SizedBox(
                height: height,
                child: Hero(
                  tag: 'article-${a.slug}',
                  child: EditorialImage(
                    url: a.image?.url,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: editorialMaxWidth),
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
                      if (a.image != null) ImageCredit(image: a.image!),
                      AppSpacing.gapLg,
                      Semantics(
                        header: true,
                        child: Text(a.title, style: e.lead),
                      ),
                      AppSpacing.gapSm,
                      Text(a.dek, style: e.dek),
                      AppSpacing.gapMd,
                      MetaLine([
                        'pt_minutes'.plural(a.readingMinutes),
                        if (a.lastVerified != null)
                          'pt_reviewed'.tr(
                            args: [storyDate(context, a.lastVerified!)],
                          ),
                      ]),
                      AppSpacing.gapMd,
                      const GhatRule(padding: EdgeInsets.zero),
                      AppSpacing.gapLg,
                      if (a.verification == Verification.awaiting) ...[
                        Text('pt_awaiting'.tr(), style: e.meta),
                        AppSpacing.gapSm,
                      ],
                      if (result.isSavedCopy) ...[
                        Text('ak_saved_copy'.tr(), style: e.meta),
                        AppSpacing.gapSm,
                      ],
                      if (fallback) ...[
                        Text('ak_english_only'.tr(), style: e.meta),
                        AppSpacing.gapSm,
                      ],
                      for (var i = 0; i < d.blocks.length; i++)
                        _block(context, d.blocks[i], i == firstParagraph),
                      if (a.isEditorial) ...[
                        AppSpacing.gapSm,
                        Text('ak_editorial'.tr(), style: e.meta),
                      ],
                      for (final temple in d.temples)
                        _LinkCard(
                          kicker: 'pt_visit_temple'.tr(),
                          title: temple.name,
                          onTap: () => _openTemple(context, temple),
                        ),
                      for (final akhada in d.akhadas)
                        _LinkCard(
                          kicker: 'pt_meet_akhada'.tr(),
                          title: akhada.label,
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                '/akhadaDetail',
                                arguments: akhada.slug,
                              ),
                        ),
                      if (d.sources.isNotEmpty) ...[
                        AppSpacing.gapXl,
                        Text('ak_sources'.tr(), style: e.kicker),
                        AppSpacing.gapSm,
                        for (var i = 0; i < d.sources.length; i++)
                          _SourceLine(number: i + 1, source: d.sources[i]),
                      ],
                      if (d.related.isNotEmpty) ...[
                        AppSpacing.gapXl,
                        Text('pt_read_next'.tr(), style: e.headline),
                        AppSpacing.gapSm,
                        for (final r in d.related)
                          Pressable(
                            onTap: () => openArticle(context, r.slug),
                            label: r.title,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                              ),
                              child: Text(r.title, style: e.title),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        SafeArea(
          child: Column(
            children: [
              ValueListenableBuilder<double>(
                valueListenable: _progress,
                builder:
                    (context, value, _) => ExcludeSemantics(
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        color: context.semanticColors.gold,
                      ),
                    ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    ImageIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const Spacer(),
                    SaveButton(item: saved, onImage: true),
                    AppSpacing.gapSm,
                    ImageIconButton(
                      icon: Icons.ios_share_rounded,
                      tooltip: 'pt_share'.tr(),
                      onPressed: () {
                        final text = '${a.title}\n${a.dek}';
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _block(BuildContext context, ArticleBlock block, bool lede) {
    final e = context.editorial;
    final s = context.semanticColors;
    final gap = const EdgeInsets.only(bottom: AppSpacing.lg);
    return switch (block) {
      ParagraphBlock(:final text) => Padding(
        padding: gap,
        child: Text(
          text,
          style:
              lede
                  ? e.dek.copyWith(color: context.colorScheme.onSurface)
                  : e.reading,
        ),
      ),
      HeadingBlock(:final text) => Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.sm,
        ),
        child: Semantics(header: true, child: Text(text, style: e.headline)),
      ),
      QuoteBlock(:final text) => Container(
        margin: gap,
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: s.gold, width: 2)),
        ),
        child: Text(text, style: e.quote),
      ),
      CalloutBlock(:final text, :final warning) => Container(
        width: double.infinity,
        margin: gap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: warning ? s.warningContainer : s.infoContainer,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              warning
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              size: 20,
              color: warning ? s.onWarningContainer : s.onInfoContainer,
            ),
            AppSpacing.gapSm,
            Expanded(
              child: Text(
                text,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: warning ? s.onWarningContainer : s.onInfoContainer,
                ),
              ),
            ),
          ],
        ),
      ),
      ListBlock(:final items) => Padding(
        padding: gap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 11),
                      child: Container(width: 12, height: 1.5, color: s.gold),
                    ),
                    AppSpacing.gapMd,
                    Expanded(child: Text(item, style: e.reading)),
                  ],
                ),
              ),
          ],
        ),
      ),
      ImageBlock(:final image, :final caption) => Padding(
        padding: gap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: EditorialImage(url: image.url),
              ),
            ),
            if (caption.isNotEmpty) ...[
              AppSpacing.gapXs,
              Text(caption, style: e.meta),
            ],
            ImageCredit(image: image),
          ],
        ),
      ),
    };
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.kicker,
    required this.title,
    required this.onTap,
  });

  final String kicker;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md),
    child: Pressable(
      onTap: onTap,
      label: '$kicker: $title',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHigh,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kicker, style: context.editorial.kicker),
                  AppSpacing.gapXs,
                  Text(title, style: context.editorial.title),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: context.colorScheme.primary,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.number, required this.source});

  final int number;
  final ContentSource source;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final link = source.url;
    return InkWell(
      onTap: link == null ? null : () => openExternal(context, link),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 24, child: Text('$number', style: e.meta)),
            Expanded(
              child: Text(
                [
                  source.title,
                  source.organization,
                ].whereType<String>().join(', '),
                style: e.meta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `/glossary`: terms as typography, not a list of tiles.
class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key, this.repository});

  final PatrikaRepository? repository;

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  late final PatrikaRepository _repo =
      widget.repository ?? PatrikaServices.repository;
  late final ContentListController<GlossaryEntry> _terms =
      ContentListController(
        (page) =>
            _repo.glossary(language: _language!, query: _query, page: page),
      );
  final _field = TextEditingController();
  Timer? _timer;
  String? _language;
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = journeyLanguage(context);
    if (language != _language) {
      _language = language;
      _terms.load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _field.dispose();
    _terms.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () {
      _query = value.trim();
      _terms.load();
    });
  }

  Future<void> _open(GlossaryEntry entry) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (_) =>
            _TermSheet(entry: entry, load: _repo.term(entry.slug, _language!)),
  );

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    return MainLayout(
      ctx: 0,
      body: ListenableBuilder(
        listenable: _terms,
        builder: (context, _) {
          final t = _terms;
          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.huge),
            children: [
              Masthead(
                title: 'pt_glossary'.tr(),
                dateline: 'pt_glossary_line'.tr(),
              ),
              Padding(
                padding: editorialPage,
                child: TextField(
                  controller: _field,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'pt_find_word'.tr(),
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
              if (t.loading && t.items.isEmpty)
                const AppLoading.compact()
              else if (t.error != null)
                PatrikaMessage(
                  title: akhadaErrorText(t.error),
                  actionLabel: 'common_retry'.tr(),
                  onAction: t.load,
                )
              else if (t.items.isEmpty)
                PatrikaMessage(title: 'pt_no_results'.tr())
              else
                for (final entry in t.items)
                  Pressable(
                    onTap: () => _open(entry),
                    label: entry.term,
                    child: Container(
                      margin: editorialPage,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.term, style: e.headline),
                          AppSpacing.gapXs,
                          Text(
                            entry.simple,
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _TermSheet extends StatelessWidget {
  const _TermSheet({required this.entry, required this.load});

  final GlossaryEntry entry;
  final Future<GlossaryDetail> load;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          editorialMargin,
          0,
          editorialMargin,
          editorialMargin,
        ),
        child: FutureBuilder<GlossaryDetail>(
          future: load,
          builder: (context, snap) {
            final d = snap.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.term, style: e.masthead),
                AppSpacing.gapSm,
                Text(entry.simple, style: e.dek),
                if (d != null && d.detail.isNotEmpty) ...[
                  AppSpacing.gapMd,
                  Text(d.detail, style: e.reading),
                ],
                if (d != null)
                  for (final a in d.articles)
                    _LinkCard(
                      kicker: 'pt_read_more'.tr(),
                      title: a.title,
                      onTap: () => openArticle(context, a.slug),
                    ),
                if (d != null)
                  for (final a in d.akhadas)
                    _LinkCard(
                      kicker: 'pt_meet_akhada'.tr(),
                      title: a.label,
                      onTap:
                          () => Navigator.pushNamed(
                            context,
                            '/akhadaDetail',
                            arguments: a.slug,
                          ),
                    ),
                if (d != null)
                  for (final t in d.temples)
                    _LinkCard(
                      kicker: 'pt_visit_temple'.tr(),
                      title: t.name,
                      onTap: () => _openTemple(context, t),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// `/patrikaSaved`: saved on this device, no account needed.
class PatrikaSavedScreen extends StatefulWidget {
  const PatrikaSavedScreen({super.key});

  @override
  State<PatrikaSavedScreen> createState() => _PatrikaSavedScreenState();
}

class _PatrikaSavedScreenState extends State<PatrikaSavedScreen> {
  @override
  void initState() {
    super.initState();
    PatrikaServices.bookmarks.load();
  }

  @override
  Widget build(BuildContext context) {
    final bookmarks = PatrikaServices.bookmarks;
    final e = context.editorial;
    return MainLayout(
      ctx: 0,
      body: ListenableBuilder(
        listenable: bookmarks,
        builder: (context, _) {
          final items = bookmarks.items;
          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.huge),
            children: [
              Masthead(title: 'pt_saved'.tr(), dateline: 'pt_saved_line'.tr()),
              if (items.isEmpty)
                PatrikaMessage(
                  title: 'pt_nothing_saved'.tr(),
                  body: 'pt_nothing_saved_body'.tr(),
                ),
              for (final item in items)
                Pressable(
                  onTap:
                      () =>
                          item.kind == 'story'
                              ? openStory(context, item.slug)
                              : openArticle(context, item.slug),
                  label: item.title,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      editorialMargin,
                      AppSpacing.md,
                      editorialMargin,
                      0,
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: AppRadius.mdAll,
                          child: SizedBox.square(
                            dimension: 72,
                            child: EditorialImage(url: item.imageUrl),
                          ),
                        ),
                        AppSpacing.gapMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, style: e.title),
                              Text(
                                item.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: e.meta,
                              ),
                            ],
                          ),
                        ),
                        SaveButton(item: item),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
