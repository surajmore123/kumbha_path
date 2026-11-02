import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/modules/booking/models/booking_models.dart'
    show JourneyPrefill;
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/journey/data/journey_repository.dart';
import 'package:kumbha_path/src/modules/journey/journey_controllers.dart';
import 'package:kumbha_path/src/modules/journey/models/journey_models.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart';

const _pagePadding = EdgeInsets.fromLTRB(
  AppSpacing.lg,
  AppSpacing.lg,
  AppSpacing.lg,
  AppSpacing.huge,
);

Future<void> _report(BuildContext context, Future<JourneyException?> f) async {
  final error = await f;
  if (error != null && context.mounted) {
    showJourneySnack(context, journeyErrorText(error));
  }
}

Widget _centered(Widget child) => Align(
  alignment: Alignment.topCenter,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 760),
    child: child,
  ),
);

// ---------------------------------------------------------------- itinerary

class ItineraryTab extends StatelessWidget {
  const ItineraryTab({
    super.key,
    required this.plan,
    required this.controller,
    required this.onGenerate,
    required this.header,
  });

  final JourneyPlan plan;
  final JourneyDetailController controller;
  final VoidCallback onGenerate;
  final Widget header;

  @override
  Widget build(BuildContext context) {
    return _centered(
      ListView(
        padding: _pagePadding,
        children: [
          header,
          AppSpacing.gapLg,
          if (!plan.hasItinerary)
            AppEmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'jp_no_itinerary'.tr(),
              message: 'jp_no_itinerary_message'.tr(),
              actionLabel: 'jp_create_itinerary'.tr(),
              onAction: controller.busy ? null : onGenerate,
            )
          else ...[
            SourceNote('jp_itinerary_disclaimer'.tr()),
            AppSpacing.gapMd,
            for (final day in plan.days) ...[
              _DayCard(plan: plan, day: day, controller: controller),
              AppSpacing.gapMd,
            ],
          ],
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.plan,
    required this.day,
    required this.controller,
  });

  final JourneyPlan plan;
  final JourneyDay day;
  final JourneyDetailController controller;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final heading = [
      'jp_day_n'.tr(args: ['${day.number}']),
      if (day.date != null) formatDay(context, day.date!),
    ].join(' · ');
    return AppCard(
      key: ValueKey('journey_day_${day.number}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: text.labelLarge?.copyWith(
              color: context.colorScheme.primary,
            ),
          ),
          if (day.title.isNotEmpty) Text(day.title, style: text.titleMedium),
          AppSpacing.gapSm,
          if (day.items.isEmpty)
            Text('jp_day_empty'.tr(), style: text.bodyMedium)
          else
            for (var i = 0; i < day.items.length; i++)
              _ItemRow(
                plan: plan,
                day: day,
                index: i,
                item: day.items[i],
                controller: controller,
              ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed:
                  controller.busy
                      ? null
                      : () => showItemEditor(
                        context,
                        plan,
                        controller,
                        dayNumber: day.number,
                      ),
              icon: const Icon(Icons.add_rounded),
              label: Text('jp_add_activity'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ItemAction { edit, up, down, delete }

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.plan,
    required this.day,
    required this.index,
    required this.item,
    required this.controller,
  });

  final JourneyPlan plan;
  final JourneyDay day;
  final int index;
  final JourneyItem item;
  final JourneyDetailController controller;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final muted = context.colorScheme.onSurfaceVariant;
    final meta = [
      'jp_period_${item.period}'.tr(),
      if (!item.isSuggested) 'jp_added_by_you'.tr(),
      if (item.isSuggested && item.isEdited) 'jp_edited'.tr(),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: item.isDone,
            onChanged:
                controller.busy
                    ? null
                    : (_) => _report(context, controller.toggleItem(item)),
            semanticLabel: item.title,
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Icon(kindIcon(item.kind), size: 18, color: muted),
          ),
          AppSpacing.gapSm,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: text.titleSmall?.copyWith(
                      decoration:
                          item.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(meta, style: text.labelSmall?.copyWith(color: muted)),
                  if (item.details.isNotEmpty) ...[
                    AppSpacing.gapXs,
                    Text(item.details, style: text.bodySmall),
                  ],
                ],
              ),
            ),
          ),
          PopupMenuButton<_ItemAction>(
            tooltip: 'jp_item_actions'.tr(),
            enabled: !controller.busy,
            onSelected: (a) async {
              switch (a) {
                case _ItemAction.edit:
                  await showItemEditor(
                    context,
                    plan,
                    controller,
                    dayNumber: day.number,
                    item: item,
                  );
                case _ItemAction.up:
                  await _report(context, controller.moveItem(day, index, -1));
                case _ItemAction.down:
                  await _report(context, controller.moveItem(day, index, 1));
                case _ItemAction.delete:
                  final ok = await confirmJourneyAction(
                    context,
                    title: 'jp_delete_item_title'.tr(),
                    message: item.title,
                    confirm: 'jp_delete'.tr(),
                    destructive: true,
                  );
                  if (ok && context.mounted) {
                    await _report(context, controller.deleteItem(item.id));
                  }
              }
            },
            itemBuilder:
                (_) => [
                  PopupMenuItem(
                    value: _ItemAction.edit,
                    child: Text('jp_edit'.tr()),
                  ),
                  if (index > 0)
                    PopupMenuItem(
                      value: _ItemAction.up,
                      child: Text('jp_move_up'.tr()),
                    ),
                  if (index < day.items.length - 1)
                    PopupMenuItem(
                      value: _ItemAction.down,
                      child: Text('jp_move_down'.tr()),
                    ),
                  PopupMenuItem(
                    value: _ItemAction.delete,
                    child: Text('jp_delete'.tr()),
                  ),
                ],
          ),
        ],
      ),
    );
  }
}

