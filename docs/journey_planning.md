# Plan Your Kumbh Journey (Module 1)

Lets a pilgrim plan a visit to the Nashik–Trimbakeshwar Simhastha Kumbh 2027.
They can save several plans, get a suggested day-by-day itinerary around the
published bathing days, keep a checklist and their own booking details, and
share the plan as text.

## What it does and doesn't do

| Does | Doesn't |
| --- | --- |
| Suggests an itinerary from real temples and events in the KumbhaPath database | Invent schedules, routes, fares, crowd forecasts or restrictions |
| Links to official transport, tourism and authority sites (each with a check date) | Book tickets or rooms, or show availability. No public booking APIs exist |
| Stores booking details the user types, labelled as their own | Claim that a booking exists or is confirmed |
| Splits the user's own budget by planning shares (labelled as an assumption) | Estimate prices |
| Lists stay *categories* with practical guidance | List, rate or endorse specific properties |
| Works in English, Hindi and Marathi, in light and dark themes, at all font scales | Take payments or store card data |

## User flow

1. **Entry:** the dashboard has a **Plan** tab, first in the Explore panel. Crowd
   stays selected by default. The tab shows the next planned journey, or a
   "Plan My Journey" call to action. "My journeys" opens `/journeys`.
2. **`/journeyForm`:** four steps.
   - About the trip: name, starting city and state.
   - Dates: arrival and departure, or "not fixed yet" with a number of days. Dates can be marked flexible.
   - Travellers: adults (at least 1), children and seniors, up to 50 in total. Accessibility needs.
   - Preferences: transport, stay type, interests, budget (total or per person), food needs, notes.

   "Save draft" needs only a name. "Create my plan" saves the plan and
   generates the itinerary. In edit mode the form is prefilled. After saving,
   the app offers to update the suggestions.
3. **`/journeyDetail`:** five tabs.
   - **Itinerary:** days with suggested and own activities. You can tick, edit, move up or down, move to another day, delete, or add activities.
   - **Checklist:** grouped by category. You can tick, add and delete items.
   - **Travel & stay:** your own booking details (add, edit, delete), official transport links with your chosen mode first, stay categories and official tourism links.
   - **Budget:** the planning split of your budget, or a prompt to add one.
   - **Info:** important dates from the events database (the ones during your trip are marked), helpful contacts (tap to call), and when the information was last checked.

   The menu has Edit, Update suggestions (with confirmation; your own and edited
   items are kept), Duplicate, Mark completed or Mark planned, and Delete (with
   confirmation). The share button sends the exported text through the system
   share sheet.
4. **`/journeys`:** tabs for Upcoming (planned), Drafts and Completed, each
   paged with "Load more". Pull to refresh. A "New plan" button.

## Itinerary rules (backend `apps/journeys/planner.py`)

The planner is deterministic and rules-based. It makes no LLM calls.

- **Recommended length:** 3 days. Add 1 day for akhadas or spiritual learning,
  and 1 more for seniors or accessibility needs.
- **Bathing days:** published `SNAN` events in the trip become a "sacred bath"
  day with an early start and a rest afterwards.
- **Temples:** Trimbakeshwar gets a day of its own. Nashik temples are ordered by
  distance from Ramkund.
- **Pace:** gentler for seniors, children and accessibility needs. The
  departure day has nothing else on it.
- **Regenerating:** keeps every item the user added or edited. Items kept from
  days that no longer exist move to the last day. Ticked and user-added
  checklist items are kept.

## Data sources (checked 2026-10-29)

The source list lives in `apps/journeys/guide.py` (`SOURCES`, `CHECKED_ON`).
Unreachable links stay listed, but are flagged "Couldn't be checked" in the
app:

- **Reachable:** nashikkumbha2027.com, NTES, indianrail.gov.in, MSRTC and its
  reservation site, AAI Pune, Maharashtra Tourism, MTDC, Trimbakeshwar Trust,
  Nashik Municipal Corporation. The PIB release (25 Jul 2025) on the five Nashik
  stations is also reachable.
- **Not verifiable from the build machine:** IRCTC (timeout), divcomnashik
  (DNS), 112.gov.in (connection refused).
- **Contacts:** 112, plus the Kumbh Mela Authority office number and email as
  published on the official portal.

Important dates come from the events table (`SNAN`, `KUMBH_LIFECYCLE`). Each
date's "updated" stamp is that row's `updated_at`.

> **Data issue to fix in the events table (not changed by this module):**
> - "Second Amrit Snan" is stored as 2027-09-12, but the published date is 31 Aug.
> - The 11 Sep bath is missing.
> - Two "demo" events are published.
>
> Until this is fixed, the Info tab and the generated bathing days show these
> values.

## API (`/api/journeys/`, JWT required)

The owner always comes from the token. Another user's objects return 404.

| Method | Path | Purpose |
| --- | --- | --- |
| GET / POST | `` | List (`status`, `ordering`, `page`); create (`?generate=true`) |
| GET / PATCH / DELETE | `<id>/` | Plan detail with days, checklist, references, budget split |
| POST | `<id>/generate/` | Build or rebuild suggestions (`language` optional) |
| POST | `<id>/duplicate/` | Copy (references not copied; checklist unticked) |
| GET | `<id>/export/` | Plain-text itinerary `{text}` |
| POST | `<id>/items/` | Add an activity (`day_number`, `title`, …) |
| PATCH / DELETE | `<id>/items/<item>/` | Edit, move (`day_number`), tick, delete |
| POST | `<id>/days/<n>/reorder/` | `{item_ids: [...]}`, the day's full new order |
| POST, PATCH / DELETE | `<id>/checklist/`, `<id>/checklist/<item>/` | Checklist |
| POST, PATCH / DELETE | `<id>/references/`, `<id>/references/<ref>/` | User's own booking details (https links only) |
| GET | `guide/?language=` | Transport, stay, contacts, important dates, sources |

**Limits:**
- 20 plans per user, 15 days per plan and 50 travellers.
- 40 items per day, 100 checklist items and 30 references.
- Budget up to ₹1 crore; notes up to 4,000 characters.

**Migration:** `journeys/0001_initial` only creates new tables and doesn't
touch existing data.

## App code

`lib/src/modules/journey/`:

- `models/journey_models.dart`: parses responses and drops malformed or
  non-https values.
- `data/journey_repository.dart`: `JourneyRepository` plus the HTTP
  implementation.
  - The token goes in the `Authorization` header, never in the URL, and responses aren't logged.
  - Errors are typed as offline, unauthorized, not found, invalid or server.
  - Tests swap `JourneyServices.repository`.
- `journey_controllers.dart`: list paging and the detail actions. Every change is
  saved first, then the screen shows the saved copy.
- `journeys_screen.dart`, `journey_form_screen.dart`, `journey_detail_screen.dart`,
  `widgets/`.

## Tests

- **Backend:** `apps/journeys/tests.py` (22 tests).
  - Covers CRUD, owner from the token, validation and DB constraints, and other users getting 404 everywhere.
  - Also covers generation from real temples and bathing days, hi and mr text, regeneration that keeps edits, reordering, checklist, references, budget, duplicate, export, guide, and editing a trip already under way.
- **App:** `test/journey_test.dart` (48 tests) with `test/journey_fakes.dart`.
  - Covers model parsing, the HTTP client (header, error mapping, offline, signed out, 204), form steps and validation, draft, edit, list paging and retry, and every detail action and tab.
  - Also covers the dashboard panel, and no overflow in en, hi and mr, light and dark, at 1.6× text and 320 dp.
  - `test/dashboard_test.dart` checks the Plan tab's links and the five-tab strip.
