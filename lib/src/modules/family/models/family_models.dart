/// Models for the Family Safety Circle. Everything comes from `/api/family/`;
/// fields the requester may not see simply arrive as null.
library;

const familyRelationships = [
  'father',
  'mother',
  'son',
  'daughter',
  'grandfather',
  'grandmother',
  'spouse',
  'sibling',
  'other',
];

const dependentKinds = [
  'dependent_child',
  'dependent_elderly',
  'dependent_other',
];

const familyAgeGroups = ['under_6', '6_12', '13_17', 'adult', 'senior'];

const contactMethods = ['call', 'sms', 'whatsapp'];

/// 10 digits starting 6 to 9, the app-wide phone rule.
bool isValidMobile(String value) =>
    RegExp(r'^[6-9]\d{9}$').hasMatch(value.trim());

/// The bare 10 digits of a stored "+91XXXXXXXXXX" number.
String localMobile(String value) =>
    value.startsWith('+91') ? value.substring(3) : value;

DateTime? _date(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

class FamilyCircle {
  const FamilyCircle({
    required this.id,
    required this.name,
    this.description = '',
    this.language = 'en',
    this.memberCount = 1,
    this.myRole,
    this.myMemberId,
    this.organizerOfferForMe = false,
  });

  factory FamilyCircle.fromJson(Map<String, dynamic> json) => FamilyCircle(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    language: json['language'] as String? ?? 'en',
    memberCount: json['member_count'] as int? ?? 1,
    myRole: json['my_role'] as String?,
    myMemberId: json['my_member_id'] as String?,
    organizerOfferForMe: json['organizer_offer_for_me'] as bool? ?? false,
  );

  final String id;
  final String name;
  final String description;
  final String language;
  final int memberCount;
  final String? myRole;
  final String? myMemberId;
  final bool organizerOfferForMe;

  bool get isOrganizer => myRole == 'organizer';
}

class GuardianRef {
  const GuardianRef({required this.id, required this.name});

  factory GuardianRef.fromJson(Map<String, dynamic> json) => GuardianRef(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
  );

  final String id;
  final String name;
}

/// What the backend says this requester may do. The API still checks each one.
class MemberPermissions {
  const MemberPermissions({
    this.editProfile = false,
    this.editRelationship = false,
    this.remove = false,
    this.manageGuardians = false,
    this.viewContacts = false,
    this.editContacts = false,
    this.makeOrganizer = false,
    this.viewQr = false,
  });

  factory MemberPermissions.fromJson(Map<String, dynamic> json) =>
      MemberPermissions(
        editProfile: json['edit_profile'] == true,
        editRelationship: json['edit_relationship'] == true,
        remove: json['remove'] == true,
        manageGuardians: json['manage_guardians'] == true,
        viewContacts: json['view_contacts'] == true,
        editContacts: json['edit_contacts'] == true,
        makeOrganizer: json['make_organizer'] == true,
        viewQr: json['view_qr'] == true,
      );

  final bool editProfile;
  final bool editRelationship;
  final bool remove;
  final bool manageGuardians;
  final bool viewContacts;
  final bool editContacts;
  final bool makeOrganizer;
  final bool viewQr;
}

/// An adult's own choices, sent only to that adult.
class MemberPrivacy {
  const MemberPrivacy({
    this.sharePhone = false,
    this.shareContactsWithOrganizer = false,
    this.shareLocationInAlerts = false,
  });

  factory MemberPrivacy.fromJson(Map<String, dynamic> json) => MemberPrivacy(
    sharePhone: json['share_phone'] == true,
    shareContactsWithOrganizer: json['share_contacts_with_organizer'] == true,
    shareLocationInAlerts: json['location_sharing_consent'] == true,
  );

  final bool sharePhone;
  final bool shareContactsWithOrganizer;

  /// Whether the family may see where a helper reported this person.
  final bool shareLocationInAlerts;
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.kind,
    required this.role,
    required this.relationship,
    required this.isDependent,
    this.ageGroup = '',
    this.dateOfBirth,
    this.language = 'en',
    this.hasPhoto = false,
    this.phone,
    this.guardians = const [],
    this.permissions = const MemberPermissions(),
    this.privacy,
    this.consentBasis,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    kind: json['kind'] as String? ?? '',
    role: json['role'] as String? ?? 'member',
    relationship: json['relationship'] as String? ?? 'other',
    isDependent: json['is_dependent'] == true,
    ageGroup: json['age_group'] as String? ?? '',
    dateOfBirth: _date(json['date_of_birth']),
    language: json['language'] as String? ?? 'en',
    hasPhoto: json['has_photo'] == true,
    phone: json['phone'] as String?,
    guardians: [
      for (final g in json['guardians'] as List? ?? const [])
        GuardianRef.fromJson(g as Map<String, dynamic>),
    ],
    permissions:
        json['permissions'] is Map<String, dynamic>
            ? MemberPermissions.fromJson(
              json['permissions'] as Map<String, dynamic>,
            )
            : const MemberPermissions(),
    privacy:
        json['privacy'] is Map<String, dynamic>
            ? MemberPrivacy.fromJson(json['privacy'] as Map<String, dynamic>)
            : null,
    consentBasis: json['consent_basis'] as String?,
  );

  final String id;
  final String name;
  final String kind;
  final String role;
  final String relationship;
  final bool isDependent;
  final String ageGroup;
  final DateTime? dateOfBirth;
  final String language;
  final bool hasPhoto;
  final String? phone;
  final List<GuardianRef> guardians;
  final MemberPermissions permissions;
  final MemberPrivacy? privacy;
  final String? consentBasis;

  bool get isOrganizer => role == 'organizer';
}

