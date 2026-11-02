# Family Safety Circle (Module 5, Phase 1)

The foundation only: who is in a family, who looks after whom, and who to call.
Lost & Found, location, reunification, SOS and operations dashboards
are later phases and aren't here, apart from the Digital Safety QR
(`docs/safety_qr.md`). `location_sharing_consent` starts off and only decides whether
an adult's family sees where a helper reported them.

## Data

| Model | Purpose |
|---|---|
| `FamilyCircle` | UUID id, name, description, language, `organizer_offer` |
| `FamilyMember` | One person in one circle. Adults link to `User`, so no profile is copied. Dependents have `user = NULL` and hold their own name, age and mobile |
| `MemberPhoto` | Bytes in the database, because `/media/` is public |
| `GuardianLink` | Dependent to adult, many to many |
| `FamilyInvitation` | SHA-256 of the code, expiry, status, optional `invited_phone` |
| `EmergencyContact` | Belongs to a member, or to the family when `member` is null |
| `FamilyAuditLog` | Action, actor, ids and field names, never names or numbers. Survives deletion of the family |

The brief's `FamilyMembership` and `FamilyDependent` are one table, `FamilyMember`.
Database constraints enforce: one membership per user per circle, one organizer
per circle, adults always have an account and dependents never do, and the
organizer is an adult.

Limits: 3 circles per user, 30 members per circle, 10 contacts per owner,
10 open invitations per circle, 2 MB per photo.

Migration: `apps/family/migrations/0001_initial.py`. It only adds tables.

## Who can do what

All rules are in `apps/family/policy.py`. Someone outside a circle gets 404
everywhere, the same as for a circle that doesn't exist.

| Action | Organizer | Guardian | Other adult | Self (adult) |
|---|---|---|---|---|
| Edit a dependent, see their mobile and birth date | Yes | Own dependents | No | n/a |
| Edit an adult's profile or privacy | No | No | No | Yes |
| See an adult's phone | If shared | If shared | If shared | Yes |
| See an adult's contacts | If shared (read only) | No | No | Yes |
| Change an adult's contacts | No | No | No | Yes |
| Family's shared contacts | Read and edit | Read | Read | Read |
| Correct someone's relationship label | Yes | Own dependents | No | Yes |
| Add dependents, invite, revoke, remove members, manage guardians | Yes | No | No | No |

- Adults only join by accepting an invitation. No endpoint adds an account to a circle.
- The organizer role moves only when the other adult accepts it.
- Removing the last guardian is refused. If a sole guardian leaves or is removed, the organizer takes over.
- A family can't be deleted while other adults are in it.
- If an organizer deletes their account, any remaining adult can accept the vacant role. A circle with no adult left is deleted, including dependents' details.

Invitation codes are 12 characters from `secrets`, valid for 3 days, single-use
and revocable. Only the hash is stored, so the code is returned once. Code
endpoints allow 20 requests an hour per user, and any bad, used, expired or
revoked code gets the same 404. An invitation with a phone number can only be
used by the account with that number, and the reply doesn't reveal whether that
number has an account.

**Nothing sends SMS, WhatsApp or push.** The organizer shares the link or code,
or it waits in the invitee's app if their account uses that number. Links are
covered in `docs/family_invite_links.md`.

## API

All paths are under `/api/family/` and need `Authorization: Bearer <access token>`.
Success is `{"status":"success","data":...}` and failure
`{"status":"error","errors":{...}}`. DELETE, leave and decline return 204.
`403` means a member without permission, `404` someone outside the circle,
`409` a state conflict.

### Circles

| Method and path | Who |
|---|---|
| `GET circles/` | Own circles |
| `POST circles/` | Anyone signed in; becomes organizer |
| `GET circles/<id>/` | Member |
| `PATCH circles/<id>/` | Organizer |
| `DELETE circles/<id>/` | Organizer, no other adults left |
| `POST circles/<id>/leave/` | Member; organizer gets 409 |
| `POST circles/<id>/organizer/` | Organizer, `{"member_id": "..."}` |
| `POST circles/<id>/organizer/accept/` | The adult offered it, or any adult if vacant |

