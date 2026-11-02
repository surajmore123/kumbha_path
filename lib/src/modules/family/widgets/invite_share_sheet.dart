import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show formatDate, showJourneySnack;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// One invitation, ready to be passed on. [link] holds a secret token, so this
/// and everything below must never be printed.
@immutable
class InviteShare {
  const InviteShare({
    required this.familyName,
    required this.link,
    this.expires,
    this.phone,
  });

  final String familyName;
  final String link;
  final DateTime? expires;

  /// The number the organizer typed, as 10 digits, if any.
  final String? phone;

  @override
  String toString() => 'InviteShare';
}

enum InviteShareResult { shared, cancelled, unknown }

/// What the phone can do. A real device, or a fake in tests.
abstract class InviteSharer {
  /// False if nothing on the phone can open it. Implementations must just try:
  /// url_launcher's `canLaunchUrl` writes the address to the device log.
  Future<bool> open(Uri uri);
  Future<InviteShareResult> system(String text, Rect? origin);
  Future<void> copy(String text);
}

class PlatformInviteSharer implements InviteSharer {
  const PlatformInviteSharer();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<InviteShareResult> system(String text, Rect? origin) async {
    final result = await Share.share(text, sharePositionOrigin: origin);
    return switch (result.status) {
      ShareResultStatus.success => InviteShareResult.shared,
      ShareResultStatus.dismissed => InviteShareResult.cancelled,
      ShareResultStatus.unavailable => InviteShareResult.unknown,
    };
  }

  @override
  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}

/// Swappable in tests.
class InviteSharing {
  InviteSharing._();

  static InviteSharer sharer = const PlatformInviteSharer();
}

/// Everything in the text is encoded, so the "#" before the token survives.
Uri whatsAppUri(String text, {String? phone}) => Uri.parse(
  'whatsapp://send?text=${Uri.encodeComponent(text)}'
  '${phone == null ? '' : '&phone=91$phone'}',
);

/// iOS expects `&body=` where other platforms expect `?body=`.
Uri smsUri(String text, {String? phone, required bool ios}) => Uri.parse(
  'sms:${phone == null ? '' : '+91$phone'}'
  '${ios ? '&' : '?'}body=${Uri.encodeComponent(text)}',
);

String inviteMessage(BuildContext context, InviteShare share) {
  final expires = share.expires;
  return expires == null
      ? 'fam_invite_msg_open'.tr(args: [share.familyName, share.link])
      : 'fam_invite_msg'.tr(
        args: [share.familyName, share.link, formatDate(context, expires)],
      );
}

enum _Way { whatsApp, sms, more, copy }

/// Lets the organizer choose how to pass an invitation on. Nothing is sent
/// from here: each option hands the message to an app, and the person sends it.
Future<void> shareInvite(BuildContext context, InviteShare share) async {
  final text = inviteMessage(context, share);
  final box = context.findRenderObject();
  final origin =
      box is RenderBox && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
  final way = await showModalBottomSheet<_Way>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ShareSheet(share: share, message: text),
  );
  if (way == null || !context.mounted) return;

  final sharer = InviteSharing.sharer;
  void say(String key) {
    if (context.mounted) showJourneySnack(context, key.tr());
  }

  /// Nothing that goes wrong may leave the organizer with no way to share.
  Future<void> saveLink() async {
    try {
      await sharer.copy(share.link);
      say('fam_share_failed_copied');
    } catch (_) {
      say('fam_share_failed');
    }
  }

  Future<void> system({bool quiet = false}) async {
    try {
      final result = await sharer.system(text, origin);
      if (quiet) return;
      say(switch (result) {
        InviteShareResult.cancelled => 'fam_share_cancelled',
        _ => 'fam_share_opened',
      });
    } catch (_) {
      await saveLink();
    }
  }

  Future<void> app(Uri uri, String opened, String missing) async {
    if (await sharer.open(uri)) {
      say(opened);
    } else {
      say(missing);
      await system(quiet: true);
    }
  }

  switch (way) {
    case _Way.whatsApp:
      await app(
        whatsAppUri(text, phone: share.phone),
        'fam_share_opened_whatsapp',
        'fam_whatsapp_missing',
      );
    case _Way.sms:
      await app(
        smsUri(
          text,
          phone: share.phone,
          ios: defaultTargetPlatform == TargetPlatform.iOS,
        ),
        'fam_share_opened_sms',
        'fam_sms_missing',
      );
    case _Way.more:
      await system();
    case _Way.copy:
      try {
        await sharer.copy(share.link);
        say('fam_link_copied');
      } catch (_) {
        say('fam_share_failed');
      }
  }
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.share, required this.message});

  final InviteShare share;
  final String message;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final expires = share.expires;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          editorialMargin,
          0,
          editorialMargin,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('fam_share_title'.tr(), style: e.headline),
            ),
            AppSpacing.gapXs,
            Text(share.familyName, style: e.meta),
            AppSpacing.gapLg,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  [
                    _Way.whatsApp,
                    _Way.sms,
                    _Way.more,
                    _Way.copy,
                  ].map((way) => _WayButton(way)).toList(),
            ),
            AppSpacing.gapLg,
            FamilyNote(title: 'fam_share_preview'.tr(), text: message),
            AppSpacing.gapMd,
            Text(
              expires == null
                  ? 'fam_share_note_open'.tr()
                  : 'fam_share_note'.tr(args: [formatDate(context, expires)]),
              style: e.meta,
            ),
          ],
        ),
      ),
    );
  }
}

class _WayButton extends StatelessWidget {
  const _WayButton(this.way);

  final _Way way;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final (IconData icon, String key) = switch (way) {
      _Way.whatsApp => (Icons.chat_rounded, 'fam_way_whatsapp'),
      _Way.sms => (Icons.sms_outlined, 'fam_way_sms'),
      _Way.more => (Icons.ios_share_rounded, 'fam_way_more'),
      _Way.copy => (Icons.link_rounded, 'fam_way_copy'),
    };
    return Expanded(
      child: Pressable(
        onTap: () => Navigator.pop(context, way),
        label: key.tr(),
        child: ExcludeSemantics(
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: colors.onPrimaryContainer),
              ),
              AppSpacing.gapXs,
              Text(
                key.tr(),
                textAlign: TextAlign.center,
                style: context.editorial.meta,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