/// Where a contact stands against the server.
enum ContactSyncState {
  synced,
  pendingCreate,
  pendingUpdate,
  pendingDelete,

  /// Changed on both sides. Waits for the user to choose.
  conflict,

  /// The server refused it. Waits for the user to fix or discard it.
  failed,
}

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.mobile,
    this.relationship = '',
    this.priority = 1,
    this.method = 'call',
    this.updatedAt,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        relationship: json['relationship'] as String? ?? '',
        priority: json['priority'] as int? ?? 1,
        method: json['method'] as String? ?? 'call',
        updatedAt: json['updated_at'] as String?,
      );

  final String id;
  final String name;
  final String mobile;
  final String relationship;
  final int priority;
  final String method;

  /// The server's version of this contact. Null until the server has it.
  final String? updatedAt;

  EmergencyContact copyWith({
    String? name,
    String? mobile,
    String? relationship,
    int? priority,
    String? method,
    String? updatedAt,
    bool clearUpdatedAt = false,
  }) => EmergencyContact(
    id: id,
    name: name ?? this.name,
    mobile: mobile ?? this.mobile,
    relationship: relationship ?? this.relationship,
    priority: priority ?? this.priority,
    method: method ?? this.method,
    updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
  );

  /// Contacts are private, so this must never print their details.
  @override
  String toString() => 'EmergencyContact(priority: $priority)';
}

class FamilyInvite {
  const FamilyInvite({
    required this.id,
    required this.relationship,
    required this.state,
    this.inApp = false,
    this.expiresAt,
    this.code,
    this.link,
  });

  factory FamilyInvite.fromJson(Map<String, dynamic> json) => FamilyInvite(
    id: json['id'] as String,
    relationship: json['relationship'] as String? ?? 'other',
    state: json['state'] as String? ?? 'pending',
    inApp: json['in_app'] == true,
    expiresAt: _date(json['expires_at']),
    code: json['code'] as String?,
    link: json['link'] as String?,
  );

  final String id;
  final String relationship;
  final String state;
  final bool inApp;
  final DateTime? expiresAt;

  /// Only present in the response that created it.
  final String? code;

  /// Also only in that response. Holds a secret, so it's never stored.
  final String? link;

  bool get isOpen => state == 'pending';
}

/// What an invited person sees before deciding.
class InvitePreview {
  const InvitePreview({
    required this.id,
    required this.familyName,
    required this.organizerName,
    required this.memberCount,
    required this.relationship,
    this.expiresAt,
    this.alreadyMember = false,
  });

  factory InvitePreview.fromJson(Map<String, dynamic> json) => InvitePreview(
    id: json['id'] as String,
    familyName: json['family_name'] as String? ?? '',
    organizerName: json['organizer_name'] as String? ?? '',
    memberCount: json['member_count'] as int? ?? 1,
    relationship: json['relationship'] as String? ?? 'other',
    expiresAt: _date(json['expires_at']),
    alreadyMember: json['already_member'] == true,
  );

  final String id;
  final String familyName;
  final String organizerName;
  final int memberCount;
  final String relationship;
  final DateTime? expiresAt;

  /// The person looking at this is already in the family.
  final bool alreadyMember;
}
