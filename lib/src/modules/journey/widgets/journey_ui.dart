import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/journey/data/journey_repository.dart';
import 'package:kumbha_path/src/modules/journey/models/journey_models.dart';
import 'package:url_launcher/url_launcher.dart';

/// The plan language for the app's current locale (en, hi or mr).
String journeyLanguage(BuildContext context) {
  final code = context.locale.languageCode;
  return const ['en', 'hi', 'mr'].contains(code) ? code : 'en';
}

/// Formats in the app locale; falls back to English when that locale's
/// date symbols aren't loaded (Material localizations load them at runtime).
String _format(BuildContext context, String pattern, DateTime d) {
  try {
    return intl.DateFormat(pattern, context.locale.toLanguageTag()).format(d);
  } catch (_) {
    return intl.DateFormat(pattern, 'en').format(d);
  }
}

String formatDay(BuildContext context, DateTime d) =>
    _format(context, 'EEE, d MMM', d);

String formatDate(BuildContext context, DateTime d) =>
    _format(context, 'd MMM yyyy', d);

String formatRange(BuildContext context, DateTime? a, DateTime? b) {
  if (a == null || b == null) return 'jp_dates_not_set'.tr();
  if (a == b) return formatDate(context, a);
  return '${formatDate(context, a)} – ${formatDate(context, b)}';
}

/// "₹ 12,500" from a backend decimal string; null for blanks.
String? formatRupees(String? amount) {
  final value = double.tryParse(amount ?? '');
  if (value == null) return null;
  return '₹ ${intl.NumberFormat.decimalPattern('en_IN').format(value.round())}';
}

String statusLabel(JourneyStatus s) => 'jp_status_${s.name}'.tr();

({Color fg, Color bg}) statusColors(BuildContext context, JourneyStatus s) {
  final c = context.colorScheme;
  final sem = context.semanticColors;
  return switch (s) {
    JourneyStatus.planned => (
      fg: sem.onSuccessContainer,
      bg: sem.successContainer,
    ),
    JourneyStatus.completed => (
      fg: c.onSurfaceVariant,
      bg: c.surfaceContainerHigh,
    ),
    JourneyStatus.draft => (
      fg: sem.onWarningContainer,
      bg: sem.warningContainer,
    ),
  };
}

Widget journeyStatusPill(BuildContext context, JourneyStatus s) {
  final colors = statusColors(context, s);
  return StatusPill(
    label: statusLabel(s),
    foreground: colors.fg,
    background: colors.bg,
  );
}

IconData kindIcon(String kind) => switch (kind) {
  'travel' => Icons.directions_transit_rounded,
  'temple' => Icons.temple_hindu_rounded,
  'ghat' => Icons.water_rounded,
  'bathing' => Icons.waves_rounded,
  'event' => Icons.event_rounded,
  'rest' => Icons.self_improvement_rounded,
  'meal' => Icons.restaurant_rounded,
  'akhada' => Icons.groups_rounded,
  'sightseeing' => Icons.photo_camera_outlined,
  _ => Icons.sticky_note_2_outlined,
};

IconData transportIcon(String mode) => switch (mode) {
  'train' => Icons.train_rounded,
  'bus' => Icons.directions_bus_rounded,
  'flight' => Icons.flight_rounded,
  'private' => Icons.directions_car_rounded,
  'local' => Icons.directions_walk_rounded,
  _ => Icons.help_outline_rounded,
};

/// A user-facing sentence for a failed request.
String journeyErrorText(JourneyException? e) {
  if (e == null) return 'jp_error_generic'.tr();
  return switch (e.kind) {
    JourneyFailure.offline => 'jp_error_offline'.tr(),
    JourneyFailure.unauthorized => 'jp_error_signin'.tr(),
    JourneyFailure.notFound => 'jp_error_not_found'.tr(),
    JourneyFailure.invalid => e.message ?? 'jp_error_generic'.tr(),
    JourneyFailure.server => 'jp_error_server'.tr(),
  };
}

void showJourneySnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Opens an https link or tel:/sms:/mailto: outside the app.
Future<void> openExternal(BuildContext context, String link) async {
  final uri = Uri.tryParse(link);
  var opened = false;
  if (uri != null && const ['https', 'tel', 'sms', 'mailto'].contains(uri.scheme)) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
  }
  if (!opened && context.mounted) {
    showJourneySnack(context, 'jp_link_failed'.tr());
  }
}

Future<bool> confirmJourneyAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('jp_cancel'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style:
                  destructive
                      ? TextButton.styleFrom(
                        foregroundColor: ctx.colorScheme.error,
                      )
                      : null,
              child: Text(confirm),
            ),
          ],
        ),
  );
  return result == true;
}

/// "- 2 +" counter with a label, for traveller counts.
class CountField extends StatelessWidget {
  const CountField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = JourneyChoices.maxTravellers,
    this.helper,
  });

  final String label;
  final String? helper;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.titleSmall),
                if (helper != null)
                  Text(
                    helper!,
                    style: text.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'jp_decrease'.tr(args: [label]),
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: text.titleMedium,
              semanticsLabel: '$label $value',
            ),
          ),
          IconButton(
            tooltip: 'jp_increase'.tr(args: [label]),
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}

/// Small caption under official information: where it came from.
class SourceNote extends StatelessWidget {
  const SourceNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.info_outline_rounded,
        size: 16,
        color: context.colorScheme.onSurfaceVariant,
      ),
      AppSpacing.gapXs,
      Expanded(
        child: Text(
          text,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}
