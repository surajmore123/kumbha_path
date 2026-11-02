import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/akhada/data/akhada_repository.dart';
import 'package:kumbha_path/src/modules/akhada/models/akhada_models.dart';
import 'package:kumbha_path/src/modules/akhada/widgets/akhada_cards.dart';
import 'package:kumbha_path/src/modules/akhada/widgets/akhada_ui.dart';

/// The four parts of the module, shared by the landing page and dashboard.
class AkhadaSection {
  const AkhadaSection(this.route, this.icon, this.titleKey, this.detailKey);

  final String route;
  final IconData icon;
  final String titleKey;
  final String detailKey;

  static const all = [
    AkhadaSection(
      '/akhadaList',
      akhadaIcon,
      'ak_directory',
      'ak_directory_about',
    ),
    AkhadaSection('/saints', saintIcon, 'ak_saints', 'ak_saints_about'),
    AkhadaSection(
      '/akhadaLearn',
      Icons.auto_stories_outlined,
      'ak_learn',
      'ak_learn_about',
    ),
    AkhadaSection(
      '/akhadaActivities',
      Icons.campaign_outlined,
      'ak_nashik',
      'ak_nashik_about',
    ),
  ];
}

/// A chip's value is `kind:value`, so one row can mix filter kinds.
String? _valueOf(String? filter, String kind) =>
    filter != null && filter.startsWith('$kind:')
        ? filter.substring(kind.length + 1)
        : null;

/// `/akhadas`: the way into the directory, saints, articles and Nashik news.
class AkhadasHomeScreen extends StatelessWidget {
  const AkhadasHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return MainLayout(
      ctx: 0,
      appBar: AppAppBar(title: 'ak_title'.tr()),
      body: akhadaCentered(
        ListView(
          padding: akhadaPagePadding,
          children: [
            Text('ak_intro'.tr(), style: text.bodyLarge),
            AppSpacing.gapLg,
            for (final s in AkhadaSection.all) ...[
              AppCard(
                semanticLabel: s.titleKey.tr(),
                onTap: () => Navigator.pushNamed(context, s.route),
                child: Row(
                  children: [
                    Icon(s.icon, color: context.colorScheme.primary),
                    AppSpacing.gapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.titleKey.tr(), style: text.titleMedium),
                          Text(s.detailKey.tr(), style: text.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              AppSpacing.gapMd,
            ],
            SourceNote('ak_trust_note'.tr()),
          ],
        ),
      ),
    );
  }
}

/// `/akhadaList`
class AkhadaListScreen extends StatelessWidget {
  const AkhadaListScreen({super.key, this.repository});

  final AkhadaRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? AkhadaServices.repository;
    return DirectoryList<AkhadaSummary>(
      title: 'ak_directory'.tr(),
      searchHint: 'ak_search_akhadas'.tr(),
      emptyTitle: 'ak_empty_akhadas'.tr(),
      emptyIcon: akhadaIcon,
      loadPage:
          (language, query, filter, page) => repo.akhadas(
            language: language,
            query: query,
            tradition: _valueOf(filter, 'tradition'),
            location: _valueOf(filter, 'location'),
            page: page,
          ),
      loadFilters: (language) async {
        final filters = await repo.filters(language);
        return [
          for (final t in filters.traditions)
            FilterOption('tradition:${t.slug}', t.name),
          for (final l in filters.locations) FilterOption('location:$l', l),
        ];
      },
      itemBuilder: (_, a) => AkhadaCard(akhada: a),
    );
  }
}

/// `/saints`
class SaintListScreen extends StatelessWidget {
  const SaintListScreen({super.key, this.repository});

