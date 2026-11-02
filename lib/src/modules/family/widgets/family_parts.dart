import 'dart:math' as math;
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart';

/// A readable, translated message for a failed family request.
String familyErrorText(Object error) {
  if (error is! FamilyException) return 'jp_error_generic'.tr();
  return switch (error.kind) {
    FamilyFailure.offline => 'jp_error_offline'.tr(),
    FamilyFailure.signedOut => 'jp_error_signin'.tr(),
    FamilyFailure.forbidden => 'fam_error_forbidden'.tr(),
    FamilyFailure.notFound => 'fam_error_not_found'.tr(),
    FamilyFailure.server => 'jp_error_server'.tr(),
    FamilyFailure.gone => 'fam_code_invalid'.tr(),
    _ => error.message ?? 'jp_error_generic'.tr(),
  };
}

String relationshipLabel(String relationship) => 'fam_rel_$relationship'.tr();

String memberKindLabel(FamilyMember m) =>
    m.isOrganizer ? 'fam_role_organizer'.tr() : 'fam_kind_${m.kind}'.tr();

/// Who someone is to the family, without leaking "self" into the UI.
String memberRelationLine(FamilyMember m) =>
    m.relationship == 'self'
        ? memberKindLabel(m)
        : relationshipLabel(m.relationship);

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p.characters.first).join().toUpperCase();
}

/// Photos sit behind the login, so they're fetched with the token and held
/// only in memory for this run of the app.
class FamilyPhotos {
  FamilyPhotos._();

  static final _cache = <String, Future<Uint8List?>>{};

  static Future<Uint8List?> load(
    FamilyRepository repo,
    String familyId,
    String memberId,
  ) =>
      _cache[memberId] ??= repo.photo(familyId, memberId).catchError((_) {
        _cache.remove(memberId);
        return null;
      });

  static void forget(String memberId) => _cache.remove(memberId);

  static void clear() => _cache.clear();
}

/// A round portrait. Dependents sit inside a gold ring with a gap, adults in a
/// solid one, so the two differ in shape as well as colour.
class FamilyAvatar extends StatelessWidget {
  const FamilyAvatar({
    super.key,
    required this.member,
    required this.familyId,
    required this.repository,
    this.size = 64,
  });

  final FamilyMember member;
  final String familyId;
  final FamilyRepository repository;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final s = context.semanticColors;
    final ring = member.isDependent ? s.gold : colors.primary;
    final initials = Center(
      child: Text(
        initialsOf(member.name),
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w600,
          color: member.isDependent ? s.onWarningContainer : colors.onPrimary,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(member.isDependent ? 4 : 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: member.isDependent ? 1.5 : 2),
      ),
      child: ClipOval(
        child: ColoredBox(
          color: member.isDependent ? s.warningContainer : colors.primary,
          child:
              member.hasPhoto
                  ? FutureBuilder<Uint8List?>(
                    future: FamilyPhotos.load(repository, familyId, member.id),
                    builder: (context, snapshot) {
                      final bytes = snapshot.data;
                      if (bytes == null) return initials;
                      return Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        width: size,
                        height: size,
                        cacheWidth: (size * 3).round(),
                        errorBuilder: (_, __, ___) => initials,
                      );
                    },
                  )
                  : initials,
        ),
      ),
    );
  }
}

/// The family as it actually holds together: adults along the top, those in
/// their care below, and a gold thread from each dependent up to the adults
/// responsible for them.
class FamilyMap extends StatelessWidget {
  const FamilyMap({
    super.key,
    required this.familyId,
    required this.members,
    required this.repository,
    required this.onOpen,
  });

  final String familyId;
  final List<FamilyMember> members;
  final FamilyRepository repository;
  final ValueChanged<FamilyMember> onOpen;

  static const _avatar = 60.0;
  static const _threadGap = 36.0;

