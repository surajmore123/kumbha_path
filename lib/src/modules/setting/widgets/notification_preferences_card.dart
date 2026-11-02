import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show confirmJourneyAction;
import 'package:kumbha_path/src/services/notification_preferences.dart';

/// On/off switch per notification type, saved to the server (which only
/// sends the types left on). A switch changes at once and moves back if
/// saving fails.
class NotificationPreferencesCard extends StatefulWidget {
  const NotificationPreferencesCard({
    super.key,
    this.api = const NotificationPreferencesApi(),
    this.systemAllowed,
  });

  final NotificationPreferencesApi api;

  /// Whether the phone allows notifications for the app (null = unknown).
  final bool? systemAllowed;

  @override
  State<NotificationPreferencesCard> createState() =>
      _NotificationPreferencesCardState();
}

class _NotificationPreferencesCardState
    extends State<NotificationPreferencesCard> {
  Map<NotificationCategory, bool>? _values;
  bool _loading = true;
  final Set<NotificationCategory> _saving = {};

  static const Map<NotificationCategory, IconData> _icons = {
    NotificationCategory.eventReminders: Icons.alarm_outlined,
    NotificationCategory.eventUpdates: Icons.edit_calendar_outlined,
    NotificationCategory.newEvents: Icons.event_available_outlined,
    NotificationCategory.crowdAlerts: Icons.groups_outlined,
    NotificationCategory.safetyAlerts: Icons.health_and_safety_outlined,
    NotificationCategory.familyLocation: Icons.share_location_rounded,
    NotificationCategory.reunification: Icons.diversity_3_rounded,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final values = await widget.api.load();
    if (!mounted) return;
    setState(() {
      _values = values;
      _loading = false;
    });
  }

  Future<void> _toggle(NotificationCategory category, bool enabled) async {
    // These carry family and case news, so turning them off takes a second look.
    if (category == NotificationCategory.safetyAlerts && !enabled) {
      final sure = await confirmJourneyAction(
        context,
        title: 'note_safety_off_title'.tr(),
        message: 'note_safety_off_body'.tr(),
        confirm: 'note_safety_off_confirm'.tr(),
        destructive: true,
      );
      if (!sure || !mounted) return;
    }
    final previous = _values![category]!;
    setState(() {
      _values = {..._values!, category: enabled};
      _saving.add(category);
    });
    final saved = await widget.api.update(category, enabled);
    if (!mounted) return;
    setState(() {
      _saving.remove(category);
      _values = saved ?? {..._values!, category: previous};
    });
    if (saved == null) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('set_notif_save_failed'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colorScheme;
    final values = _values;

    Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: AppLoading(compact: true),
      );
    } else if (values == null) {
      body = Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: colors.onSurfaceVariant),
          AppSpacing.gapMd,
          Expanded(
            child: Text('set_notif_load_failed'.tr(), style: text.bodyMedium),
          ),
          TextButton(onPressed: _load, child: Text('common_retry'.tr())),
        ],
      );
    } else {
      body = Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.sos_rounded, color: colors.error),
            title: Text('note_emergency_title'.tr()),
            subtitle: Text('note_emergency_body'.tr()),
            trailing: const Icon(Icons.lock_outline_rounded),
          ),
          for (final category in NotificationCategory.values)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(_icons[category], color: colors.primary),
              title: Text('set_notif_${category.key}'.tr()),
              subtitle: Text('set_notif_${category.key}_desc'.tr()),
              value: values[category]!,
              onChanged:
                  _saving.contains(category)
                      ? null
                      : (enabled) => _toggle(category, enabled),
            ),
        ],
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('set_notif_types'.tr(), style: text.titleSmall),
          AppSpacing.gapXs,
          Text('set_notif_types_desc'.tr(), style: text.bodySmall),
          if (widget.systemAllowed == false) ...[
            AppSpacing.gapSm,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  size: 18,
                  color: colors.error,
                ),
                AppSpacing.gapXs,
                Expanded(
                  child: Text(
                    'set_notif_types_blocked'.tr(),
                    style: text.bodySmall?.copyWith(color: colors.error),
                  ),
                ),
              ],
            ),
          ],
          AppSpacing.gapSm,
          body,
        ],
      ),
    );
  }
}