```json
POST circles/
{"name": "More Family", "description": "", "language": "mr"}

201
{"status": "success", "data": {
  "id": "7f1c2d0e-6a54-4f0b-9f1a-2b9c1e6d3a10",
  "name": "More Family", "description": "", "language": "mr",
  "member_count": 1, "my_role": "organizer",
  "my_member_id": "c0a8012e-41d2-4c6f-8a53-0e2b7f19d644",
  "organizer_offer_for_me": false,
  "created_at": "2026-10-30T09:12:00Z"}}
```

### Members

| Method and path | Who |
|---|---|
| `GET circles/<id>/members/` | Member; private fields are null |
| `POST circles/<id>/members/` | Organizer; adds a dependent only |
| `GET`, `PATCH`, `DELETE circles/<id>/members/<mid>/` | By policy |
| `GET`, `PUT`, `DELETE .../members/<mid>/photo/` | GET any member; change by policy. `PUT` is multipart field `photo` |
| `POST .../members/<mid>/guardians/` | Organizer, `{"member_id": "..."}` |
| `DELETE .../members/<mid>/guardians/<guardian_id>/` | Organizer; 409 for the last one |

```json
POST circles/<id>/members/
{"full_name": "Aarav More", "kind": "dependent_child", "relationship": "son",
 "age_group": "6_12", "language": "mr"}

201
{"status": "success", "data": {
  "id": "2e7f...", "name": "Aarav More", "kind": "dependent_child",
  "role": "member", "relationship": "son", "is_dependent": true,
  "age_group": "6_12", "date_of_birth": null, "language": "mr",
  "has_photo": false, "phone": null,
  "guardians": [{"id": "c0a8...", "name": "Suresh More"}],
  "permissions": {"edit_profile": true, "edit_relationship": true,
    "remove": true, "manage_guardians": true, "view_contacts": true,
    "edit_contacts": true, "make_organizer": false},
  "privacy": null, "consent_basis": ""}}
```

`kind` is `dependent_child`, `dependent_elderly` or `dependent_other`. A date of
birth or an age group is required. `dependent_elderly` also needs
`consent_basis`: `agreed` or `authority`. Mobiles are 10 digits starting 6 to 9
and are stored as `+91XXXXXXXXXX`, as on `User`.

An adult's own PATCH accepts `language`, `share_phone`,
`share_contacts_with_organizer` and `location_sharing_consent`.

### Emergency contacts

| Method and path | Who |
|---|---|
| `GET`, `POST circles/<id>/contacts/` | Family list: all read, organizer writes |
| `GET`, `POST .../members/<mid>/contacts/` | One person's list, by policy |
| `PATCH`, `DELETE circles/<id>/contacts/<cid>/` | By policy |
| `POST circles/<id>/contacts/reorder/` | By policy; send every id, in order, plus `member_id` for a person's list |

```json
POST circles/<id>/contacts/
{"name": "Ramesh More", "relationship": "Uncle", "mobile": "9812345678", "method": "whatsapp"}

201
{"status": "success", "data": {"id": "91ab...", "name": "Ramesh More",
 "relationship": "Uncle", "mobile": "+919812345678", "priority": 1, "method": "whatsapp"}}
```

Offline sync uses three optional additions. Each response includes `updated_at`.

- `POST` may include the app's own UUID as `id`. Repeating it returns the first
  record with 200, so a retry can't create a duplicate.
- `PATCH` and `DELETE` may send `If-Match: <updated_at>`. If the contact has
  changed since, the reply is 412 with the current record in `data`.
- Reordering doesn't change `updated_at`, so it never counts as an edit.

### Invitations

| Method and path | Who |
|---|---|
| `GET`, `POST circles/<id>/invitations/` | Organizer |
| `POST circles/<id>/invitations/<iid>/revoke/` | Organizer |
| `GET invitations/mine/` | In-app invitations for this account's number |
| `POST invitations/lookup/` | `{"code": "..."}` or `{"token": "..."}` |
| `POST invitations/accept/` | `{"code": "..."}`, `{"token": "..."}` or `{"invitation_id": "..."}` |
| `POST invitations/decline/` | The same |

