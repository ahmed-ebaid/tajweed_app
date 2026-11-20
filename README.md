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
│   │   ├── hifz/                     # Surah review and memorization
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
├── docs/                             # Public privacy, terms, and support pages
├── test/
│   ├── unit/
│   ├── widget/
│   └── manual/
├── pubspec.yaml
└── README.md
```

---

## Store review requests

After at least one minute of reading on three distinct days, a later launch
can request the native store review sheet after five seconds. Switching from
Home to Reader does not cancel the request. Requests wait while the app is
backgrounded, another route or dialog is open, Quiz or Hifz is selected, reader audio
is playing, or a seasonal icon update is in progress. An icon change skips the
request for that launch. Attempts are limited to once every 120 days.

The app does not ask for a username or create an account to leave a review.
Apple and Google control the review sheet and any store-account requirements;
calling their API does not guarantee that the sheet is displayed.

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

### 3. Run on an Android emulator

Android builds and renders, but only iOS has an attestation provider today, so
content requests fail closed with `Android does not have a supported
attestation provider yet.` The UI still draws, which is enough for layout,
RTL, and localization checks.

One-time SDK setup:

```bash
brew install --cask android-commandlinetools
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses
sdkmanager --sdk_root="$ANDROID_HOME" \
  platform-tools emulator \
  "platforms;android-36" "build-tools;36.0.0" \
  "system-images;android-36;google_apis;arm64-v8a"
flutter config --android-sdk "$ANDROID_HOME"
```

Create an emulator and boot it:

```bash
avdmanager create avd -n tajweed_test \
  -k "system-images;android-36;google_apis;arm64-v8a" -d pixel_7
"$ANDROID_HOME/emulator/emulator" -avd tajweed_test &
```

`avdmanager` prints `Error: Could not load devices from ... devices.xml` when
it applies the `-d` hardware profile. The AVD still boots, but only the device
*name* is recorded — the skin and display-cutout geometry are not. A known
side effect is that the emulator's own status-bar clock renders clipped along
its baseline. This is cosmetic and confined to system UI; app content is
unaffected.

To load real content, use the existing simulator bypass — it is
platform-agnostic and works on Android:

```bash
flutter run -d emulator-5554 \
  --dart-define=QURAN_CONTENT_API_BASE_URL=https://tajweed-quran-proxy.ebaidllc.workers.dev/v2/content \
  --dart-define=QURAN_BYPASS_APP_ATTEST_IN_DEBUG=true \
  --dart-define=QURAN_PROXY_TEST_TOKEN="$SIMULATOR_TEST_TOKEN"
```

The bypass is guarded on both ends and cannot reach a shipping build: the
client disables it whenever `kReleaseMode` is true, and the Worker refuses it
when `QF_ENV` is `production` or the token is shorter than 32 characters. Set
the matching secret on the prelive Worker with
`npx wrangler secret put SIMULATOR_TEST_TOKEN --env=""`.

The same prelive configuration works on the iOS simulator. The prelive
chapter endpoint currently supplies Al-Fatihah and Al-Baqarah only. Hifz
accepts that limited chapter list solely when the existing non-release
bypass is enabled against the prelive Worker host, and shows a debug sandbox
banner. It never writes a partial list into the complete Reader chapter
cache; full-surah and printed-page completeness checks still apply.
Production builds still require all 114 chapters. Simulator microphone
recognition availability and accuracy must be evaluated separately from
content loading.

#### Play Integrity (the Android counterpart to App Attest)

Android proves sender identity with the [Play Integrity
API](https://developer.android.com/google/play/integrity) rather than App
Attest, but the handshake is deliberately identical: the client asks the Worker
for a single-use challenge, passes it to Google as the request **nonce**, and
exchanges the returned token for the same bearer access token iOS receives. A
*classic* request is used precisely because it accepts a caller-supplied nonce;
standard requests are cached by Google and cannot bind a token to one challenge.

The client names the Google Cloud project that owns the Play Integrity API.
The production project number (`312770688680`) is public app configuration and
is included by default, including when building without extra flags. A
different project's number can be supplied explicitly for development:

```bash
flutter run -d emulator-5554 \
  --dart-define=QURAN_CONTENT_API_BASE_URL=https://tajweed-quran-proxy.ebaidllc.workers.dev/v2/content \
  --dart-define=PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER=<gcp-project-number>
```

An explicitly configured non-positive number still fails closed, and a missing
or invalid integrity token never falls back to an unauthenticated request.
The Worker needs four matching secrets; until they are
set it answers `integrity` challenges with `503`, which is also fail-closed:
`ANDROID_PACKAGE_NAME`, `ANDROID_CERT_SHA256`, `PLAY_INTEGRITY_SA_EMAIL`, and
`PLAY_INTEGRITY_SA_PRIVATE_KEY`.

##### One-time Google Cloud setup

1. Create (or pick) a Google Cloud project and note its **project number** —
   that is the value for `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER`. The number, not
   the project ID.
2. Enable the **Play Integrity API** for that project.
3. Create a service account and grant it access to the Play Integrity API, then
   download a JSON key for it.

##### Writing the secrets

`scripts/setup-play-integrity.sh` derives the certificate digest from a keystore
and extracts the service-account fields from that JSON key, so the stored values
always match what Google reports. Run it from `backend/quran-proxy`:

```bash
# Preview the values without writing anything
./scripts/setup-play-integrity.sh \
  --service-account ~/Downloads/play-integrity-sa.json --dry-run

