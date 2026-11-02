# News & Learn About Kumbh (Module 3)

Kumbh Patrika has two parts: a news journal, and Gyan, a learning library.
Design direction and screen plan: [news_learn_design.md](news_learn_design.md).

## Research summary (checked 2026-10-30)

| Source | Feed or API? | Decision |
| --- | --- | --- |
| Press Information Bureau | Official RSS, listed at pib.gov.in/ViewRss.aspx. Items have no dates | Connected and on. Queues items with a note to set the date |
| nashikkumbha2027.com | No feed, sitemap or public API. News loads by script | Manual entry. Not scraped |
| divcomnashik.maharashtra.gov.in | `/feed/` returns an error | Manual entry |
| nashik.gov.in | `/feed/` returns an error | Manual entry; used as a Learn source |
| Free Press Journal, Sakal | Public RSS with real Kumbh coverage | Adapter ready, **off until you confirm the terms** |
| The Hindu, Express, Times of India | RSS exists, but the regional feeds had no Kumbh items in the sample | Not added |
| Lokmat | Feed refuses requests (403) | Not used |
| Google News RSS | An aggregator, not a publisher | Not used |

## How news gets in

1. **Feeds fill a review queue.** Only the headline, link, date and publisher are
   kept. Publisher text is used only to judge relevance, then thrown away.
2. **An editor reviews each story** in admin (status: Draft), writes a short
   summary in their own words, picks a category and publishes.
3. **Editors can add any story by hand**, which is how official notices arrive today.

Nothing from a feed reaches pilgrims without a person publishing it.

**Safeguards:** at most one request per source per 6 hours, doubling after failures
(capped at 48 hours), conditional requests, a 3 MB size limit, refusal of XML with
entity declarations, https links only, duplicate detection by address and by headline,
and a sync log in admin. Sources are off by default.

**Adding a publisher:** add a News source in admin. For a new format, add one class
to `apps/news/adapters.py` and one line to `ADAPTERS`.

**Schedule:** `python manage.py setup_news_sync` creates a 6-hourly task on the
existing Celery beat. It hasn't been run.

### Rules enforced

- **Official notice** needs an official publisher, checked in admin and again in the app.
- **Publishing** needs a summary and a category.
- **Publisher images aren't stored.** A story uses its own licensed image, or its
  category's, labelled "Illustrative image".
- **Full articles aren't reproduced.** The story page credits the publisher and links out.

## API (read-only, no login)

| Path | Purpose |
| --- | --- |
| `/api/news/home/` | Lead story, notices, latest, categories, publishers |
| `/api/news/` | `q`, `category`, `publisher`, `date_from`, `date_to`, `official`, `ordering=latest\|relevant`, `page` |
| `/api/news/<slug>/` | Story with related stories |
| `/api/learn/home/` | Cover, sections with articles, one glossary term |
| `/api/learn/articles/` | `q`, `section`, `kind`, `translated=true` |
| `/api/learn/articles/<slug>/` | Article as structured blocks, with links and sources |
| `/api/learn/glossary/`, `/api/learn/glossary/<slug>/` | Terms |

All take `language=en|hi|mr` and report `content_language` when falling back.

## Writing a Learn article

Admin → Learn → Learning articles. Each language has a title, a one-line dek and a
body. Separate blocks with a blank line, and start a line with:

| Start | Becomes |
| --- | --- |
| `## ` | Heading |
| `- ` | List item |
| `> ` | Pull quote |
| `!info ` / `!warn ` | Callout |
| `[[image:key]]` | An image added under Images, with its credit |

Reading time is worked out from the text. Link temples and Akhadas rather than
repeating them; they appear as "Visit this temple" and "Meet the Akhada". Glossary
terms have their own admin page.

## Setup

```bash
python manage.py migrate news
```

```bash
python manage.py migrate learn
```

```bash
python manage.py seed_kumbh_content
```

The seed adds only what's missing, and loads drafts unless given `--publish`.

## App

`lib/src/modules/patrika/`. Routes: `/kumbhNews`, `/newsArticle`, `/newsSearch`,
`/learn`, `/learnArticle`, `/glossary`, `/patrikaSaved`. The dashboard's **Discover**
tab replaces the Akhadas tab and leads to News, Learn and Akhadas. Saved items and
recently read pages stay on the device; nothing needs an account.

Shared additions: `context.editorial` (typography) and
`lib/src/components/editorial/` (ghat edge, temple arch, rule, images).

## Known gaps

- **No official notices yet.** Every seeded story comes from a news organization, so
  the blue notice panel stays hidden until an editor adds one from an official source.
- **Topics merged or not yet written.** The library has 18 articles: some listed
  topics are combined (why Kumbh is celebrated and the 12-year cycle, for example) and
  these aren't written yet: Godavari Aarti, a dedicated Ramkund visitor guide,
  and basic safety as its own article.
- **Sita Gufa and Tapovan** are marked as awaiting verification: no official text
  could be found, and the municipal tourism site is down.
- **Hindi and Marathi text** is machine-written and needs a native reviewer.
- **Source checks:** Jacobsen and Wikipedia entries were read through references or
  excerpts. Each record's notes say so.
- **Images** are freely licensed from Wikimedia Commons and illustrate topics, not the
  specific news events.
