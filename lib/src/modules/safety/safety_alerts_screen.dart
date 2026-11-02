import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart'
    show FamilyRepository, FamilyServices;
import 'package:kumbha_path/src/modules/family/family_home_screen.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show confirmJourneyAction, formatDate, openExternal, showJourneySnack;
import 'package:kumbha_path/src/modules/safety/data/safety_repository.dart';
import 'package:kumbha_path/src/modules/safety/models/safety_models.dart';

/// `/safetyAlerts`: what registered helpers have reported. With no arguments,
/// as when opened from a notification, it covers all the person's families.
class SafetyAlertsScreen extends StatefulWidget {
  const SafetyAlertsScreen({
    super.key,
    this.args,
    this.repository,
    this.families,
  });

  final FamilyArgs? args;
  final SafetyRepository? repository;
  final FamilyRepository? families;

  @override
  State<SafetyAlertsScreen> createState() => _SafetyAlertsScreenState();
}

class _SafetyAlertsScreenState extends State<SafetyAlertsScreen> {
  late final SafetyRepository _repo =
      widget.repository ?? SafetyServices.repository;
  List<FamilyAlert>? _alerts;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<String>> _familyIds() async {
    final circle = widget.args?.circle;
    if (circle != null) return [circle.id];
    final families = widget.families ?? FamilyServices.repository;
    return [for (final c in await families.circles()) c.id];
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final all = <FamilyAlert>[];
      for (final id in await _familyIds()) {
        all.addAll(await _repo.alerts(id));
      }
      all.sort((a, b) {
        if (a.isResolved != b.isResolved) return a.isResolved ? 1 : -1;
        final at = a.createdAt, bt = b.createdAt;
        return at == null || bt == null ? 0 : bt.compareTo(at);
      });
      if (mounted) setState(() => _alerts = all);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) showJourneySnack(context, familyErrorText(e));
    }
  }

  Future<void> _resolve(FamilyAlert alert) async {
    final sure = await confirmJourneyAction(
      context,
      title: 'alert_resolve_title'.tr(),
      message: 'alert_resolve_body'.tr(),
      confirm: 'alert_resolve'.tr(),
    );
    if (sure) {
      await _act(() => _repo.resolveAlert(alert.familyId, alert.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _alerts;
    Widget body;
    if (alerts == null) {
      body =
          _error == null
              ? const Center(child: CircularProgressIndicator())
              : AppErrorView(message: familyErrorText(_error!), onRetry: _load);
    } else if (alerts.isEmpty) {
      body = AppEmptyState(
        icon: Icons.verified_user_outlined,
        title: 'alert_none_title'.tr(),
        message: 'alert_none_body'.tr(),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(editorialMargin),
          children: [
            FamilyNote(
              title: 'scan_handover_title'.tr(),
              text: 'alert_handover_family'.tr(),
            ),
            AppSpacing.gapXl,
            for (final alert in alerts)
              _AlertBlock(
                alert: alert,
                onAcknowledge:
                    () =>
                        _act(() => _repo.acknowledge(alert.familyId, alert.id)),
                onResolve: () => _resolve(alert),
              ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('alert_title'.tr())),
      body: SafeArea(child: body),
    );
  }
}

class _AlertBlock extends StatelessWidget {
  const _AlertBlock({
    required this.alert,
    required this.onAcknowledge,
    required this.onResolve,
  });

  final FamilyAlert alert;
  final VoidCallback onAcknowledge;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final colors = context.colorScheme;
    final at = alert.createdAt;
    final lat = alert.latitude;
    final lng = alert.longitude;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: alert.isResolved ? colors.outlineVariant : colors.error,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('alert_kind_${alert.kind}'.tr(), style: e.meta),
          Text(alert.memberName, style: e.headline),
          MetaLine([
            alert.reference,
            'alert_status_${alert.status}'.tr(),
            if (at != null) formatDate(context, at),
          ]),
          AppSpacing.gapXs,
          Text('alert_reported_by_${alert.helperRole}'.tr()),
          if (alert.note.isNotEmpty) ...[
            AppSpacing.gapXs,
            Text(alert.note, style: e.title),
          ],
          if (alert.locationWithheld) ...[
            AppSpacing.gapXs,
            Text('alert_location_withheld'.tr(), style: e.meta),
          ],
          if (lat != null && lng != null)
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed:
                  () => openExternal(
                    context,
                    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                  ),
              icon: const Icon(Icons.place_outlined, size: 18),
              label: Text('alert_open_map'.tr()),
            ),
          if (!alert.isResolved) ...[
            AppSpacing.gapSm,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (alert.isOpen)
                  AppButton(
                    expand: false,
                    label: 'alert_acknowledge'.tr(),
                    onPressed: onAcknowledge,
                  ),
                AppButton.secondary(
                  expand: false,
                  label: 'alert_resolve'.tr(),
                  onPressed: onResolve,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
