import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show showJourneySnack;
import 'package:kumbha_path/src/modules/lostfound/widgets/lf_parts.dart'
    show dateTimeText;
import 'package:kumbha_path/src/modules/setting/widgets/notification_preferences_card.dart';
import 'package:kumbha_path/src/services/notification_router.dart';

const noteCategories = [
  'emergency',
  'family_safety',
  'lost_found',
  'safety_qr',
  'family_location',
  'reunification',
  'operations',
  'general',
];

IconData noteIcon(String category) => switch (category) {
  'emergency' => Icons.sos_rounded,
  'family_safety' => Icons.family_restroom_rounded,
  'lost_found' => Icons.person_search_rounded,
  'safety_qr' => Icons.qr_code_2_rounded,
  'family_location' => Icons.share_location_rounded,
  'reunification' => Icons.diversity_3_rounded,
  'operations' => Icons.assignment_ind_outlined,
  _ => Icons.campaign_outlined,
};

class AppNote {
  const AppNote({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    this.data = const {},
    this.read = false,
    this.createdAt,
    this.delivery,
  });

  factory AppNote.fromJson(Map<String, dynamic> json) => AppNote(
    id: json['id'] as String,
    category: json['category'] as String? ?? 'general',
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    data:
        json['data'] is Map<String, dynamic>
            ? json['data'] as Map<String, dynamic>
            : const {},
    read: json['read'] == true,
    createdAt:
        json['created_at'] is String
            ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
            : null,
    delivery: json['delivery'] as String?,
  );

  final String id;
  final String category;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime? createdAt;

  /// pending, sent, no_device or failed. Null when it isn't tracked.
  final String? delivery;

  bool get isGeneral => category == 'general';

  AppNote asRead() => AppNote(
    id: id,
    category: category,
    title: title,
    body: body,
    data: data,
    read: true,
    createdAt: createdAt,
    delivery: delivery,
  );
}

class NotePage {
  const NotePage({required this.notes, this.hasNext = false});

  final List<AppNote> notes;
  final bool hasNext;
}

abstract class NotificationRepository {
  Future<NotePage> list({String? category, int page});
  Future<int> unreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead({String? category});
}

class HttpNotificationRepository implements NotificationRepository {
  HttpNotificationRepository({
    http.Client? client,
    Future<String?> Function()? token,
    this.requireHttps = kReleaseMode,
  }) : _client = client ?? http.Client(),
       _token = token ?? (() => storage.read(key: 'access_token'));

  final http.Client _client;
  final Future<String?> Function() _token;
  final bool requireHttps;

