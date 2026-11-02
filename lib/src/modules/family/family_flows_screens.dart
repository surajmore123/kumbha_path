import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/family_home_screen.dart';
import 'package:kumbha_path/src/modules/family/invite_links.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/family/widgets/invite_share_sheet.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show formatDate, journeyLanguage, showJourneySnack;

const _languages = ['en', 'hi', 'mr'];

final _digitsOnly = [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(10),
];

String? _optionalMobile(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty || isValidMobile(text) ? null : 'auth_phone_invalid'.tr();
}

/// `/familyCreate`: four short steps. Nothing is created until the last one.
class CreateFamilyScreen extends StatefulWidget {
  const CreateFamilyScreen({super.key, this.repository});

  final FamilyRepository? repository;

  @override
  State<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends State<CreateFamilyScreen> {
  late final FamilyRepository _repo =
      widget.repository ?? FamilyServices.repository;
  final _nameForm = GlobalKey<FormState>();
  final _contactForm = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _contactName = TextEditingController();
  final _contactRelation = TextEditingController();
  final _contactMobile = TextEditingController();
  late String _language = journeyLanguage(context);
  int _step = 0;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _contactName.dispose();
    _contactRelation.dispose();
    _contactMobile.dispose();
    super.dispose();
  }

  bool get _hasContact =>
      _contactName.text.trim().isNotEmpty ||
      _contactMobile.text.trim().isNotEmpty;

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final circle = await _repo.createCircle({
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'language': _language,
      });
      if (_hasContact) {
        try {
          await _repo.addContact(circle.id, {
            'name': _contactName.text.trim(),
            'relationship': _contactRelation.text.trim(),
            'mobile': _contactMobile.text.trim(),
          });
        } catch (_) {
          // The family exists either way; the contact can be added again.
          if (mounted) showJourneySnack(context, 'fam_contact_retry'.tr());
        }
      }
      if (mounted) Navigator.pop(context, circle);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showJourneySnack(context, familyErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = 'fam_create'.tr();
    void back() => setState(() => _step--);
    void next() => setState(() => _step++);
    return switch (_step) {
      0 => GuidedStep(
        flowTitle: title,
        step: 0,
        total: 4,
        title: 'fam_create_name_title'.tr(),
        subtitle: 'fam_create_name_hint'.tr(),
        nextLabel: 'fam_continue'.tr(),
        onNext: () {
          if (_nameForm.currentState?.validate() ?? false) next();
        },
        children: [
          Form(
            key: _nameForm,
            child: Column(
              children: [
                AppTextField(
                  controller: _name,
                  label: 'fam_field_family_name'.tr(),
                  textCapitalization: TextCapitalization.words,
                  maxLength: 80,
                  validator:
                      (v) =>
                          (v ?? '').trim().isEmpty
                              ? 'fam_name_required'.tr()
                              : null,
                ),
                AppSpacing.gapMd,
                AppTextField(
                  controller: _description,
                  label: 'fam_field_description'.tr(),
                  maxLength: 300,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
      1 => GuidedStep(
        flowTitle: title,
        step: 1,
        total: 4,
        title: 'fam_create_role_title'.tr(),
        nextLabel: 'fam_continue'.tr(),
        onBack: back,
        onNext: next,
        children: [
          for (final (i, key)
              in const [
                'fam_role_can_1',
                'fam_role_can_2',
                'fam_role_cannot',
              ].indexed)
            ThreadStep(
              marker: i == 2 ? '!' : '${i + 1}',
              isLast: i == 2,
              child: Text(key.tr()),
            ),
          FieldLabel('fam_field_language'.tr()),
          PillChoices(
            values: _languages,
            labelOf: (l) => 'fam_lang_$l'.tr(),
            selected: _language,
            onChanged: (l) => setState(() => _language = l),
          ),
        ],
      ),
      2 => GuidedStep(
        flowTitle: title,
        step: 2,
        total: 4,
        title: 'fam_create_contact_title'.tr(),
        subtitle: 'fam_create_contact_hint'.tr(),
        nextLabel: _hasContact ? 'fam_continue'.tr() : 'fam_skip'.tr(),
        onBack: back,
        onNext: () {
          if (_contactForm.currentState?.validate() ?? false) next();
        },
        children: [
          Form(
            key: _contactForm,
            child: Column(
              children: [
                AppTextField(
                  controller: _contactName,
                  label: 'fam_field_contact_name'.tr(),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  validator:
                      (v) =>
                          _contactMobile.text.trim().isNotEmpty &&
                                  (v ?? '').trim().isEmpty
                              ? 'fam_name_required'.tr()
                              : null,
                ),
                AppSpacing.gapMd,
                AppTextField(
                  controller: _contactRelation,
                  label: 'fam_field_contact_relation'.tr(),
                ),
                AppSpacing.gapMd,
                AppTextField(
                  controller: _contactMobile,
                  label: 'fam_field_mobile'.tr(),
                  prefixText: '+91 ',
                  keyboardType: TextInputType.phone,
                  inputFormatters: _digitsOnly,
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (_contactName.text.trim().isNotEmpty &&
                        (v ?? '').trim().isEmpty) {
                      return 'auth_phone_invalid'.tr();
                    }
                    return _optionalMobile(v);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      _ => GuidedStep(
        flowTitle: title,
        step: 3,
        total: 4,
        title: 'fam_create_review_title'.tr(),
        nextLabel: 'fam_create_confirm'.tr(),
        busy: _busy,
        onBack: back,
        onNext: _busy ? null : _create,
        children: [
          FactRow(
            label: 'fam_field_family_name'.tr(),
            value: _name.text.trim(),
          ),
          if (_description.text.trim().isNotEmpty)
            FactRow(
              label: 'fam_field_description'.tr(),
              value: _description.text.trim(),
            ),
          FactRow(label: 'fam_field_organizer'.tr(), value: 'fam_you'.tr()),
          FactRow(
            label: 'fam_field_language'.tr(),
            value: 'fam_lang_$_language'.tr(),
          ),
          if (_hasContact)
            FactRow(
              label: 'fam_field_contact_name'.tr(),
              value: _contactName.text.trim(),
            ),
          AppSpacing.gapLg,
          FamilyNote(text: 'fam_create_no_messages'.tr()),
        ],
      ),
    };
  }
}

/// `/familyMemberForm`: add a dependent in steps, or edit one on a single page.
class MemberFormScreen extends StatefulWidget {
  const MemberFormScreen({super.key, required this.args, this.repository});

  final FamilyArgs args;
  final FamilyRepository? repository;

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  late final FamilyRepository _repo =
      widget.repository ?? FamilyServices.repository;
  final _form = GlobalKey<FormState>();
  late final FamilyMember? _existing = widget.args.member;
  late final _name = TextEditingController(text: _existing?.name);
  late final _mobile = TextEditingController(
    text: localMobile(_existing?.phone ?? ''),
  );
  late String _kind = _existing?.kind ?? 'dependent_child';
  late String? _relationship = _existing?.relationship;
  late String? _ageGroup =
      (_existing?.ageGroup ?? '').isEmpty ? null : _existing?.ageGroup;
  late DateTime? _birth = _existing?.dateOfBirth;
  late String _language = _existing?.language ?? widget.args.circle.language;
  late String? _consent = _existing?.consentBasis;
  Uint8List? _photo;
  int _step = 0;
  bool _busy = false;
  bool _showAgeError = false;

  bool get _editing => _existing != null;
  bool get _needsConsent => _kind != 'dependent_child';

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) setState(() => _photo = bytes);
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 8),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (picked != null) setState(() => _birth = picked);
  }

  Map<String, dynamic> get _payload => {
    'full_name': _name.text.trim(),
    'kind': _kind,
    'relationship': _relationship,
    if (_ageGroup != null) 'age_group': _ageGroup,
    if (_birth != null)
      'date_of_birth': DateFormat('yyyy-MM-dd', 'en').format(_birth!),
    'mobile': _mobile.text.trim(),
    'language': _language,
    if (_consent != null) 'consent_basis': _consent,
  };

  Future<void> _save() async {
    setState(() => _busy = true);
    final familyId = widget.args.circle.id;
    try {
      final saved =
          _editing
              ? await _repo.updateMember(familyId, _existing!.id, _payload)
              : await _repo.addDependent(familyId, _payload);
      if (_photo != null) {
        try {
          await _repo.uploadPhoto(familyId, saved.id, _photo!);
          FamilyPhotos.forget(saved.id);
        } catch (_) {
          if (mounted) showJourneySnack(context, 'fam_photo_failed'.tr());
        }
      }
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showJourneySnack(context, familyErrorText(e));
    }
  }

  bool _detailsValid() {
    final ok = _form.currentState?.validate() ?? false;
    final hasAge = _ageGroup != null || _birth != null;
    setState(() => _showAgeError = !hasAge);
    return ok && hasAge;
  }

  List<Widget> _whoFields() => [
    for (final (kind, icon) in const [
      ('dependent_child', Icons.child_care_rounded),
      ('dependent_elderly', Icons.elderly_rounded),
      ('dependent_other', Icons.accessibility_new_rounded),
    ])
      ChoiceRow(
        icon: icon,
        title: 'fam_kind_$kind'.tr(),
        subtitle: 'fam_kind_${kind}_hint'.tr(),
        selected: _kind == kind,
        onTap: () => setState(() => _kind = kind),
      ),
    FieldLabel('fam_field_relationship'.tr()),
    PillChoices(
      values: familyRelationships,
      labelOf: relationshipLabel,
      selected: _relationship,
      onChanged: (r) => setState(() => _relationship = r),
    ),
  ];

  List<Widget> _detailFields() => [
    Center(
      child: Column(
        children: [
          Pressable(
            onTap: _pickPhoto,
            label: 'fam_add_photo'.tr(),
            child: CircleAvatar(
              radius: 44,
              backgroundColor: context.colorScheme.surfaceContainerHigh,
              backgroundImage: _photo == null ? null : MemoryImage(_photo!),
              child:
                  _photo == null
                      ? Icon(
                        Icons.add_a_photo_outlined,
                        color: context.colorScheme.primary,
                      )
                      : null,
            ),
          ),
          AppSpacing.gapXs,
          Text('fam_photo_optional'.tr(), style: context.editorial.meta),
        ],
      ),
    ),
    AppSpacing.gapMd,
    Form(
      key: _form,
      child: Column(
        children: [
          AppTextField(
            controller: _name,
            label: 'fam_field_full_name'.tr(),
            textCapitalization: TextCapitalization.words,
            validator:
                (v) =>
                    (v ?? '').trim().isEmpty ? 'fam_name_required'.tr() : null,
          ),
          AppSpacing.gapMd,
          AppTextField(
            controller: _mobile,
            label: 'fam_field_mobile_optional'.tr(),
            prefixText: '+91 ',
            keyboardType: TextInputType.phone,
            inputFormatters: _digitsOnly,
            validator: _optionalMobile,
          ),
        ],
      ),
    ),
    FieldLabel('fam_field_age_group'.tr()),
    PillChoices(
      values: familyAgeGroups,
      labelOf: (a) => 'fam_age_$a'.tr(),
      selected: _ageGroup,
      onChanged:
          (a) => setState(() {
            _ageGroup = a;
            _showAgeError = false;
          }),
    ),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () async {
          await _pickBirth();
          if (_birth != null) setState(() => _showAgeError = false);
        },
        icon: const Icon(Icons.calendar_month_outlined, size: 18),
        label: Text(
          _birth == null ? 'fam_add_birth'.tr() : formatDate(context, _birth!),
        ),
      ),
    ),
    if (_showAgeError)
      Text(
        'fam_age_required'.tr(),
        style: TextStyle(color: context.colorScheme.error),
      ),
    FieldLabel('fam_field_language'.tr()),
    PillChoices(
      values: _languages,
      labelOf: (l) => 'fam_lang_$l'.tr(),
      selected: _language,
      onChanged: (l) => setState(() => _language = l),
    ),
  ];

  List<Widget> _consentFields() => [
    for (final basis in const ['agreed', 'authority'])
      ChoiceRow(
        title: 'fam_consent_$basis'.tr(),
        selected: _consent == basis,
        onTap: () => setState(() => _consent = basis),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final title = 'fam_add_dependent'.tr();
    if (_editing) {
      return Scaffold(
        appBar: AppBar(title: Text('fam_edit_member'.tr())),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(editorialMargin),
            children: [
              ..._detailFields(),
              FieldLabel('fam_field_relationship'.tr()),
              PillChoices(
                values: familyRelationships,
                labelOf: relationshipLabel,
                selected: _relationship,
                onChanged: (r) => setState(() => _relationship = r),
              ),
              if (_needsConsent) ...[
                FieldLabel('fam_consent_title'.tr()),
                ..._consentFields(),
              ],
              AppSpacing.gapXl,
              AppButton(
                label: 'fam_save'.tr(),
                isLoading: _busy,
                onPressed:
                    _busy
                        ? null
                        : () {
                          if (_detailsValid()) _save();
                        },
              ),
            ],
          ),
        ),
      );
    }
    final total = _needsConsent ? 3 : 2;
    return switch (_step) {
      0 => GuidedStep(
        flowTitle: title,
        step: 0,
        total: total,
        title: 'fam_dep_who_title'.tr(),
        subtitle: 'fam_dep_who_hint'.tr(),
        nextLabel: 'fam_continue'.tr(),
        onNext: _relationship == null ? null : () => setState(() => _step = 1),
        children: _whoFields(),
      ),
      1 => GuidedStep(
        flowTitle: title,
        step: 1,
        total: total,
        title: 'fam_dep_details_title'.tr(),
        subtitle: 'fam_dep_details_hint'.tr(),
        nextLabel: _needsConsent ? 'fam_continue'.tr() : 'fam_dep_add'.tr(),
        busy: _busy,
        onBack: () => setState(() => _step = 0),
        onNext:
            _busy
                ? null
                : () {
                  if (!_detailsValid()) return;
                  if (_needsConsent) {
                    setState(() => _step = 2);
                  } else {
                    _save();
                  }
                },
        children: _detailFields(),
      ),
      _ => GuidedStep(
        flowTitle: title,
        step: 2,
        total: total,
        title: 'fam_consent_title'.tr(),
        subtitle: 'fam_consent_hint'.tr(),
        nextLabel: 'fam_dep_add'.tr(),
        busy: _busy,
        onBack: () => setState(() => _step = 1),
        onNext: _consent == null || _busy ? null : _save,
        children: _consentFields(),
      ),
    };
  }
}

/// `/familyInvite`: create an invitation and see the ones still open.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key, required this.args, this.repository});

  final FamilyArgs args;
  final FamilyRepository? repository;

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  late final FamilyRepository _repo =
      widget.repository ?? FamilyServices.repository;
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  String? _relationship;
  bool _busy = false;
  FamilyInvite? _created;

  /// The number the created invitation was made for, if any.
  String? _createdPhone;
  List<FamilyInvite> _invites = const [];
  Object? _error;

  String get _familyId => widget.args.circle.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final invites = await _repo.invitations(_familyId);
      if (mounted) {
        setState(() {
          _invites = invites;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _create() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final phone = _phone.text.trim();
    try {
      final invite = await _repo.createInvitation(
        _familyId,
        relationship: _relationship!,
        phone: phone,
      );
      if (!mounted) return;
      setState(() {
        _created = invite;
        _createdPhone = phone.isEmpty ? null : phone;
        _busy = false;
        _phone.clear();
        _relationship = null;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showJourneySnack(context, familyErrorText(e));
    }
  }

  Future<void> _revoke(FamilyInvite invite) async {
    try {
      await _repo.revokeInvitation(_familyId, invite.id);
      if (!mounted) return;
      if (_created?.id == invite.id) setState(() => _created = null);
      await _load();
    } catch (e) {
      if (mounted) showJourneySnack(context, familyErrorText(e));
    }
  }

  /// Why this invitation can't be passed on, or null if it can. The server
  /// still decides when the link is used; this just avoids sending a dead one.
  Future<String?> _closedState(FamilyInvite invite) async {
    final link = invite.link;
    if (link == null || parseInviteLink(Uri.parse(link))?.token == null) {
      return 'invalid';
    }
    final expires = invite.expiresAt;
    if (expires != null && expires.isBefore(DateTime.now())) return 'expired';
    try {
      final latest = await _repo.invitations(_familyId);
      final state = latest.where((i) => i.id == invite.id).firstOrNull?.state;
      return state == null || state == 'pending' ? null : state;
    } catch (_) {
      return null; // Offline: it can still be sent, and is checked when used.
    }
  }

  Future<void> _share(FamilyInvite invite) async {
    final closed = await _closedState(invite);
    if (!mounted) return;
    if (closed != null) {
      setState(() => _created = null);
      showJourneySnack(context, 'fam_link_${closed}_title'.tr());
      await _load();
      return;
    }
    await shareInvite(
      context,
      InviteShare(
        familyName: widget.args.circle.name,
        link: invite.link!,
        expires: invite.expiresAt,
        phone: _createdPhone,
      ),
    );
  }

  static String _pretty(String code) => [
    for (var i = 0; i < code.length; i += 4)
      code.substring(i, (i + 4).clamp(0, code.length)),
  ].join('-');

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final created = _created;
    final open = _invites.where((i) => i.isOpen).toList();
    return Scaffold(
      appBar: AppBar(title: Text('fam_invite_title'.tr())),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(editorialMargin),
          children: [
            if (created != null) ...[
              _CodeTicket(
                code: _pretty(created.code ?? ''),
                expires: created.expiresAt,
                inApp: created.inApp,
                onShare: created.link == null ? null : () => _share(created),
              ),
              AppSpacing.gapXl,
            ],
            Text('fam_invite_who'.tr(), style: e.headline),
            AppSpacing.gapSm,
            Text('fam_invite_consent'.tr()),
            FieldLabel('fam_field_relationship'.tr()),
            PillChoices(
              values: familyRelationships,
              labelOf: relationshipLabel,
              selected: _relationship,
              onChanged: (r) => setState(() => _relationship = r),
            ),
            AppSpacing.gapLg,
            Form(
              key: _form,
              child: AppTextField(
                controller: _phone,
                label: 'fam_field_invite_phone'.tr(),
                helperText: 'fam_invite_phone_hint'.tr(),
                prefixText: '+91 ',
                keyboardType: TextInputType.phone,
                inputFormatters: _digitsOnly,
                validator: _optionalMobile,
              ),
            ),
            AppSpacing.gapLg,
            AppButton(
              label: 'fam_invite_create'.tr(),
              isLoading: _busy,
              onPressed: _relationship == null || _busy ? null : _create,
            ),
            AppSpacing.gapXl,
            Text('fam_invite_will_see'.tr(), style: e.title),
            AppSpacing.gapXs,
            Text('fam_invite_will_see_body'.tr()),
            if (_error != null) ...[
              AppSpacing.gapXl,
              AppErrorView(
                compact: true,
                message: familyErrorText(_error!),
                onRetry: _load,
              ),
            ],
            if (open.isNotEmpty) ...[
              AppSpacing.gapXl,
              Text('fam_invite_open'.tr(), style: e.headline),
              for (final invite in open)
                FactRow(
                  label:
                      invite.expiresAt == null
                          ? ''
                          : 'fam_invite_expires'.tr(
                            args: [formatDate(context, invite.expiresAt!)],
                          ),
                  value: relationshipLabel(invite.relationship),
                  trailing: TextButton(
                    onPressed: () => _revoke(invite),
                    child: Text('fam_revoke'.tr()),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CodeTicket extends StatelessWidget {
  const _CodeTicket({
    required this.code,
    required this.inApp,
    this.expires,
    this.onShare,
  });

  final String code;
  final bool inApp;
  final DateTime? expires;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final colors = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: context.semanticColors.gold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('fam_code_title'.tr(), style: e.meta),
          AppSpacing.gapXs,
          SelectableText(
            code,
            style: e.headline.copyWith(
              color: colors.primary,
              letterSpacing: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          AppSpacing.gapXs,
          if (expires != null)
            Text(
              'fam_invite_expires'.tr(args: [formatDate(context, expires!)]),
              style: e.meta,
            ),
          AppSpacing.gapMd,
          Text(inApp ? 'fam_code_in_app'.tr() : 'fam_code_not_sent'.tr()),
          AppSpacing.gapMd,
          if (onShare != null) ...[
            Builder(
              builder:
                  (context) => AppButton(
                    label: 'fam_share_invitation'.tr(),
                    leadingIcon: Icons.share_outlined,
                    onPressed: onShare,
                  ),
            ),
            AppSpacing.gapSm,
          ],
          AppButton.secondary(
            label: 'fam_copy'.tr(),
            leadingIcon: Icons.copy_rounded,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                showJourneySnack(context, 'fam_copied'.tr());
              }
            },
          ),
        ],
      ),
    );
  }
}

/// `/familyJoin`: enter a code, or arrive with an in-app invitation or a link.
/// Nothing happens to the account until the person presses Join.
class JoinFamilyScreen extends StatefulWidget {
  const JoinFamilyScreen({super.key, this.invite, this.link, this.repository});

  final InvitePreview? invite;

  /// Set when opened from an invitation link.
  final InviteLink? link;
  final FamilyRepository? repository;

  @override
  State<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<JoinFamilyScreen> {
  late final FamilyRepository _repo =
      widget.repository ?? FamilyServices.repository;
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  late InvitePreview? _preview = widget.invite;
  String? _enteredCode;
  bool _busy = false;
  String? _error;

  /// A link that can't be used: its state, or 'invalid'.
  String? _closedLink;
  Object? _linkFailure;

  String? get _token => widget.link?.token;

  @override
  void initState() {
    super.initState();
    if (widget.link != null) _openLink();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _openLink() async {
    final token = _token;
    if (token == null) {
      setState(() => _closedLink = 'invalid');
      return;
    }
    setState(() {
      _busy = true;
      _linkFailure = null;
    });
    try {
      final preview = await _repo.lookupInvitationLink(token);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _busy = false;
      });
    } on FamilyException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e.kind == FamilyFailure.gone) {
          _closedLink = e.invitationState ?? 'invalid';
        } else if (e.kind == FamilyFailure.notFound) {
          _closedLink = 'invalid';
        } else {
          _linkFailure = e;
        }
      });
    }
  }

  Future<void> _lookup() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final code = _code.text.trim();
    try {
      final preview = await _repo.lookupInvitation(code);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _enteredCode = code;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            e is FamilyException && e.kind == FamilyFailure.notFound
                ? 'fam_code_invalid'.tr()
                : familyErrorText(e);
      });
    }
  }

  Future<void> _respond({required bool accept}) async {
    final preview = _preview!;
    final token = _token;
    final id = _enteredCode == null && token == null ? preview.id : null;
    setState(() => _busy = true);
    try {
      if (accept) {
        await _repo.acceptInvitation(
          code: _enteredCode,
          invitationId: id,
          token: token,
        );
      } else {
        await _repo.declineInvitation(
          code: _enteredCode,
          invitationId: id,
          token: token,
        );
      }
      if (mounted) Navigator.pop(context, accept);
    } on FamilyException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e.kind == FamilyFailure.gone) {
          _preview = null;
          _closedLink = e.invitationState ?? 'invalid';
        }
      });
      if (e.kind != FamilyFailure.gone) {
        showJourneySnack(context, familyErrorText(e));
      }
    }
  }