  final AkhadaRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? AkhadaServices.repository;
    return DirectoryList<SaintSummary>(
      title: 'ak_saints'.tr(),
      searchHint: 'ak_search_saints'.tr(),
      emptyTitle: 'ak_empty_saints'.tr(),
      emptyIcon: saintIcon,
      header: SourceNote('ak_saints_note'.tr()),
      loadPage:
          (language, query, filter, page) => repo.saints(
            language: language,
            query: query,
            title: _valueOf(filter, 'title'),
            akhada: _valueOf(filter, 'akhada'),
            page: page,
          ),
      loadFilters: (language) async {
        final filters = await repo.filters(language);
        return [
          for (final t in filters.titles)
            FilterOption('title:${t.slug}', t.name),
          for (final a in filters.saintAkhadas)
            FilterOption('akhada:${a.slug}', a.label),
        ];
      },
      itemBuilder: (_, s) => SaintCard(saint: s),
    );
  }
}

/// `/akhadaLearn`
class AkhadaLearnScreen extends StatelessWidget {
  const AkhadaLearnScreen({super.key, this.repository});

  final AkhadaRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? AkhadaServices.repository;
    return DirectoryList<ArticleSummary>(
      title: 'ak_learn'.tr(),
      searchHint: 'ak_search_articles'.tr(),
      emptyTitle: 'ak_empty_articles'.tr(),
      emptyIcon: Icons.auto_stories_outlined,
      loadPage:
          (language, query, filter, page) => repo.articles(
            language: language,
            query: query,
            category: filter,
            page: page,
          ),
      loadFilters: (language) async {
        final filters = await repo.filters(language);
        return [
          for (final c in filters.categories)
            FilterOption(c, 'ak_category_$c'.tr()),
        ];
      },
      itemBuilder: (_, a) => ArticleCard(article: a),
    );
  }
}

/// `/akhadaActivities`: announcements, kept apart from educational content
/// and always labelled with how firm they are.
class AkhadaActivitiesScreen extends StatelessWidget {
  const AkhadaActivitiesScreen({super.key, this.repository});

  final AkhadaRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? AkhadaServices.repository;
    return DirectoryList<AkhadaActivity>(
      title: 'ak_nashik'.tr(),
      emptyTitle: 'ak_empty_activities'.tr(),
      emptyIcon: Icons.campaign_outlined,
      header: SourceNote('ak_nashik_note'.tr()),
      loadPage:
          (language, query, filter, page) => repo.activities(
            language: language,
            confirmation: filter,
            page: page,
          ),
      loadFilters:
          (language) async => [
            for (final c in Confirmation.values)
              FilterOption(c.name, 'ak_confirmation_${c.name}'.tr()),
          ],
      itemBuilder: (_, a) => ActivityCard(activity: a),
    );
  }
}

Widget _relatedLinks(
  BuildContext context,
  String title,
  List<Widget> children,
) {
  if (children.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: context.textTheme.titleMedium),
        AppSpacing.gapSm,
        for (final child in children) ...[child, AppSpacing.gapSm],
      ],
    ),
  );
}

Widget _officialLink(BuildContext context, String label, String? url) {
  if (url == null) return const SizedBox.shrink();
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.link_rounded),
    title: Text(label),
    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
    onTap: () => openExternal(context, url),
  );
}

/// Header of a detail page: image, name, subtitle and how it was verified.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.image,
    required this.fallback,
    required this.title,
    required this.subtitle,
    required this.verification,
    required this.lastVerified,
  });

  final ContentImage? image;
  final IconData fallback;
  final String title;
  final String? subtitle;
  final Verification verification;
  final DateTime? lastVerified;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContentBanner(image: image, alignment: Alignment.topCenter),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image == null) ...[
                ContentThumbnail(image: null, fallback: fallback, size: 80),
                AppSpacing.gapMd,
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleLarge),
                    if (subtitle != null)
                      Text(subtitle!, style: text.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          VerificationLine(status: verification, date: lastVerified),
        ],
      ),
    );
  }
}

/// `/akhadaDetail` (argument: slug)
class AkhadaDetailScreen extends StatelessWidget {
  const AkhadaDetailScreen({super.key, required this.slug, this.repository});

