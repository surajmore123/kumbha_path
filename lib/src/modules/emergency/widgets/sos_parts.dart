import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/emergency/data/emergency_repository.dart';
import 'package:kumbha_path/src/modules/emergency/models/emergency_models.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show confirmJourneyAction, openExternal;
import 'package:kumbha_path/src/modules/lostfound/widgets/lf_parts.dart'
    show dateTimeText;

String sosCategoryLabel(String category) => 'sos_cat_$category'.tr();
String sosStatusLabel(String status) => 'sos_status_$status'.tr();
String sosErrorText(Object error) => familyErrorText(error);

IconData sosCategoryIcon(String category) => switch (category) {
  'medical' => Icons.medical_services_outlined,
  'separated_vulnerable' => Icons.escalator_warning_rounded,
  'lost' => Icons.person_search_rounded,
  'safety_threat' => Icons.gpp_maybe_outlined,
  'accident' => Icons.personal_injury_outlined,
  'crowd' => Icons.groups_rounded,
  _ => Icons.emergency_outlined,
};

/// A phone call, always behind a confirmation and never started by the app
/// alone. The wording keeps it apart from an app SOS.
Future<void> confirmAndDial(
  BuildContext context, {
  required String number,
  required String title,
  String? message,
}) async {
  final sure = await confirmJourneyAction(
    context,
    title: title,
    message: message ?? 'sos_call_body'.tr(),
    confirm: 'sos_call_confirm'.tr(),
  );
  if (sure && context.mounted) await openExternal(context, 'tel:$number');
}

/// The numbers a phone can always ring, offered wherever an SOS may fail.
class DirectCallButtons extends StatelessWidget {
  const DirectCallButtons({super.key, this.numbers = fallbackEmergencyNumbers});

  final List<EmergencyNumber> numbers;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final n in numbers)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error),
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed:
                  () => confirmAndDial(
                    context,
                    number: n.number,
                    title: 'sos_call_title'.tr(args: [n.number]),
                  ),
              icon: const Icon(Icons.call_rounded),
              label: Text('sos_call_number'.tr(args: [n.number])),
            ),
          ),
      ],
    );
  }
}

/// Always visible, because the most dangerous mistake here is someone thinking
/// help is on its way when it isn't.
class NoDispatchNote extends StatelessWidget {
  const NoDispatchNote({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.semanticColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: s.warningContainer,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: s.onWarningContainer),
          AppSpacing.gapSm,
          Expanded(
            child: Text(
              'sos_no_dispatch'.tr(),
              style: TextStyle(color: s.onWarningContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Press and hold to send. Letting go early cancels. It's a large target, and
/// screen readers get a plain button that starts the countdown instead, because
/// a long press is hard or impossible for some people.
class SosHoldButton extends StatefulWidget {
  const SosHoldButton({
    super.key,
    required this.onActivated,
    required this.onAccessibleTap,
    this.holdFor = const Duration(seconds: 2),
    this.size = 188,
  });

  final VoidCallback onActivated;
  final VoidCallback onAccessibleTap;
  final Duration holdFor;
  final double size;

  @override
  State<SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<SosHoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: widget.holdFor,
  )..addStatusListener(_finished);

  void _finished(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      HapticFeedback.heavyImpact();
      _hold.value = 0;
      widget.onActivated();
    }
  }

  void _down(TapDownDetails _) {
    HapticFeedback.selectionClick();
    _hold.forward(from: 0);
  }

  void _release() {
    _hold.stop();
    _hold.value = 0;
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Semantics(
      button: true,
      label: 'sos_hold_semantics'.tr(),
      onTap: widget.onAccessibleTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _down,
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) {
            final holding = _hold.value > 0;
            return SizedBox.square(
              dimension: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: _hold.value,
                      strokeWidth: 10,
                      color: colors.onSurface,
                      backgroundColor: colors.error.withValues(alpha: 0.2),
                    ),
                  ),
                  Container(
                    width: widget.size - 28,
                    height: widget.size - 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.error,
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SOS',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            color: colors.onError,
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Text(
                            (holding ? 'sos_keep_holding' : 'sos_press_hold')
                                .tr(),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(color: colors.onError),
                          ),
                        ),
                      ],
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
}

/// Every stage of an SOS, in order. Each line says only what's actually known.
class SosStagesCard extends StatelessWidget {
  const SosStagesCard({super.key, required this.sos});

  final SosDetail sos;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final s = context.semanticColors;
    final family = sos.family;
    final sent = family.where((f) => f.sent).length;
    final reached = family.where((f) => f.reachedAppAt != null).length;
    final acknowledged = family.where((f) => f.acknowledgedAt != null).length;
    final responder = sos.responderAcknowledgedAt;

    Widget line(bool done, String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: done ? s.success : context.colorScheme.outline,
          ),
          AppSpacing.gapSm,
          Expanded(child: Text(text)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('sos_progress'.tr(), style: e.title),
        AppSpacing.gapSm,
        line(true, 'sos_stage_saved'.tr()),
        if (sos.isOwner) ...[
          if (family.isEmpty)
            line(false, 'sos_stage_no_family'.tr())
          else ...[
            line(
              sent > 0,
              'sos_stage_sent'.tr(args: ['$sent', '${family.length}']),
            ),
            line(
              reached > 0,
              'sos_stage_reached'.tr(args: ['$reached', '${family.length}']),
            ),
            line(
              acknowledged > 0,
              'sos_stage_family_ack'.tr(
                args: ['$acknowledged', '${family.length}'],
              ),
            ),
          ],
        ],
        line(
          responder != null,
          responder != null
              ? 'sos_stage_responder'.tr(
                args: [dateTimeText(context, responder)],
              )
              : 'sos_stage_no_responder'.tr(),
        ),
      ],
    );
  }
}

/// What happened, oldest first, saying who did each step.
class SosTimeline extends StatelessWidget {
  const SosTimeline({super.key, required this.sos});

  final SosDetail sos;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final steps = sos.timeline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, step) in steps.indexed)
          ThreadStep(
            marker: '${i + 1}',
            isLast: i == steps.length - 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sosStatusLabel(step.status), style: e.title),
                Text(
                  [
                    'sos_by_${step.by}'.tr(),
                    if (step.at != null) dateTimeText(context, step.at!),
                  ].join(' · '),
                  style: e.meta,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Asks for a short piece of text. Null if they backed out.
Future<String?> askForText(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirm,
  int maxLength = 1000,
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  final text = await showDialog<String>(
    context: context,
    builder:
        (dialog) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: maxLength,
            maxLines: 3,
            decoration: InputDecoration(hintText: hint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, controller.text.trim()),
              child: Text(confirm),
            ),
          ],
        ),
  );
  return text == null || text.isEmpty ? null : text;
}

/// Tells a request that didn't get through from one the server refused.
bool isNetworkFailure(Object error) =>
    error is FamilyException &&
    (error.kind == FamilyFailure.offline || error.kind == FamilyFailure.server);

/// The dashboard's way in. Red, so it can be found without reading.
class SosDashboardEntry extends StatelessWidget {
  const SosDashboardEntry({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final label = 'sos_entry'.tr();
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: colors.error,
        borderRadius: AppRadius.lgAll,
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: onOpen,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.sos_rounded, color: colors.onError),
                AppSpacing.gapSm,
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelLarge?.copyWith(
                      color: colors.onError,
                    ),
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
