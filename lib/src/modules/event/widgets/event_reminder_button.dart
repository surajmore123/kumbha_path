import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/event/event_item.dart';
import 'package:permission_handler/permission_handler.dart';

/// Whether the OS is blocking notifications for the app. Reminders are
/// delivered as push notifications, so a saved reminder can't arrive then.
typedef NotificationsBlockedCheck = Future<bool> Function();

Future<bool> defaultNotificationsBlocked() async {
  try {
    final status = await Permission.notification.status;
    return status.isDenied || status.isPermanentlyDenied;
  } catch (_) {
    return false; // Unknown: don't warn.
  }
}

/// Reminder toggle for one event, backed by the app-wide
/// [AppDetailsBloc] exactly as before: `ReminderToggleEvent` with an
/// explicit `ENABLE` / `DISABLE` action, and `reminderStatus[eventId]` as
/// the state. The explicit action makes repeated taps idempotent.
///
/// The API provides no reminder state with events, so "on" reflects
/// changes made during this app session only.
class EventReminderButton extends StatefulWidget {
  const EventReminderButton({
    super.key,
    required this.event,
    this.compact = false,
    this.notificationsBlocked,
  });

  final EventItem event;

  /// Icon toggle for list rows instead of a full-width button.
  final bool compact;
  final NotificationsBlockedCheck? notificationsBlocked;

  static const Duration timeout = Duration(seconds: 30);

  @override
  State<EventReminderButton> createState() => _EventReminderButtonState();
}

class _EventReminderButtonState extends State<EventReminderButton> {
  bool _pending = false;
  bool _target = false;
  Timer? _timeout;

  String get _id => widget.event.id;

  void _toggle(bool currentlyOn) {
    if (_pending || !widget.event.canRemind) return;
    setState(() {
      _pending = true;
      _target = !currentlyOn;
    });
    _timeout?.cancel();
    _timeout = Timer(EventReminderButton.timeout, () => _finish(false));
    context.read<AppDetailsBloc>().add(
      ReminderToggleEvent(
        action: currentlyOn ? 'DISABLE' : 'ENABLE',
        eventId: _id,
      ),
    );
  }

  Future<void> _finish(bool ok) async {
    if (!mounted || !_pending) return;
    _timeout?.cancel();
    final target = _target;
    setState(() => _pending = false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();

    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('events_reminder_failed'.tr()),
          action: SnackBarAction(
            label: 'common_retry'.tr(),
            onPressed: () => _toggle(!target),
          ),
        ),
      );
      return;
    }
    final blocked =
        target &&
        await (widget.notificationsBlocked ?? defaultNotificationsBlocked)();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          blocked
              ? 'events_reminder_blocked'.tr()
              : (target ? 'events_reminder_set' : 'events_reminder_off').tr(
                args: [widget.event.name],
              ),
        ),
        action:
            blocked
                ? SnackBarAction(
                  label: 'temple_open_settings'.tr(),
                  onPressed: openAppSettings,
                )
                : null,
      ),
    );
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.event.canRemind) return const SizedBox.shrink();
    return BlocConsumer<AppDetailsBloc, AppDetailsState>(
      listenWhen:
          (a, b) =>
              _pending &&
              (a.status != b.status || a.reminderStatus != b.reminderStatus),
      listener: (context, state) {
        if (state.status == AppDetailsStatus.success &&
            (state.reminderStatus[_id] ?? false) == _target) {
          _finish(true);
        } else if (state.status == AppDetailsStatus.failed) {
          _finish(false);
        }
      },
      buildWhen: (a, b) => a.reminderStatus[_id] != b.reminderStatus[_id],
      builder: (context, state) {
        final on = state.reminderStatus[_id] ?? false;
        return widget.compact ? _compact(on) : _full(on);
      },
    );
  }

  Widget _compact(bool on) {
    if (_pending) {
      return const SizedBox.square(
        dimension: AppSpacing.minTouchTarget,
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return AppIconButton(
      icon: Icons.notifications_none_rounded,
      selectedIcon: Icons.notifications_active_rounded,
      isSelected: on,
      variant: on ? AppIconButtonVariant.tonal : AppIconButtonVariant.standard,
      tooltip: on ? 'events_disable_reminder'.tr() : 'events_remind_me'.tr(),
      onPressed: () => _toggle(on),
    );
  }

  Widget _full(bool on) {
    final semantic = context.semanticColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (on) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusPill(
              label: 'events_reminder_on'.tr(),
              icon: Icons.check_rounded,
              foreground: semantic.onSuccessContainer,
              background: semantic.successContainer,
            ),
          ),
          AppSpacing.gapSm,
        ],
        on
            ? AppButton.outlined(
              label: 'events_disable_reminder'.tr(),
              leadingIcon: Icons.notifications_off_outlined,
              isLoading: _pending,
              onPressed: () => _toggle(on),
            )
            : AppButton.secondary(
              label: 'events_remind_me'.tr(),
              leadingIcon: Icons.notifications_active_outlined,
              isLoading: _pending,
              onPressed: () => _toggle(on),
            ),
      ],
    );
  }
}