  final String slug;
  final AkhadaRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? AkhadaServices.repository;
    return DetailLoader<AkhadaDetail>(
      title: 'ak_directory'.tr(),
      titleOf: (d) => d.summary.commonName ?? d.summary.name,
      load: (language) => repo.akhada(slug, language),
      builder: (context, result) {
        final d = result.value;
        final a = d.summary;
        final t = a.tradition;
        return akhadaCentered(
          ListView(
            padding: akhadaPagePadding,
            children: [
              if (result.isSavedCopy) const SavedCopyNote(),
              FallbackLanguageNote(contentLanguage: a.contentLanguage),
              _DetailHeader(
                image: a.image,
                fallback: akhadaIcon,
                title: a.name,
                subtitle: t?.name,
                verification: a.verification,
                lastVerified: a.lastVerified,
              ),
              ContentSection(title: 'ak_overview'.tr(), text: a.summary),
              ContentSection(title: 'ak_history'.tr(), text: d.history),
              ContentSection(
                title: 'ak_tradition'.tr(),
                text:
                    d.philosophy.isNotEmpty ? d.philosophy : (t?.summary ?? ''),
              ),
              ContentSection(
                title: 'ak_practices'.tr(),
                text:
                    d.practices.isNotEmpty ? d.practices : (t?.practices ?? ''),
              ),
              ContentSection(
                title: 'ak_organization'.tr(),
                text: d.organization,
              ),
              if (d.titles.isNotEmpty)
                ContentSection(
                  title: 'ak_titles'.tr(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final title in d.titles)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.name,
                                style: context.textTheme.titleSmall,
                              ),
                              Text(
                                title.meaning,
                                style: context.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      SourceNote('ak_titles_note'.tr()),
                    ],
                  ),
                ),
              _relatedLinks(context, 'ak_related_saints'.tr(), [
                for (final s in d.saints) SaintCard(saint: s),
              ]),
              ContentSection(title: 'ak_kumbh'.tr(), text: d.kumbhSignificance),
              ContentSection(
                title: 'ak_nashik_info'.tr(),
                text: d.nashikNote,
                child:
                    d.nashikNote.isEmpty && d.activities.isEmpty
                        ? null
                        : Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: SourceNote('ak_not_confirmed'.tr()),
                        ),
              ),
              _relatedLinks(context, 'ak_nashik'.tr(), [
                for (final activity in d.activities)
                  ActivityCard(activity: activity),
              ]),
              _relatedLinks(context, 'ak_related_articles'.tr(), [
                for (final article in d.articles) ArticleCard(article: article),
              ]),
              if (d.websiteUrl != null ||
                  d.socialUrl != null ||
                  d.contactEmail != null ||
                  d.contactPhone != null)
                ContentSection(
                  title: 'ak_official_links'.tr(),
                  child: Column(
                    children: [
                      _officialLink(context, 'ak_website'.tr(), d.websiteUrl),
                      _officialLink(context, 'ak_social'.tr(), d.socialUrl),
                      if (d.contactEmail != null)
                        _officialLink(
                          context,
                          d.contactEmail!,
                          'mailto:${d.contactEmail}',
                        ),
                      if (d.contactPhone != null)
                        _officialLink(
                          context,
                          d.contactPhone!,
                          'tel:${d.contactPhone}',
                        ),
                    ],
                  ),
                ),
              SourcesSection(sources: d.sources),
            ],
          ),
        );
      },
    );
  }
}

/// `/saintDetail` (argument: slug)
class SaintDetailScreen extends StatelessWidget {
  const SaintDetailScreen({super.key, required this.slug, this.repository});

