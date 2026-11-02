import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/akhada/akhada_controllers.dart';
import 'package:kumbha_path/src/modules/akhada/data/akhada_repository.dart';
import 'package:kumbha_path/src/modules/akhada/models/akhada_models.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show SourceNote, formatDate, journeyLanguage, openExternal;

export 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show SourceNote, formatDate, journeyLanguage, openExternal;

const akhadaMaxWidth = 720.0;

const akhadaPagePadding = EdgeInsets.fromLTRB(
  AppSpacing.lg,
  AppSpacing.lg,
  AppSpacing.lg,
  AppSpacing.huge,
);

String akhadaErrorText(AkhadaException? e) => switch (e?.kind) {
  AkhadaFailure.offline => 'ak_error_offline'.tr(),
  AkhadaFailure.notFound => 'ak_error_not_found'.tr(),
  _ => 'ak_error_server'.tr(),
};

/// Centres page content at a readable width on tablets.
Widget akhadaCentered(Widget child) => Align(
  alignment: Alignment.topCenter,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: akhadaMaxWidth),
    child: child,
  ),
);

/// How far a record has been checked, and when.
class VerificationLine extends StatelessWidget {
  const VerificationLine({super.key, required this.status, this.date});

  final Verification status;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final c = context.colorScheme;
    final s = context.semanticColors;
    final (fg, bg, icon) = switch (status) {
      Verification.official => (
        s.onSuccessContainer,
        s.successContainer,
        Icons.verified_outlined,
      ),
      Verification.sourced => (
        s.onInfoContainer,
        s.infoContainer,
        Icons.menu_book_outlined,
      ),
      Verification.awaiting => (
        s.onWarningContainer,
        s.warningContainer,
        Icons.hourglass_empty_rounded,
      ),
    };
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusPill(
          label: 'ak_verification_${status.name}'.tr(),
          foreground: fg,
          background: bg,
          icon: icon,
        ),
        if (date != null)
          Text(
            'ak_last_verified'.tr(args: [formatDate(context, date!)]),
            style: context.textTheme.bodySmall?.copyWith(
              color: c.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Official status of a Nashik Kumbh item. Never green unless confirmed.
class ConfirmationPill extends StatelessWidget {
  const ConfirmationPill(this.status, {super.key});

  final Confirmation status;

  @override
  Widget build(BuildContext context) {
    final c = context.colorScheme;
    final s = context.semanticColors;
    final (fg, bg, icon) = switch (status) {
      Confirmation.confirmed => (
        s.onSuccessContainer,
        s.successContainer,
        Icons.check_circle_outline_rounded,
      ),
      Confirmation.announced => (
        s.onWarningContainer,
        s.warningContainer,
        Icons.campaign_outlined,
      ),
      Confirmation.awaiting => (
        c.onSurfaceVariant,
        c.surfaceContainerHigh,
        Icons.hourglass_empty_rounded,
      ),
      Confirmation.historical => (
        s.onInfoContainer,
        s.infoContainer,
        Icons.history_edu_outlined,
      ),
    };
    return StatusPill(
      label: 'ak_confirmation_${status.name}'.tr(),
      foreground: fg,
      background: bg,
      icon: icon,
    );
  }
}

/// An authorized image with its credit available, or a neutral placeholder.
/// Never a generic photograph standing in for a named person.
class ContentThumbnail extends StatelessWidget {
  const ContentThumbnail({
    super.key,
    required this.image,
    required this.fallback,
    this.size = 56,
  });

  final ContentImage? image;
  final IconData fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colorScheme;
    final placeholder = ColoredBox(
      color: c.surfaceContainerHigh,
      child: Center(
        child: Icon(
          fallback,
          size: size.isFinite ? size * 0.5 : 40,
          color: c.onSurfaceVariant,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: AppRadius.mdAll,
      child: SizedBox.square(
        dimension: size,
        child:
            image == null
                ? placeholder
                : CachedNetworkImage(
                  imageUrl: image!.url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => placeholder,
                  errorWidget: (_, __, ___) => placeholder,
                ),
      ),
    );
  }
}

/// A wide image with its attribution, linked to the licence page. Shows
/// nothing without an image, so pages don't carry an empty banner.
class ContentBanner extends StatelessWidget {
  const ContentBanner({
    super.key,
    required this.image,
    this.aspectRatio = 16 / 9,
    this.alignment = Alignment.center,
  });

  final ContentImage? image;
  final double aspectRatio;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final img = image;
    if (img == null) return const SizedBox.shrink();
    final colors = context.colorScheme;
    final style = context.textTheme.labelSmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final placeholder = ColoredBox(color: colors.surfaceContainerHigh);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppRadius.mdAll,
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: CachedNetworkImage(
                imageUrl: img.url,
                fit: BoxFit.cover,
                alignment: alignment,
                placeholder: (_, __) => placeholder,
                errorWidget: (_, __, ___) => placeholder,
              ),
            ),
          ),
          AppSpacing.gapXs,
          if (img.representative) Text('ak_representative'.tr(), style: style),
          InkWell(
            onTap:
                img.sourceUrl == null
                    ? null
                    : () => openExternal(context, img.sourceUrl!),
            child: Text(
              'ak_image_credit'.tr(args: [img.credit]),
              style: style?.copyWith(
                decoration:
                    img.sourceUrl == null ? null : TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One titled block of text on a detail page. Empty text shows nothing.
class ContentSection extends StatelessWidget {
  const ContentSection({
    super.key,
    required this.title,
    this.text = '',
    this.child,
  });

  final String title;
  final String text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty && child == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.textTheme.titleMedium),
            AppSpacing.gapSm,
            if (text.isNotEmpty)
              Text(text, style: context.textTheme.bodyMedium),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

/// Shows where a page's facts come from.
class SourcesSection extends StatelessWidget {
  const SourcesSection({super.key, required this.sources});

  final List<ContentSource> sources;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();
    return ContentSection(
      title: 'ak_sources'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in sources)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                s.isOfficial ? Icons.verified_outlined : Icons.article_outlined,
              ),
              title: Text(s.title),
              subtitle: s.organization == null ? null : Text(s.organization!),
              trailing:
                  s.url == null
                      ? null
                      : const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: s.url == null ? null : () => openExternal(context, s.url!),
            ),
        ],
      ),
    );
  }
}