# Write all four secrets to prelive
./scripts/setup-play-integrity.sh \
  --service-account ~/Downloads/play-integrity-sa.json
```

It defaults to the Android debug keystore and the prelive Worker, which is the
combination a sideloaded build needs. For a release build, pass the release
keystore and target production:

```bash
./scripts/setup-play-integrity.sh \
  --service-account ~/Downloads/play-integrity-sa.json \
  --keystore /path/to/release.jks --alias upload \
  --storepass "$KEYSTORE_PASSWORD" --env production
```

The digest must be the base64url-encoded SHA-256 of the DER certificate with
padding stripped; any other encoding fails the comparison with a generic
"certificate is not trusted" error. The script handles that encoding, so prefer
it over setting `ANDROID_CERT_SHA256` by hand.

**Emulators can never pass this check.** An AVD does not return
`MEETS_DEVICE_INTEGRITY`, so the emulator can exercise the plumbing — channel
call, challenge binding, server decode — but the device verdict will always
fail. End-to-end verification requires a physical Android device. Sideloaded
builds are tolerated only on prelive: the stricter `PLAY_RECOGNIZED` app
verdict is asserted only when `QF_ENV` is `production`, mirroring the existing
App Attest development/production split. A real device plus a prelive Worker is
therefore enough to verify the whole flow without publishing to Google Play.

### 4. Offline audit for shifted end-token tajweed

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

### 5. Release integrity gate

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
- Tanween annotations highlight only the letter carrying the tanween and its marks, not a supporting alif or preceding letters included in the upstream tag.
- Tapping a span opens `WordDetailSheet` explaining the rule in the current UI language

### Rule teaching and quizzes
- Rules, word-detail explanations, and quiz feedback share the eight-language definitions in `RulesRepository`.
- Silent-letter details and reader word sheets show a large, labeled comparison of small-head sukoon, rounded zero, and circular ordinary Arabic sukoon. The shared guidance explains that a circle alone does not identify a silent letter; source Quran marks remain unchanged.
- Opening-letter guidance distinguishes the two-count readings of `حي طهر` from the six-count readings of `ن ق ص س ل ك م`. Alif has no madd; ayn permits four or six counts in Hafs via al-Shatibiyyah. In `حمٓ`, ha takes two counts and meem six; in `الٓمٓ`, lam and meem each take six.
- The intermediate izhar example uses the separate Quranic hamza in `مَنْ ءَامَنَ`; its highlight covers the noon and following hamza, without adding a maddah sign.

### Home
- A localized reading shortcut opens the Reader tab without changing the saved ayah, scroll offset, or reader mode.
- New readers see “Start reading”; returning readers see their saved surah and ayah.
- The daily lesson retains its targeted navigation and shows progress only after practice begins. Home shows surah names and omits the fire/streak widget.
- Opening Today’s lesson shows a dismissible, localized rule explanation at its
  ayah and highlights one authored word or cross-word example. Tapping any part
  of that example opens the corresponding word-detail rule sheet. Existing
  Tajweed letter colors and audio word highlighting are preserved. Lesson focus
  clears when dismissed, leaving the Reader tab, changing surahs, or switching
  to Mushaf mode; ordinary reading navigation does not enable it.

### Audio
- Reader playback uses selectable Quran.Foundation recitations and defaults to AbdulBasit Mujawwad
- Tajweed rule examples use Mahmoud Khalil Al-Husary's Al-Muallim recitation
- `just_audio` streams verse audio and `AudioCacheService` stores optional offline downloads

### Mushaf pages
- The 604-page reader uses Quran.Foundation Uthmani verse text and page metadata
- Pages are rendered locally as text; the app does not download or redistribute Mushaf page images
- The bundled Amiri Quran font is provided by the Amiri Project under the SIL Open Font License 1.1

### Experimental memorization
- The **Hifz** bottom tab lets you select a surah and choose **Review** (visible text and reference audio) or **Recite from memory**. Continuous practice is the default; an optional ayah-by-ayah switch retains the step-based experience. Reader's **Memorize this surah** shortcut also opens continuous practice.
- Practice starts at ayah 1 and preserves the complete Reader Mushaf page, including neighboring surahs, original word lines and ayah end-lines, surah headings, Juz, page numbers, and Hizb/sajdah markers. Only the selected surah is masked; hints and matches change visibility without reflowing text.
- Final recognition segments are checked against consecutive ayahs in Quran order. Fully matched ayahs are revealed and the current ayah/page advances automatically; a valid unfinished ayah prefix is retained for the next segment. Revisable partial native results never count as matches. When the platform ends recognition, **Resume** continues from the current passage; the app does not promise an unlimited microphone session.
- The optional **Live ayah preview (unconfirmed)** switch shows fully matching ayahs from the current partial transcript in place while listening. Previews are explicitly labelled, may disappear when recognition revises its text, and never advance the confirmed position or counters. Final results confirm matching ayahs; stopping, errors, hints, and interruptions discard unconfirmed previews. The switch is off by default.
- Recognition failures show **Retry**, not Resume. Retrying preserves confirmed ayahs, the current page/ayah, and any valid unfinished prefix from earlier final segments; it does not turn a failed or provisional transcript into a confirmed match.
- A separate local Quran-ASR prototype is available in `tool/quran_asr_eval.py`. Install `tool/quran_asr_requirements.txt` in an isolated Python virtualenv, then run `python tool/quran_asr_eval.py /path/to/clip.wav --cache-dir /private/model-cache` (add `--offline` after the initial download). It accepts only explicit mono PCM16 WAV clips at 16 kHz, up to 30 seconds; it never uploads audio or updates app progress. It defaults to Tarteel AI's [Whisper tiny Quran model](https://huggingface.co/tarteel-ai/whisper-tiny-ar-quran), with the base model also selectable. The model cards declare Apache-2.0 but leave training-data and limitations details incomplete; reported benchmark scores are not evidence of mistake-detection accuracy. Actual offline inference on synthetic silence produced nonempty Arabic text, confirming the need for silence filtering and independent evaluation before any app integration. This is a short-clip research tool, not streaming recognition or Tajweed grading. Input checks run with `python -m unittest discover -s tool -p test_quran_asr_eval.py`.
- To replay an existing whisper.cpp model without Python inference dependencies, use `python3 tool/quran_asr_eval.py /path/to/clip.wav --native-cli /path/to/whisper-cli --native-model /path/to/model.bin --beam-size 1`. The decoder runs locally on CPU without reference prompting, temperature fallback, or context carryover. Optional `--reference 'Arabic target'` reports target edit distance, not recognition accuracy; only independently checked audio transcripts qualify for `--reference-kind transcribed` and WER. Desktop timings include model loading and do not predict iPhone latency.
- `tool/quran_asr_corpus_eval.py` downloads public Quran.com ayah recordings and saves raw local decoder snapshots. On macOS, run `python3 tool/quran_asr_corpus_eval.py --native-cli /path/to/whisper-cli --native-model /path/to/model.bin --output-dir /private/corpus-run`. The default covers all 6,236 ayahs for Al-Husary, Alafasy, and Al-Minshawi (recitation IDs 6, 7, 9); `--verse-keys 1:1 2:255 91:11 91:13` selects a smaller pilot. Cached downloads and atomic per-ayah reports allow the identical command to resume; changed model/CLI hashes or inference settings require another output directory. Network/conversion/decoder failures are explicit error reports and a nonzero exit, not recognition misses. This can take hours and uses macOS `afconvert`, disk space for downloaded MP3s, and four CPU threads per worker. Optional `--workers 2` runs independent ayahs concurrently with isolated WAV work files, using up to eight CPU threads without changing inference settings. It performs evaluation, not training, and never uploads recordings.
- Corpus previews use the app's eight-second window at a configurable four-second sampling hop, followed by its final bounded 30-second tail. This approximates window shape, not real-device inference cadence, microphone capture, or between-ayah transitions. To measure actual Hifz screen completion from the stored transcripts, run `flutter test --no-pub --dart-define=QURAN_ASR_EXPERIMENT=true --dart-define=ASR_CORPUS_DIR=/private/corpus-run test/widget/memorization_screen_test.dart --plain-name 'corpus replay'`. Per-ayah outcomes in `hifz-results/` and aggregate counts/stalled verse keys in `hifz-summary.json` distinguish accepted ayah completion (`hifz_completed`), UI session ending (`ui_session_finished`), and unaided text-match credit. The UI-ending metric is recorded separately to detect false completion (`ui_finished_without_accepted_completion`); a full retained preview alone must not end the session or disable Resume. If final recognition does not verify that preview, its words remain visible and unverified, and the user is asked to recite the ayah again. Test success means replay executed, not that every recording completed Hifz. Training-set overlap for these reciters is unknown. Studio recordings do not establish mistake-detection accuracy; independently reviewed omission/error recordings and phone microphone trials remain necessary. Tool checks run with `python3 -m unittest discover -s tool -p 'test_quran_asr*_eval.py'`.
- Invalid UTF-8 output is never silently replaced or turned into matchable text. Corpus replay records the raw stdout bytes as hex, labels that snapshot with `decoder_error`, and continues transcribing the rest of the recording. Such recordings have status `decoder_error`, are counted separately in progress, and cause a nonzero corpus exit. Hifz replay forwards stored recognition errors rather than granting credit from later snapshots; it does not retroactively simulate the native bridge's separate malformed-text retry.
- A complete paired replay of all 18,708 recordings increased accepted Hifz completions from 17,378 to 17,389 with exact split-word matching, and to 17,680 (+291 additional long-ayah recoveries across the 1,253 >30-second unaccepted cases) after sliding-window boundary reconciliation, with no accepted regressions. False UI completion fell from 144 to zero; unaided text-match credit stayed at 7,067. All 15,350 recordings with a normalized-exact final transcript completed, while 1,028 recordings remain unaccepted (962 over 30 seconds and 66 at or under 30 seconds, including three flagged decoder-error recordings). These are isolated-ayah replay results, not pronunciation accuracy or phone latency measurements; default-off context recovery was not part of this comparison.
- Native microphone startup can be checked independently of Quran content and playback with `flutter test integration_test/memorization_microphone_test.dart -d <device-id> --dart-define=RUN_NATIVE_MICROPHONE_TEST=true`. This opt-in check uses real microphone/speech permissions, discards transcripts, and checks two starts; it does not verify recognition accuracy. On the current iOS 26.4 simulator, the isolated first session still fails with native `error_unknown (300)` even after selecting the Mac microphone. The corresponding local speech service log reports failure to create its recognizer from an installed model asset (`_EARSpeechRecognizer is nil`). The live-preview feature does not resolve that native failure.
- Loading checks the full surah's verse count and consecutive ayah numbers. Complete-page loading checks every expected verse key against the Mushaf page boundaries and requires word and end-token line metadata. Incomplete neighboring-surah caches or missing line metadata show an explicit error/retry state instead of a partial or reflowed page. Full-Quran downloads are needed for complete shared pages offline.
- Comparison uses complete Quran.Foundation `text_imlaei`, not stripped Uthmani display glyphs. Missing references, omitted/extra/reordered words, and similar-looking substitutions cannot pass. Recognition uncertainty is not presented as a definitive recitation error.
- **Need a hint?** shows the current ayah's first two word tokens in place. **Reveal ayah and continue** skips it with assistance. Hint-assisted ayahs are distinguished from unaided word matches. Reference listening uses the selected reciter and existing audio cache; playback cancels microphone checking, and starting voice input stops reference audio. Entering Hifz stops background Reader audio. Leaving or backgrounding practice cancels both inputs.
- Arabic recognition uses the phone's speech service. Before any voice permission request, an eight-language consent screen explains that the platform may process audio remotely and that offline/Arabic availability varies. The app does not store recordings, transcripts, or memorization results.
- During voice startup, temporary inactivity from the system microphone/speech permission prompt does not cancel the attempt. Actual backgrounding or leaving the screen still cancels pending startup and ignores late results; inactivity after startup also cancels active input.
- This is word checking, **not pronunciation or Tajweed grading**. Ordinary speech recognition can mishear Quran recitation and may stop at pauses or truncate long ayahs. Physical-device accuracy, permission, audio-interruption, and offline trials are required before a store release. A Quran-trained recognizer would be a separate evaluated integration, not direct waveform comparison with the reference reciter.
- Disconnected-letter openings use spoken letter names (for example, **الم → ألف لام ميم**) in both continuous and ayah-by-ayah checking. Alif recognition variants such as `1000` and `١٠٠٠` are accepted only at the known opening positions; ordinary words remain strict and the displayed Mushaf text is unchanged. This does not evaluate letter pronunciation or madd duration.

### On-device Quran ASR lab experiment (iOS)

On the isolated `aebaid-hifz-asr-lab` branch, an enabled iOS lab build also uses
the local model for **Hifz → Recite from memory**. This lab now uses a strict
word-by-word preview by default in both continuous and ayah-by-ayah practice.
The **Live word preview (unverified)** switch is the first practice control
and can be disabled for strict final-check-only practice. Live preview shows only
the current ordered matching prefix while recording. In continuous lab practice,
already displayed words remain visible through shorter or contradictory recognition
revisions, including within a partial ayah. Only the immediately following
ayah can continue a dropped-prefix preview. If a later snapshot starts at the
same earlier position and contradicts a previously previewed word, it cannot
use retained words to bypass the mismatch or reveal new later words. Previously
displayed words stay visible as unverified, not as final match credit. An
ambiguous repeated opening is treated as a mismatch, not an ayah skip.
If a snapshot contains only the next missing word of a partially previewed
current ayah (for example `الرحيم` after `بسم الله الرحمن`), it can extend
that exact prefix without Pause/Resume, including after any contiguous
completed ayahs and before the audio window starts rolling. Empty or unrelated tail snapshots keep
the current visible prefix, but never reveal a later position; contradictory
snapshots that start at the earlier position still block at the first mismatch.
Live retries may also repeat the exact trailing words of that prefix, such as
`الرحمن الرحيم` after `بسم الله الرحمن`. Only an exact suffix-prefix overlap is
removed; a wrong word between the overlap and the missing word still blocks it.
These retained previews are still unverified and never advance match counters.
In continuous practice, every recognition ending retains the visible ordered
prefix: **Pause**, completion without a final
result, recognition errors, and app interruptions. A tail-only final snapshot
cannot erase earlier visible ayahs. A contradictory snapshot also keeps the
visible cursor but cannot extend it past that snapshot's mismatch. A tail-only snapshot can reveal the
matching prefix of the immediately next contiguous ayah even when an earlier
unfinished prefix was carried into the recording; it cannot bypass an unmatched
ayah or word. **Resume** (or **Retry**
after an error) continues at the next unrevealed word, including within an ayah.
Retained words remain labeled unverified; any ayah containing such words is
excluded from unaided-match credit. Turning off new live previews does not erase
this paused cursor. Disabling the switch discards only active, unsaved live
guesses, not earlier retained or final progress.

ASR spelling/phonetic recovery may reveal words, but cannot supply **unaided
matches**. Both continuous and ayah-by-ayah lab practice also check literal
transcript evidence, retaining support for disconnected-letter openings.
Two transcript tokens can recover one expected word only when their normalized
letters concatenate exactly, such as `بعد ما` for `بعدما`; neither missing
letters nor intervening words are discarded. This remains display recovery,
not literal match credit, and does not change ordinary platform recognition.
An ayah or unfinished prefix that needed correction remains unverified across
Resume; an exact retained prefix and a later exact suffix can still earn credit.
Ordered whole-ayah evidence can verify later exact ayahs without crediting an
earlier corrected one or counting a repeated ayah occurrence twice. Literal
transcript agreement is still not proof of correct pronunciation: the model
itself can hallucinate or fill in words.

The raw transcript remains hidden. The microphone
keeps capturing until **Pause**, an input error, or an app interruption, with no
session time cap. Only the latest 30 seconds of mono PCM16 audio are retained
in memory (at most 960,000 PCM bytes); older audio is discarded while the
microphone stays active. Serialized rolling audio snapshots first check after
one second of capture, then wait
500 ms after each inference finishes before checking again. Slow inference
never queues concurrent checks. These are scheduling delays, not measured word
reveal latency; checks may need more audio and more frequent inference can
increase heat and battery use, especially during longer sessions.
When a window rolls, the lab carries forward only the contiguous matching word
prefix, reuses exact normalized overlap with the next snapshot, and keeps those
earlier words unverified and excluded from match credit. This also tracks words
internally when live preview is off, without displaying them before Pause.
An unmatched word still blocks later text even if its audio has left the window;
Pause and Resume from that word to retry it. Windows do not skip over mistakes.
This is bounded chunked recognition, not a streaming model or a
promise of per-word latency. **Pause** checks the final snapshot before accepting
new words as final matches, while retaining earlier visible words separately.
In continuous practice, only the exact prefix before the first
mismatch is revealed; later matching words cannot bypass that position.
**Resume** starts a fresh recording at the indicated blocked word, retaining
earlier final prefixes without retaining incorrect suffixes. Spoken
words may repeat the current ayah's saved prefix, or its trailing words, when
restarting a recording. The lab removes only an exact normalized overlap with
that prefix, consistently for live and final checks; it never searches past a
wrong new word or skips an unmatched position. Spoken
disconnected-letter names must complete their single printed opening word before
it is revealed. The local Quran model also transcribes spoken letter names as
their printed opening (verified with the preserved Alafasy 2:1 clip returning
`الم`). Hifz requires explicit Alif, Lam, and Meem names for `الم` openings:
the compact token alone cannot reveal the opening or earn completion credit.
For other openings, lab matching accepts either representation only at the
authoritative opening position; ordinary platform recognition still requires
spoken names.
Standalone Quranic pause marks do not count as words when retaining a prefix,
and a pause mark attached to a printed word does not prevent its reveal.
This accommodates model spelling, not proof that every letter was pronounced
correctly. A final ayah with trailing extra words is not accepted; its
previously accepted prefix is retained. Ayah-by-ayah practice still requires a
complete ayah match. Hints show the next two words after the accepted prefix;
hints, explicit reveals, and reference listening mark the ayah as assisted.
For example, reciting `الرحمن العليم` at Al-Fatihah 1:3 reveals only `الرحمن`;
`الرحيم` remains hidden until matched, including after Pause and Resume.
Errors and interruptions checkpoint the visible prefix without giving it match credit.
Interim words never advance the confirmed ayah or match counters. **Pause**
stops capture immediately, requests cancellation of an unfinished lab preview,
and checks the final snapshot; **Resume** begins a new recording. Cancellation/backgrounding discards
late results. The shared fixed-line Mushaf renderer preserves line endings and
Hizb markers while masking/revealing words without reflow.

The local path is opt-in and non-Release, and its native channel is registered
only for the lab bundle identifier. Normal builds retain the existing platform
speech path. Audio snapshots are temporary and deleted after inference; the
bounded microphone buffer stays in memory and is discarded on finish/cancel.
The lab keeps a bounded 768 KiB local diagnostic file at
`tmp/quran-asr-diagnostics.jsonl` inside its own app container. It records
inference request/return times, audio-window durations, numeric error codes,
and numeric progress counters to diagnose live-versus-final stalls. This file
does not contain audio, recognized text, or reference text. When cloud
diagnostics are enabled, uploads retain up to 1 MiB of complete log records
from the current capture only. Each capture has its own ID, and the cloud
listing includes the iOS build number alongside the app version;
the backend retains recordings for up to 30 days, subject to a 1,000-recording
limit. Debug audio retention remains separately opt-in.
Version 2 progress records also include the recording start, displayed cursor,
raw mismatch position, and prefix counts for cumulative and exact-tail alignment.
Displayed totals include fully revealed ayahs, so committing a preview on Pause
does not look like deletion in diagnostics. These counters explain where matching
stops, not whether the learner actually pronounced a word correctly.
When a live preview reveals new words, the numeric `preview_reveal` diagnostic
records the audio position, the number of newly visible words, and
`snapshotToRevealMs`: time from requesting recognition to the end of the
Flutter frame that shows the words. It includes decoding and frame processing,
but not the time between speaking a word and requesting that snapshot.
Live recognition uses overlapping eight-second audio tails to reduce latency
and whole-ayah omissions in long hypotheses; Stop retains the last 30 seconds
for final recognition, so its audio window may start earlier than the latest
preview. Already completed previews remain unverified word progress; an unfinished
preview is cancelled to start the final check sooner, but its result is retained
if it finishes before cancellation takes effect. Missing or incorrect words still
block ordered matching.
Before that final check, Stop also decodes the last eight seconds of audio as a
tail preview when at least 0.25 seconds were recorded after the latest preview
window, because long finals can truncate their last words. The tail can only
extend a final that itself verified more words than the previews and ended at
its verified cursor (its last heard word is the last verified word or a
truncated start of the next word); it is joined at that cursor through the
same anchored checks, so a final that heard a wrong or missing word stays open.
Live windows may rejoin the retained prefix only at the verified cursor:
skipped window words must be garbled overlap context, and once a skipped word
exactly repeats a retained word the rest must repeat the retained suffix. A
repeated window over a fully retained ayah must repeat those words in order.
Lab spelling tolerance is limited to hamza seats, taa marbuta, alif maqsura,
the same letters split differently, and one-letter non-Quran ASR spellings
followed by the next two expected words.
Context recovery is **enabled by default in experimental lab builds** when
`--dart-define=QURAN_ASR_EXPERIMENT=true` is set; pass
`--dart-define=QURAN_ASR_CONTEXT_RECOVERY=false` to disable it. Ordinary builds
remain unaffected. Recovery starts its no-progress timer on the first valid
preview, even when it reveals zero words. With no visible words it makes at most
three attempts (12 seconds, then up to two 28-second contexts); if those do not
reveal a prefix, it stops retrying until visible progress occurs. After visible
progress, any advance resets recovery to 12 seconds, and attempts are separated
by at least eight seconds of audio. Inference remains serial, ordinary previews
remain eight seconds, and the final check remains 30 seconds.
Lab previews may also display the first word from a narrowly anchored
split-final-consonant correction. It is excluded from final matching and Hifz
credit, and does not advance later words from that transcript.
Only explicitly requested recovery responses may have an earlier window start;
their audio end cannot regress. Recovery does not bypass ordered matching,
contradiction checks, or unverified-credit restrictions, and never supplies
expected text to the model. This remains experimental and excluded from
distribution builds pending broader accuracy and physical-device latency,
memory, heat, and battery validation. A visible reveal gap is not itself a
speech-to-display latency measurement; pauses and prolonged recitation need
separate word-aligned audio review.
Exploratory paired trials across 213 distinct recordings from the same three
initial reciters (including 18 audio-omission controls) increased accepted
completions across the 195 positive fixtures from 55 to 85 with sliding-window
boundary reconciliation alone (recovery off), and from 85 to 135 (+50 additional
recoveries) with progressive 12→28-second context recovery enabled, without
losing an existing completion. The 18 retained audio-omission controls (12 short
and 6 strict long) remained unaccepted and UI-unfinished. These selected trials
do not estimate the recovery rate for all remaining full-corpus failures or
replace natural-error and live-microphone validation; strict long controls may
remove multiple words because public timing boundaries are ambiguous.

On the three held-out reciters for 2:255 and 2:282, progressive recovery
advanced one preview earlier but did not complete any of the six recordings.
Al-Shatri's 2:255 completed with recovery off after recognizing the exact
alternate ASR spelling `يأوده` for `يئوده` when followed by the expected word.
This lab-only correction does not count as literal unaided evidence. The other
five recordings remained unaccepted, and all 18 audio-omission controls stayed
blocked.

When changing pages, the lab keeps previously displayed partial words highlighted
as unverified. Returning to a page still starts at its first ayah; those saved
highlights do not skip words or grant match credit.
The lab build applies a local whisper.cpp CPU-backend patch so cancellation can
interrupt encoder graph execution; final decoding and its 30-second window are unchanged.
For an experimental GPU final pass, set `QURAN_ASR_METAL=1` when running the
lab build script. By default previews remain on the cancellable CPU backend. This option
uses CPU inference in the iOS simulator and requires physical-device
performance, memory, battery, and accuracy checks.
To test GPU previews separately on a physical device, also set
`QURAN_ASR_GPU_PREVIEWS=1`. GPU graph execution may not stop immediately when
Pause requests cancellation, so compare pause latency, recognition accuracy,
heat, and battery use against the CPU-preview build before adopting it.
For a separate device-only startup experiment, also set
`QURAN_ASR_PRECOMPILED_METAL=1` to package Metal shaders compiled at build time
instead of compiling them on the phone. This requires Apple's Metal toolchain
and has not yet been validated on physical devices.
For explicitly consented speech debugging only, the additional Dart define
`QURAN_ASR_RETAIN_DEBUG_AUDIO=true` enables retention in the separate lab app.
The consent dialog then explicitly discloses audio retention instead of claiming
all snapshots are deleted. Only the latest six inference snapshots (up to 30
seconds each) and their recognized text/timing metadata are kept for the latest
capture under `tmp/quran-asr-debug/`. Starting another capture clears those
snapshots; Hifz diagnostic uploads attach complete pairs only when debug audio
retention is enabled. This is off by default and does not retain audio supplied
through the standalone `checkWav` diagnostic path.
For transcript-only diagnostics in a test build, use
`QURAN_ASR_RETAIN_DEBUG_TRANSCRIPTS=true`. The consent dialog explains that
each recognized preview transcript is added to the current recording's
diagnostic log and uploaded with it; remote diagnostic reports are retained for
up to 30 days. Audio retention remains off unless its separate flag is enabled.
Transcript retention is off by default, and the archive/upload script enables
it for its TestFlight diagnostic build.
The near-silence filter is not full voice-activity detection. Human-recitation
accuracy, false matches, omissions, repetitions, timing, heat, and battery use
still need physical-device evaluation; text matches are not validated Hifz scores.

This opt-in screen is separate from Hifz scoring: **Hifz → DEBUG: On-device Quran AI → Record → Stop and check**. It records mono PCM16 audio at 16 kHz for at most 30 seconds, transcribes locally, and deletes its temporary recording after checking or cancellation. Cancelling inference discards its result; the native computation and deletion finish on the worker queue. Backgrounding or leaving the screen cancels the attempt. No audio is uploaded or persisted by this experiment; transcript diagnostics are separately gated by the build flag and explicit consent described above. Labels and warnings support all eight app languages.

The transcript is **unverified**, not a pronunciation/Tajweed assessment or proof of correct memorization. The near-silence RMS check rejects essentially inaudible input; it is not validated voice-activity detection and cannot prevent hallucinations from noise. Real microphone capture, interruptions, thermal behavior, and accuracy still require physical-iPhone trials.

The experimental native decoder normally uses single-beam greedy decoding (`best_of = 1`, `beam_size = 1`) with temperature fallback disabled to reduce preview and Stop latency. Local replay comparisons showed unchanged transcripts on the tested clips, but this may reduce recovery on difficult audio; validate accuracy and latency on an iPhone before relying on it.

Malformed or null native text segments trigger one logged, cancellable retry on
the same audio using beam size 3, without expected-text prompting. Partial text
from the failed attempt is discarded. The report's `invalidTextRetries` records
whether a retry occurred, and inference time includes both attempts. A second
malformed result or decoder failure remains an explicit error; invalid bytes are
never repaired or replaced. Counterfactual replay recovered one of the three
flagged corpus recordings, not all three. A macOS regression harness exercises
the actual bridge with stubbed model output and generated non-silent PCM audio:

```bash
mkdir -p build/native-tests
clang++ -std=c++17 -fobjc-arc -DQURAN_ASR_NATIVE=1 -DDEBUG=1 \
  -DQURAN_ASR_USE_METAL=0 \
  -I /absolute/whisper.cpp-1.9.5/include \
  -I /absolute/whisper.cpp-1.9.5/ggml/include \
  ios/Runner/QuranASRBridge.mm test/native/quran_asr_bridge_utf8_test.mm \
  -framework Foundation -framework AVFoundation \
  -o build/native-tests/quran-asr-utf8-test
