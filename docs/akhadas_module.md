# Akhadas & Sadhus (Module 2)

An educational, sourced directory of Akhadas, saints and traditions, with a
separate section for what's been announced for Nashik–Trimbakeshwar 2027.
Content is written and published in Django admin, without code changes.

## Research summary (checked 2026-10-30)

- **What an Akhada is.** Official Kumbh publications trace the word to "akhand"
  (indivisible) and describe orders joining scripture with martial training.
- **The 13.** Seven Shaiva, three Vaishnava, and three usually counted together:
  Bada Udasin, Naya Udasin and Nirmal. Nirmal is a separate tradition.
- **Nashik.** Vaishnava and Shaiva Akhadas bathe separately. Scholars date this to
  an 1789 clash, after which the Peshwa moved the Vaishnava bath to Ramkund.
- **Amrit Snan.** Reported dates are 2 Aug, 31 Aug, 11 Sep (Nashik) and 12 Sep
  (Trimbakeshwar) 2027. The name replaced Shahi Snan at the June 2025 meeting.

### Where sources conflict, and what the app does

| Topic | Conflict | Handling |
| --- | --- | --- |
| Origin of Akhadas | PIB says 6th century; Britannica dates Shankara to the 8th | States the disagreement on his profile; gives no founding date |
| Founding years, headquarters | Reference sites disagree | Left blank; Nirmal (1862) is the only date stated, and Naya Udasin notes the dispute |
| Sect of Mahanirvani and Atal | Wikipedia's *Akhara* article lists them as Vaishnava; ABAP counts, PIB and ANI do not | Treated as Shaiva |
| Akhara Parishad head | Rival factions in June 2026, both led by a "Mahant Ravindra Puri" (Mahanirvani and Niranjani) | Neither is named as head |
| Second bath date | The existing events table disagrees with reports (see below) | Activities use the reported dates |

**Sources** are stored as `ContentSource` records and shown on each page. The full
list is in `apps/akhadas/seed_directory.py`. Three kinds need a human re-check,
and each record's `verification_notes` says which applies:

- Britannica, kumbh.gov.in (one page), Sarkarnama (land) and Deccan Herald block
  automated reading, so they were checked through search excerpts.
- Jacobsen (2008) and Lochtefeld (2009) are cited through Wikipedia's references.
  The books weren't read.
- The nashikkumbha2027.com site publishes nothing yet on Akhadas or dates, so
  **no activity is marked "Officially confirmed"**.

## Editorial workflow (Django admin, section "Akhadas")

| Task | Where |
| --- | --- |
| Add or correct an Akhada, profile or article | Its admin page; language tabs are the inline rows |
| Add a source | *Content sources*, then attach it to the record |
| Publish or unpublish | List page actions, or the status field |
| Mark checked | Action "Mark verified today" sets the status and date |
| Post a Nashik update | *Akhada activities*: set status, dates, location, sources |

Rules the admin enforces:
- Publishing needs the English text and at least one source. A verified record
  also needs a last-verified date. Otherwise it stays a draft and the editor is told why.
- "Officially confirmed" needs a government or official Akhada source.
- An image needs a usage basis and a credit. Without both the API never exposes
  it, and the app shows a neutral placeholder.
- Saved changes reach the API at once, because each save empties the cache.

**Permissions:** normal Django staff permissions. There is no public write API.

## API (`/api/akhadas/`, read-only, no login)

Published reference content with nothing personal in it, so it's open, which
differs from the app's JWT endpoints. All take `?language=en|hi|mr`, falling back
to English. `content_language` says which was used. Lists page with `page` and
`page_size` (max 50). Drafts answer 404.

| Path | Filters |
| --- | --- |
| `` | `q`, `tradition`, `classification`, `location`, `ordering` |
| `<slug>/` | Detail with titles, saints, articles, activities, sources |
| `filters/` | Choices that have published content |
| `saints/`, `saints/<slug>/` | `q`, `akhada`, `title`, `era`, `ordering` |
| `articles/`, `articles/<slug>/` | `q`, `category`, `translated=true`, `ordering` |
| `activities/` | `akhada`, `confirmation`, `kind`, `upcoming=true`, `ordering` |

## Setup

```bash
python manage.py migrate akhadas
python manage.py seed_akhadas
```

The seed adds only missing records and leaves edited ones alone. It loads drafts
by default; add `--publish` after review. The migration only creates new tables.

## Data model

`Tradition`, `SpiritualTitle`, `Akhada`, `SadhuProfile`, `SpiritualArticle` and
`AkhadaActivity`, each with a `*Translation` table (one row per language), plus
`ContentSource`. `AkhadaActivity.event` can link an existing `events.Event`
rather than copying it.

## App

`lib/src/modules/akhada/`. Routes: `/akhadas`, `/akhadaList`, `/akhadaDetail`,
`/saints`, `/saintDetail`, `/akhadaLearn`, `/akhadaArticle`, `/akhadaActivities`.
The dashboard entry is an **Akhadas** tab in the Explore panel. Viewed pages are
saved on the device (80 most recent) and shown, labelled, when offline.

## Known gaps

- **Images are freely licensed, not official.** 15 reviewed Wikimedia Commons
  images ship in `apps/akhadas/seed_images/`, with licences in `manifest.json`.
  Credit and source link appear in the app; CC BY-SA requires that, so keep them.
  Images are resized and cropped to fit, which the licences allow.
- **Ten Akhadas have only a representative place image** (Kushavarta for Shaiva,
  Ramkund for Vaishnava), labelled as such. Upload their own official images in admin.
- **Living leaders keep the placeholder.** Commons portraits of Swami Avdheshanand
  Giri (copied from Facebook) and Swami Kailashanand Giri (filed as an unidentified
  man) don't have a trustworthy licence. Use photos supplied by their offices.
- **Official websites, contacts and headquarters are blank.** None could be
  verified. Atal and Anand have only a one-line summary for the same reason.
- **Only five saint profiles.** Current leaders of most Akhadas couldn't be
  confirmed from strong sources.
- **Hindi and Marathi text is machine-written** and needs a native reviewer,
  especially religious terms.
- **Existing events table:** "Second Amrit Snan" is stored as 2027-09-12 (reported
  date 31 Aug), the 11 Sep bath is missing, and two demo events are published.