class SavedCopyNote extends StatelessWidget {
  const SavedCopyNote({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: SourceNote('ak_saved_copy'.tr()),
  );
}

/// Said when a translation isn't available yet.
class FallbackLanguageNote extends StatelessWidget {
  const FallbackLanguageNote({super.key, required this.contentLanguage});

  final String? contentLanguage;

  @override
  Widget build(BuildContext context) {
    if (contentLanguage == null ||
        contentLanguage == journeyLanguage(context)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SourceNote('ak_english_only'.tr()),
    );
  }
}

/// Loads one record for the app's language, with loading, retry and reload
/// when the language changes.
class DetailLoader<T> extends StatefulWidget {
  const DetailLoader({
    super.key,
    required this.load,
    required this.title,
    required this.builder,
    this.titleOf,
  });

  final Future<Fetched<T>> Function(String language) load;
  final String title;
  final String Function(T value)? titleOf;
  final Widget Function(BuildContext context, Fetched<T> result) builder;

  @override
  State<DetailLoader<T>> createState() => _DetailLoaderState<T>();
}

class _DetailLoaderState<T> extends State<DetailLoader<T>> {
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
  Widget build(BuildContext context) {
    return FutureBuilder<Fetched<T>>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data;
        return MainLayout(
          ctx: 0,
          appBar: AppAppBar(
            title:
                data != null && widget.titleOf != null
                    ? widget.titleOf!(data.value)
                    : widget.title,
          ),
          body:
              snap.connectionState != ConnectionState.done
                  ? const AppLoading()
                  : data == null
                  ? AppErrorView(
                    message: akhadaErrorText(
                      snap.error is AkhadaException
                          ? snap.error as AkhadaException
                          : null,
                    ),
                    onRetry: () {
                      setState(() {
                        _future = widget.load(_language!);
                      });
                    },
                  )
                  : widget.builder(context, data),
        );
      },
    );
  }
}

/// A filter choice for [DirectoryList].
class FilterOption {
  const FilterOption(this.value, this.label);

  final String value;
  final String label;
}

