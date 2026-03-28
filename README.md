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
│   │   │   ├── quran_api_service.dart     # Quran.com v4 API wrapper
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

---

## Key architecture decisions

### Multilingual (i18n)
- All UI strings are in `AppLocalizations` with keys for all 7 languages (EN, AR, UR, TR, FR, ID, DE)
- `LocaleProvider` persists the chosen locale in Hive and notifies the whole app
- `isRtl` flag in `LocaleProvider` is used to set `Directionality` at the widget level
- Arabic Quranic text is always RTL regardless of app language; UI chrome flips for Arabic/Urdu
- German uses Quran.com translation ID 27 (Adul Hye & Ahmad von Denffer)

### Tajweed highlighting
- The Quran.com API returns a `tajweed` character code per word
- `QuranApiService.ruleFromCode()` maps codes → `TajweedRule` enum
- `TajweedText` widget builds a `RichText` with `TextSpan` per letter, each colored by its rule
- Tapping a span opens `WordDetailSheet` explaining the rule in the current UI language

### Audio
- Playback: `just_audio` streams from `verses.quran.com` CDN (Mishary reciter default)
- Recording: `record` package captures microphone; saved locally with `path_provider`
- Waveform: `audio_waveforms` visualizes both playback and recording in real time

### AI recitation feedback
- After recording, audio is uploaded to the **Tarteel AI API** (`tarteel.ai`)
- Response includes per-ayah and per-word tajweed scores
- `RecitationFeedback` model maps scores to `TajweedRule` for the feedback panel

### Offline support
- Hive caches fetched verses, translations, and audio file paths
- `rules_db.json` bundles all tajweed rule definitions for fully offline rules library
- Streak data, quiz progress, and recitation history are all stored locally in Hive

---

## API references
- Quran.com API v4: https://api.quran.com/api/v4
- Tarteel AI: https://tarteel.ai/api (requires free API key)
- Audio CDN: https://verses.quran.com/{reciterId}/{surah}{ayah}.mp3
