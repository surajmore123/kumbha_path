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
import 'package:kumbha_path/src/modules/website/widgets/website_widgets.dart';

/// `/announcements`: the notices admins publish in the website admin panel
/// (the same list kumbhapath.in shows on Today and Home), pinned first.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  static const double _maxWidth = 760;

  @override
  void initState() {
    super.initState();
    // Always fetch fresh; any list already loaded stays visible meanwhile.
    context.read<WebsiteBloc>().add(const LoadAnnouncements());
  }

  Future<void> _refresh() => loadAndWait(
    context.read<WebsiteBloc>().add,
    (done) => LoadAnnouncements(done: done),
  );

  @override
  Widget build(BuildContext context) {
    final locale =
        EasyLocalization.of(context)?.locale.languageCode ??
        Localizations.localeOf(context).languageCode;
    return MainLayout(
      appBar: AppAppBar(title: 'web_ann_title'.tr()),
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
                      a.announcementsStatus != b.announcementsStatus ||
                      a.announcements != b.announcements,
              builder:
                  (context, state) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      side,
                      AppSpacing.sm,
                      side,
                      AppSpacing.huge,
                    ),
                    children: [
                      FadeSlideIn(
                        child: Text(
                          'web_ann_note'.tr(),
                          style: context.textTheme.bodySmall,
                        ),
                      ),
                      AppSpacing.gapLg,
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: KeyedSubtree(
                          key: ValueKey(state.announcementsStatus),
                          child: _body(state, locale),
                        ),
                      ),
                    ],
                  ),
            );
          },
        ),
      ),
    );
  }

  Widget _body(WebsiteState state, String locale) {
    switch (state.announcementsStatus) {
      case WebsiteStatus.initial:
      case WebsiteStatus.loading:
        return Column(
          children: [
            for (var i = 0; i < 3; i++) ...[
              Container(
                height: 132,
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
            title: 'web_ann_failed'.tr(),
            onRetry: _refresh,
          ),
        );
      case WebsiteStatus.ready:
        if (state.announcements.isEmpty) {
          return AppCard(
            padding: EdgeInsets.zero,
            child: AppEmptyState(
              compact: true,
              icon: Icons.campaign_outlined,
              title: 'web_ann_empty'.tr(),
            ),
          );
        }
        return Column(
          children: [
            for (final (i, a) in state.announcements.indexed) ...[
              FadeSlideIn(
                key: ValueKey(a.id),
                index: i,
                child: AnnouncementCard(announcement: a, locale: locale),
              ),
              AppSpacing.gapMd,
            ],
          ],
        );
    }
  }
}