/// Add ([item] null) or edit an activity, including moving it to another day.
Future<void> showItemEditor(
  BuildContext context,
  JourneyPlan plan,
  JourneyDetailController controller, {
  required int dayNumber,
  JourneyItem? item,
}) async {
  final title = TextEditingController(text: item?.title ?? '');
  final details = TextEditingController(text: item?.details ?? '');
  var period = item?.period ?? 'anytime';
  var kind = item?.kind ?? 'note';
  var day = dayNumber;
  final formKey = GlobalKey<FormState>();

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (ctx) => StatefulBuilder(
          builder:
              (ctx, setSheet) => Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom + AppSpacing.lg,
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          (item == null
                                  ? 'jp_add_activity'
                                  : 'jp_edit_activity')
                              .tr(),
                          style: ctx.textTheme.titleLarge,
                        ),
                        AppSpacing.gapLg,
                        AppTextField(
                          controller: title,
                          label: 'jp_activity_title'.tr(),
                          maxLength: 150,
                          autofocus: item == null,
                          validator:
                              (v) =>
                                  (v ?? '').trim().isEmpty
                                      ? 'jp_err_required'.tr()
                                      : null,
                        ),
                        AppSpacing.gapSm,
                        AppTextField(
                          controller: details,
                          label: 'jp_activity_details'.tr(),
                          maxLength: 1000,
                          maxLines: 4,
                          minLines: 2,
                        ),
                        AppSpacing.gapSm,
                        DropdownButtonFormField<int>(
                          initialValue: day,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'jp_activity_day'.tr(),
                          ),
                          items: [
                            for (final d in plan.days)
                              DropdownMenuItem(
                                value: d.number,
                                child: Text(
                                  [
                                    'jp_day_n'.tr(args: ['${d.number}']),
                                    if (d.date != null) formatDay(ctx, d.date!),
                                  ].join(' · '),
                                ),
                              ),
                          ],
                          onChanged: (v) => setSheet(() => day = v ?? day),
                        ),
                        AppSpacing.gapMd,
                        DropdownButtonFormField<String>(
                          initialValue: period,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'jp_activity_time'.tr(),
                          ),
                          items: [
                            for (final p in JourneyChoices.periods)
                              DropdownMenuItem(
                                value: p,
                                child: Text('jp_period_$p'.tr()),
                              ),
                          ],
                          onChanged:
                              (v) => setSheet(() => period = v ?? period),
                        ),
                        AppSpacing.gapMd,
                        DropdownButtonFormField<String>(
                          initialValue: kind,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'jp_activity_kind'.tr(),
                          ),
                          items: [
                            for (final k in JourneyChoices.kinds)
                              DropdownMenuItem(
                                value: k,
                                child: Text('jp_kind_$k'.tr()),
                              ),
                          ],
                          onChanged: (v) => setSheet(() => kind = v ?? kind),
                        ),
                        AppSpacing.gapLg,
                        AppButton(
                          label: 'jp_save'.tr(),
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              Navigator.pop(ctx, true);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ),
  );

  final data = {
    'title': title.text.trim(),
    'details': details.text.trim(),
    'period': period,
    'kind': kind,
  };
  // The controllers aren't disposed here: the sheet may still be animating
  // out and reading them. They hold no other resources.
  if (saved != true || !context.mounted) return;
  await _report(context, controller.saveItem(item?.id, day, data));
}

