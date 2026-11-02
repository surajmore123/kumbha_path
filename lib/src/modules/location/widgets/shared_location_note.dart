import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show openExternal;
import 'package:kumbha_path/src/modules/location/data/location_repository.dart';
import 'package:kumbha_path/src/modules/location/models/location_models.dart';
import 'package:kumbha_path/src/modules/location/widgets/location_parts.dart';

/// On a Lost & Found case: the person's own sharing, if it's already open to
/// this viewer. The server decides, and a report changes nothing about that.
class SharedLocationNote extends StatefulWidget {
  const SharedLocationNote({super.key, required this.caseId, this.repository});

  final String caseId;
  final LocationRepository? repository;

  @override
  State<SharedLocationNote> createState() => _SharedLocationNoteState();
}

class _SharedLocationNoteState extends State<SharedLocationNote> {
  LocationPerson? _person;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final person = await (widget.repository ?? LocationServices.repository)
          .caseLocation(widget.caseId);
      if (mounted) {
        setState(() {
          _person = person;
          _loaded = true;
        });
      }
    } catch (_) {
      // Nothing is shown rather than a guess.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final person = _person;
    if (person == null) {
      return FamilyNote(
        title: 'loc_case_title'.tr(),
        text: 'loc_case_none'.tr(),
      );
    }
    final e = context.editorial;
    final now = DateTime.now();
    final age = person.ageSeconds;
    final accuracy = person.accuracyM;
    final freshness = person.freshnessAt(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('loc_case_title'.tr(), style: e.title),
        AppSpacing.gapXs,
        FreshnessTag(freshness),
        AppSpacing.gapXs,
        Text(
          [
            if (age != null) 'loc_updated'.tr(args: [agoText(age)]),
            if (accuracy != null) accuracyText(accuracy),
          ].join(' · '),
          style: e.meta,
        ),
        Text('loc_case_note'.tr(), style: e.meta),
        if (person.hasPosition)
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed:
                () => openExternal(
                  context,
                  'https://www.google.com/maps/search/?api=1&query=${person.latitude},${person.longitude}',
                ),
            icon: const Icon(Icons.place_outlined, size: 18),
            label: Text('loc_case_open'.tr()),
          ),
      ],
    );
  }
}