  /// Everything shown for a link before there's an invitation to review.
  Widget _linkState() {
    final closed = _closedLink;
    if (closed != null) {
      final known = const [
        'expired',
        'revoked',
        'accepted',
        'declined',
      ].contains(closed);
      final key = known ? closed : 'invalid';
      return AppEmptyState(
        icon: Icons.link_off_rounded,
        title: 'fam_link_${key}_title'.tr(),
        message: 'fam_link_${key}_body'.tr(),
      );
    }
    final failure = _linkFailure;
    if (failure != null) {
      return AppErrorView(
        message: familyErrorText(failure),
        onRetry: _openLink,
      );
    }
    return const Center(child: CircularProgressIndicator());
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: Text('fam_join'.tr())),
      body: SafeArea(
        child:
            preview == null && widget.link != null
                ? _linkState()
                : preview == null
                ? ListView(
                  padding: const EdgeInsets.all(editorialMargin),
                  children: [
                    Text('fam_join_title'.tr(), style: e.headline),
                    AppSpacing.gapSm,
                    Text('fam_join_hint'.tr(), style: e.dek),
                    AppSpacing.gapXl,
                    Form(
                      key: _form,
                      child: AppTextField(
                        controller: _code,
                        label: 'fam_field_code'.tr(),
                        errorText: _error,
                        textCapitalization: TextCapitalization.characters,
                        validator:
                            (v) =>
                                (v ?? '').trim().isEmpty
                                    ? 'fam_code_required'.tr()
                                    : null,
                      ),
                    ),
                    AppSpacing.gapLg,
                    AppButton(
                      label: 'fam_continue'.tr(),
                      isLoading: _busy,
                      onPressed: _busy ? null : _lookup,
                    ),
                  ],
                )
                : ListView(
                  padding: const EdgeInsets.all(editorialMargin),
                  children: [
                    Text('fam_review_invited'.tr(), style: e.meta),
                    AppSpacing.gapXs,
                    Text(preview.familyName, style: e.masthead),
                    AppSpacing.gapSm,
                    MetaLine([
                      'fam_organized_by'.tr(args: [preview.organizerName]),
                      'fam_member_count'.plural(preview.memberCount),
                    ]),
                    AppSpacing.gapXl,
                    Text('fam_review_can_title'.tr(), style: e.title),
                    AppSpacing.gapXs,
                    Text('fam_review_can_body'.tr()),
                    AppSpacing.gapLg,
                    Text('fam_review_cannot_title'.tr(), style: e.title),
                    AppSpacing.gapXs,
                    Text('fam_review_cannot_body'.tr()),
                    AppSpacing.gapLg,
                    if (preview.alreadyMember) ...[
                      FamilyNote(text: 'fam_already_member'.tr()),
                      AppSpacing.gapXl,
                      AppButton(
                        label: 'fam_open_family'.tr(),
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ] else ...[
                      FamilyNote(text: 'fam_review_leave'.tr()),
                      AppSpacing.gapXl,
                      AppButton(
                        label: 'fam_join_confirm'.tr(
                          args: [preview.familyName],
                        ),
                        isLoading: _busy,
                        onPressed: _busy ? null : () => _respond(accept: true),
                      ),
                      AppSpacing.gapSm,
                      AppButton.secondary(
                        label: 'fam_decline'.tr(),
                        onPressed: _busy ? null : () => _respond(accept: false),
                      ),
                    ],
                  ],
                ),
      ),
    );
  }
}