  @override
  Widget build(BuildContext context) {
    final adults = members.where((m) => !m.isDependent).toList();
    final cared = members.where((m) => m.isDependent).toList();
    final scale = MediaQuery.textScalerOf(context);
    final labelHeight = scale.scale(20) * 2 + scale.scale(17);
    final rowHeight = _avatar + AppSpacing.sm + labelHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final perRow = math.max(2, (width / 100).floor());
        final cell = width / perRow;
        final centers = <String, Offset>{};
        final nodes = <Widget>[];
        var y = 0.0;

        void place(List<FamilyMember> group) {
          for (var i = 0; i < group.length; i += perRow) {
            final row = group.skip(i).take(perRow).toList();
            final inset = (width - row.length * cell) / 2;
            for (var j = 0; j < row.length; j++) {
              final left = inset + j * cell;
              centers[row[j].id] = Offset(left + cell / 2, y + _avatar / 2);
              nodes.add(
                Positioned(
                  left: left,
                  top: y,
                  width: cell,
                  height: rowHeight,
                  child: _MapNode(
                    member: row[j],
                    familyId: familyId,
                    repository: repository,
                    onTap: () => onOpen(row[j]),
                  ),
                ),
              );
            }
            y += rowHeight;
          }
        }

        place(adults);
        if (cared.isNotEmpty && adults.isNotEmpty) y += _threadGap;
        place(cared);

        final links = <(Offset, Offset)>[
          for (final d in cared)
            for (final g in d.guardians)
              if (centers[g.id] != null && centers[d.id] != null)
                (centers[g.id]!, centers[d.id]!),
        ];

        return SizedBox(
          height: y,
          child: Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _ThreadPainter(
                      links: links,
                      color: context.semanticColors.gold,
                      avatarRadius: _avatar / 2,
                      labelHeight: AppSpacing.sm + labelHeight,
                    ),
                  ),
                ),
              ),
              ...nodes,
            ],
          ),
        );
      },
    );
  }
}

class _MapNode extends StatelessWidget {
  const _MapNode({
    required this.member,
    required this.familyId,
    required this.repository,
    required this.onTap,
  });

