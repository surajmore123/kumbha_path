import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/patrika/data/patrika_repository.dart';
import 'package:kumbha_path/src/modules/patrika/models/patrika_models.dart';
import 'package:kumbha_path/src/modules/patrika/widgets/patrika_parts.dart';

/// Dashboard "Discover" tab: today's story above the three ways in. If the
/// story can't load, the three links still work.
class DiscoverPanel extends StatefulWidget {
  const DiscoverPanel({super.key, required this.onOpen, this.repository});

  final void Function(String route, {Object? arguments}) onOpen;
  final PatrikaRepository? repository;

  @override
  State<DiscoverPanel> createState() => _DiscoverPanelState();
}

class _DiscoverPanelState extends State<DiscoverPanel> {
  NewsStory? _lead;
  String? _language;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = journeyLanguage(context);
    if (language == _language) return;
    _language = language;
    (widget.repository ?? PatrikaServices.repository)
        .newsHome(language)
        .then((home) {
          if (mounted) setState(() => _lead = home.lead);
        })
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final lead = _lead;
    Widget link(String label, String route) => Expanded(
      child: Pressable(
        onTap: () => widget.onOpen(route),
        label: label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
          ),
          child: Center(
            child: Text(label, textAlign: TextAlign.center, style: e.title),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lead != null)
          Pressable(
            onTap: () => widget.onOpen('/newsArticle', arguments: lead.slug),
            label: lead.headline,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipPath(
                    clipper: const ArchClipper(),
                    child: SizedBox(
                      width: 84,
                      height: 104,
                      child: EditorialImage(url: lead.image?.url),
                    ),
                  ),
                  AppSpacing.gapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('pt_todays_story'.tr(), style: e.kicker),
                        AppSpacing.gapXs,
                        Text(
                          lead.headline,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: e.title,
                        ),
                        AppSpacing.gapXs,
                        MetaLine([lead.publisher.name]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const GhatRule(padding: EdgeInsets.zero),
        Row(
          children: [
            link('pt_tab_news'.tr(), '/kumbhNews'),
            link('pt_tab_learn'.tr(), '/learn'),
            link('dash_tab_akhadas'.tr(), '/akhadas'),
          ],
        ),
      ],
    );
  }
}