/// The shared directory layout: optional search, filter chips, then a paged
/// list with loading, empty, error and load-more states.
class DirectoryList<T> extends StatefulWidget {
  const DirectoryList({
    super.key,
    required this.title,
    required this.emptyTitle,
    required this.emptyIcon,
    required this.loadPage,
    required this.itemBuilder,
    this.searchHint,
    this.loadFilters,
    this.header,
  });

  final String title;
  final String emptyTitle;
  final IconData emptyIcon;

  /// Search hint; leave null for a list without search.
  final String? searchHint;

  /// Loads the page for a language, search text and selected filter.
  final Future<ContentPage<T>> Function(
    String language,
    String query,
    String? filter,
    int page,
  )
  loadPage;
  final Future<List<FilterOption>> Function(String language)? loadFilters;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget? header;

  @override
  State<DirectoryList<T>> createState() => _DirectoryListState<T>();
}

class _DirectoryListState<T> extends State<DirectoryList<T>> {
  static const _debounce = Duration(milliseconds: 350);

  late final ContentListController<T> _c = ContentListController<T>(
    (page) => widget.loadPage(_language!, _query, _filter, page),
  );
  final _search = TextEditingController();
  Timer? _timer;
  String? _language;
  String _query = '';
  String? _filter;
  List<FilterOption> _options = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = journeyLanguage(context);
    if (language != _language) {
      _language = language;
      _c.load();
      _loadFilters(language);
    }
  }

  Future<void> _loadFilters(String language) async {
    final load = widget.loadFilters;
    if (load == null) return;
    try {
      final options = await load(language);
      if (mounted && language == _language) {
        setState(() => _options = options);
      }
    } on AkhadaException {
      // The list still works unfiltered.
    }
  }

  void _onSearch(String value) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      final query = value.trim();
      if (query == _query) return;
      _query = query;
      _c.load();
    });
  }

  void _setFilter(String? value) {
    setState(() => _filter = value);
    _c.load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      ctx: 0,
      appBar: AppAppBar(title: widget.title),
      body: akhadaCentered(
        Column(
          children: [
            if (widget.searchHint != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  0,
                ),
                child: AppTextField(
                  controller: _search,
                  hint: widget.searchHint,
                  prefixIcon: Icons.search_rounded,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearch,
                ),
              ),
            if (_options.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text('ak_filter_all'.tr()),
                        selected: _filter == null,
                        onSelected: (_) => _setFilter(null),
                      ),
                    ),
                    for (final o in _options)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text(o.label),
                          selected: _filter == o.value,
                          onSelected: (_) => _setFilter(o.value),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: ListenableBuilder(
                listenable: _c,
                builder: (context, _) => _list(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final c = _c;
    if (c.loading && c.items.isEmpty) return const AppLoading();
    if (c.error != null) {
      return AppErrorView(message: akhadaErrorText(c.error), onRetry: c.load);
    }
    if (c.items.isEmpty) {
      return AppEmptyState(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        message:
            _query.isNotEmpty || _filter != null
                ? 'ak_empty_filtered'.tr()
                : 'ak_empty_message'.tr(),
      );
    }
    final hasHeader = widget.header != null || c.isSavedCopy;
    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView.separated(
        padding: akhadaPagePadding,
        itemCount: c.items.length + 1 + (hasHeader ? 1 : 0),
        separatorBuilder: (_, __) => AppSpacing.gapMd,
        itemBuilder: (context, index) {
          var i = index;
          if (hasHeader) {
            if (i == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (c.isSavedCopy) const SavedCopyNote(),
                  if (widget.header != null) widget.header!,
                ],
              );
            }
            i--;
          }
          if (i < c.items.length) {
            return widget.itemBuilder(context, c.items[i]);
          }
          if (c.loadingMore) return const AppLoading.compact();
          if (c.moreError != null) {
            return AppErrorView(
              compact: true,
              message: akhadaErrorText(c.moreError),
              onRetry: c.loadMore,
            );
          }
          if (!c.hasNext) return const SizedBox.shrink();
          return AppButton.outlined(
            label: 'ak_load_more'.tr(),
            onPressed: c.loadMore,
          );
        },
      ),
    );
  }
}