  final FamilyMember member;
  final String familyId;
  final FamilyRepository repository;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final firstName = member.name.trim().split(RegExp(r'\s+')).first;
    return Pressable(
      onTap: onTap,
      label: 'fam_member_semantics'.tr(
        args: [
          member.name,
          memberRelationLine(member),
          memberKindLabel(member),
        ],
      ),
      child: ExcludeSemantics(
        child: Column(
          children: [
            FamilyAvatar(
              member: member,
              familyId: familyId,
              repository: repository,
              size: FamilyMap._avatar,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: e.title.copyWith(fontSize: 15, height: 1.3),
            ),
            Text(
              memberRelationLine(member),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: e.meta,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadPainter extends CustomPainter {
  const _ThreadPainter({
    required this.links,
    required this.color,
    required this.avatarRadius,
    required this.labelHeight,
  });

  final List<(Offset, Offset)> links;
  final Color color;
  final double avatarRadius;
  final double labelHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final line =
        Paint()
          ..color = color.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.25;
    final knot = Paint()..color = color;
    for (final (from, to) in links) {
      // Leaves below the guardian's name, arrives at the top of the avatar.
      final start = from.translate(0, avatarRadius + labelHeight + 2);
      final end = to.translate(0, -avatarRadius - 3);
      final middle = (start.dy + end.dy) / 2;
      canvas
        ..drawPath(
          Path()
            ..moveTo(start.dx, start.dy)
            ..cubicTo(start.dx, middle, end.dx, middle, end.dx, end.dy),
          line,
        )
        ..drawCircle(end, 2.5, knot);
    }
  }

  @override
  bool shouldRepaint(_ThreadPainter oldDelegate) =>
      oldDelegate.links != links || oldDelegate.color != color;
}

/// A numbered step on a vertical thread. Used for how things work, and for
/// the order emergency contacts are tried in.
class ThreadStep extends StatelessWidget {
  const ThreadStep({
    super.key,
    required this.marker,
    required this.child,
    this.isLast = false,
  });

  final String marker;
  final Widget child;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final s = context.semanticColors;
    final beadSize = 28 + MediaQuery.textScalerOf(context).scale(4);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: beadSize,
            child: Column(
              children: [
                Container(
                  width: beadSize,
                  height: beadSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: s.gold, width: 1.5),
                  ),
                  child: Text(
                    marker,
                    style: context.textTheme.labelLarge?.copyWith(
                      color: s.gold,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1.25, color: s.gold)),
              ],
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.xl),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Beads on a thread, filled as a guided flow moves along.
class StepThread extends StatelessWidget {
  const StepThread({super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final s = context.semanticColors;
    return Semantics(
      label: 'fam_step_of'.tr(args: ['${step + 1}', '$total']),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              AnimatedContainer(
                duration:
                    reduceMotion(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= step ? s.gold : Colors.transparent,
                  border: Border.all(color: s.gold, width: 1.5),
                ),
              ),
              if (i < total - 1)
                Expanded(
                  child: Container(
                    height: 1.25,
                    color: i < step ? s.gold : s.divider,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One step of a guided flow: where you are, the question, and the way on.
class GuidedStep extends StatelessWidget {
  const GuidedStep({
    super.key,
    required this.flowTitle,
    required this.step,
    required this.total,
    required this.title,
    required this.children,
    required this.nextLabel,
    required this.onNext,
    this.subtitle,
    this.onBack,
    this.busy = false,
    this.formKey,
    this.problem,
  });

  final String flowTitle;
  final int step;
  final int total;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final String nextLabel;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final bool busy;
  final Key? formKey;

  /// Why the step can't go on. Shown beside the button, so it's always visible.
  final String? problem;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    return Scaffold(
      appBar: AppBar(title: Text(flowTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                editorialMargin,
                AppSpacing.sm,
                editorialMargin,
                0,
              ),
              child: StepThread(step: step, total: total),
            ),
            Expanded(
              child: ListView(
                key: formKey,
                padding: const EdgeInsets.all(editorialMargin),
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: e.headline),
                  ),
                  if (subtitle != null) ...[
                    AppSpacing.gapSm,
                    Text(subtitle!, style: e.dek),
                  ],
                  AppSpacing.gapXl,
                  ...children,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                editorialMargin,
                AppSpacing.sm,
                editorialMargin,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (problem != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          problem!,
                          style: TextStyle(color: context.colorScheme.error),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      if (onBack != null) ...[
                        Expanded(
                          child: AppButton.secondary(
                            label: 'fam_back'.tr(),
                            onPressed: busy ? null : onBack,
                          ),
                        ),
                        AppSpacing.gapMd,
                      ],
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          label: nextLabel,
                          isLoading: busy,
                          onPressed: onNext,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A large choice with a title and a line of explanation.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final e = context.editorial;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: colors.primary),
                  AppSpacing.gapMd,
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: e.title),
                      if (subtitle != null) Text(subtitle!, style: e.meta),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_rounded, color: colors.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small selectable pills that wrap, for short lists.
class PillChoices extends StatelessWidget {
  const PillChoices({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final List<String> values;
  final String Function(String) labelOf;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.xs,
    children: [
      for (final value in values)
        ChoiceChip(
          label: Text(labelOf(value)),
          selected: value == selected,
          onSelected: (_) => onChanged(value),
        ),
    ],
  );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
    child: Text(text, style: context.textTheme.labelLarge),
  );
}

/// A label and value divided by a hairline, in place of boxed cards.
class FactRow extends StatelessWidget {
  const FactRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: context.semanticColors.divider)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.editorial.meta),
              Text(value, style: context.editorial.title),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

/// Reassurance or a caution, set apart by a gold rule rather than a box.
class FamilyNote extends StatelessWidget {
  const FamilyNote({
    super.key,
    required this.text,
    this.title,
    this.trailing = const [],
  });

  final String? title;
  final String text;

  /// Details or actions below the text.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: AppSpacing.md),
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: context.semanticColors.gold, width: 2),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) Text(title!, style: context.editorial.title),
        Text(text, style: context.textTheme.bodyMedium),
        ...trailing,
      ],
    ),
  );
}

/// Placeholder shaped like the family screen.
class FamilySkeleton extends StatelessWidget {
  const FamilySkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    children: [
      Container(height: 200, color: context.colorScheme.surfaceContainerHigh),
      AppSpacing.gapXl,
      Padding(
        padding: editorialPage,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colorScheme.surfaceContainerHigh,
                ),
              ),
          ],
        ),
      ),
      AppSpacing.gapXl,
      const Padding(
        padding: editorialPage,
        child: Column(
          children: [
            SkeletonLine(),
            SkeletonLine(width: 220),
            SkeletonLine(width: 160),
          ],
        ),
      ),
    ],
  );
}
