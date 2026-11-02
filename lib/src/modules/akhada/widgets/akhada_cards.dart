import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/akhada/models/akhada_models.dart';
import 'package:kumbha_path/src/modules/akhada/widgets/akhada_ui.dart';

const akhadaIcon = Icons.temple_hindu_outlined;
const saintIcon = Icons.self_improvement_rounded;

Color _muted(BuildContext context) => context.colorScheme.onSurfaceVariant;

class AkhadaCard extends StatelessWidget {
  const AkhadaCard({super.key, required this.akhada});

  final AkhadaSummary akhada;

  @override
  Widget build(BuildContext context) {
    final a = akhada;
    final text = context.textTheme;
    return AppCard(
      semanticLabel: a.commonName ?? a.name,
      onTap:
          () =>
              Navigator.pushNamed(context, '/akhadaDetail', arguments: a.slug),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContentThumbnail(image: a.image, fallback: akhadaIcon, size: 72),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.commonName ?? a.name, style: text.titleMedium),
                if (a.tradition != null)
                  Text(
                    a.tradition!.name,
                    style: text.labelMedium?.copyWith(
                      color: context.colorScheme.primary,
                    ),
                  ),
                if (a.summary.isNotEmpty) ...[
                  AppSpacing.gapXs,
                  Text(
                    a.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: _muted(context)),
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

class SaintCard extends StatelessWidget {
  const SaintCard({super.key, required this.saint});

  final SaintSummary saint;

  @override
  Widget build(BuildContext context) {
    final s = saint;
    final text = context.textTheme;
    final line = [
      if (s.title != null) s.title!.name,
      if (s.akhada != null) s.akhada!.label,
      if (s.historical) 'ak_historical_figure'.tr(),
    ].join(' · ');
    return AppCard(
      semanticLabel: s.name,
      onTap:
          () => Navigator.pushNamed(context, '/saintDetail', arguments: s.slug),
      child: Row(
        children: [
          ContentThumbnail(image: s.image, fallback: saintIcon, size: 64),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: text.titleMedium),
                if (line.isNotEmpty)
                  Text(
                    line,
                    style: text.bodySmall?.copyWith(color: _muted(context)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ArticleCard extends StatelessWidget {
  const ArticleCard({super.key, required this.article});

  final ArticleSummary article;

  @override
  Widget build(BuildContext context) {
    final a = article;
    final text = context.textTheme;
    return AppCard(
      semanticLabel: a.title,
      onTap:
          () =>
              Navigator.pushNamed(context, '/akhadaArticle', arguments: a.slug),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (a.image != null) ...[
            ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: AspectRatio(
                aspectRatio: 2,
                child: ContentThumbnail(
                  image: a.image,
                  fallback: Icons.auto_stories_outlined,
                  size: double.infinity,
                ),
              ),
            ),
            AppSpacing.gapSm,
          ],
          Text(
            'ak_category_${a.category}'.tr(),
            style: text.labelMedium?.copyWith(
              color: context.colorScheme.primary,
            ),
          ),
          AppSpacing.gapXs,
          Text(a.title, style: text.titleMedium),
          if (a.intro.isNotEmpty) ...[
            AppSpacing.gapXs,
            Text(
              a.intro,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: _muted(context)),
            ),
          ],
        ],
      ),
    );
  }
}

class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.activity});

  final AkhadaActivity activity;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final text = context.textTheme;
    final when =
        a.startDate == null
            ? null
            : a.endDate == null || a.endDate == a.startDate
            ? formatDate(context, a.startDate!)
            : '${formatDate(context, a.startDate!)} – '
                '${formatDate(context, a.endDate!)}';
    final link = a.sources.where((s) => s.url != null).firstOrNull;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConfirmationPill(a.confirmation),
          AppSpacing.gapSm,
          Text(a.title, style: text.titleMedium),
          if (when != null) _line(context, Icons.event_outlined, when),
          if (a.location != null)
            _line(context, Icons.place_outlined, a.location!),
          if (a.description.isNotEmpty) ...[
            AppSpacing.gapSm,
            Text(a.description, style: text.bodyMedium),
          ],
          if (a.akhadas.isNotEmpty) ...[
            AppSpacing.gapSm,
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final akhada in a.akhadas)
                  ActionChip(
                    label: Text(akhada.label),
                    onPressed:
                        () => Navigator.pushNamed(
                          context,
                          '/akhadaDetail',
                          arguments: akhada.slug,
                        ),
                  ),
              ],
            ),
          ],
          if (link != null)
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => openExternal(context, link.url!),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(
                'ak_source_named'.tr(args: [link.organization ?? link.title]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Row(
      children: [
        Icon(icon, size: 16, color: _muted(context)),
        AppSpacing.gapXs,
        Expanded(child: Text(value, style: context.textTheme.bodySmall)),
      ],
    ),
  );
}
