# Volunteer Management & Safety Operations

Approved people use the normal Kumbh Path app. The server decides their role on
every request, and the app only follows it.

## Must fix before launch

**SMS sign-in needs credentials.** Development uses the fixed OTP `111111`, which
proves nothing about who is signing in. `config.settings.production` sends real
codes through MSG91, and it needs `KP_SMS_PROVIDER`, `KP_MSG91_AUTH_KEY` and
`KP_MSG91_TEMPLATE_ID`. See [production readiness](production_readiness.md).
Operational and admin accounts never use OTP.

## Roles

There is no separate Role table, so `SafetyHelper`, which already drove every
permission, stays the role record. `User.role` is the website's field and is
unrelated.

| Role | Stored as |
| --- | --- |
| PILGRIM | No `SafetyHelper` row |
| VOLUNTEER | `volunteer` |
| HELP_DESK_OPERATOR | `help_desk` |
| SAFETY_COORDINATOR | `safety_staff` |
| ADMIN | Django superuser, all zones |

| | Volunteer | Help desk | Coordinator | Admin |
| --- | --- | --- | --- | --- |
| Scan QR, report found | Yes | Yes | Yes | Yes |
| Assigned cases | Own only | Own and zone | Zone | All |
| Add sightings and observations, escalate | Assigned | Yes | Yes | Yes |
| Verify and record reunions | No | Zone | Zone | All |
| SOS alerts | No | Zone | Zone | All |
| Assign cases, see team workload | No | No | Zone | All |
| Manage accounts | No | No | No | Django Admin |

Unzoned cases and SOS go to all coordinators, so one with no GPS can't be missed.

## Accounts

1. In Django Admin, open Safety helpers > Add. Enter their phone, name, role and
   zones. The account starts Pending, with no `is_staff`.
2. A one-time setup code appears once. Give it to the person directly. It's
   stored hashed and expires after 48 hours.
3. They choose "Volunteer or staff? Sign in here" on the login screen, enter the
   code and set a password.
4. An administrator checks them and uses the Activate action. Until then, the
   app shows a waiting screen and every operational API refuses them.

Status actions: Activate, Suspend, Deactivate, Reset credentials, Sign out on all
devices. Suspending or deactivating ends sessions and returns open cases.

### Accounts from before this phase

Existing helpers have no password, and OTP is now refused for them. Use Reset
credentials on each one to issue a setup code.

## Zones

`Zone` is the existing table. A case or SOS gets the zone whose radius holds its
coordinates. Zones with no radius can't be matched. Every zone needs a radius,
and every coordinator and help desk needs zones, or they'll see only unzoned or
assigned work.

## Assignment

`CaseAssignment` keeps the history, and `LostFoundCase.assigned_to` remains the
current assignee. Statuses: ASSIGNED, ACCEPTED, IN_PROGRESS, ESCALATED, COMPLETED,
REASSIGNED. A volunteer's task status never changes the case: only staff, through
the existing checks, can confirm a match or a reunion.

## API

Under `/api/operations/`. Sign-in is public and rate-limited. Everything else
needs a token.

| Method | Path | Who |
| --- | --- | --- |
| POST | `auth/setup/`, `auth/login/` | Public |
| GET | `me/` | Anyone signed in |
| PATCH | `me/availability/` | Active helper |
| GET | `overview/`, `zones/`, `cases/` | Active helper |
| GET | `cases/<id>/` | Assignee or operator |
| POST | `cases/<id>/progress/` | Assignee |
| POST | `cases/<id>/observation/`, `escalate/` | Assignee or operator |
| POST | `cases/<id>/assign/`, `unassign/` | Coordinator |
| GET | `cases/<id>/assignments/`, `team/`, `escalations/` | Coordinator |

Reused and extended: `/api/lostfound/ops/...` and `/api/emergency/ops/...` are now
zone-scoped, with `?unassigned=true` and `ops/sos/<id>/escalate/` added.
`/api/safety/scan/...` is unchanged and checks live status.

## Sessions

`User.tokens_valid_after` ends a user's tokens, checked in
`authentication.tokens.KumbhAccessToken`. This adds one small query to each
authenticated API call. Roles are also read live, so losing a role takes effect
on the next request.

## Rolling it out

Nothing has been deployed.

```bash
python manage.py migrate
```

Migrations add tables and nullable columns. One data step marks helpers who were
already inactive as deactivated.

## Testing

```bash
python manage.py test apps.operations
```

```bash
flutter test test/operations_test.dart
```

`integration_test/operations_live_test.dart` needs a local server, and a local
zone, volunteer, coordinator, pilgrim and child case. Delete them afterwards.

### By hand

1. Create a volunteer in Django Admin and note the code.
2. On the login screen, use staff sign-in with the code. The waiting screen shows.
3. Activate them in the admin, then retry. The Volunteer Dashboard appears.
4. As a coordinator, assign them a case in their zone. They get a notification.
5. As the volunteer, accept the case, add an observation and escalate it.
6. Try a phone number for this account on normal OTP login: it's refused.
7. Deactivate them. Their session ends at once, and staff sign-in is refused.
8. Try `/admin/` as the volunteer: it redirects to login.
