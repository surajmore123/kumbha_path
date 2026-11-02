import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart';

enum FamilyFailure {
  offline,
  signedOut,
  forbidden,
  notFound,
  invalid,
  conflict,

  /// The record changed since this request's version: see [serverContact].
  stale,

  /// An invitation link that has ended: see [FamilyException.invitationState].
  gone,
  server,
}

class FamilyException implements Exception {
  const FamilyException(
    this.kind, {
    this.fieldErrors = const {},
    this.serverContact,
  });

  final FamilyFailure kind;
  final Map<String, String> fieldErrors;

  /// The server's current record, on [FamilyFailure.stale].
  final EmergencyContact? serverContact;

  /// Why a link no longer works: expired, revoked, accepted or declined.
  String? get invitationState => fieldErrors['state'];

  String? get message =>
      fieldErrors['non_field_errors'] ??
      fieldErrors['detail'] ??
      (fieldErrors.isEmpty ? null : fieldErrors.values.first);

  @override
  String toString() => 'FamilyException($kind)';
}

/// Everything the family screens need from `/api/family/`.
abstract class FamilyRepository {
  Future<List<FamilyCircle>> circles();
  Future<FamilyCircle> createCircle(Map<String, dynamic> data);
  Future<FamilyCircle> updateCircle(String id, Map<String, dynamic> data);
  Future<void> deleteCircle(String id);
  Future<void> leaveCircle(String id);
  Future<void> offerOrganizer(String familyId, String memberId);
  Future<void> acceptOrganizer(String familyId);

  Future<List<FamilyMember>> members(String familyId);
  Future<FamilyMember> member(String familyId, String memberId);
  Future<FamilyMember> addDependent(String familyId, Map<String, dynamic> data);
  Future<FamilyMember> updateMember(
    String familyId,
    String memberId,
    Map<String, dynamic> data,
  );
  Future<void> removeMember(String familyId, String memberId);
  Future<Uint8List?> photo(String familyId, String memberId);
  Future<void> uploadPhoto(String familyId, String memberId, Uint8List bytes);
  Future<void> removePhoto(String familyId, String memberId);
  Future<FamilyMember> addGuardian(
    String familyId,
    String memberId,
    String guardianId,
  );
  Future<void> removeGuardian(
    String familyId,
    String memberId,
    String guardianId,
  );

  /// The family's shared list, or one person's with [memberId].
  Future<List<EmergencyContact>> contacts(String familyId, {String? memberId});
  Future<EmergencyContact> addContact(
    String familyId,
    Map<String, dynamic> data, {
    String? memberId,
  });

  /// With [ifMatch], refused as [FamilyFailure.stale] if the contact's version
  /// is no longer that one.
  Future<EmergencyContact> updateContact(
    String familyId,
    String contactId,
    Map<String, dynamic> data, {
    String? ifMatch,
  });
  Future<void> deleteContact(
    String familyId,
    String contactId, {
    String? ifMatch,
  });
  Future<List<EmergencyContact>> reorderContacts(
    String familyId,
    List<String> contactIds, {
    String? memberId,
  });

  Future<List<FamilyInvite>> invitations(String familyId);
  Future<FamilyInvite> createInvitation(
    String familyId, {
    required String relationship,
    String? phone,
  });
  Future<void> revokeInvitation(String familyId, String invitationId);
  Future<List<InvitePreview>> myInvitations();
  Future<InvitePreview> lookupInvitation(String code);
  Future<InvitePreview> lookupInvitationLink(String token);

  /// Pass the [code], the link [token], or the [invitationId] of an in-app
  /// invitation.
  Future<String> acceptInvitation({
    String? code,
    String? invitationId,
    String? token,
  });
  Future<void> declineInvitation({
    String? code,
    String? invitationId,
    String? token,
  });
}

/// The live backend. Nothing personal is stored on the device, and tokens only
/// travel in the Authorization header. Invitation codes go in request bodies.
class HttpFamilyRepository implements FamilyRepository {
  HttpFamilyRepository({http.Client? client, Future<String?> Function()? token})
    : _client = client ?? http.Client(),
      _token = token ?? (() => storage.read(key: 'access_token'));

  final http.Client _client;
  final Future<String?> Function() _token;

  static const _timeout = Duration(seconds: 20);

  Uri _uri(String path) {
    final p = '/api/family/$path';
    return ApiConst.protocol == 'https'
        ? Uri.https(ApiConst.host, p)
        : Uri.http(ApiConst.host, p);
  }

  static Map<String, dynamic>? _decode(String text) {
    try {
      final json = jsonDecode(text);
      return json is Map<String, dynamic> ? json : null;
    } on FormatException {
      return null;
    }
  }

