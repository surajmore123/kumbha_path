import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show confirmJourneyAction, showJourneySnack;
import 'package:kumbha_path/src/modules/safety/data/safety_repository.dart';
import 'package:kumbha_path/src/modules/safety/models/safety_models.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

enum ScanProblem { permissionDenied, unavailable }

typedef ScannerBuilder =
    Widget Function(
      BuildContext context,
      ValueChanged<String> onCode,
      ValueChanged<ScanProblem> onProblem,
    );

typedef LocationReader = Future<(double, double)?> Function();

/// Null unless the helper allows it. Never asked for without them choosing to.
Future<(double, double)?> readHelperLocation() async {
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

class _Camera extends StatefulWidget {
  const _Camera({required this.onCode, required this.onProblem});

  final ValueChanged<String> onCode;
  final ValueChanged<ScanProblem> onProblem;

  @override
  State<_Camera> createState() => _CameraState();
}

class _CameraState extends State<_Camera> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MobileScanner(
    controller: _controller,
    onDetect: (capture) {
      final raw = capture.barcodes.firstOrNull?.rawValue;
      if (raw != null) widget.onCode(raw);
    },
    errorBuilder: (context, error) {
      final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onProblem(
          denied ? ScanProblem.permissionDenied : ScanProblem.unavailable,
        ),
      );
      return const SizedBox.shrink();
    },
  );
}

Widget _defaultScanner(
  BuildContext context,
  ValueChanged<String> onCode,
  ValueChanged<ScanProblem> onProblem,
) => _Camera(onCode: onCode, onProblem: onProblem);

enum _Stage { checking, notHelper, scanning, resolving, review, done, flagged }

/// `/safetyScan`: for registered helpers only. The server decides who that is,
/// on every request, and returns only what's needed to help.
class SafetyScanScreen extends StatefulWidget {
  const SafetyScanScreen({
    super.key,
    this.repository,
    this.scanner = _defaultScanner,
    this.location = readHelperLocation,
  });

  final SafetyRepository? repository;
  final ScannerBuilder scanner;
  final LocationReader location;

  @override
  State<SafetyScanScreen> createState() => _SafetyScanScreenState();
}

