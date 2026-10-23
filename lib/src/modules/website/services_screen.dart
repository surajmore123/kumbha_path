import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/website_bloc/website_bloc.dart';
import 'package:kumbha_path/src/bloc/website_bloc/website_event.dart';
import 'package:kumbha_path/src/bloc/website_bloc/website_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/models/website_models.dart';
import 'package:kumbha_path/src/modules/website/widgets/website_widgets.dart';

/// `/services`: stays, cabs, tours and packages published on kumbhapath.in
/// (partner listings approved in the admin panel). The heading uses the
/// website's CMS text when an admin has edited it.
///
/// Optional route argument: a [ListingCategory] to open on.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key, this.initialCategory});

  final ListingCategory? initialCategory;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  static const double _maxWidth = 760;

  late ListingCategory _category =
      widget.initialCategory ?? ListingCategory.hotels;

  /// Direction of the last category change, for the slide transition.
  int _direction = 1;

  WebsiteBloc get _bloc => context.read<WebsiteBloc>();

  @override
  void initState() {
    super.initState();
    _bloc.add(LoadListings(_category));
    if (_bloc.state.content['home'] == null) {
      _bloc.add(const LoadPageContent('home'));
    }
  }

  void _select(ListingCategory c) {
    if (c == _category) return;
    setState(() {
      _direction = c.index > _category.index ? 1 : -1;
      _category = c;
    });
    if (_bloc.state.listingsStatusOf(c) != WebsiteStatus.ready) {
      _bloc.add(LoadListings(c));
    }
  }

  Future<void> _refresh() => loadAndWait(
    _bloc.add,
    (done) => LoadListings(_category, done: done),
  );

  void _open(Listing l) =>
      Navigator.pushNamed(context, '/listingDetail', arguments: l);

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      appBar: AppAppBar(title: 'web_services_title'.tr()),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(
              AppSpacing.pageGutter,
              (constraints.maxWidth - _maxWidth) / 2,
            );
            return BlocBuilder<WebsiteBloc, WebsiteState>(
              buildWhen:
                  (a, b) =>
                      a.listingsStatus != b.listingsStatus ||
                      a.listings != b.listings ||
                      a.content != b.content,
              builder: (context, state) {
                final cms = state.page('home');
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    side,
                    AppSpacing.sm,
                    side,
                    AppSpacing.huge,
                  ),
                  children: [
                    FadeSlideIn(
                      child: _Header(
                        title: cms.text(
                          'home.services.title',
                          'web_services_heading'.tr(),
                        ),
                        subtitle: cms.text(
                          'home.services.subtitle',
                          'web_services_subtitle'.tr(),
                        ),
                      ),
                    ),
                    AppSpacing.gapLg,
                    FadeSlideIn(
                      index: 1,
                      child: _CategoryChips(
                        selected: _category,
                        onSelected: _select,
                      ),
                    ),
                    AppSpacing.gapLg,
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final incoming =
                            child.key == ValueKey(_bodyKey(state));
                        final dx = (incoming ? 0.08 : -0.08) * _direction;
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(dx, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      layoutBuilder:
                          (current, previous) => Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              ...previous,
                              if (current != null) current,
                            ],
                          ),
                      child: KeyedSubtree(
                        key: ValueKey(_bodyKey(state)),
                        child: _body(state),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _bodyKey(WebsiteState state) =>
      '${_category.name}-${state.listingsStatusOf(_category).name}';

  Widget _body(WebsiteState state) {
    switch (state.listingsStatusOf(_category)) {
      case WebsiteStatus.initial:
      case WebsiteStatus.loading:
        return Column(
          children: [
            for (var i = 0; i < 2; i++) ...[
              Container(
                height: 280,
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHigh,
                  borderRadius: AppRadius.cardAll,
                ),
              ),
              AppSpacing.gapMd,
            ],
          ],
        );
      case WebsiteStatus.failed:
        return AppCard(
          padding: EdgeInsets.zero,
          child: AppErrorView(
            compact: true,
            title: 'web_services_failed'.tr(),
            onRetry: () => _bloc.add(LoadListings(_category)),
          ),
        );
      case WebsiteStatus.ready:
        final items = state.listingsOf(_category);
        if (items.isEmpty) {
          return AppCard(
            padding: EdgeInsets.zero,
            child: AppEmptyState(
              compact: true,
              icon: ListingImage.categoryIcon(_category),
              title: 'web_services_empty'.tr(),
            ),
          );
        }
        return Column(
          children: [
            for (final (i, l) in items.indexed) ...[
              FadeSlideIn(
                key: ValueKey(l.id),
                index: i,
                child: ListingCard(listing: l, onTap: () => _open(l)),
              ),
              AppSpacing.gapMd,
            ],
          ],
        );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardAll,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryContainer, colors.secondaryContainer],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.textTheme.titleLarge?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          AppSpacing.gapXs,
          Text(
            subtitle,
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontally scrolling category chips; the selected chip animates.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

  final ListingCategory selected;
  final ValueChanged<ListingCategory> onSelected;

  static String label(ListingCategory c) => switch (c) {
    ListingCategory.hotels => 'web_cat_hotels'.tr(),
    ListingCategory.cabs => 'web_cat_cabs'.tr(),
    ListingCategory.tours => 'web_cat_tours'.tr(),
    ListingCategory.packages => 'web_cat_packages'.tr(),
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final c in ListingCategory.values) ...[
            if (c.index > 0) AppSpacing.gapSm,
            ChoiceChip(
              avatar: Icon(ListingImage.categoryIcon(c), size: 18),
              label: Text(label(c)),
              selected: c == selected,
              showCheckmark: false,
              onSelected: (_) => onSelected(c),
            ),
          ],
        ],
      ),
    );
  }
}