// ---------------------------------------------------------------- checklist

class ChecklistTab extends StatefulWidget {
  const ChecklistTab({super.key, required this.plan, required this.controller});

  final JourneyPlan plan;
  final JourneyDetailController controller;

  @override
  State<ChecklistTab> createState() => _ChecklistTabState();
}

class _ChecklistTabState extends State<ChecklistTab> {
  final _text = TextEditingController();
  String _category = 'other';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final value = _text.text.trim();
    if (value.isEmpty) return;
    final error = await widget.controller.addChecklist(value, _category);
    if (!mounted) return;
    if (error != null) {
      showJourneySnack(context, journeyErrorText(error));
    } else {
      _text.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final c = widget.controller;
    final text = context.textTheme;
    final total = plan.checklist.length;
    final groups = <String, List<ChecklistItem>>{};
    for (final item in plan.checklist) {
      groups.putIfAbsent(item.category, () => []).add(item);
    }
    return _centered(
      ListView(
        padding: _pagePadding,
        children: [
          if (total > 0) ...[
            Text(
              'jp_checklist_progress'.tr(
                args: ['${plan.checklistDone}', '$total'],
              ),
              style: text.titleSmall,
            ),
            AppSpacing.gapSm,
            LinearProgressIndicator(value: plan.checklistDone / total),
            AppSpacing.gapLg,
          ],
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _text,
                  label: 'jp_checklist_add'.tr(),
                  maxLength: 200,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _add(),
                ),
                AppSpacing.gapSm,
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _category,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'jp_checklist_category'.tr(),
                        ),
                        items: [
                          for (final cat in JourneyChoices.checklistCategories)
                            DropdownMenuItem(
                              value: cat,
                              child: Text('jp_cat_$cat'.tr()),
                            ),
                        ],
                        onChanged:
                            (v) => setState(() => _category = v ?? _category),
                      ),
                    ),
                    AppSpacing.gapMd,
                    FilledButton(
                      onPressed: c.busy ? null : _add,
                      child: Text('jp_add'.tr()),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,
          if (total == 0)
            AppEmptyState(
              compact: true,
              icon: Icons.checklist_rounded,
              title: 'jp_checklist_empty'.tr(),
            ),
          for (final cat in JourneyChoices.checklistCategories)
            if (groups[cat] != null) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.md,
                  bottom: AppSpacing.xs,
                ),
                child: Text('jp_cat_$cat'.tr(), style: text.titleSmall),
              ),
              for (final item in groups[cat]!)
                CheckboxListTile(
                  key: ValueKey('checklist_${item.id}'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: item.isDone,
                  onChanged:
                      c.busy
                          ? null
                          : (_) => _report(context, c.toggleChecklist(item)),
                  title: Text(
                    item.text,
                    style: TextStyle(
                      decoration:
                          item.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  secondary: IconButton(
                    tooltip: 'jp_delete'.tr(),
                    icon: const Icon(Icons.close_rounded),
                    onPressed:
                        c.busy
                            ? null
                            : () =>
                                _report(context, c.deleteChecklist(item.id)),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ travel & stay

class TravelStayTab extends StatelessWidget {
  const TravelStayTab({
    super.key,
    required this.plan,
    required this.controller,
    required this.guide,
    required this.onRetryGuide,
  });

  final JourneyPlan plan;
  final JourneyDetailController controller;
  final Future<PlanningGuide>? guide;
  final VoidCallback onRetryGuide;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return _centered(
      ListView(
        padding: _pagePadding,
        children: [
          AppSectionHeader(
            title: 'jp_my_bookings'.tr(),
            subtitle: 'jp_my_bookings_help'.tr(),
          ),
          AppSpacing.gapSm,
          for (final ref in plan.references) ...[
            _ReferenceCard(plan: plan, reference: ref, controller: controller),
            AppSpacing.gapSm,
          ],
          AppButton.outlined(
            label: 'jp_add_booking'.tr(),
            leadingIcon: Icons.add_rounded,
            onPressed:
                controller.busy
                    ? null
                    : () => showReferenceEditor(context, controller),
          ),
          AppSpacing.gapSm,
          AppButton(
            label: 'bk_find_with_journey'.tr(),
            leadingIcon: Icons.luggage_outlined,
            onPressed:
                () => Navigator.pushNamed(
                  context,
                  '/booking',
                  arguments: JourneyPrefill(
                    title: plan.title,
                    arrival: plan.arrivalDate,
                    departure: plan.departureDate,
                    travellers: plan.travellers,
                    origin: plan.originCity,
                  ),
                ),
          ),
          AppSpacing.gapXxl,
          FutureBuilder<PlanningGuide>(
            future: guide,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const AppLoading.compact();
              }
              final g = snap.data;
              if (g == null) {
                return AppErrorView(
                  compact: true,
                  message: journeyErrorText(
                    snap.error is JourneyException
                        ? snap.error as JourneyException
                        : null,
                  ),
                  onRetry: onRetryGuide,
                );
              }
              final chosen = plan.transportMode;
              final transport = [...g.transport]..sort(
                (a, b) => (a.mode == chosen ? 0 : 1).compareTo(
                  b.mode == chosen ? 0 : 1,
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSectionHeader(title: 'jp_getting_there'.tr()),
                  AppSpacing.gapSm,
                  for (final t in transport) ...[
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                transportIcon(t.mode),
                                color: context.colorScheme.primary,
                              ),
                              AppSpacing.gapSm,
                              Expanded(
                                child: Text(t.title, style: text.titleMedium),
                              ),
                              if (t.mode == chosen)
                                StatusPill(
                                  label: 'jp_your_choice'.tr(),
                                  foreground:
                                      context.colorScheme.onPrimaryContainer,
                                  background:
                                      context.colorScheme.primaryContainer,
                                ),
                            ],
                          ),
                          AppSpacing.gapSm,
                          Text(t.note, style: text.bodyMedium),
                          for (final link in t.links) _LinkTile(source: link),
                        ],
                      ),
                    ),
                    AppSpacing.gapSm,
                  ],
                  AppSpacing.gapXl,
                  AppSectionHeader(title: 'jp_where_to_stay'.tr()),
                  AppSpacing.gapSm,
                  SourceNote(g.stayNote),
                  AppSpacing.gapSm,
                  for (final s in g.stays)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        s.category == plan.accommodation
                            ? Icons.check_circle_rounded
                            : Icons.hotel_outlined,
                      ),
                      title: Text(s.title),
                      subtitle: Text(s.note),
                    ),
                  for (final link in g.stayLinks) _LinkTile(source: link),
                  AppSpacing.gapSm,
                  SourceNote('jp_checked_on'.tr(args: [g.checkedOn])),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.source});

  final GuideSource source;

  @override
  Widget build(BuildContext context) {
    final official = source.status.startsWith('official');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(official ? Icons.verified_outlined : Icons.link_rounded),
      title: Text(source.title),
      subtitle: Text(
        [
          if (source.organization.isNotEmpty) source.organization,
          if (official) 'jp_official_source'.tr(),
          if (!source.reachable) 'jp_link_unverified'.tr(),
        ].join(' · '),
      ),
      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
      onTap: () => openExternal(context, source.url),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({
    required this.plan,
    required this.reference,
    required this.controller,
  });

  final JourneyPlan plan;
  final JourneyReference reference;
  final JourneyDetailController controller;

  @override
  Widget build(BuildContext context) {
    final r = reference;
    final text = context.textTheme;
    final dates =
        r.startDate == null
            ? null
            : (r.endDate == null || r.endDate == r.startDate
                ? formatDate(context, r.startDate!)
                : formatRange(context, r.startDate, r.endDate));
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            r.kind == 'transport'
                ? Icons.confirmation_number_outlined
                : Icons.hotel_outlined,
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: text.titleSmall),
                for (final line in [
                  r.provider,
                  if (r.bookingReference != null)
                    'jp_booking_ref'.tr(args: [r.bookingReference!]),
                  dates,
                  r.notes,
                ])
                  if (line != null) Text(line, style: text.bodySmall),
                if (r.url != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => openExternal(context, r.url!),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text('jp_open_link'.tr()),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'jp_edit'.tr(),
            icon: const Icon(Icons.edit_outlined),
            onPressed:
                controller.busy
                    ? null
                    : () =>
                        showReferenceEditor(context, controller, reference: r),
          ),
          IconButton(
            tooltip: 'jp_delete'.tr(),
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed:
                controller.busy
                    ? null
                    : () async {
                      final ok = await confirmJourneyAction(
                        context,
                        title: 'jp_delete_booking_title'.tr(),
                        message: r.title,
                        confirm: 'jp_delete'.tr(),
                        destructive: true,
                      );
                      if (ok && context.mounted) {
                        await _report(
                          context,
                          controller.deleteReference(r.id),
                        );
                      }
                    },
          ),
        ],
      ),
    );
  }
}

