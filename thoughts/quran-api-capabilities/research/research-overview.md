# Research: Quran API Capabilities

## Research Question

Does the app follow Quran Foundation Content Sync and seven-day
revalidation requirements, can it add word definitions, and can the
text-rendered Mushaf display Tajweed colors from Quran Foundation data?

Research performed on August 24, 2026, against commit
`c45a359e5a02a3c05dd3f99ca0fc642b3d45e29b`.

## Summary

The app implements the required synchronization design. Translations, Tafseer,
and recitation data use Content Sync with a seven-day validation interval.
Quran text has its own seven-day validation path. Chapter and Juz metadata are
re-fetched whenever their reader surfaces initialize and only fall back to
their caches after a failed request. Tafseer and recitation resource lists are
not cached, while ad-hoc Tafseer caches are discovered by Content Sync.
Articles are not currently implemented.

Quran Foundation verse responses can include an English word-by-word gloss
and transliteration. This is useful for a tap-to-understand feature, but it is
not a dictionary definition: the API does not provide roots, morphology, or a
semantic range through a documented Content API endpoint.

API-driven Tajweed coloring in the text-rendered Mushaf is feasible. The app
already maps and colors word-level Tajweed spans in ayah mode. The Mushaf page
renderer currently discards those spans and builds one plain string, while
the page endpoint requests only plain Uthmani text. Adding Tajweed fields and
rendering structured word spans would enable colored pages without using or
redistributing page images.

## Detailed Findings

### Content Sync and Seven-Day Revalidation

- `QuranContentSyncService` supports the `translations`, `tafsirs`, and
  `recitations` groups and uses a seven-day validation interval
  (`lib/core/services/quran_content_sync_service.dart:20-25`).
- The service tracks the last successful validation, sync token, retry state,
  and errors, and applies incremental mutations or replacement snapshots
  (`lib/core/services/quran_content_sync_service.dart:15-19`,
  `lib/core/services/quran_content_sync_service.dart:52-111`).
- Startup, foreground, periodic, and connectivity-restoration maintenance
  invoke Content Sync and Quran-text validation
  (`lib/root_scaffold.dart:85-100`).
- Quran text uses a separate seven-day validation path through
  `QuranOfflineSyncService`
  (`lib/core/services/quran_offline_sync_service.dart:102`,
  `lib/core/services/quran_offline_sync_service.dart:221-262`).
- Articles are not represented in the current app or in the supported Content
  Sync groups.

Other Quran Foundation resources follow the regular-endpoint fallback allowed
by the requirement:

- The chapter list is fetched during reader initialization and locale changes;
  its cache is used only after a failed request
  (`lib/features/reader/reader_screen.dart:607-654`).
- Juz metadata is fetched whenever boundaries are loaded; its cache is used
  only after a failed request
  (`lib/features/reader/reader_screen.dart:888-901`).
- Available Tafseer and recitation resource lists are not cached and therefore
  are fetched from their regular endpoints when their screens load
  (`lib/core/services/quran_api_service.dart:374-388`).
- UI-driven Tafseer maps use keys matched by `_discoverResources`, so they
  participate in the next due Content Sync operation
  (`lib/core/services/quran_content_sync_service.dart:489-526`).
- Downloaded audio remains valid until recitation Content Sync invalidation
  clears the affected reciter cache
  (`lib/core/services/quran_content_sync_service.dart:300-320`).

### Word-Level Meaning

- The primary verse request already asks for word transliteration, but
  `TajweedWord` does not retain it
  (`lib/core/services/quran_api_service.dart:204-210`,
  `lib/core/models/tajweed_models.dart:183-188`).
- Adding `translation` to `word_fields` returns a contextual English gloss
  such as "the Ever-Living"; `transliteration` returns a Romanized
  pronunciation.
- `AyahMapper` already reads per-word translation objects when constructing a
  fallback verse translation, but it discards the individual values
  (`lib/core/services/ayah_mapper.dart:487-506`).
- The natural UI integration point is `WordDetailSheet`, which currently
  presents the Arabic word, Tajweed rule, description, and examples
  (`lib/features/reader/widgets/word_detail_sheet.dart:10-183`).
- The proxy already permits `word_fields`, and the relevant verse paths are
  allowlisted, so requesting the additional fields does not require a new
  backend route (`backend/quran-proxy/src/index.ts:42-71`).
- Raw verse JSON is cached on device, so included word glosses would remain
  available offline after the associated content is downloaded.

