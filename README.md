# Tajweed Practice — Flutter Project

A multilingual Quran tajweed practice app supporting English, Arabic, Urdu, Turkish, French, Indonesian, and German.

---

## Project structure

```
tajweed_practice/
├── lib/
│   ├── main.dart                          # App entry point, MultiProvider setup
│   │
│   ├── core/
│   │   ├── l10n/
│   │   │   └── app_localizations.dart     # All 6 language strings + delegate
│   │   ├── models/
│   │   │   └── tajweed_models.dart        # TajweedRule, Ayah, QuizQuestion, etc.
│   │   ├── providers/
│   │   │   ├── locale_provider.dart       # Language switching + RTL detection
│   │   │   ├── streak_provider.dart       # Daily streak tracking (Hive)
│   │   │   └── recitation_provider.dart   # Recording state + feedback
│   │   ├── services/
│   │   │   ├── quran_api_service.dart     # Quran.Foundation API client
│   │   │   ├── tarteel_service.dart       # Tarteel AI recitation feedback API
│   │   │   └── audio_service.dart         # just_audio playback wrapper
│   │   └── theme/
│   │       └── app_theme.dart             # Light + dark MaterialTheme
│   │
│   ├── features/
│   │   ├── home/
│   │   │   └── home_screen.dart           # Dashboard, streak, quick-access cards
│   │   │
│   │   ├── reader/
│   │   │   ├── reader_screen.dart         # Surah picker + scrollable ayah list
│   │   │   ├── reader_view_model.dart     # Surah loading, audio, word detail
│   │   │   └── widgets/
│   │   │       ├── tajweed_text.dart      # RichText with per-letter color spans
│   │   │       ├── tajweed_legend.dart    # Scrollable color key
│   │   │       ├── word_detail_sheet.dart # Bottom sheet: rule explanation
│   │   │       └── audio_player_bar.dart  # Mini player with waveform
│   │   │
│   │   ├── quiz/
│   │   │   ├── quiz_screen.dart           # MCQ quiz with progress bar
│   │   │   ├── quiz_view_model.dart       # Question cycling, score tracking
│   │   │   └── widgets/
│   │   │       ├── quiz_card.dart         # Arabic text + question card
│   │   │       ├── option_tile.dart       # Answer option with feedback state
│   │   │       └── quiz_results_sheet.dart
│   │   │
│   │   ├── rules/
│   │   │   ├── rules_screen.dart          # Searchable + filterable rule list
│   │   │   ├── rule_detail_screen.dart    # Expanded rule with examples + audio
│   │   │   └── rules_repository.dart     # Static rule definitions (all languages)
│   │   │
│   │   ├── record/
│   │   │   ├── record_screen.dart         # Ayah selector + record button
│   │   │   ├── record_view_model.dart     # mic permissions, upload, feedback
│   │   │   └── widgets/
│   │   │       ├── waveform_visualizer.dart
│   │   │       └── feedback_panel.dart    # Per-rule score bars
│   │   │
│   │   └── settings/
│   │       ├── settings_screen.dart
│   │       └── language_selector_screen.dart  # Language picker with native names
│   │
│   └── shared/
│       ├── widgets/
│       │   ├── app_bottom_nav.dart        # Persistent bottom navigation
│       │   ├── streak_bar.dart            # Day-dot streak widget
│       │   └── loading_skeleton.dart      # Shimmer placeholders
│       └── utils/
│           ├── rtl_utils.dart             # TextDirection helpers
│           └── arabic_utils.dart          # Arabic text shaping utilities
│
├── assets/
│   ├── fonts/
│   │   ├── UthmanicHafs_V22.ttf          # Primary Quranic font
│   │   ├── Amiri-Regular.ttf
│   │   └── Amiri-Bold.ttf
│   ├── images/
│   ├── lottie/
│   │   └── celebration.json              # Quiz correct-answer animation
│   └── tajweed/
│       └── rules_db.json                 # Local tajweed rule definitions (offline)
│
├── test/
│   ├── unit/
│   │   ├── tajweed_models_test.dart
│   │   └── quran_api_service_test.dart
│   └── widget/
│       └── tajweed_text_test.dart
│
├── pubspec.yaml
└── README.md
```

---

## Setup

### 1. Install dependencies
```bash
flutter pub get
```

Quran Foundation Content API requests use isolated app-owned Cloudflare
Workers. All app builds default to the production Worker so development and
beta testing use the complete Quran dataset. Content requests require an
Apple App Attest proof from a genuine physical-device installation; unsupported
platforms and older builds fail closed. Override the URL to test a
development-signed physical-device build against prelive with:

```bash
flutter run \
  --dart-define=QURAN_CONTENT_API_BASE_URL=https://tajweed-quran-proxy.ebaidllc.workers.dev/v2/content
```

Quran Search remains on its separate API until the required Search OAuth scope
is approved and proxied.

### 2. Download fonts
- **UthmanicHafs**: https://fonts.qurancomplex.gov.sa
- **Amiri**: https://www.amirifont.org

Place `.ttf` files in `assets/fonts/`.

### 3. Android permissions (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
```

### 4. iOS permissions (ios/Runner/Info.plist)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Used to record your Quran recitation for tajweed feedback.</string>
```

### 5. Run
```bash
flutter run
```

### 6. Offline audit for shifted end-token tajweed (release check)
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

### 7. Release integrity gate (required)
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
- All UI strings are in `AppLocalizations` with keys for all 7 languages (EN, AR, UR, TR, FR, ID, DE)
- `LocaleProvider` persists the chosen locale in Hive and notifies the whole app
- `isRtl` flag in `LocaleProvider` is used to set `Directionality` at the widget level
- Arabic Quranic text is always RTL regardless of app language; UI chrome flips for Arabic/Urdu
- German uses Quran.com translation ID 27 (Adul Hye & Ahmad von Denffer)

### Tajweed highlighting
- The Quran.Foundation Content API returns a `tajweed` character code per word
- `QuranApiService.ruleFromCode()` maps codes → `TajweedRule` enum
- `TajweedText` widget builds a `RichText` with `TextSpan` per letter, each colored by its rule
- Tapping a span opens `WordDetailSheet` explaining the rule in the current UI language

### Audio
- Playback: `just_audio` streams from `verses.quran.com` CDN (Mishary reciter default)
- Recording: `record` package captures microphone; saved locally with `path_provider`
- Waveform: `audio_waveforms` visualizes both playback and recording in real time

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
- Streak data, quiz progress, and recitation history are all stored locally in Hive

---

## API references
- Quran.Foundation Content APIs:
  https://api-docs.quran.foundation/docs/category/content-apis
- Quran.Foundation Content Sync:
  `/content/api/v4/resources/sync`
- Audio CDN: https://verses.quran.com/{reciterId}/{surah}{ayah}.mp3