/// The user's own booking details. KumbhaPath stores what they type and
/// never claims a booking exists.
Future<void> showReferenceEditor(
  BuildContext context,
  JourneyDetailController controller, {
  JourneyReference? reference,
}) async {
  final r = reference;
  final title = TextEditingController(text: r?.title ?? '');
  final provider = TextEditingController(text: r?.provider ?? '');
  final booking = TextEditingController(text: r?.bookingReference ?? '');
  final url = TextEditingController(text: r?.url ?? '');
  final notes = TextEditingController(text: r?.notes ?? '');
  var kind = r?.kind ?? 'transport';
  DateTime? start = r?.startDate;
  DateTime? end = r?.endDate;
  final formKey = GlobalKey<FormState>();

  Future<DateTime?> pick(BuildContext ctx, DateTime? initial) => showDatePicker(
    context: ctx,
    firstDate: DateTime(2025),
    lastDate: DateTime(2030, 12, 31),
    initialDate: initial ?? controller.plan?.arrivalDate ?? DateTime.now(),
  );

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (ctx) => StatefulBuilder(
          builder:
              (ctx, setSheet) => Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom + AppSpacing.lg,
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          (r == null ? 'jp_add_booking' : 'jp_edit_booking')
                              .tr(),
                          style: ctx.textTheme.titleLarge,
                        ),
                        AppSpacing.gapSm,
                        SourceNote('jp_booking_disclaimer'.tr()),
                        AppSpacing.gapMd,
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'transport',
                              label: Text('jp_ref_transport'.tr()),
                            ),
                            ButtonSegment(
                              value: 'accommodation',
                              label: Text('jp_ref_stay'.tr()),
                            ),
                          ],
                          selected: {kind},
                          onSelectionChanged:
                              (s) => setSheet(() => kind = s.first),
                        ),
                        AppSpacing.gapMd,
                        AppTextField(
                          controller: title,
                          label: 'jp_ref_title'.tr(),
                          hint: 'jp_ref_title_hint'.tr(),
                          maxLength: 120,
                          validator:
                              (v) =>
                                  (v ?? '').trim().isEmpty
                                      ? 'jp_err_required'.tr()
                                      : null,
                        ),
                        AppTextField(
                          controller: provider,
                          label: 'jp_ref_provider'.tr(),
                          maxLength: 100,
                        ),
                        AppTextField(
                          controller: booking,
                          label: 'jp_ref_number'.tr(),
                          maxLength: 60,
                        ),
                        AppTextField(
                          controller: url,
                          label: 'jp_ref_url'.tr(),
                          hint: 'https://',
                          maxLength: 300,
                          keyboardType: TextInputType.url,
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return null;
                            final uri = Uri.tryParse(value);
                            return uri == null ||
                                    uri.scheme != 'https' ||
                                    uri.host.isEmpty
                                ? 'jp_err_https'.tr()
                                : null;
                          },
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final d = await pick(ctx, start);
                                  if (d != null) setSheet(() => start = d);
                                },
                                child: Text(
                                  start == null
                                      ? 'jp_ref_start'.tr()
                                      : formatDate(ctx, start!),
                                ),
                              ),
                            ),
                            AppSpacing.gapSm,
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final d = await pick(ctx, end ?? start);
                                  if (d != null) setSheet(() => end = d);
                                },
                                child: Text(
                                  end == null
                                      ? 'jp_ref_end'.tr()
                                      : formatDate(ctx, end!),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (start != null &&
                            end != null &&
                            end!.isBefore(start!))
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              'jp_err_end_before'.tr(),
                              style: TextStyle(color: ctx.colorScheme.error),
                            ),
                          ),
                        AppSpacing.gapMd,
                        AppTextField(
                          controller: notes,
                          label: 'jp_notes'.tr(),
                          maxLength: 300,
                          maxLines: 2,
                        ),
                        AppSpacing.gapMd,
                        AppButton(
                          label: 'jp_save'.tr(),
                          onPressed: () {
                            final datesOk =
                                start == null ||
                                end == null ||
                                !end!.isBefore(start!);
                            if (formKey.currentState!.validate() && datesOk) {
                              Navigator.pop(ctx, true);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ),
  );

  final data = {
    'kind': kind,
    'title': title.text.trim(),
    'provider': provider.text.trim(),
    'booking_reference': booking.text.trim(),
    'url': url.text.trim(),
    'start_date': start == null ? null : isoDate(start!),
    'end_date': end == null ? null : isoDate(end!),
    'notes': notes.text.trim(),
  };
  // Not disposed: see showItemEditor.
  if (saved != true || !context.mounted) return;
  await _report(context, controller.saveReference(r?.id, data));
}