Codes always travel in the body, so they stay out of URLs and logs.

```json
POST circles/<id>/invitations/
{"relationship": "spouse", "phone": "9100000022"}

201
{"status": "success", "data": {"id": "5c3e...", "relationship": "spouse",
 "state": "pending", "in_app": true, "expires_at": "2026-11-02T09:12:00Z",
 "created_at": "2026-10-30T09:12:00Z", "code": "K7MPQ2XRN4TW"}}

POST invitations/lookup/
{"code": "K7MP-Q2XR-N4TW"}

200
{"status": "success", "data": {"id": "5c3e...", "family_name": "More Family",
 "organizer_name": "Suresh More", "member_count": 3, "relationship": "spouse",
 "state": "pending", "expires_at": "2026-11-02T09:12:00Z"}}

POST invitations/accept/
{"code": "K7MP-Q2XR-N4TW"}

200
{"status": "success", "data": {"family_id": "7f1c...", "member_id": "ab12..."}}
```

## Admin

Everything is read-only, and staff need view permission for each model. Circles,
memberships, guardians, invitation status and audit logs can be inspected. Names
of people, phones and birth dates aren't shown. `EmergencyContact` and
`MemberPhoto` aren't registered at all.

## App

Routes: `/family`, `/familyCreate`, `/familyJoin`, `/familyMember`,
`/familyMemberForm`, `/familyInvite`, `/familyContacts`, `/familySettings`. The
dashboard entry is one line above the panels.

Screens only offer what `permissions` allows, but the API is what enforces it.
A failed refresh keeps what is on screen. Photos are held in memory only.

Emergency contacts are the one exception to keeping nothing on the device. They
and the minimum needed to reach them (circle name, role and list labels) are in
an encrypted SQLCipher database. See "Offline emergency contacts" below.

## Offline emergency contacts

Code is in `lib/src/modules/family/offline/`.

- `contact_store.dart`: the `ContactStore` interface and its SQL version.
- `encrypted_database.dart`: opens the encrypted database.
- `contact_sync.dart`: `ContactSyncService`, the queue and merge rules.

**Storage.** SQLCipher (AES-256) through `sqflite_sqlcipher`. A random 256-bit
key is created on first use and kept in `flutter_secure_storage`. If the key is
lost, for example after a device restore, the unreadable file is replaced and
the contacts download again.

**Offline changes.** Every change goes to the local database first, with a
state on the row: `pendingCreate`, `pendingUpdate`, `pendingDelete`, `conflict`
or `failed`. These rows are the queue, so repeated edits to one contact collapse
into one request. New contacts get a UUID on the phone.

**Sync** runs when the app starts, on resume, when connectivity returns, when
the screen opens, after each change, and on a backoff timer of 5 seconds up to 5
minutes after a failure. There's no background service. Local changes go first,
oldest first, then the order, then the server list is fetched and merged.

| Result of a queued change | What happens |
|---|---|
| Offline, timeout, 5xx | Kept, retried with backoff |
| 401 | Kept, sync stops until sign-in |
| 400, 403 | `failed`: the user edits it or discards it |
| 412 | `conflict` with the server's copy kept beside the local one |
| 404 on update | `conflict`: deleted elsewhere |
| 404 on delete | Done: it's already gone |

The merge never overwrites a row with a queued change. Rows the server no longer
has are removed only if they have no queued change.

**Testing encryption.** It needs the native library, so it runs on a device:

```bash
flutter test integration_test/contact_encryption_test.dart -d <device>
```

**Conflicts** are shown on the contact, and nothing is resolved silently. "Keep
mine" requeues the local version against the server's current version. "Use
theirs" takes the server's copy. Leaving a family or signing out wipes its local
data, and signing in as a different account wipes the database, including
unsynced changes.