class _SafetyScanScreenState extends State<SafetyScanScreen> {
  late final SafetyRepository _repo =
      widget.repository ?? SafetyServices.repository;
  final _note = TextEditingController();
  _Stage _stage = _Stage.checking;
  ScanProblem? _problem;
  Object? _error;
  String? _message;
  ScanResult? _scan;
  AlertReceipt? _receipt;
  String? _situation;
  bool _shareLocation = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _stage = _Stage.checking;
      _error = null;
    });
    try {
      final status = await _repo.helperStatus();
      if (mounted) {
        setState(
          () => _stage = status.isHelper ? _Stage.scanning : _Stage.notHelper,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _restart() => setState(() {
    _stage = _Stage.scanning;
    _problem = null;
    _message = null;
    _scan = null;
    _receipt = null;
    _situation = null;
    _shareLocation = false;
    _note.clear();
  });

  Future<void> _onCode(String raw) async {
    if (_stage != _Stage.scanning) return;
    final token = safetyTokenFrom(raw);
    if (token == null) {
      setState(() => _message = 'scan_not_ours'.tr());
      return;
    }
    setState(() {
      _stage = _Stage.resolving;
      _message = null;
    });
    try {
      final scan = await _repo.resolve(token);
      if (mounted) {
        setState(() {
          _scan = scan;
          _stage = _Stage.review;
        });
      }
    } on FamilyException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.scanning;
        _message = switch (e.kind) {
          FamilyFailure.notFound => 'scan_unknown'.tr(),
          FamilyFailure.gone => 'scan_revoked'.tr(),
          _ => familyErrorText(e),
        };
      });
      if (e.kind == FamilyFailure.forbidden) {
        setState(() => _stage = _Stage.notHelper);
      }
    }
  }

  Future<void> _submit() async {
    final situation = _situation!;
    final flagged = situation == 'suspicious';
    final sure = await confirmJourneyAction(
      context,
      title: 'scan_confirm_title'.tr(),
      message: flagged ? 'scan_confirm_flag'.tr() : 'scan_confirm_alert'.tr(),
      confirm: 'scan_confirm'.tr(),
    );
    if (!sure || !mounted) return;
    setState(() => _busy = true);
    final position = _shareLocation ? await widget.location() : null;
    try {
      final receipt = await _repo.confirm(
        _scan!.scanId,
        situation: situation,
        note: _note.text.trim(),
        latitude: position?.$1,
        longitude: position?.$2,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _receipt = receipt;
        _stage = receipt == null ? _Stage.flagged : _Stage.done;
      });
    } on FamilyException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e.kind == FamilyFailure.gone) {
        _restart();
        setState(() => _message = 'scan_expired'.tr());
      } else {
        showJourneySnack(context, familyErrorText(e));
      }
    }
  }

  Future<void> _refreshReceipt() async {
    try {
      final receipt = await _repo.helperAlert(_receipt!.id);
      if (mounted) setState(() => _receipt = receipt);
    } catch (e) {
      if (mounted) showJourneySnack(context, familyErrorText(e));
    }
  }

  void _onProblem(ScanProblem problem) {
    if (mounted && _problem != problem) setState(() => _problem = problem);
  }

  Widget _body() {
    final error = _error;
    if (error != null) {
      return AppErrorView(message: familyErrorText(error), onRetry: _check);
    }
    return switch (_stage) {
      _Stage.checking ||
      _Stage.resolving => const Center(child: CircularProgressIndicator()),
      _Stage.notHelper => AppEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'scan_not_helper_title'.tr(),
        message: 'scan_not_helper_body'.tr(),
      ),
      _Stage.scanning => _scanningView(),
      _Stage.review => _reviewView(),
      _Stage.done => _doneView(),
      _Stage.flagged => AppEmptyState(
        icon: Icons.flag_outlined,
        title: 'scan_flagged_title'.tr(),
        message: 'scan_flagged_body'.tr(),
        actionLabel: 'scan_next'.tr(),
        onAction: _restart,
      ),
    };
  }

  Widget _scanningView() {
    final problem = _problem;
    if (problem != null) {
      final denied = problem == ScanProblem.permissionDenied;
      return AppEmptyState(
        icon: Icons.no_photography_outlined,
        title:
            denied
                ? 'scan_camera_denied_title'.tr()
                : 'scan_camera_failed_title'.tr(),
        message:
            denied
                ? 'scan_camera_denied_body'.tr()
                : 'scan_camera_failed_body'.tr(),
        actionLabel: denied ? 'scan_open_settings'.tr() : 'common_retry'.tr(),
        onAction: denied ? openAppSettings : _restart,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.scanner(context, _onCode, _onProblem),
        const IgnorePointer(child: _Viewfinder()),
        Positioned(
          left: editorialMargin,
          right: editorialMargin,
          bottom: AppSpacing.xl,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              borderRadius: AppRadius.lgAll,
            ),
            child: Text(
              _message ?? 'scan_hint'.tr(),
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }

  Widget _reviewView() {
    final e = context.editorial;
    final scan = _scan!;
    final situation = _situation;
    return ListView(
      padding: const EdgeInsets.all(editorialMargin),
      children: [
        Text('scan_card_of'.tr(), style: e.meta),
        Semantics(
          header: true,
          child: Text(
            scan.firstName.isEmpty ? '?' : scan.firstName,
            style: e.masthead,
          ),
        ),
        MetaLine([
          'scan_cat_${scan.category}'.tr(),
          'scan_language'.tr(args: ['fam_lang_${scan.language}'.tr()]),
        ]),
        AppSpacing.gapMd,
        FamilyNote(
          title: 'scan_verify_title'.tr(),
          text:
              scan.isChild ? 'scan_verify_child'.tr() : 'scan_verify_body'.tr(),
        ),
        if (scan.openAlerts.isNotEmpty) ...[
          AppSpacing.gapMd,
          FamilyNote(
            text: 'scan_already_open'.tr(args: [scan.openAlerts.join(', ')]),
          ),
        ],
        AppSpacing.gapXl,
        Text('scan_what_happened'.tr(), style: e.headline),
        AppSpacing.gapMd,
        for (final (value, icon) in const [
          ('separated', Icons.person_search_outlined),
          ('medical', Icons.medical_services_outlined),
          ('other', Icons.support_outlined),
          ('suspicious', Icons.flag_outlined),
        ])
          ChoiceRow(
            icon: icon,
            title: 'scan_sit_$value'.tr(),
            subtitle: 'scan_sit_${value}_hint'.tr(),
            selected: situation == value,
            onTap: () => setState(() => _situation = value),
          ),
        if (situation != null && situation != 'suspicious') ...[
          AppSpacing.gapMd,
          AppTextField(
            controller: _note,
            label: 'scan_note'.tr(),
            helperText: 'scan_note_hint'.tr(),
            maxLength: 200,
            maxLines: 2,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('scan_share_location'.tr()),
            subtitle: Text('scan_share_location_hint'.tr()),
            value: _shareLocation,
            onChanged: (v) => setState(() => _shareLocation = v),
          ),
        ],
        AppSpacing.gapLg,
        AppButton(
          label:
              situation == 'suspicious'
                  ? 'scan_record'.tr()
                  : 'scan_notify'.tr(),
          isLoading: _busy,
          onPressed: situation == null || _busy ? null : _submit,
        ),
        AppSpacing.gapSm,
        TextButton(onPressed: _restart, child: Text('scan_cancel'.tr())),
      ],
    );
  }

  Widget _doneView() {
    final e = context.editorial;
    final receipt = _receipt!;
    final key =
        receipt.duplicate
            ? 'scan_duplicate'
            : receipt.familyNotified
            ? 'scan_delivered'
            : receipt.delivery == 'no_devices'
            ? 'scan_no_devices'
            : 'scan_undelivered';
    return ListView(
      padding: const EdgeInsets.all(editorialMargin),
      children: [
        Text('scan_reference'.tr(), style: e.meta),
        SelectableText(
          receipt.reference,
          style: e.masthead.copyWith(color: context.colorScheme.primary),
        ),
        AppSpacing.gapLg,
        FamilyNote(text: key.tr()),
        AppSpacing.gapLg,
        FactRow(
          label: 'scan_family_status'.tr(),
          value:
              receipt.familyAcknowledged
                  ? 'scan_family_seen'.tr()
                  : 'scan_family_waiting'.tr(),
          trailing: IconButton(
            tooltip: 'scan_refresh'.tr(),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshReceipt,
          ),
        ),
        AppSpacing.gapLg,
        FamilyNote(
          title: 'scan_handover_title'.tr(),
          text: 'scan_handover_body'.tr(),
        ),
        AppSpacing.gapXl,
        AppButton(label: 'scan_next'.tr(), onPressed: _restart),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('scan_title'.tr())),
    body: SafeArea(child: _body()),
  );
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: context.semanticColors.gold, width: 2),
      ),
    ),
  );
}