This should be presented as **Word meaning** or **Word-by-word translation**,
not **Dictionary definition**. The current Quran Foundation Content API does
not expose a documented dictionary endpoint with roots, morphology, or
lexical definitions. A true dictionary feature would require a separately
licensed and maintained data source.

### Colored Text-Rendered Mushaf

- The active Mushaf is a local text renderer based on Quran Foundation Uthmani
  text and page metadata; it does not use page images
  (`lib/features/reader/reader_screen.dart:3019-3400`).
- Ayah mode already converts `TajweedWord.spans` into colored `TextSpan`
  objects (`lib/features/reader/widgets/tajweed_text.dart:236-316`).
- `AyahMapper` already parses `text_uthmani_tajweed` into typed spans
  (`lib/core/services/ayah_mapper.dart:280-331`,
  `lib/core/services/ayah_mapper.dart:508-584`).
- The page endpoint currently requests only `text_uthmani` and
  `char_type_name`, so page-only responses cannot produce Tajweed spans
  (`lib/core/services/quran_api_service.dart:218-235`).
- The Mushaf flow renderer calls `Ayah.plainArabicText()` and concatenates a
  plain string, losing word-level colors and tap targets
  (`lib/features/reader/reader_screen.dart:3335-3372`).

The recommended implementation is:

1. Request `text_uthmani_tajweed` and the existing Tajweed fields for
   page-based verse fetches, or reliably obtain equivalent cached chapter
   payloads.
2. Refactor `_buildFlowText` and `_MushafFlowText` to consume
   `TajweedWord`/`TajweedSpan` structures instead of a single plain string.
3. Reuse the established Tajweed color-resolution logic rather than creating
   a second rule-color mapping.
4. Preserve ayah numbers, Rub el Hizb markers, selection behavior, line
   wrapping, and offline fallback.
5. Profile dense pages and add regression tests for span ordering and marker
   placement.

## Code References

- `lib/core/services/quran_content_sync_service.dart:10-111` - Content Sync
  groups, metadata, seven-day due check, and synchronization entry point.
- `lib/core/services/quran_offline_sync_service.dart:102-262` - Quran-text
  seven-day validation and background synchronization.
- `lib/core/services/quran_api_service.dart:179-388` - Chapter, verse, page,
  Juz, Tafseer-resource, and recitation-resource requests.
- `lib/core/services/ayah_mapper.dart:280-331` - Word-level Tajweed mapping.
- `lib/core/services/ayah_mapper.dart:487-506` - Existing use of word glosses
  as a fallback verse translation.
- `lib/features/reader/widgets/tajweed_text.dart:236-316` - Existing colored
  word-span renderer.
- `lib/features/reader/widgets/word_detail_sheet.dart:10-183` - Existing
  word-tap detail UI.
- `lib/features/reader/reader_screen.dart:2690-2710` - Mushaf page data load.
- `lib/features/reader/reader_screen.dart:3335-3372` - Plain Mushaf flow-text
  construction.
- `backend/quran-proxy/src/index.ts:42-71` - Allowed Content API query keys and
  paths.

## Architecture Insights

- Content freshness is intentionally split between token-based Content Sync
  for supported resource groups and ordinary endpoint revalidation for other
  resources.
- Raw API payload caching is advantageous for adding word glosses because no
  separate offline database is required.
- The existing typed Tajweed span model is sufficient for colored Mushaf
  pages; the missing layer is page-view rendering, not rule detection.
- Page images are unnecessary for color support and would reintroduce the
  licensing and redistribution concerns the text-rendered Mushaf avoids.

## Open Questions

- Confirm with Quran Foundation whether `translation` and `transliteration`
  are supported, stable `word_fields` in the production Content API contract;
  they work in current responses but are not clearly documented in the field
  reference.
- Decide whether English-only word glosses should be shown when the reader
  selects another translation language.
- Decide whether articles will become an app feature. If not, no article sync
  implementation is required.
- Confirm desired Mushaf interaction: colors only, or colors plus tappable
  word meaning and Tajweed-rule details.

## External References

- Quran Foundation Content API field reference:
  https://api-docs.quran.foundation/docs/api/field-reference/
- Quran Foundation Content API overview:
  https://api-docs.quran.foundation/docs/content_apis_versioned/4.0.0/content-apis/
- Quran Foundation Content Sync:
  https://api-docs.quran.foundation/docs/category/content-sync-apis/
