# Emergency SOS and Notification Centre

An SOS tells a person's family and any registered staff through Kumbh Path.

**It does not call the police, an ambulance or any emergency service.** No such
integration exists. The app says so on every SOS screen, and offers a direct
phone call to 112 instead. `dispatch_integration` in `/api/emergency/me/` stays
false until a real integration exists.

## What was reused

| Need | Comes from |
| --- | --- |
| Devices, push sending | `FCMDevice`, `utils.push_notifications` |
| Preferences | `NotificationPreference`, with two new switches |
| Who to tell | `apps.safety.policy.recipients_for`, across the person's circles |
| Emergency contacts | The encrypted contact store from Offline Emergency Contacts |
| Assistance points | `MeetingPoint`, verified only, plus ambulance and fire categories |
| Responder roles | `SafetyHelper` |
| Location reading | `PositionSource` from Family Location Sharing |

New: `apps/notifications` (the personal record and outbox) and `apps/emergency`.

## Stages are never interchangeable

| Stage | Meaning | Where it's stored |
| --- | --- | --- |
| Saved | The server has the SOS | `EmergencySOS` |
| Notification sent | The provider accepted a message | `NotificationDelivery.state = sent` |
| Reached their app | Their app fetched it | `Notification.delivered_at` |
| Family acknowledged | A relative pressed "I've seen this" | `EmergencyRecipient.acknowledged_at` |
| Responder acknowledged | An authorized user acknowledged it | Status `ACKNOWLEDGED` |

FCM has no delivery receipt for the server, so "Reached their app" is the
closest honest signal. A family acknowledgement never changes the status.

## Lifecycle

```
CREATED > SUBMITTED > FAMILY_NOTIFIED > ACKNOWLEDGED > ASSISTANCE_COORDINATED > RESOLVED > CLOSED
```

- `CREATED` and `SUBMITTED` happen in one transaction.
- `FAMILY_NOTIFIED` happens only once the provider accepts a message. With no
  devices, an SOS stays at `SUBMITTED`.
- `ACKNOWLEDGED`, `ASSISTANCE_COORDINATED`, `RESOLVED` and `CLOSED` need an
  authorized operational user.
- The person can move an active SOS to `CANCELLED`, with a reason. Staff can
  close it afterwards.
- Nothing resolves by itself.

Every step records the previous and new status, the time, the actor and role,
and the reason.

## API

All JWT-protected, with no public endpoints. Anyone without access gets 404.

| Method | Path under `/api/emergency/` | Who |
| --- | --- | --- |
| GET | `me/` | Anyone signed in |
| GET, POST | `sos/` | Your own. `?scope=family` for ones you were told about |
| GET | `sos/<id>/` | Owner, family told, or responder |
| POST | `sos/<id>/cancel/`, `info/`, `location/` | Owner |
| POST | `sos/<id>/acknowledge-family/` | Family told |
| POST | `sos/<id>/contact/` | Family told or responder, active SOS only, audited |

Operations foundation for Phase 7:

| Method | Path |
| --- | --- |
| GET | `ops/sos/?category=&status=&page=`, `ops/sos/<id>/` |
| POST | `ops/sos/<id>/acknowledge/`, `coordinate/`, `update/`, `resolve/`, `close/` |
| POST | `ops/sos/<id>/assign/` (safety staff only) |

Safety staff reach every SOS. A help desk reaches only those assigned to it.
Volunteers, family and pilgrims get nothing.

Notification centre, under `/api/notifications/`: `GET ""`, `GET summary/`,
`POST <id>/read/`, `POST read-all/`.

## Notifications

- SOS messages are critical: they ignore preferences, and there's no switch.
- Lock-screen text holds only a reference. Names and categories appear inside
  the app, behind the login. Android visibility is set to private.
- The payload holds ids. The server checks access when one is opened.
- Each message is a row before it's sent. Failures retry with backoff, up to 6
  attempts, then show as failed. One event reaches one person once.
- Other modules' messages are mirrored into the centre, even if the push was
  muted.

Shared Kumbh updates aren't personal records, so they're marked read as a group.

## Location and privacy

- A position is read once when the SOS is sent, and only if location is already
  allowed. It waits at most 6 seconds, so GPS can't hold up an SOS.
- If location isn't available, the SOS goes without it and the person can
  describe where they are.
- "Send my location again" is one reading. Nothing tracks.
- Family lose the position the moment the emergency ends.
- Coordinates are removed from finished emergencies after
  `EMERGENCY_LOCATION_RETENTION_DAYS` (30).
- A phone number is fetched only to dial it, and each use is audited.

## Offline

If the server can't be reached, the app retries once with the same id, then says
the SOS was not sent and that family haven't been told, and offers 112. The SOS
is saved encrypted on the phone, labelled as not sent, for that account only. It
is never sent by itself: the person must confirm, and it goes out marked with
the time it was written. Sign-out removes it.

Offline, the 112 button and saved emergency contacts still work.

## Settings

| Variable | Default |
| --- | --- |
| `EMERGENCY_NUMBERS` | `emergency:112` (`label:number`, comma separated) |
| `EMERGENCY_LOCATION_RETENTION_DAYS` | 30 |

## Rolling it out

Nothing here has been deployed.

```bash
python manage.py migrate
```

```bash
python manage.py setup_emergency_tasks
```

The migrations only add tables and columns. The task needs the existing Celery
worker and beat, and without it failed sends aren't retried.

## Dependencies

- **Phase 7:** there's no responder screen yet. Staff can only use the API, so
  until Phase 7, nothing can move past `FAMILY_NOTIFIED` except a cancellation.
- **No responders exist:** none were created. Grant `SafetyHelper` roles in the
  admin after checking people.
- **Assistance points:** none exist until staff add them in the Django admin.
- **Contact relay:** there's no call relay, so a call shows the caller's own
  number.

## Testing

```bash
python manage.py test apps.emergency
```

```bash
flutter test test/sos_test.dart
```

`integration_test/sos_live_test.dart` runs on an emulator against a local server
with `API_HOST`, `ASHA_TOKEN`, `SURESH_TOKEN` and `RAVI_TOKEN`. Asha and Suresh
share a family, and Ravi is outside it. Delete the accounts afterwards.

### By hand

1. Phone A: open SOS from the dashboard. Press briefly: nothing happens.
2. Use the countdown, then cancel it: nothing is sent.
3. Press and hold for 2 seconds. Details open, showing each stage separately.
4. Phone B, in the same family: a notification arrives, showing only a reference
   on the lock screen. Open it and press "I've seen this". The status doesn't
   change, and A shows B has seen it.
5. A: send your location again, add information, then cancel with a reason.
6. Turn on airplane mode and send an SOS. It says it wasn't sent. Reconnect and
   reopen the screen: it's still unsent until you confirm.
7. With a safety staff account, call the operations API to acknowledge. Family
   and A see a responder acknowledgement.
8. Turn off every notification switch: emergency stays on and locked.
