import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show formatDate, journeyLanguage;
import 'package:kumbha_path/src/modules/lostfound/data/lf_repository.dart';
import 'package:kumbha_path/src/modules/lostfound/models/lf_models.dart';

String lfErrorText(Object error) => familyErrorText(error);

String statusLabel(String status) => 'lf_status_$status'.tr();

/// What this status means for a family, in plain words.
String statusMeaning(String status) => 'lf_status_${status}_means'.tr();

String ageText(int? low, int? high) {
  if (low == null) return '';
  if (high == null || high == low) return 'lf_age_about'.tr(args: ['$low']);
  return 'lf_age_range'.tr(args: ['$low', '$high']);
}

String dateTimeText(BuildContext context, DateTime at) =>
    '${formatDate(context, at)}, ${TimeOfDay.fromDateTime(at).format(context)}';

/// A status with its colour, label and icon, so it never relies on colour.
class StatusTag extends StatelessWidget {
  const StatusTag(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final s = context.semanticColors;
    final (IconData icon, Color color) = switch (status) {
      'REUNITED' => (Icons.favorite_rounded, s.success),
      'MATCH_CONFIRMED' => (Icons.verified_rounded, s.success),
      'POTENTIAL_MATCH_FOUND' => (Icons.search_rounded, s.gold),
      'VERIFICATION_REQUIRED' => (Icons.fact_check_outlined, s.gold),
      'REJECTED' => (Icons.block_rounded, colors.error),
      'CLOSED' => (Icons.check_circle_outline, colors.onSurfaceVariant),
      _ => (Icons.schedule_rounded, colors.primary),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        AppSpacing.gapXs,
        Flexible(
          child: Text(
            statusLabel(status),
            style: context.textTheme.labelMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// How far a case has come: beads on a thread, filled to the current stage.
class StageRail extends StatelessWidget {
  const StageRail({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final stage = caseStages.indexOf(status);
    if (stage < 0) return StatusTag(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepThread(step: stage, total: caseStages.length),
        AppSpacing.gapSm,
        StatusTag(status),
      ],
    );
  }
}

/// A case photo, fetched with the login and held only for this screen.
class PrivatePhoto extends StatelessWidget {
  const PrivatePhoto({
    super.key,
    required this.id,
    required this.repository,
    this.size = 96,
  });

  final String id;
  final LostFoundRepository repository;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: AppRadius.mdAll,
    child: SizedBox.square(
      dimension: size,
      child: FutureBuilder<Uint8List?>(
        future: repository.attachment(id),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          return bytes == null
              ? ColoredBox(color: context.colorScheme.surfaceContainerHigh)
              : Image.memory(
                bytes,
                fit: BoxFit.cover,
                cacheWidth: (size * 3).round(),
                errorBuilder:
                    (_, __, ___) => ColoredBox(
                      color: context.colorScheme.surfaceContainerHigh,
                    ),
              );
        },
      ),
    ),
  );
}

/// Picks a time, up to now.
class WhenField extends StatelessWidget {
  const WhenField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value ?? now),
    );
    if (time == null) return;
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final at = value;
    return FactRow(
      label: label,
      value: at == null ? 'lf_choose_time'.tr() : dateTimeText(context, at),
      trailing: IconButton(
        tooltip: label,
        icon: const Icon(Icons.schedule_rounded),
        onPressed: () => _pick(context),
      ),
    );
  }
}

/// The person's current position, once, if they allow it.
Future<(double, double)?> readPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition();
    return (position.latitude, position.longitude);
  } catch (_) {
    return null;
  }
}

typedef PhotoPicker = Future<Uint8List?> Function();

Future<Uint8List?> pickCasePhoto() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
  );
  return picked?.readAsBytes();
}

/// Shown wherever someone reports: what this is, and what it isn't.
class NotOfficialNote extends StatelessWidget {
  const NotOfficialNote({super.key});

  @override
  Widget build(BuildContext context) =>
      FamilyNote(text: 'lf_not_official'.tr());
}

String lfLanguage(BuildContext context) => journeyLanguage(context);
