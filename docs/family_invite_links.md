# Family invitation links

A link looks like `https://kumbhapath.in/join/family#t=<token>`.

- The token is 256 random bits. Only its SHA-256 hash is stored.
- It sits after `#`, which browsers never send to a server, so it can't reach
  Cloudflare or nginx logs.
- The web page has no script and never sees family details.
- Details are only returned by `POST /api/family/invitations/lookup/`, which needs
  a signed-in user. Tokens always travel in request bodies.
- One invitation has a link and a short code. Accepting, declining, revoking or
  expiry ends both.
- A link holder gets 410 with `state` (`expired`, `revoked`, `accepted`, `declined`)
  and no family details. Unknown tokens and short codes get 404. Lookups allow 20
  requests an hour per user.
- An invitation made for a phone number only works for that account, by link too.

## App

`lib/src/modules/family/invite_links.dart` holds the checks and the routing.

1. `app_links` delivers the address, including at a cold start.
2. `parseInviteLink` accepts only `https://kumbhapath.in/join/family`. Anything else
   is ignored.
3. If the dashboard is on screen, `/familyJoin` opens. Otherwise the token waits in
   secure storage and opens after sign-in, then is removed. Signing out removes it.
4. The person reviews the family and what's shared, then joins or declines.

Release builds strip `Log.v`, `Log.d` and `Log.i` (`android/app/proguard-rules.pro`),
because `app_links` logs every address it receives. **Debug builds still log the
link.** Never call url_launcher's `canLaunchUrl` with an invitation address: it logs
it. `InviteSharer.open` just tries, and falls back.

## Sharing

`widgets/invite_share_sheet.dart` offers WhatsApp, SMS, other apps and Copy link. The
message is handed to the chosen app and the organizer sends it. Kumbh Path sends
nothing itself and uses no paid messaging service.

A new link is only available right after creating the invitation, because only its
hash is stored. Before sharing, the app checks that the invitation is still open. If
WhatsApp or SMS isn't available, the system share sheet opens instead. If that fails
too, the link is copied.

Deployment is covered in `deploy/kumbhapath-web/README.md` in the backend repo.

## Testing locally

```bash
flutter test test/invite_links_test.dart
```

Android's domain check can't pass until the live file exists, so approve the domain
by hand on a test device or emulator:

```bash
adb shell pm set-app-links-user-selection --user 0 --package com.example.kumbha_path true kumbhapath.in
```

Then open a link. Create a real one in the app first to see the review screen:

```bash
adb shell "am start -W -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d 'https://kumbhapath.in/join/family#t=PASTE_TOKEN'"
```

To run the real client against a local backend, create two test accounts, make an
access token for each, start the server, and run:

```bash
EXTRA_ALLOWED_HOSTS=10.0.2.2 python manage.py runserver 0.0.0.0:8000
```

```bash
flutter test integration_test/invite_link_live_test.dart -d emulator-5554 --dart-define=API_HOST=10.0.2.2:8000 --dart-define=ORGANIZER_TOKEN=... --dart-define=GUEST_TOKEN=...
```

On iOS, simulators can't verify domains without a signed build. Use a real device
with the Team ID configured.