// ------------------------------------------------------------------- budget

class BudgetTab extends StatelessWidget {
  const BudgetTab({super.key, required this.plan, required this.onEdit});

  final JourneyPlan plan;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final budget = plan.budget;
    final text = context.textTheme;
    if (budget == null) {
      return AppEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'jp_no_budget'.tr(),
        message: 'jp_no_budget_message'.tr(),
        actionLabel: 'jp_add_budget'.tr(),
        onAction: onEdit,
      );
    }
    return _centered(
      ListView(
        padding: _pagePadding,
        children: [
          AppCard(
            variant: AppCardVariant.filled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('jp_budget_total_label'.tr(), style: text.labelLarge),
                Text(
                  formatRupees(budget.total) ?? '—',
                  style: text.headlineSmall,
                ),
                if (plan.travellers > 1)
                  Text(
                    'jp_budget_per_person_value'.tr(
                      args: [formatRupees(budget.perPerson) ?? '—'],
                    ),
                    style: text.bodyMedium,
                  ),
              ],
            ),
          ),
          AppSpacing.gapLg,
          for (final line in budget.lines) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'jp_budget_cat_${line.category}'.tr(),
                    style: text.titleSmall,
                  ),
                ),
                Text(formatRupees(line.amount) ?? '—', style: text.titleSmall),
              ],
            ),
            AppSpacing.gapXs,
            LinearProgressIndicator(
              value: line.percent / 100,
              semanticsLabel: '${line.percent}%',
            ),
            AppSpacing.gapMd,
          ],
          SourceNote('jp_budget_assumption'.tr()),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- info