build/native-tests/quran-asr-utf8-test
```

Prepare external artifacts, not repository assets:

- Use [whisper.cpp v1.9.5](https://github.com/ggml-org/whisper.cpp/tree/v1.9.5) and the Tarteel tiny snapshot `c3d7e624af5c81bef25a10a2af3a5a84cb4dd0f0` downloaded by the evaluator above.
- Convert that snapshot with the upstream `models/convert-h5-to-ggml.py`, supplying the model snapshot directory, OpenAI Whisper's assets directory (including `mel_filters.npz`), and an external output directory. The resulting fp16 `ggml-model.bin` is approximately 77 MB. Use an isolated Python environment with the evaluator dependencies and CMake.
- whisper.cpp is MIT-licensed; the model card declares Apache-2.0 and has incomplete training-data/limitations documentation. Keep upstream license/notice material with the external artifacts. No third-party source, model weights, or personal recordings belong in Git.

From the repository root, configure Flutter for the experiment, then build with explicit external paths:

```bash
flutter build ios --simulator --debug --config-only --no-pub \
  -t lib/main.dart --dart-define=QURAN_ASR_EXPERIMENT=true
bash tool/build_quran_asr_ios.sh /absolute/whisper.cpp-1.9.5 \
  /absolute/converted/ggml-model.bin /absolute/external-build \
  simulator CODE_SIGNING_ALLOWED=NO -quiet
