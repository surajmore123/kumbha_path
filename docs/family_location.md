# Family Location Sharing

Temporary, chosen location sharing inside a Family Circle. It is not tracking:
every session is started by the person (or a guardian, for a dependent), goes
only to the people chosen, and ends by itself.

## The rules the code enforces

Checked in Django on every request, never only in Flutter.

| Rule | Where |
| --- | --- |
| An adult starts only their own sharing, with `consent: true`. An organizer gets 403. | `policy.can_start_for`, `StartSerializer` |
| A dependent's sharing is started by someone who manages them, and goes only to those responsible. | `policy.can_start_for`, `policy.eligible_viewers` |
| A viewer must be chosen, not revoked, and still eligible, on every read. | `policy.can_view` |
| Outsiders get 404, so they can't tell a session exists. | `_Location.session_for`, `_Family.actor_for` |
| Only the account that started a session can report positions. | `LocationUpdateAPI` |
| Expiry is enforced at every read and write, even if Celery is down. | `services.settle` |
| Stopping or expiring deletes the position in the same step. | `services._end` |
| One position per session, no history. An older fix can't replace a newer one. | `MemberLocation`, `services.record_update` |
| A missing-person report changes none of this. | `CaseLocationAPI`, `policy.py` never looks at cases |
| Coordinates are never logged, audited, sent in a notification or shown in the admin. | `services._notify`, `admin.py` |

A QR scan, a helper role or a staff role gives no access.

## API

All under `/api/location/`, JWT required, no public endpoints.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `circles/<id>/eligible/?member_id=` | Who could be chosen, and the longest share |
| GET, POST | `circles/<id>/sessions/` | Sessions you control; start one |
| GET | `circles/<id>/feed/` | What you may see now, including how often to poll |
| GET | `sessions/<id>/` | One session you control |
| POST | `sessions/<id>/pause/`, `resume/`, `stop/` | Controls |
| POST | `sessions/<id>/recipients/`, `duration/` | Change who or how long |
| POST | `sessions/<id>/update/` | A position, from the phone that started it |
| GET | `cases/<id>/` | Lost & Found: the shared position, only if already allowed |

A refused position returns 410 with the session's status. The app stops
collecting when it sees this.

## Freshness

Worked out from when the phone took the position, never when it arrived, and
the server sends each position's age so a wrong phone clock can't change it.

| State | Meaning |
| --- | --- |
| Live | Taken within `LOCATION_LIVE_SECONDS` (2 min) |
| Updated recently | Within `LOCATION_RECENT_SECONDS` (10 min) |
| Last known location | Older than that |
| Location unavailable | Sharing is on, but no position yet |
| Sharing paused | No position returned at all |
| Sharing expired | Time passed. The app removes the person even with no connection |

Positions are never moved or estimated. With no new data, one simply ages on
screen.

## Settings

Environment variables on the server, all optional.

| Variable | Default |
| --- | --- |
| `LOCATION_MAX_SHARE_HOURS` | 12 (the limit for "Until I stop") |
| `LOCATION_UPDATE_SECONDS` | 30 |
| `LOCATION_DISTANCE_METRES` | 25 |
| `LOCATION_POLL_SECONDS` | 20 |
| `LOCATION_LIVE_SECONDS` | 120 |
| `LOCATION_RECENT_SECONDS` | 600 |
| `LOCATION_STALE_NOTICE_MINUTES` | 30 |
| `LOCATION_SESSION_RETENTION_DAYS` | 7 (ended session records; they hold no position) |

## Rolling it out

Nothing here has been deployed.

```bash
python manage.py migrate familylocation
python manage.py setup_location_tasks
```

The migration only adds tables. The task needs the existing Celery worker and
beat. Without it, sessions still expire on time, but expiry and "not updating"
notifications aren't sent and old records aren't purged.

## Platform configuration

### Android (done in this repository)

- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
- `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`
- `POST_NOTIFICATIONS`, requested when sharing starts

`ACCESS_BACKGROUND_LOCATION` is deliberately not requested. Background updates
come from a foreground service with a visible notification, started while the
app is open, so "Allow all the time" isn't needed.

**Google Play:** declare the location foreground service in the Play Console's
App content section, with a video of the feature, and describe it in the data
safety form. This has to be done by the account holder.

### iOS (configured, not yet tested on a device)

`Info.plist` has `UIBackgroundModes: location` and updated usage text. In Xcode,
confirm **Signing & Capabilities > Background Modes > Location updates** is on.

**App Store:** review asks why background location is needed. The answer is that
a person chooses to share with their family for a limited time, and iOS shows
the location indicator throughout.

## What background sharing can and can't do

- Android: continues when the app is in the background, with a notification.
- iOS: continues in the background with the location indicator, once started
  from the app. While someone is standing still, iOS may send nothing, so
  viewers correctly see the position age.
- Swiping the app away stops collection on both. The session stays open until
  it expires. The app resumes it next time it's opened, if time remains.
- Aggressive battery savers on some Android phones can stop the service. The
  app can't prevent this. Viewers see the position age, and the owner gets a
  notice after 30 minutes without an update.
- A dependent's sharing uses the guardian's phone, because dependents have no
  account. The app says so and asks them to keep the phone with the person.

## Testing

```bash
python manage.py test apps.familylocation
```

```bash
flutter test test/location_test.dart
```

`integration_test/location_live_test.dart` runs the real tracker and GPS against
a local server on an emulator. It needs `API_HOST`, `FAMILY_ID` and
`ASHA_TOKEN`, `SURESH_TOKEN`, `RAVI_TOKEN`, `MEERA_TOKEN` for four members of one
test family. While it runs, something on the host must:

1. grant the location and notification permissions with `adb shell pm grant`;
2. keep moving the emulator with `adb emu geo fix`;
3. press Home after the first position arrives, then reopen the app.

Delete the test accounts afterwards.

### By hand, on two phones

1. Phone A: Family > Family location > Share my location. Choose B, 30 minutes,
   agree, and allow location and notifications.
2. Phone B: open Family location. A appears as Live, with a pin.
3. A: press Home and walk. The notification stays, and B sees the pin update.
4. A: pause. B sees "Sharing paused" and no pin.
5. A: turn off mobile data, walk, then reconnect. B sees one update, not a trail.
6. A: stop. B's pin goes at the next update.
7. With a third family member C who wasn't chosen: C sees nothing of A.
8. Report A missing as B, then have A stop sharing. The case shows no location.