  final String slug;
  final AkhadaRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? AkhadaServices.repository;
    return DetailLoader<SaintDetail>(
      title: 'ak_saints'.tr(),
      titleOf: (d) => d.summary.name,
      load: (language) => repo.saint(slug, language),
      builder: (context, result) {
        final d = result.value;
        final s = d.summary;
        return akhadaCentered(
          ListView(
            padding: akhadaPagePadding,
            children: [
              if (result.isSavedCopy) const SavedCopyNote(),
              FallbackLanguageNote(contentLanguage: s.contentLanguage),
              _DetailHeader(
                image: s.image,
                fallback: saintIcon,
                title: s.name,
                subtitle:
                    s.title?.name ??
                    (s.historical ? 'ak_historical_figure'.tr() : null),
                verification: s.verification,
                lastVerified: s.lastVerified,
              ),
              if (s.akhada != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: AppButton.outlined(
                    label: s.akhada!.label,
                    leadingIcon: akhadaIcon,
                    onPressed:
                        () => Navigator.pushNamed(
                          context,
                          '/akhadaDetail',
                          arguments: s.akhada!.slug,
                        ),
                  ),
                ),
              ContentSection(title: 'ak_biography'.tr(), text: d.biography),
              ContentSection(title: 'ak_teachings'.tr(), text: d.teachings),
              ContentSection(
                title: 'ak_public_activities'.tr(),
                text: d.publicActivities,
              ),
              ContentSection(
                title: 'ak_significance'.tr(),
                text: d.significance,
              ),
              _relatedLinks(context, 'ak_related_articles'.tr(), [
                for (final article in d.articles) ArticleCard(article: article),
              ]),
              if (d.websiteUrl != null || d.socialUrl != null)
                ContentSection(
                  title: 'ak_official_links'.tr(),
                  child: Column(
                    children: [
                      _officialLink(context, 'ak_website'.tr(), d.websiteUrl),
                      _officialLink(context, 'ak_social'.tr(), d.socialUrl),
                    ],
                  ),
                ),
              SourcesSection(sources: d.sources),
              SourceNote('ak_no_endorsement'.tr()),
            ],
          ),
        );
      },
    );
  }
}

/// `/akhadaArticle` (argument: slug)
class AkhadaArticleScreen extends StatelessWidget {
  const AkhadaArticleScreen({super.key, required this.slug, this.repository});

  final String slug;
  final AkhadaRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? AkhadaServices.repository;
    return DetailLoader<ArticleDetail>(
      title: 'ak_learn'.tr(),
      load: (language) => repo.article(slug, language),
      builder: (context, result) {
        final d = result.value;
        final a = d.summary;
        final text = context.textTheme;
        return akhadaCentered(
          ListView(
            padding: akhadaPagePadding,
            children: [
              if (result.isSavedCopy) const SavedCopyNote(),
              FallbackLanguageNote(contentLanguage: a.contentLanguage),
              ContentBanner(image: a.image),
              Text(a.title, style: text.headlineSmall),
              AppSpacing.gapSm,
              Text(a.intro, style: text.titleSmall),
              AppSpacing.gapLg,
              for (final paragraph in d.paragraphs) ...[
                Text(paragraph, style: text.bodyLarge),
                AppSpacing.gapMd,
              ],
              if (a.isEditorial) ...[
                SourceNote('ak_editorial'.tr()),
                AppSpacing.gapMd,
              ],
              VerificationLine(status: a.verification, date: a.lastVerified),
              AppSpacing.gapLg,
              _relatedLinks(context, 'ak_related_akhadas'.tr(), [
                for (final akhada in d.akhadas)
                  AppButton.outlined(
                    label: akhada.label,
                    leadingIcon: akhadaIcon,
                    onPressed:
                        () => Navigator.pushNamed(
                          context,
                          '/akhadaDetail',
                          arguments: akhada.slug,
                        ),
                  ),
              ]),
              _relatedLinks(context, 'ak_related_saints'.tr(), [
                for (final saint in d.saints) SaintCard(saint: saint),
              ]),
              SourcesSection(sources: d.sources),
            ],
          ),
        );
      },
    );
  }
}