```

Use `--dart-define-from-file=<private-debug-config>` only when explicitly testing the prelive content environment; never include those private debug defines in a store build. The experiment entry is independent of Quran-content loading. The script builds arm64 static libraries and Runner with invocation-only native flags, then adds the model to the resulting lab bundle. It uses the separate bundle identifier `com.ebaidllc.tajweedpractice.quranailab` and display name **Tajweed AI Lab**, so installation does not replace the store/TestFlight app. It does not install or upload anything.

**Physical iPhone builds use Profile mode**, which runs without a debugger. Flutter Debug builds on iOS 14+ exit when opened from the Home Screen without Flutter tooling or Xcode attached. Configure the phone build and then run the script:

```bash
flutter build ios --profile --config-only --no-pub --no-codesign \
  -t lib/main.dart --dart-define=QURAN_ASR_EXPERIMENT=true
bash tool/build_quran_asr_ios.sh /absolute/whisper.cpp-1.9.5 \
  /absolute/converted/ggml-model.bin /absolute/external-build \
  device -allowProvisioningUpdates -quiet
```

The script defaults to Debug for the simulator and Profile for the phone. `QURAN_ASR_CONFIGURATION=Debug` is available only for debugger-attached development; configure Flutter with the matching mode. `CODE_SIGNING_ALLOWED=NO` produces a compilation-only app; a signed device build requires development provisioning for the lab identifier, and the script re-signs after copying the model. Profile outputs are under `app/Build/Products/Profile-iphoneos/Runner.app`.

Clean ordinary builds do not link the engine or bundle the model. The UI requires a non-Release build and `QURAN_ASR_EXPERIMENT=true`. Native code requires `QURAN_ASR_NATIVE` plus either `DEBUG` or the invocation-only `QURAN_ASR_PROFILE` condition, and channel registration requires the separate lab identifier. The script refuses Release configuration. Keep experimental build outputs separate, and do not carry experimental flags or use experimental artifacts for distribution.

Widget/lifecycle checks:

```bash
flutter test --no-pub --dart-define=QURAN_ASR_EXPERIMENT=true \
  test/widget/quran_asr_experiment_screen_test.dart