class InfoTab extends StatelessWidget {
  const InfoTab({
    super.key,
    required this.plan,
    required this.guide,
    required this.onRetryGuide,
  });

  final JourneyPlan plan;
  final Future<PlanningGuide>? guide;
  final VoidCallback onRetryGuide;

  bool _inTrip(DateTime d) {
    final a = plan.arrivalDate, b = plan.departureDate;
    return a != null && b != null && !d.isBefore(a) && !d.isAfter(b);
  }

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return FutureBuilder<PlanningGuide>(
      future: guide,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const AppLoading();
        }
        final g = snap.data;
        if (g == null) {
          return AppErrorView(
            message: journeyErrorText(
              snap.error is JourneyException
                  ? snap.error as JourneyException
                  : null,
            ),
            onRetry: onRetryGuide,
          );
        }
        return _centered(
          ListView(
            padding: _pagePadding,
            children: [
              AppSectionHeader(title: 'jp_important_dates'.tr()),
              AppSpacing.gapSm,
              if (g.dates.isEmpty)
                Text('jp_no_dates'.tr(), style: text.bodyMedium)
              else
                for (final d in g.dates)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _inTrip(d.date)
                          ? Icons.star_rounded
                          : Icons.event_outlined,
                      color:
                          _inTrip(d.date) ? context.colorScheme.primary : null,
                    ),
                    title: Text(d.name),
                    subtitle: Text(
                      [
                        formatDate(context, d.date),
                        if (d.location != null) d.location!,
                        if (_inTrip(d.date)) 'jp_during_trip'.tr(),
                        if (d.lastChecked != null)
                          'jp_updated_on'.tr(
                            args: [formatDate(context, d.lastChecked!)],
                          ),
                      ].join(' · '),
                    ),
                  ),
              AppSpacing.gapSm,
              SourceNote(g.datesNote),
              AppSpacing.gapXl,
              AppSectionHeader(title: 'jp_contacts'.tr()),
              AppSpacing.gapSm,
              SourceNote(g.contactsNote),
              for (final c in g.contacts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.call_outlined),
                  title: Text(c.label),
                  subtitle: Text(
                    [c.phone, c.email].whereType<String>().join(' · '),
                  ),
                  onTap:
                      c.phone == null
                          ? null
                          : () => openExternal(context, 'tel:${c.phone}'),
                  trailing:
                      c.email == null
                          ? null
                          : IconButton(
                            tooltip: c.email,
                            icon: const Icon(Icons.mail_outline_rounded),
                            onPressed:
                                () =>
                                    openExternal(context, 'mailto:${c.email}'),
                          ),
                ),
              AppSpacing.gapXl,
              SourceNote('jp_checked_on'.tr(args: [g.checkedOn])),
            ],
          ),
        );
      },
    );
  }
}
