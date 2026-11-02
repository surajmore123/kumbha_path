# Booking & Stay (Module 4)

A travel assistant, not a booking engine. Pilgrims find stays, reach trusted
providers, and keep their own reservations together. KumbhaPath books nothing and
never says otherwise.

## Implementation plan

**Reused:** the website's `Listing`/`Partner` catalogue (stays extend it, so there's
one source and partner submissions reach the app), `ContentSource`, `ImageRights`,
`Temple`, `JourneyPlan`, `geo.distance_km`, JWT conventions, the public-content cache,
`ContentStore` for offline copies, `context.editorial` and the Module 3 components.

**New backend:** `apps/bookings`. **New app module:** `lib/src/modules/booking/`.

**Sequence followed:** inspect, research providers, design, backend, screens, API
integration, journey link, dashboard link, tests.

## Design direction: the ticket

Travel has its own object, and it carries trust: a paper ticket. Module 3's journal
is about reading; this module is about having what you need in your hand.

- **Ticket shape:** saved bookings are cards with semicircle notches and a perforated
  line, separating what the trip is from its reference number.
- **Numbers lead:** dates, prices and references are set large in the serif, because
  that's what a traveller looks for.
- **Honesty is visible:** every price says whether it's published, an estimate, or to
  be asked. A trust line sits on every stay.
- **Transport isn't one card:** rail reads as a ticket, bus as a route line, flight as
  an airport note, cabs as side-by-side tiles.

**Flow:** Home (search panel over a hero) → Results → Stay detail → provider's site →
back to save the booking. Transport: route form → honest result → provider.
My Bookings: Upcoming and Past → ticket detail → edit.

**Dashboard:** the Plan tab gains a "Stay & travel" link, so the tab strip stays at six.
The Journey's Travel tab links here too, and pre-fills dates and travellers.

## Provider research (2026-10-30)

| Provider | Public API? | Access | Live search or booking in this app? |
| --- | --- | --- | --- |
| IRCTC (train) | None found | Accredited agents, through a formal agreement or principal service provider | No. Opens IRCTC |
| NTES (train info) | None found | None | No. Opens NTES |
| MSRTC (bus) | None found. API shared with IRCTC under an MoU | Direct request, unconfirmed | No. Opens MSRTC reservation |
| redBus | None public | Partner only | Not added |
| Flights: Amadeus | Yes, self-service | Production approval; booking needs a consolidator agreement and may be limited by country | No. Needs your account |
| Stays: Booking.com | Yes, Demand API | Approved Managed Affiliate only, under contract | No |
| Uber | Deep links are documented | Pre-filled links need a `client_id` | Opens the website only |
| Ola | None found | Unknown | Opens the website only |
| Official pilgrim stay portal | **None announced** | The authority sought accommodation aggregators; tender closed about 28 Oct 2026 | Watch this: it's the likely official route |

Sources: IRCTC agent norms, IRCTC–MSRTC MoU filing (BSE), Amadeus and Booking.com
developer docs, Uber deep-linking docs. Where a claim came from a reseller, it isn't used.

Commercial API sellers advertising "IRCTC APIs" were not treated as authorized: their
status couldn't be confirmed.

**Adding a provider:** implement `TransportAdapter` in `apps/bookings/adapters.py` and
add it to `ADAPTERS`. Results then appear with `live: true`. A failing provider is
skipped and reported, and never guessed.

## API (`/api/bookings/`)

Public and read-only:

| Path | Purpose |
| --- | --- |
| `stays/` | `q`, `type`, `area`, `min_price`, `max_price`, `amenity` (repeatable), `family`, `seniors`, `accessible`, `available`, `near` or `lat`+`lng`, `radius_km`, `sort=recommended\|price\|distance`, `page` |
| `stays/filters/` | Areas, amenities, types in use |
| `stays/<id>/` | Rooms, images, landmarks, nearest temples, policy text, sources |
| `transport/` | `mode` |
| `transport/<slug>/` | One provider |
| `transport/search/` | `from`, `to`, `date`, `mode`, `passengers`. Returns `live`, `results`, `providers` |

Login required; every lookup is limited to your own records:

| Path | Purpose |
| --- | --- |
| `saved/` | GET (`status`, `category`, `when=upcoming\|past`), POST |
| `saved/<id>/` | GET, PATCH, DELETE |

Example, an honest search:

```
GET /api/bookings/transport/search/?from=Pune&to=Nashik&mode=train
{"status": "success", "data": {"live": false, "results": [], "failed_providers": [],
 "providers": [{"slug": "irctc", "name": "IRCTC", "can_book": true, ...}]}}
```

## Rules enforced

- A stay shows only if its Listing is published, isn't a website sample, and hasn't expired.
- A stay with no published price never matches a budget filter, and sorts last.
- "Available" needs provider confirmation on a verified stay.
- Only verified stays can be published from the admin action.
- Property photos need rights. Otherwise a labelled area photo is shown.
- Saved bookings refuse anything that passes the card-number check, and hold no
  CVV, password or OTP fields.
- Booking links must be https. Saved bookings aren't visible in admin lists.

## Setup

```bash
python manage.py migrate website
```

```bash
python manage.py migrate bookings
```

```bash
python manage.py seed_bookings
```

`migrate website` was needed locally because those tables hadn't been created. It adds
tables only. The seed needs Module 3's images, adds only what's missing and loads
drafts unless given `--publish`.

**Environment variables:** none new.

## Remaining work

- **Content:** two stays are seeded. Only Shivprasad Bhaktniwas has official rates;
  MTDC Grape Park is marked unverified. Both need property photos and coordinates,
  and distances stay hidden until coordinates are added.
- **Tent cities:** the authority's rules were still being prepared in September 2026.
  None is listed.
- **Credentials or approval needed:** IRCTC, MSRTC, Amadeus, Booking.com, Uber `client_id`.
- **Attachments** on saved bookings aren't built. Secure private storage needs a decision.
- **Journey references:** the Journey's own booking notes stay separate from My Bookings.
  Merging them is a product decision.
- **Central Kumbh Map** link waits for that module.