```

Native channel tests use an explicitly supplied Alafasy 1:2 mono PCM16 16 kHz WAV, not a personal recording. Set `QURAN_ASR_BUILD_ACTION=build-for-testing` and `QURAN_ASR_REFERENCE_WAV=/absolute/reference.wav` for the build script. For a physical phone, configure Flutter with `--profile` as above and pass `ENABLE_TESTABILITY=YES` to the build script; do not use Debug for unattended device tests, whose host can exit before XCTest starts because no Flutter debugger is attached. Then run `xcodebuild test-without-building -xctestrun <external-build>/app/Build/Products/Runner_<sdk>-arm64.xctestrun -destination 'platform=iOS,id=<device-id>' -only-testing:RunnerTests/QuranASRChannelTests -parallel-testing-enabled NO`. For a simulator, use the Debug build and an `iOS Simulator` destination instead. Read the actual test count: all nine channel tests must execute, covering bounded diagnostics, audio capture/conversion and 12/28-second recovery-window bounds, recovery request validation, repeat reference decoding, 12-second and 28-second repeated-reference decode latency checks (~1.22s on iPhone 15 Pro), malformed-input recovery, and cancellation/concurrent-work rejection. These are not live-microphone or thermal/battery benchmarks. The lab-only `checkWav` channel accepts typed WAV bytes, not arbitrary filesystem paths.

If signing reports **No Accounts** or **No profiles** for the lab identifier, add the Apple developer account in **Xcode → Settings → Accounts**, then create/download a development provisioning profile for `com.ebaidllc.tajweedpractice.quranailab`. The ordinary app's profile cannot sign a different identifier. Do not change the lab back to the ordinary identifier to bypass this requirement.

### API attestation
- `QuranAttestationService` owns token caching and request coalescing, and delegates the platform handshake to an `AttestationProvider`
- `AppAttestProvider` registers an Apple App Attest key and generates assertions; every other platform gets `UnsupportedAttestationProvider` and fails closed
- Adding Android support means adding a `PlayIntegrityProvider` and a case in `QuranAttestationService._providerFor`; nothing else changes
- The Cloudflare Worker validates Apple's certificate chain, app identity, one-time challenge, and monotonic assertion counter
- Successful assertions receive environment-bound bearer tokens valid for ten minutes
- Protected `/v2/content` routes reject missing, forged, expired, or cross-environment tokens
- App Attest private keys remain in Apple's Secure Enclave; only the key identifier is stored locally

### Offline support
- Hive caches fetched verses, translations, Tafseer, recitation metadata, and
  audio file paths for app features only
- Quran text is revalidated when its last successful validation is seven days
  old; checks run at startup, on foreground resume, every 12 hours while the app
  remains open, and promptly after connectivity returns
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
- Quran.Foundation Developer Terms:
  https://api-docs.quran.com/legal/developer-terms/
- Quran.Foundation Developer Privacy Policy Packet:
  https://api-docs.quran.foundation/legal/developer-privacy/
- Audio CDN: https://verses.quran.com/{reciterId}/{surah}{ayah}.mp3
- Amiri Quran font: https://github.com/aliftype/amiri

---

## Public documentation

- Product page: https://ahmed-ebaid.github.io/tajweed_app/
- Privacy Policy: https://ahmed-ebaid.github.io/tajweed_app/privacy-policy.html
- Terms of Use: https://ahmed-ebaid.github.io/tajweed_app/terms-of-use.html
- Support: https://ahmed-ebaid.github.io/tajweed_app/support.html

---

## App Store release

The public version is read from `pubspec.yaml` in `<marketing>+<build>` form:
`1.1.1+63` produces App Store version **1.1.1** and internal build **63**.
Increment the build number for every upload, even when the marketing version
is unchanged — App Store Connect rejects a duplicate build number.

Before submission:

1. Run the complete Flutter test suite and analyzer.
2. Run the release integrity gate documented above.
3. Archive with the production Quran proxy configuration and export the IPA.
4. Confirm the hosted Privacy Policy, Terms of Use, and Support URLs.
5. Upload current App Store screenshots, complete listing metadata, and submit
   the accepted build for App Review.

Prepared English listing copy, review notes, and the screenshot plan are in
`release/app-store-listing.md`.
