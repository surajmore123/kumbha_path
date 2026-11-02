# Digital Safety QR

Backend: `apps/safety` in `kumbha_Backend`. App: `lib/src/modules/safety/`.

## What it does and doesn't do

Each family member can have a card with a QR. If they're separated, a registered
helper scans it, confirms what's happening, and the family gets an in-app alert.

It's a card, not an identity. A scan doesn't prove who is holding it, and doesn't
prove who a guardian is. Nothing here marks anyone as missing, identifies faces,
or is connected to the police or the Kumbh administration.

## Tokens

The QR holds `https://kumbhapath.in/safety/qr#t=<token>` and nothing else.

- `token = HMAC-SHA256(SAFETY_QR_SECRET, salt)`, base64url. The salt is 256 random
  bits, unique to each identity.
- The database holds the salt and `SHA-256(token)`, never the token. A copy of the
  database alone gives no working token.
- Deriving the token means guardians on different phones see the same QR.
- The token is after `#`, so an ordinary camera opening it sends nothing to a
  server. It lands on a static page telling the finder to go to a help desk.
- Changing `SAFETY_QR_SECRET` stops every QR working, and the API answers 409 until
  a new one is generated. **Set it once in production and keep it.**

## Who can do what

Rules are in `apps/family/policy.py` (`can_view_qr`) and `apps/safety/policy.py`.

| Action | Result |
|---|---|
| Own QR | Yes |
| A dependent's QR | Their guardians and the organizer |
| Another adult's QR | No, including the organizer |
| Someone outside the family | 404 |
| Scanning | Only an active `SafetyHelper`. Everyone else gets the same 403 before the token is read, so a scan can't test whether a token is real |

**A helper sees** first name, category (child, elderly, adult or other), language,
and references of open reports. Never a surname, number, birth date, photo or family.

**Alerts reach** a dependent's guardians and the organizer, or an adult's family
(not the adult). **The family sees** the helper's role, never who they are.

**Location** is the helper's, sent once if they turn it on. A dependent's guardians
see it. For an adult, the family sees it only if that adult turned on the setting in
their profile (`location_sharing_consent`). Otherwise the alert says it was withheld.

**Contact relay:** no phone number is ever returned. The family hears through the
app and acknowledges there, and the helper sees that they have. There's no call
relay yet: that needs a telephony provider.

## Scanning

1. `POST scan/resolve/` with the token. It's logged, and returns a `scan_id`.
2. The helper checks in person and picks a situation.
3. `POST scan/<scan_id>/confirm/` with `confirmed: true`. It works for 15 minutes,
   only for the helper who scanned.

A scan alone creates nothing. "Incorrect or suspicious" is recorded for review and
doesn't tell the family. One open alert exists per person and situation, enforced by
the database, so repeated scans return the first with `duplicate: true` and don't
notify again.

The response's `delivery` is `sent`, `no_devices` or `unavailable`, and the app shows
that. `sent` means a push reached a device, not that someone read it.

## API

Under `/api/safety/`, JWT required. Responses use the usual `{"status", "data"}` form.

| Method and path | Purpose |
|---|---|
| `GET circles/<fid>/members/<mid>/qr/` | The active QR, or `data: null` |
| `POST circles/<fid>/members/<mid>/qr/` | Returns it, creating it if needed (201 if created) |
| `POST .../qr/regenerate/` | Replaces it. The old one stops working |
| `POST .../qr/revoke/` | Turns it off |
| `GET helper/me/` | `{"is_helper", "role"}` |
| `POST scan/resolve/` | Helper only. 404 unknown, 410 revoked or expired |
| `POST scan/<scan_id>/confirm/` | `situation`, `confirmed`, optional `note`, `latitude`, `longitude` |
| `GET helper/alerts/<id>/` | A helper's own report |
| `GET circles/<fid>/alerts/` | Alerts this person may review |
| `POST circles/<fid>/alerts/<id>/acknowledge/` | Family has seen it |
| `POST circles/<fid>/alerts/<id>/resolve/` | Closes it |

Scanning allows 120 requests an hour per user, and QR changes 30. Limits use Django's
cache, which is per process unless a shared cache is configured.

```json
POST scan/resolve/
{"token": "..."}

200
{"status": "success", "data": {
  "scan_id": "0f3c...", "first_name": "Aarav", "category": "child", "language": "mr",
  "open_alerts": [], "valid_seconds": 900}}

POST scan/0f3c.../confirm/
{"situation": "separated", "confirmed": true, "note": "East gate help desk"}

201
{"status": "success", "data": {
  "id": "7ab1...", "reference": "KP-7H2MQX4R", "kind": "separated", "status": "open",
  "delivery": "sent", "created_at": "2026-11-01T10:12:00+05:30",
  "family_acknowledged": false, "duplicate": false}}
```

## Helpers

Scanning is granted only in Django Admin > Safety > Safety helpers. Add a helper only
after checking the person yourself: there's no self-registration, and no accounts are
created by this code. The later Safety Operations Dashboard should take this over.

## Settings

| Variable | Purpose |
|---|---|
| `SAFETY_QR_SECRET` | Required in production. A long random value, separate from `SECRET_KEY` |
| `SAFETY_REQUIRE_HTTPS` | Defaults to on when `DEBUG` is off. Needs nginx to send `X-Forwarded-Proto: https`, or every request is refused |

## Testing

Run the tests:

```bash
python manage.py test apps.safety
```

```bash
flutter test test/safety_test.dart
```

To test by hand:

1. Migrate and start the backend, with the app's `.env` pointing at it.
2. In the app, open Family Safety and tap **Safety QR**.
3. Create a card for yourself or a dependent, then save, print or share it.
4. In Django Admin, add a Safety helper for a second account.
5. Sign in as that account. **Helper scanner** appears on the Family Safety screen.
6. Scan the card, choose a situation and confirm.
7. As the first account, open **Safety alerts**, acknowledge it, then resolve it.

Scanning needs a real phone or an emulator with a camera feed. The live test covers
everything except the camera, and needs an organizer and a helper access token:

```bash
flutter test integration_test/safety_live_test.dart -d emulator-5554 --dart-define=API_HOST=10.0.2.2:8000 --dart-define=ORGANIZER_TOKEN=... --dart-define=HELPER_TOKEN=...
```
