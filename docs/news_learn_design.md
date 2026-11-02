# Kumbh Patrika: design direction for News & Learn

*Patrika* (पत्रिका) means journal. The module is designed as a pilgrim's journal
of the Simhastha, not as a news app or a list of articles.

## Why Modules 1 and 2 feel ordinary

| Finding | Effect |
| --- | --- |
| Only the system font; every heading is the same sans-serif | No voice. Nothing says "culture" or "editorial" |
| Almost every element is `AppCard` → `Row` → text | Each screen has one rhythm, so nothing leads the eye |
| `ListTile` used for content, not just settings | Reads as a settings screen |
| Images were added after layout, as thumbnails | Photography can't carry the mood |
| No scroll-driven or shared-element motion | Screens feel like static forms |
| Every item has equal visual weight | No hierarchy, no sense of a front page |

## Direction

Three ideas, all drawn from the place itself:

1. **The journal.** A printed-journal hierarchy: masthead, dateline, one lead
   story, then a calmer feed. Big serif headlines, generous margins, hairline rules.
2. **The ghat.** A signature shape: images end in a **stepped edge**, like stone
   steps descending into the river, and fall into the page colour.
3. **The shikhara.** Places appear in a **temple-arch** crop, so the Learn library
   looks like nothing else in the app.

**Restraint rule:** one idea per screen, and photography does the decorating.
No gradients except image scrims, and no icons where a word works.

## Tokens (added to the design system, not a second one)

- **`AppEditorial`** (`context.editorial`): `masthead`, `lead`, `headline`, `title`,
  `quote`, `kicker`, `reading`. Built from `textTheme` colours and sizes, so theme
  and font-scale preferences apply automatically. The module changes no global style.
- **Typeface:** Tiro Devanagari Hindi and Marathi (SIL OFL, bundled). A true
  editorial serif covering Latin and Devanagari, with the right letterforms for each.
- **Colour:** existing roles only. Saffron is the kicker accent, `gold` the hairline
  rule, `surface` the page. Official notices use the `info` (Godavari blue) family,
  so authority is never confused with a story.
- **Spacing:** `AppSpacing`, with a wider 20dp editorial margin (`xl`).

## Motion (restrained, purposeful)

| Moment | Motion |
| --- | --- |
| Image → article | Shared-element Hero |
| Scrolling a lead image | Gentle parallax at 0.4× |
| Category change | Underline slides; feed cross-fades |
| Reading | Hairline progress thread under the app bar |
| Image load | 300ms fade from the page colour |

Motion is removed when the device's reduce-motion setting is on.

## Screens

**News home** (`/kumbhNews`)
1. Masthead: "Kumbh Patrika", dateline, search and saved actions.
2. Official notice panel, only when a real one exists: a blue seal, "Official notice",
   headline, publisher. Visually unlike any story.
3. Lead story: full-bleed image with stepped edge, kicker, large serif headline, dek,
   publisher and date.
4. Category rail: words with a sliding underline, not chips.
5. Feed by day: date headers on a hairline; the first story of a day is large, the
   next are compact with a small image, the rest are text only. Rhythm changes
   by position, so no two sections look identical.

**News article** (`/newsArticle`): immersive image with stepped edge; kicker; serif
headline; publisher line; "What we know" summary in reading type; a source card
leading to the publisher; "image shown is illustrative" when it isn't the story's own;
related stories as a text list. Floating save and share.

**Search** (`/newsSearch`): a calm full-screen sheet: search field, publisher, date
range and sort, with results in the compact row style.

**Learn home** (`/learn`)
1. Masthead "Gyan" with a one-line invitation.
2. Cover story: tall image, stepped edge, serif title.
3. Numbered chapters: large Devanagari numerals (१ २ ३) in gold with the section
   title, each with a horizontal shelf of portrait covers.
4. Places: temple-arch shelf.
5. Glossary invitation: one term displayed large, as a page-turner into the glossary.

**Reader** (`/learnArticle`): parallax header; progress thread; lede opening paragraph;
reading-width column; pull quotes; callouts; captioned images with credits;
"Visit this temple" and "Meet the Akhada" links; numbered sources; next-article footer.

**Glossary** (`/glossary`): search on top, then terms as typographic rows: large
serif term, one-line meaning. Tapping opens a sheet with detail and links.

**Saved** (`/kumbhSaved`): saved stories and articles, on the device.

**Dashboard:** Akhadas moves into a single **Discover** tab with News and Learn. The
strip stays at six tabs, so nothing adds scrolling. Its panel leads with today's story.

## States

Loading uses editorial skeletons shaped like the real layout. Empty and error
states use serif text and a single action, never a generic icon block. With no
official notices, the panel is absent. With no stories, the page says so plainly.

## Quality checklist

Light and dark, English, Hindi and Marathi, 320dp at 1.6× text, font-scale presets,
reduced motion, screen-reader order, and 48dp touch targets.
