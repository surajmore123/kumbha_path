# Family Reunification Map

Helps a separated family find each other safely. It brings together the Family
Circle, Live Location Sharing and Lost & Found, and adds safe meeting points and
routes. It holds no copy of anyone's position or case: those stay in
`apps.familylocation` and `apps.lostfound`, under their existing rules.

Kumbh Path isn't an official Kumbh, police or government system. Nothing here is
integrated with one.

## What was reused, and what's new

| Need | Comes from |
| --- | --- |
| Family positions, consent, freshness | `/api/location/.../feed/`, unchanged |
| Case access, last-seen, sightings, approved updates | `apps.lostfound.policy`, `FamilyCaseSerializer` |
| Notifying family and staff | The Lost & Found outbox, plus one new `meeting_point` message |
| Verification and reunion | `verify_case`, `record_reunion`, and the existing operations screen |
| Map | `AppMap` |

New in `apps/reunification`:

- `MeetingPoint`: a place, its category, how far it's verified, and its source.
- `ReunificationPlan`: the chosen point and arrivals for one case.

## API

All under `/api/reunification/`, JWT required, no public endpoints.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `overview/?family_id=` | Your open family cases, and whether you need protected guidance |
| GET | `points/?category=&verified=&page=` | Public points, and your family's private ones |
| POST | `circles/<id>/points/` | Add a private family spot |
| DELETE | `points/<id>/` | Remove a private spot |
| POST | `points/<id>/suggest/` | Offer a private spot to staff |
| POST | `circles/<id>/notify/` | Notify your family, optionally with a point id |
| GET | `cases/<id>/` | A case as the map's details screen shows it |
| POST | `cases/<id>/guidance/` | Recommended places, safest kind first |
| POST | `cases/<id>/meeting-point/` | Choose the meeting point |
| POST | `cases/<id>/coordination/` | Record an arrival, or a staff update |
| POST | `route/` | A walking route to a point or a permitted family member |

Positions always travel in a request body, never in a URL.

## Meeting points

There is deliberately no seed data. The map says so until staff add real places.

| Status | Who sees it | Shown as |
| --- | --- | --- |
| `family` | That family | Private to your family |
| `suggested` | That family | Private, waiting for staff |
| `community` | Everyone | Community suggestion, not verified |
| `verified` | Everyone | Verified by Kumbh Path staff |
| `verified` + official source | Everyone | Verified, official source |
| `retired` | Nobody | |

Families can only create `family_meeting` spots, so nobody can label a place as
a police booth or help desk. Verifying needs a named source, which the database
enforces, and records who did it and when.

**Staff manage points in the Django admin**, under Reunification > Meeting
points: add a place, enter its source, and save it as verified. List actions
review suggestions in bulk.

## Children and vulnerable people

A case is protected if it has any vulnerability, a child or elderly found
category, a dependent member, or an age under 18.

- Only verified, staffed points can be recommended, chosen or routed to for that
  case. The server enforces this.
- Places rank by kind first (Lost & Found, help desk, emergency, police, then
  medical), and distance only decides within a kind. A medical need puts medical
  first.
- Someone who is protected gets no route to family at all. That covers a child's
  own account, a person with a protected open case, and a phone reporting a
  missing dependent. They see instructions to go to staff and stay there.
- A relative going to a protected person gets a caution: ask them to stay put,
  and don't ask them to walk to you.
- Arriving, being close on the map, or a QR scan proves nothing. Only staff can
  record a reunion, through the existing checks, and for a vulnerable person
  they must confirm the person recognised the family and is willing to go.

## Routing

Walking routes come from Google's Routes API through the server, so the key
stays off the phone and every destination is re-checked for permission. Distance
and time appear only when the provider returns them.

**Required:** set `GOOGLE_ROUTES_API_KEY` on the server, for a key with the
Routes API enabled. Restrict it to that API and to the server's IP.

The Maps key currently in the app can't be used: Google refuses it for the
Routes API (`API_KEY_SERVICE_BLOCKED`). Without a working key, Route Preview says
a preview isn't available and offers Google Maps, which works.

Distances in the meeting-point list are straight-line, worked out on the phone,
and labelled that way.

## Offline

| Situation | What happens |
| --- | --- |
| No connection | Last answers stay on screen, labelled with the last update time |
| Public help points | Saved on the phone with the date, and shown as possibly out of date |
| Private spots, positions, cases | Held in memory for this run only |
| Family position | Ages on screen, and leaves when its session's time passes |
| Earlier route | Shown dashed, with its time, as not refreshable |
| Sharing ended or access lost | Any kept route is dropped |
| GPS unavailable | Explained, and Google Maps offered |
| One source fails | The others still show |

Offline maps and offline navigation aren't implemented. Map tiles need a
connection.

## Contact relay

No call relay exists. "View family member" opens the existing profile, which
shows a phone number only if that person allowed it. Help points can publish a
public number.

## Rolling it out

Nothing here has been deployed.

```bash
python manage.py migrate reunification
```

The migration only adds tables. Phase 4's `setup_location_tasks` should also be
in place.

## Testing

```bash
python manage.py test apps.reunification
```

```bash
flutter test test/reunion_test.dart
```

`integration_test/reunion_live_test.dart` runs on an emulator against a local
server with no routing key. It needs `API_HOST`, `FAMILY_ID`, `CASE_ID`,
`ASHA_TOKEN`, `SURESH_TOKEN` and `RAVI_TOKEN`, and local records for: a child's
open case in that family, two approved sightings, two verified points and one
community point. Delete those records afterwards.

### By hand

1. In the Django admin, add a help desk with a source and save it as verified.
   Add a community suggestion with no source.
2. Phone A: open Reunification map from the dashboard. Both appear, labelled
   differently. The key explains the markers.
3. Share B's location with A. B appears with its freshness. Stop sharing: B goes.
4. Report a child missing as A. The safety banner appears. Open the details: only
   verified places are offered, and choosing one notifies staff.
5. Tap Get walking route. With no key, Google Maps is offered and no distance is
   shown.
6. Tap We've arrived. The stage changes and the case status doesn't.
7. As staff: record the person arriving, send an update, then verify and record
   the handover from the operations screen. Only then does it show Reunited.
8. Sign in as someone outside the family: nothing appears, and the case gives 404.
