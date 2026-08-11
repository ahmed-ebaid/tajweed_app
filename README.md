# Tajweed Practice — Flutter Project

A multilingual Quran tajweed practice app supporting English, Arabic, Urdu,
Turkish, French, Indonesian, German, and Spanish.

---

## Project structure

```text
tajweed_app/
├── lib/
│   ├── main.dart                     # App bootstrap
│   ├── root_scaffold.dart            # Main navigation shell
│   ├── core/
│   │   ├── l10n/                     # Eight-language localization
│   │   ├── models/                   # Quran and tajweed domain models
│   │   ├── providers/                # Reader, progress, tafsir, and settings state
│   │   ├── services/
│   │   │   ├── quran_api_service.dart
│   │   │   ├── quran_attestation_service.dart
│   │   │   ├── quran_content_sync_service.dart
│   │   │   ├── quran_offline_sync_service.dart
│   │   │   └── audio_service.dart
│   │   └── theme/
│   ├── features/
│   │   ├── home/
│   │   ├── reader/                   # Ayah and Mushaf reading experiences
│   │   ├── quiz/
│   │   ├── rules/
│   │   └── settings/                 # Preferences, About, and attributions
│   └── shared/                       # Reusable widgets and utilities
├── backend/quran-proxy/
│   ├── src/
│   │   ├── index.ts                  # Quran.Foundation proxy routes
│   │   └── attestation.ts            # Apple App Attest verification
│   ├── test/                         # Worker and attestation tests
│   ├── wrangler.jsonc                # Prelive/production Cloudflare config
│   └── README.md                     # Proxy setup and deployment
├── ios/Runner/
│   ├── Runner.entitlements           # Production App Attest
│   └── RunnerDebug.entitlements      # Development App Attest
├── assets/
│   ├── app_icon/
│   ├── fonts/                         # Amiri Quran font and SIL OFL license
│   └── tajweed/
├── docs/                             # Public privacy and support pages
├── test/
│   ├── unit/
│   ├── widget/
│   └── manual/
├── pubspec.yaml
└── README.md
```

---

## Setup

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Run on a physical iPhone

Quran.Foundation Content API requests use isolated app-owned Cloudflare
Workers protected by Apple App Attest. The app requires iOS 15 or later and
does not support the Simulator. Production accepts only distribution
attestations, so run Debug builds against prelive:

```bash
flutter run \
  --dart-define=QURAN_CONTENT_API_BASE_URL=https://tajweed-quran-proxy.ebaidllc.workers.dev/v2/content
```

To prepare generated Swift package metadata before opening Xcode:

```bash
flutter build ios --release --config-only --no-codesign
open ios/Runner.xcworkspace
```

Release and Profile builds use the production Worker and complete Quran
dataset. Android, macOS, Simulator, and older builds fail closed until an
equivalent platform attestation flow is implemented.

### 3. Offline audit for shifted end-token tajweed

Run this before beta release to detect all ayahs where the end token has shifted tajweed payload:

1) Generate a full 6236-ayah words dump:

```bash
dart run tool/fetch_quran_words_dump.dart --output /tmp/quran_words_full_6236.json
```

2) Run the audit on the generated dump:

```bash
dart run tool/end_token_audit.dart --input /path/to/quran_words_full_6236.json --output /tmp/shifted_end_token_report.json
```

Expected console format:

```text
Shifted end-token ayahs: <count>
SHIFTED_END_TOKEN 8:6
SHIFTED_END_TOKEN <surah>:<ayah>
...
```

Input JSON can be either:
- a flat list of verse objects
- `{ "verses": [ ... ] }`
- per-surah map like `{ "1": [ ... ], "2": [ ... ] }`

### 4. Release integrity gate

Before every release candidate, run both checks below:

```bash
flutter test test/unit/ayah_mapper_test.dart
node tool/check_sajdah_ayahs.js
```

Expected output includes:

```text
ALL_SAJDAH_FIRST_WORDS_PRESENT
```

These checks guard against regressions where ayah word mapping can hide the
first word (especially on sajdah-marker ayahs like `16:50`).

CI enforcement:
- GitHub Actions workflow: `.github/workflows/release-integrity.yml`
- It runs on push/PR and can also be triggered manually (`workflow_dispatch`).

---

## Key architecture decisions

### Multilingual (i18n)
- All UI strings are in `AppLocalizations` for eight languages: EN, AR, UR, TR, FR, ID, DE, and ES
- `LocaleProvider` persists the chosen locale in Hive and notifies the whole app
- `isRtl` flag in `LocaleProvider` is used to set `Directionality` at the widget level
- Arabic Quranic text is always RTL regardless of app language; UI chrome flips for Arabic/Urdu
- German uses Quran.Foundation translation resource ID 27 (Adul Hye & Ahmad von Denffer)
- Spanish uses Quran.Foundation translation resource ID 83 (Sheikh Isa Garcia)

### Tajweed highlighting
- The Quran.Foundation Content API returns a `tajweed` character code per word
- `QuranApiService.ruleFromCode()` maps codes → `TajweedRule` enum
- `TajweedText` widget builds a `RichText` with `TextSpan` per letter, each colored by its rule
- Tapping a span opens `WordDetailSheet` explaining the rule in the current UI language

### Audio
- Reader playback uses selectable Quran.Foundation recitations and defaults to AbdulBasit Mujawwad
- Tajweed rule examples use Mahmoud Khalil Al-Husary's Al-Muallim recitation
- `just_audio` streams verse audio and `AudioCacheService` stores optional offline downloads

### Mushaf pages
- The 604-page reader uses Quran.Foundation Uthmani verse text and page metadata
- Pages are rendered locally as text; the app does not download or redistribute Mushaf page images
- The bundled Amiri Quran font is provided by the Amiri Project under the SIL Open Font License 1.1

### API attestation
- `QuranAttestationService` registers an Apple App Attest key and generates assertions
- The Cloudflare Worker validates Apple's certificate chain, app identity, one-time challenge, and monotonic assertion counter
- Successful assertions receive environment-bound bearer tokens valid for ten minutes
- Protected `/v2/content` routes reject missing, forged, expired, or cross-environment tokens
- App Attest private keys remain in Apple's Secure Enclave; only the key identifier is stored locally

### Offline support
- Hive caches fetched verses, translations, Tafseer, recitation metadata, and
  audio file paths for app features only
- Quran text is revalidated when its last successful validation is seven days
  old; reconnecting after an offline period promptly retries overdue checks
- Quran.Foundation Content Sync mutation tokens and replacement snapshots keep
  cached translations, Tafseer, and recitations current without redistributing
  the underlying raw datasets
- Failed refreshes preserve the last valid local cache
- `rules_db.json` bundles all tajweed rule definitions for fully offline rules library
- Streak data, quiz progress, bookmarks, and reader settings are stored locally in Hive

---

## API references
- Quran.Foundation Content APIs:
  https://api-docs.quran.foundation/docs/category/content-apis
- Quran.Foundation Content Sync:
  `/content/api/v4/resources/sync`
- Audio CDN: https://verses.quran.com/{reciterId}/{surah}{ayah}.mp3
- Amiri Quran font: https://github.com/aliftype/amiri