  static Map<String, String> _errors(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, String>{};
    raw.forEach((key, value) {
      final msg = value is List ? value.whereType<String>().firstOrNull : value;
      if (msg is String && msg.trim().isNotEmpty) out['$key'] = msg.trim();
    });
    return out;
  }

  Future<String> _bearer() async {
    String? token;
    try {
      token = await _token();
    } catch (_) {
      token = null;
    }
    if (token == null || token.isEmpty || token == 'null') {
      throw const FamilyException(FamilyFailure.signedOut);
    }
    return token;
  }

  Future<http.Response> _send(http.BaseRequest request) async {
    try {
      return await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      );
    } on SocketException {
      throw const FamilyException(FamilyFailure.offline);
    } on TimeoutException {
      throw const FamilyException(FamilyFailure.offline);
    } on http.ClientException {
      throw const FamilyException(FamilyFailure.offline);
    }
  }

  static FamilyException _failure(http.Response response) {
    final body = _decode(utf8.decode(response.bodyBytes));
    final current = body?['data'];
    return FamilyException(
      switch (response.statusCode) {
        401 => FamilyFailure.signedOut,
        403 => FamilyFailure.forbidden,
        404 => FamilyFailure.notFound,
        400 => FamilyFailure.invalid,
        409 => FamilyFailure.conflict,
        410 => FamilyFailure.gone,
        412 => FamilyFailure.stale,
        _ => FamilyFailure.server,
      },
      fieldErrors: _errors(body?['errors']),
      serverContact:
          response.statusCode == 412 && current is Map<String, dynamic>
              ? EmergencyContact.fromJson(current)
              : null,
    );
  }

  Future<Object?> _call(
    String method,
    String path, [
    Object? body,
    String? ifMatch,
  ]) async {
    final request = http.Request(method, _uri(path))
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await _bearer()}',
        if (ifMatch != null) 'If-Match': ifMatch,
      });
    if (body != null) request.body = jsonEncode(body);
    final response = await _send(request);
    if (response.statusCode == 204) return null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _decode(utf8.decode(response.bodyBytes))?['data'];
    }
    throw _failure(response);
  }

  Future<T> _one<T>(
    Future<Object?> call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final data = await call;
    if (data is! Map<String, dynamic>) {
      throw const FamilyException(FamilyFailure.server);
    }
    return parse(data);
  }

  Future<List<T>> _many<T>(
    Future<Object?> call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final data = await call;
    if (data is! List) throw const FamilyException(FamilyFailure.server);
    return [
      for (final item in data.whereType<Map<String, dynamic>>()) parse(item),
    ];
  }

  String _c(String id) => 'circles/$id/';
  String _m(String familyId, String memberId) =>
      'circles/$familyId/members/$memberId/';

  @override
  Future<List<FamilyCircle>> circles() =>
      _many(_call('GET', 'circles/'), FamilyCircle.fromJson);

  @override
  Future<FamilyCircle> createCircle(Map<String, dynamic> data) =>
      _one(_call('POST', 'circles/', data), FamilyCircle.fromJson);

  @override
  Future<FamilyCircle> updateCircle(String id, Map<String, dynamic> data) =>
      _one(_call('PATCH', _c(id), data), FamilyCircle.fromJson);

  @override
  Future<void> deleteCircle(String id) => _call('DELETE', _c(id));

  @override
  Future<void> leaveCircle(String id) => _call('POST', '${_c(id)}leave/', {});

  @override
  Future<void> offerOrganizer(String familyId, String memberId) =>
      _call('POST', '${_c(familyId)}organizer/', {'member_id': memberId});

  @override
  Future<void> acceptOrganizer(String familyId) =>
      _call('POST', '${_c(familyId)}organizer/accept/', {});

  @override
  Future<List<FamilyMember>> members(String familyId) =>
      _many(_call('GET', '${_c(familyId)}members/'), FamilyMember.fromJson);

  @override
  Future<FamilyMember> member(String familyId, String memberId) =>
      _one(_call('GET', _m(familyId, memberId)), FamilyMember.fromJson);

  @override
  Future<FamilyMember> addDependent(
    String familyId,
    Map<String, dynamic> data,
  ) => _one(
    _call('POST', '${_c(familyId)}members/', data),
    FamilyMember.fromJson,
  );

  @override
  Future<FamilyMember> updateMember(
    String familyId,
    String memberId,
    Map<String, dynamic> data,
  ) =>
      _one(_call('PATCH', _m(familyId, memberId), data), FamilyMember.fromJson);

  @override
  Future<void> removeMember(String familyId, String memberId) =>
      _call('DELETE', _m(familyId, memberId));

  @override
  Future<Uint8List?> photo(String familyId, String memberId) async {
    final request = http.Request('GET', _uri('${_m(familyId, memberId)}photo/'))
      ..headers['Authorization'] = 'Bearer ${await _bearer()}';
    final response = await _send(request);
    return response.statusCode == 200 ? response.bodyBytes : null;
  }

  @override
  Future<void> uploadPhoto(
    String familyId,
    String memberId,
    Uint8List bytes,
  ) async {
    final request =
        http.MultipartRequest('PUT', _uri('${_m(familyId, memberId)}photo/'))
          ..headers['Authorization'] = 'Bearer ${await _bearer()}'
          ..files.add(
            http.MultipartFile.fromBytes('photo', bytes, filename: 'photo.jpg'),
          );
    final response = await _send(request);
    if (response.statusCode != 200) throw _failure(response);
  }

  @override
  Future<void> removePhoto(String familyId, String memberId) =>
      _call('DELETE', '${_m(familyId, memberId)}photo/');

  @override
  Future<FamilyMember> addGuardian(
    String familyId,
    String memberId,
    String guardianId,
  ) => _one(
    _call('POST', '${_m(familyId, memberId)}guardians/', {
      'member_id': guardianId,
    }),
    FamilyMember.fromJson,
  );

  @override
  Future<void> removeGuardian(
    String familyId,
    String memberId,
    String guardianId,
  ) => _call('DELETE', '${_m(familyId, memberId)}guardians/$guardianId/');

  String _contactsPath(String familyId, String? memberId) =>
      memberId == null
          ? '${_c(familyId)}contacts/'
          : '${_m(familyId, memberId)}contacts/';

  @override
  Future<List<EmergencyContact>> contacts(
    String familyId, {
    String? memberId,
  }) => _many(
    _call('GET', _contactsPath(familyId, memberId)),
    EmergencyContact.fromJson,
  );

  @override
  Future<EmergencyContact> addContact(
    String familyId,
    Map<String, dynamic> data, {
    String? memberId,
  }) => _one(
    _call('POST', _contactsPath(familyId, memberId), data),
    EmergencyContact.fromJson,
  );

  @override
  Future<EmergencyContact> updateContact(
    String familyId,
    String contactId,
    Map<String, dynamic> data, {
    String? ifMatch,
  }) => _one(
    _call('PATCH', '${_c(familyId)}contacts/$contactId/', data, ifMatch),
    EmergencyContact.fromJson,
  );

  @override
  Future<void> deleteContact(
    String familyId,
    String contactId, {
    String? ifMatch,
  }) => _call('DELETE', '${_c(familyId)}contacts/$contactId/', null, ifMatch);

  @override
  Future<List<EmergencyContact>> reorderContacts(
    String familyId,
    List<String> contactIds, {
    String? memberId,
  }) => _many(
    _call('POST', '${_c(familyId)}contacts/reorder/', {
      'contact_ids': contactIds,
      if (memberId != null) 'member_id': memberId,
    }),
    EmergencyContact.fromJson,
  );

  @override
  Future<List<FamilyInvite>> invitations(String familyId) =>
      _many(_call('GET', '${_c(familyId)}invitations/'), FamilyInvite.fromJson);

  @override
  Future<FamilyInvite> createInvitation(
    String familyId, {
    required String relationship,
    String? phone,
  }) => _one(
    _call('POST', '${_c(familyId)}invitations/', {
      'relationship': relationship,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    }),
    FamilyInvite.fromJson,
  );

  @override
  Future<void> revokeInvitation(String familyId, String invitationId) =>
      _call('POST', '${_c(familyId)}invitations/$invitationId/revoke/', {});

  @override
  Future<List<InvitePreview>> myInvitations() =>
      _many(_call('GET', 'invitations/mine/'), InvitePreview.fromJson);

  @override
  Future<InvitePreview> lookupInvitation(String code) => _one(
    _call('POST', 'invitations/lookup/', {'code': code}),
    InvitePreview.fromJson,
  );

  @override
  Future<InvitePreview> lookupInvitationLink(String token) => _one(
    _call('POST', 'invitations/lookup/', {'token': token}),
    InvitePreview.fromJson,
  );

  Map<String, String> _proof(
    String? code,
    String? invitationId,
    String? token,
  ) => {
    if (code != null) 'code': code,
    if (invitationId != null) 'invitation_id': invitationId,
    if (token != null) 'token': token,
  };

  @override
  Future<String> acceptInvitation({
    String? code,
    String? invitationId,
    String? token,
  }) => _one(
    _call('POST', 'invitations/accept/', _proof(code, invitationId, token)),
    (data) => data['family_id'] as String,
  );

  @override
  Future<void> declineInvitation({
    String? code,
    String? invitationId,
    String? token,
  }) =>
      _call('POST', 'invitations/decline/', _proof(code, invitationId, token));
}

/// Swappable in tests.
class FamilyServices {
  FamilyServices._();

  static FamilyRepository repository = HttpFamilyRepository();
}
