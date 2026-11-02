# Lost & Found

Backend: `apps/lostfound`. App: `lib/src/modules/lostfound/`.

Kumbh Path helps families and registered helpers coordinate. It is not a police or
government system, and the app says so wherever someone reports. There's no public
list: only the people below can reach a case, and anyone else gets 404.

| Person | What they can reach |
|---|---|
| Reporter | Their own report |
| Family | A case linked to their circle: guardians and organizer for a dependent, the circle for an adult |
| Volunteer, help desk | Found reports they filed: reference, status and safe place only |
| Help desk | Cases assigned to them, through `ops/` |
| Safety staff | All cases, through `ops/` |

Roles are `SafetyHelper` records, granted only in Django Admin. `safety_staff` is new in
this phase. No accounts are created by this code.

## Lifecycle

```
SUBMITTED → UNDER_REVIEW → VERIFICATION_REQUIRED → POTENTIAL_MATCH_FOUND
                                    ↓                       ↓
                             MATCH_CONFIRMED  ←─────────────┘
                                    ↓
                                REUNITED → CLOSED
```

Most stages can also move to `CLOSED` or `REJECTED`, and those can reopen to
`UNDER_REVIEW`. The full table is `TRANSITIONS` in `services.py`.

- Every change writes `CaseStatusHistory`: from, to, who, when and why.
- `CaseStatusHistory` and `CaseAudit` refuse edits and deletion in the app.
- The ordinary status route can't reach `MATCH_CONFIRMED` or `REUNITED`.
  - `MATCH_CONFIRMED` needs a reviewed match or a linked family, plus a recorded check.
  - `REUNITED` needs a confirmed match, an identity check, and for a child or vulnerable
    person, confirmation that they recognised the guardian and are willing to go.
- A family saying "we've found them" only tells staff. It changes no status.

## Matching

`matching.py`. Scores out of 100: clothing 30, age 25, description 20, distance 15,
time 10. A pair needs 35 points from at least 2 signals, and a signal with nothing to
compare is skipped. Colours and common clothing words in Hindi and Marathi fold into
English so that reports can be compared across languages.

Not used: names, gender, faces, photographs. No AI is used. The score only orders
staff review. It changes no case, and it's never shown to families. Each match stores
which attributes contributed.

Staff approve a suggestion ("worth checking"), optionally telling the family a lead is
being checked, then confirm it only after an in-person check. Dismissed matches aren't
overwritten when matching runs again.

## Digital Safety QR

When a helper confirms a scan, `apps.safety` sends the `alert_confirmed` signal and
`receivers.py` calls `case_from_alert`:

- A scan alone creates nothing, and a suspicious scan opens no case.
- It opens one found case linked to the member and family, or adds a sighting to the
  open one, so repeated scans can't stack up.
- If a lost report is open for that member, it adds a match for staff to review. It
  doesn't confirm it, because a card doesn't prove who is holding it.
- The family was already told by the safety alert, so the receiver sends nothing more.
- A failure here can't undo the safety alert.

## Notifications

`CaseNotification` is an outbox. A row is written with the change, sent after commit,
and a key stops one event reaching a person twice. Failed sends retry with backoff up
to 5 attempts. To schedule that:

```bash
python manage.py setup_lostfound_tasks
```

Text is generic and names nobody, because it shows on a lock screen. It uses the
existing `safety_alerts` preference, so someone who turned that off gets no push but
still sees updates in the app. The push carries a case id; the server checks access when
the app opens it.

## Privacy

- Photos are in the database, never `/media/`, and are served through a permission
  check with `no-store`. They're re-encoded to JPEG, which removes GPS and camera data.
- An adult's location reaches their family only with their consent, as in Phase 2.
- A reporter's number isn't in any case response. It has one route, staff only, and
  every read is audited.
- Family views leave out internal notes, staff names, reasons, matches and unreviewed
  sightings. Sightings say whether they're community-reported, helper-reported or verified.
- Coordinates are one-off reports. The app says this isn't live tracking.
- Pushes, logs and the admin hold no names, numbers, descriptions or locations.

## Offline

Reports are saved at each step to the encrypted SQLCipher database (schema version 2
adds `lf_drafts`). Sending uses the draft's id as `client_id`, so retrying after a lost
reply can't create a second case. A draft sends itself when the network returns. The app
says "not submitted yet" until the server has confirmed it. Sign-out and a change of
account wipe drafts. Viewing a case needs a connection.

## API

Under `/api/lostfound/`, JWT required, in the usual `{"status", "data"}` form.

| Method and path | Who |
|---|---|
| `GET me/` | Anyone: role and what they can do |
| `GET, POST cases/` | Own cases. POST is a missing-person report |
| `POST found/` | Helpers |
| `GET cases/<id>/` | Family view, or the helper's short view |
| `POST cases/<id>/info/`, `correction/`, `confirm-reunion/` | Family side |
| `POST cases/<id>/cancel/` | The reporter |
| `POST cases/<id>/sightings/` | Anyone with access |
| `POST cases/<id>/attachments/` | Anyone with access. Multipart `photo`, optional `client_id` |
| `GET attachments/<id>/` | Anyone with access |
| `GET ops/cases/` | Filters: `type`, `status`, `q` (exact reference), `mine`, `page` |
| `GET ops/cases/<id>/` | Staff, or assigned help desk |
| `POST ops/cases/<id>/status/`, `notes/`, `contact/`, `find-matches/`, `verify/`, `reunite/` | Staff, or assigned help desk |
| `POST ops/cases/<id>/assign/` | Staff |
| `POST ops/sightings/<id>/review/` | Staff, or assigned help desk |
| `GET ops/matches/`, `POST ops/matches/<id>/approve/`, `dismiss/`, `confirm/` | Staff |

## Testing

```bash
python manage.py test apps.lostfound
```

```bash
flutter test test/lostfound_test.dart
```

The live test needs a parent, a volunteer and a safety staff access token:

```bash
flutter test integration_test/lostfound_live_test.dart -d emulator-5554 --dart-define=API_HOST=10.0.2.2:8000 --dart-define=PARENT_TOKEN=... --dart-define=HELPER_TOKEN=... --dart-define=STAFF_TOKEN=...
```