  Future<Map<String, dynamic>> _call(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    if (requireHttps && ApiConst.protocol != 'https') {
      throw const FamilyException(FamilyFailure.server);
    }
    String? token;
    try {
      token = await _token();
    } catch (_) {
      token = null;
    }
    if (token == null || token.isEmpty || token == 'null') {
      throw const FamilyException(FamilyFailure.signedOut);
    }
    final p = '/api/notifications/$path';
    final uri =
        ApiConst.protocol == 'https'
            ? Uri.https(ApiConst.host, p, query)
            : Uri.http(ApiConst.host, p, query);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 15)),
      );
    } on SocketException {
      throw const FamilyException(FamilyFailure.offline);
    } on TimeoutException {
      throw const FamilyException(FamilyFailure.offline);
    } on http.ClientException {
      throw const FamilyException(FamilyFailure.offline);
    }
    final code = response.statusCode;
    if (code < 200 || code >= 300) {
      throw FamilyException(switch (code) {
        401 => FamilyFailure.signedOut,
        404 => FamilyFailure.notFound,
        _ => FamilyFailure.server,
      });
    }
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      final data = json is Map<String, dynamic> ? json['data'] : null;
      return data is Map<String, dynamic> ? data : const {};
    } on FormatException {
      throw const FamilyException(FamilyFailure.server);
    }
  }

  @override
  Future<NotePage> list({String? category, int page = 1}) async {
    final data = await _call(
      'GET',
      '',
      query: {'page': '$page', if (category != null) 'category': category},
    );
    return NotePage(
      hasNext: data['has_next'] == true,
      notes: [
        for (final row in data['results'] as List? ?? const [])
          AppNote.fromJson(row as Map<String, dynamic>),
      ],
    );
  }

  @override
  Future<int> unreadCount() async {
    final data = await _call('GET', 'summary/');
    return (data['unread'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> markRead(String id) async {
    await _call('POST', '$id/read/', body: {});
  }

  @override
  Future<void> markAllRead({String? category}) async {
    await _call(
      'POST',
      'read-all/',
      body: {if (category != null) 'category': category},
    );
  }
}

class NotificationServices {
  NotificationServices._();

  static NotificationRepository repository = HttpNotificationRepository();
}

/// The app bar bell, with the unread count in words for screen readers.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, this.repository});

  final NotificationRepository? repository;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;

  NotificationRepository get _repo =>
      widget.repository ?? NotificationServices.repository;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final count = await _repo.unreadCount();
      if (mounted) setState(() => _unread = count);
    } catch (_) {
      // No count is better than a wrong one.
    }
  }

  @override
  Widget build(BuildContext context) {
    final tooltip =
        _unread > 0 ? 'note_unread'.plural(_unread) : 'dash_notifications'.tr();
    return IconButton(
      tooltip: tooltip,
      onPressed: () async {
        await Navigator.pushNamed(context, '/notificationCentre');
        if (mounted) await _load();
      },
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text(_unread > 99 ? '99+' : '$_unread'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}

/// `/notificationCentre`: everything sent to this person, in one place.
class NotificationCentreScreen extends StatefulWidget {
  const NotificationCentreScreen({super.key, this.repository, this.onOpen});

  final NotificationRepository? repository;

  /// Injected in tests.
  final void Function(Map<String, dynamic> data)? onOpen;

  @override
  State<NotificationCentreScreen> createState() =>
      _NotificationCentreScreenState();
}

class _NotificationCentreScreenState extends State<NotificationCentreScreen> {
  late final NotificationRepository _repo =
      widget.repository ?? NotificationServices.repository;
  static const _all = 'all';

  String _category = _all;
  List<AppNote>? _notes;
  Object? _error;
  bool _hasNext = false;
  int _page = 1;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _filter => _category == _all ? null : _category;

  Future<void> _load() async {
    setState(() {
      _error = null;
      _page = 1;
    });
    try {
      final page = await _repo.list(category: _filter);
      if (!mounted) return;
      setState(() {
        _notes = page.notes;
        _hasNext = page.hasNext;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _more() async {
    setState(() => _loadingMore = true);
    try {
      final page = await _repo.list(category: _filter, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _notes = [...?_notes, ...page.notes];
        _hasNext = page.hasNext;
      });
    } catch (e) {
      if (mounted) showJourneySnack(context, familyErrorText(e));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _setRead(AppNote note) {
    setState(() {
      _notes = [
        for (final n in _notes ?? const <AppNote>[])
          n.id == note.id ? n.asRead() : n,
      ];
    });
  }

  Future<void> _open(AppNote note) async {
    if (!note.read && !note.isGeneral) {
      _setRead(note);
      try {
        await _repo.markRead(note.id);
      } catch (_) {
        // It's shown unread again on the next load.
      }
    }
    if (!mounted) return;
    (widget.onOpen ?? NotificationRouter.open)(note.data);
  }

  Future<void> _markAll() async {
    try {
      await _repo.markAllRead(category: _filter);
      if (!mounted) return;
      setState(() {
        _notes = [for (final n in _notes ?? const <AppNote>[]) n.asRead()];
      });
    } catch (e) {
      if (mounted) showJourneySnack(context, familyErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = _notes;
    final failed = _error;
    final anyUnread = notes?.any((n) => !n.read) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text('note_title'.tr()),
        actions: [
          if (anyUnread)
            IconButton(
              tooltip: 'note_mark_all'.tr(),
              icon: const Icon(Icons.done_all_rounded),
              onPressed: _markAll,
            ),
          IconButton(
            tooltip: 'note_preferences'.tr(),
            icon: const Icon(Icons.tune_rounded),
            onPressed:
                () => Navigator.pushNamed(context, '/notificationPreferences'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              editorialMargin,
              AppSpacing.sm,
              editorialMargin,
              AppSpacing.huge,
            ),
            children: [
              PillChoices(
                values: const [_all, ...noteCategories],
                labelOf:
                    (c) => c == _all ? 'note_all'.tr() : 'note_cat_$c'.tr(),
                selected: _category,
                onChanged: (c) {
                  setState(() {
                    _category = c;
                    _notes = null;
                  });
                  _load();
                },
              ),
              AppSpacing.gapMd,
              if (failed != null && notes == null)
                AppErrorView(
                  compact: true,
                  message: familyErrorText(failed),
                  onRetry: _load,
                )
              else if (notes == null)
                const SkeletonLine(height: 72)
              else if (notes.isEmpty)
                AppEmptyState(
                  compact: true,
                  icon: Icons.notifications_none_rounded,
                  title: 'note_empty'.tr(),
                  message: 'note_empty_body'.tr(),
                )
              else ...[
                if (failed != null) ...[
                  FamilyNote(text: 'note_stale'.tr()),
                  AppSpacing.gapSm,
                ],
                for (final note in notes)
                  _NoteRow(note: note, onTap: () => _open(note)),
                if (_hasNext)
                  TextButton(
                    onPressed: _loadingMore ? null : _more,
                    child: Text('note_more'.tr()),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note, required this.onTap});

  final AppNote note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final colors = context.colorScheme;
    final at = note.createdAt;
    final emergency = note.category == 'emergency';
    final delivery = note.delivery;
    return Semantics(
      label: note.read ? null : 'note_unread_item'.tr(),
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                noteIcon(note.category),
                color: emergency ? colors.error : colors.primary,
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      style: e.title.copyWith(
                        fontWeight:
                            note.read ? FontWeight.w400 : FontWeight.w700,
                      ),
                    ),
                    Text(note.body),
                    Text(
                      [
                        'note_cat_${note.category}'.tr(),
                        if (at != null) dateTimeText(context, at),
                      ].join(' · '),
                      style: e.meta,
                    ),
                    if (delivery != null && delivery != 'sent')
                      Text('note_delivery_$delivery'.tr(), style: e.meta),
                  ],
                ),
              ),
              if (!note.read)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 10, color: colors.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `/notificationPreferences`: every switch, with the one that doesn't exist
/// shown too, so nobody wonders whether they've turned emergencies off.
class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('note_preferences'.tr())),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(editorialMargin),
          child: NotificationPreferencesCard(),
        ),
      ),
    );
  }
}
