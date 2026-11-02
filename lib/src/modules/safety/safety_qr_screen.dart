import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/family_home_screen.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show confirmJourneyAction, formatDate, showJourneySnack;
import 'package:kumbha_path/src/modules/safety/data/safety_repository.dart';
import 'package:kumbha_path/src/modules/safety/models/safety_models.dart';
import 'package:kumbha_path/src/modules/safety/widgets/safety_card.dart';

/// `/safetyQr`: one person's card. Reachable only for yourself, or for someone
/// you look after. The server checks that on every request.
class SafetyQrScreen extends StatefulWidget {
  const SafetyQrScreen({super.key, required this.args, this.repository});

  final FamilyArgs args;
  final SafetyRepository? repository;

  @override
  State<SafetyQrScreen> createState() => _SafetyQrScreenState();
}

class _SafetyQrScreenState extends State<SafetyQrScreen> {
  late final SafetyRepository _repo =
      widget.repository ?? SafetyServices.repository;
  final _cardKey = GlobalKey();
  bool _loading = true;
  bool _busy = false;
  bool _justRevoked = false;
  SafetyQr? _qr;
  Object? _error;

  String get _familyId => widget.args.circle.id;
  String get _memberId => widget.args.memberId!;
  String get _name => widget.args.memberName ?? _qr?.memberName ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final qr = await _repo.qr(_familyId, _memberId);
      if (mounted) {
        setState(() {
          _qr = qr;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _change(Future<SafetyQr?> Function() action) async {
    setState(() => _busy = true);
    try {
      final qr = await action();
      if (mounted) {
        setState(() {
          _qr = qr;
          _busy = false;
          _justRevoked = qr == null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showJourneySnack(context, familyErrorText(e));
    }
  }

  Future<void> _regenerate() async {
    final sure = await confirmJourneyAction(
      context,
      title: 'qr_regenerate_title'.tr(),
      message: 'qr_regenerate_body'.tr(),
      confirm: 'qr_regenerate'.tr(),
      destructive: true,
    );
    if (sure) await _change(() => _repo.regenerate(_familyId, _memberId));
  }

  Future<void> _revoke() async {
    final sure = await confirmJourneyAction(
      context,
      title: 'qr_revoke_title'.tr(),
      message: 'qr_revoke_body'.tr(),
      confirm: 'qr_revoke'.tr(),
      destructive: true,
    );
    if (!sure) return;
    await _change(() async {
      await _repo.revoke(_familyId, _memberId);
      return null;
    });
  }

  /// Everything is rendered and handed over here, so failures read the same.
  Future<void> _withCard(
    Future<String?> Function(Uint8List png, Rect? origin) action,
  ) async {
    final box = context.findRenderObject();
    final origin =
        box is RenderBox && box.hasSize
            ? box.localToGlobal(Offset.zero) & box.size
            : null;
    try {
      final png = await captureCard(_cardKey);
      final done = await action(png, origin);
      if (done != null && mounted) showJourneySnack(context, done.tr());
    } catch (_) {
      if (mounted) showJourneySnack(context, 'qr_card_failed'.tr());
    }
  }

  Future<void> _save() => _withCard((png, _) async {
    final saved = await SafetyCardServices.actions.save(png);
    return saved ? 'qr_saved' : null;
  });

  Future<void> _print() => _withCard((png, _) async {
    await SafetyCardServices.actions.printCard(await buildCardPdf(png));
    return null;
  });

  Future<void> _share() => _withCard((png, origin) async {
    await SafetyCardServices.actions.share(png, origin);
    return null;
  });

  @override
  Widget build(BuildContext context) {
    final qr = _qr;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      final offline =
          _error is FamilyException &&
          (_error! as FamilyException).kind == FamilyFailure.offline;
      body = AppErrorView(
        title: offline ? 'fam_offline_title'.tr() : null,
        icon: offline ? Icons.cloud_off_rounded : Icons.error_outline,
        message: offline ? 'qr_offline_none'.tr() : familyErrorText(_error!),
        onRetry: _load,
      );
    } else if (qr == null) {
      body = _NoCard(
        name: _name,
        revoked: _justRevoked,
        busy: _busy,
        onCreate: () => _change(() => _repo.generate(_familyId, _memberId)),
      );
    } else {
      body = _CardView(
        name: _name,
        qr: qr,
        cardKey: _cardKey,
        busy: _busy,
        onSave: _save,
        onPrint: _print,
        onShare: _share,
        onRegenerate: _regenerate,
        onRevoke: _revoke,
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('qr_title'.tr())),
      body: SafeArea(child: body),
    );
  }
}

typedef Uint8ListLike = dynamic;

class _NoCard extends StatelessWidget {
  const _NoCard({
    required this.name,
    required this.revoked,
    required this.busy,
    required this.onCreate,
  });

  final String name;
  final bool revoked;
  final bool busy;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    return ListView(
      padding: const EdgeInsets.all(editorialMargin),
      children: [
        if (revoked) ...[_StatusLine(active: false), AppSpacing.gapMd],
        Text('qr_none_title'.tr(args: [name]), style: e.headline),
        AppSpacing.gapSm,
        Text('qr_none_body'.tr(), style: e.dek),
        AppSpacing.gapXl,
        const _HowItWorks(),
        AppSpacing.gapXl,
        AppButton(
          label: 'qr_create'.tr(),
          leadingIcon: Icons.qr_code_2_rounded,
          isLoading: busy,
          onPressed: busy ? null : onCreate,
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final s = context.semanticColors;
    final color = active ? s.success : context.colorScheme.error;
    return Row(
      children: [
        Icon(
          active ? Icons.verified_outlined : Icons.block_rounded,
          size: 18,
          color: color,
        ),
        AppSpacing.gapSm,
        Expanded(
          child: Text(
            active ? 'qr_status_active'.tr() : 'qr_status_revoked'.tr(),
            style: context.textTheme.labelLarge?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, key)
            in const ['qr_how_1', 'qr_how_2', 'qr_how_3'].indexed)
          ThreadStep(
            marker: '${i + 1}',
            isLast: i == 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${key}_title'.tr(), style: e.title),
                Text('${key}_body'.tr()),
              ],
            ),
          ),
      ],
    );
  }
}

class _CardView extends StatelessWidget {
  const _CardView({
    required this.name,
    required this.qr,
    required this.cardKey,
    required this.busy,
    required this.onSave,
    required this.onPrint,
    required this.onShare,
    required this.onRegenerate,
    required this.onRevoke,
  });

  final String name;
  final SafetyQr qr;
  final GlobalKey cardKey;
  final bool busy;
  final VoidCallback onSave;
  final VoidCallback onPrint;
  final VoidCallback onShare;
  final VoidCallback onRegenerate;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final created = qr.createdAt;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        editorialMargin,
        AppSpacing.sm,
        editorialMargin,
        AppSpacing.huge,
      ),
      children: [
        Semantics(header: true, child: Text(name, style: e.headline)),
        AppSpacing.gapXs,
        _StatusLine(active: qr.isActive),
        if (created != null)
          MetaLine([
            'qr_since'.tr(args: [formatDate(context, created)]),
          ]),
        if (qr.fromDevice) ...[
          AppSpacing.gapMd,
          FamilyNote(
            title: 'fam_offline_title'.tr(),
            text: 'qr_offline_saved'.tr(),
          ),
        ],
        AppSpacing.gapLg,
        // Scaled to fit narrow screens, without changing the printed layout.
        Center(
          child: FittedBox(
            child: RepaintBoundary(
              key: cardKey,
              child: SafetyCard(
                payload: qr.payload,
                initial: cardInitial(name),
              ),
            ),
          ),
        ),
        AppSpacing.gapLg,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafetyAction(
              icon: Icons.download_rounded,
              label: 'qr_save',
              onTap: onSave,
            ),
            SafetyAction(
              icon: Icons.print_outlined,
              label: 'qr_print',
              onTap: onPrint,
            ),
            SafetyAction(
              icon: Icons.ios_share_rounded,
              label: 'qr_share',
              onTap: onShare,
            ),
          ],
        ),
        AppSpacing.gapXl,
        FamilyNote(
          title: 'qr_private_title'.tr(),
          text: 'qr_private_body'.tr(),
        ),
        AppSpacing.gapXl,
        Text('fam_how_title'.tr(), style: e.headline),
        AppSpacing.gapLg,
        const _HowItWorks(),
        AppSpacing.gapXl,
        const GhatRule(padding: EdgeInsets.zero),
        AppSpacing.gapLg,
        AppButton.secondary(
          label: 'qr_regenerate'.tr(),
          leadingIcon: Icons.autorenew_rounded,
          isLoading: busy,
          onPressed: busy || qr.fromDevice ? null : onRegenerate,
        ),
        AppSpacing.gapSm,
        TextButton(
          onPressed: busy || qr.fromDevice ? null : onRevoke,
          child: Text(
            'qr_revoke'.tr(),
            style: TextStyle(color: context.colorScheme.error),
          ),
        ),
      ],
    );
  }
}
