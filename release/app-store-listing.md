# App Store listing — Tajweed 1.1.20

## Localized Tajweed corrections — 1.1.20 (100)

- **Status:** Submitted to both stores on 2026-10-18. Apple build 100 is
  `VALID` and version 1.1.20 is `WAITING_FOR_REVIEW`, with automatic release
  after approval. Google Play production versionCode 100 and `completed`
  rollout status were re-read successfully. This does not establish Google
  review approval or public availability. Other Play tracks and screenshots
  are unchanged.
- **Sukoon:** Authored learning and quiz examples use the Quranic small-head
  haa mark (U+06E1), with matching letter-level highlights. The rounded-zero
  silent-letter examples and intentional circular-sukoon comparison remain.
  Source Quran data and reader layout are unchanged.
- **Ghunnah:** All eight languages distinguish the nasal outlet of ghunnah
  from noon's tongue-tip/upper-gum articulation and meem's two lips.
- **Hamzat al-Wasl:** Localized starting-vowel steps distinguish the definite
  article from other following lams, original third-letter dammah from
  incidental dammah, and kasrah starts in verbs and wasl nouns.
- **Tafkhim:** Every localized article pairs each of the five degrees with a
  qaf example: قَالَ, قَتَلَ, قُلۡ, يَقۡطَعُونَ, and قِيلَ.
- **Android configuration:** Built through
  `release/build_android_release.sh appbundle` with explicit
  `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER=312770688680`. The previous attestation
  hotfix and fail-closed safeguards are retained.
- **Validation:** 397 tests passed with the full 6,236-ayah words fixture;
  two fixture/manual checks were skipped. Analysis completed without errors.
  Both artifacts were verified as version 1.1.20, build 100. No physical-device
  verification of build 100 has been performed.
- **Artifacts (SHA-256):** Android bundle
  `4e216a488c6aa2a1c67580c62567b1ae285a978126a80cdef2b5f1d17ea33177`;
  iOS IPA
  `741ff6450602e50291e7dcc2ee0a5f94d0e7c6a566302e680d54fa5a40625180`.

## Android attestation hotfix — 1.1.19 (99)

- **Status:** 1.1.18 (98) uploaded to Google Play internal testing on 2026-10-18.
  The user confirmed that internal-testing version works on their device.
  The same fix was rebuilt as 1.1.19 (99) so the displayed version distinguishes
  it from affected 1.1.18 installations. Build 99 was uploaded to internal
  testing, then submitted to production on 2026-10-18 with user authorization.
  Production versionCode 99, `completed` rollout status, and eight localized
  release notes were re-read successfully; non-production tracks are unchanged.
  This API status does not confirm review approval or public availability.
  iOS is unchanged by this hotfix.
- **Incident:** Android builds 96 and 97 were built without the guarded release
  script and omitted `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER`. The app rejected
  attestation locally before requesting an integrity token. Fresh installs are
  affected; cached Quran content can mask the failure on existing installs.
  Reinstalling or changing the Worker cannot repair an affected binary.
- **Fix:** The public production project number `312770688680` is now embedded
  as the app default, including builds with no Dart defines. Explicit invalid
  configuration still fails closed; integrity verification is not bypassed.
- **Prevention:** A regression test starts the Android attestation service with
  empty storage and no build flags and verifies the challenge/token exchange
  uses the production project. CI runs it explicitly before the guarded build.
  Gradle also rejects invalid explicit project-number overrides before release
  compilation, even when the build wrapper is not used.
- **Release build:** Use `release/build_android_release.sh appbundle` with
  `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER=312770688680`.
- **Validation:** 390 Flutter tests passed; six fixture/manual tests skipped.
  Analysis completed with no errors. An ordinary Flutter release build with
  an explicit project number of zero was rejected by the Gradle guard. Signed
  bundle SHA-256:
  `34f364187f3c11095c51f22f4dd626b9edd95aa03b7dab3a175fc66486c49922`
  (build 98). Build 99 passed the version and attestation tests and was built
  through the same guarded script with project number `312770688680`.
  Build 99 bundle SHA-256:
  `0b989c5ffc9ad981ee4fca26cfdc8dafdbcc53f48b44a70b6a5fc2ea90d2ba12`.
- **Device verification:** The user confirmed the internal-testing version
  works before authorizing production submission. Build 99 is a version-label
  rebuild of that fix, not a separately device-tested build.

## App information

- **App Store name:** Tajweed Practice
- **Device display name:** Tajweed
- **Subtitle:** Read, Listen & Learn Tajweed
- **Primary category:** Education
- **Secondary category:** Reference
- **Copyright:** © 2026 Ebaid LLC
- **Version:** 1.1.18 (live); 1.1.20 (submitted for review).
- **Build:** 97 (live App Store version) / 100 (submitted for review).
- **Release stage:** 1.1.20 verified `WAITING_FOR_REVIEW`.
  All eight localized release notes and 160 inherited screenshots verified.
- **Release setting:** Automatic release after approval.
- **Submission:** d5d46905-cfd7-4158-8a5c-958cf7340ea6
- **App Store version ID:** 7f2be577-8f4f-4fc3-a7fb-7925ebaa0cd9
- **Store assets:** All 160 inherited screenshots verified unchanged; What's New
  updated in all eight store languages.
- **TestFlight status:** 1.1.20 (100) uploaded and Apple-validated (`VALID`),
  assigned to the internal Tajweed Testers group. Localized What to Test notes
  are configured in all eight languages.
- **TestFlight build ID:** 0a8211d5-7bd4-47e7-bb6e-50a3f3a76dc3
- **Public release:** 1.1.18 (97) verified `READY_FOR_SALE`; unchanged by this upload.
- **Google Play (historical build 97):** Matching 1.1.18 (97) bundle uploaded and production-track edit
  committed and re-read successfully. Store review/public availability is not
  established by the track's `completed` rollout status. Other tracks and
  screenshots were not changed.
- **Build 96 changes:** Includes build 95 corrections plus large, localized
  sukoon/rounded-zero comparisons in rule details and reader word sheets.
  Explains circular ordinary Arabic sukoon versus the Madani mark convention.
  Source Quran glyphs, line endings, and zoom controls remain unchanged.
- **Build 97 changes:** Clarifies in all eight languages that the
  closed rounded zero marks an unpronounced written ا، و، or ي, and only the
  marked letter is omitted; the other letters are not inherently silent.
- **Build 97 regressions:** Full Flutter test suite passed. Both signed store
  artifacts use version 1.1.18, build 97; the release notes are localized in
  all eight store languages.
- **Build 96 regressions:** 392 tests passed with both corpus fixtures; one
  intentionally disabled manual utility remains skipped. Both signed store
  artifacts use version 1.1.18, build 96.
- **Build 95 changes:** Opening-letter madd guidance distinguishes two and six
  counts in all eight languages, including alif and ayn exceptions and the
  separate durations in Alif-Lam-Meem and Ha-Meem. The intermediate izhar
  example uses `مَنْ ءَامَنَ` with the separate Quranic hamza and corrected
  highlight. Rules, word details, and quiz feedback share the corrections.
  No Mushaf image or scrolling changes are included.
- **Build 95 regressions:** 390 tests passed with both Quran fixtures; only the
  intentionally disabled manual utility is skipped.
- **Build train:** Apple closed 1.1.16 to new builds after release, so build 94
  uses 1.1.17. The initial 1.1.16 (94) upload was rejected with error 90186.
- **Build 94 mark clarity:** Hamzat al-Wasl examples and tips use the Quranic
  small-head sukoon (ۡ), not ordinary Arabic sukoon or rounded zero. Explanatory
  prose and shares omit tiny standalone mark glyphs; Quran text and marked
  examples remain unchanged.
- **Build 94 example layout:** Larger library and word-detail examples, stronger
  neutral-letter contrast, and extra line height protect hamza and Quran marks.
  Hamza highlights include their attached vowels without changing Arabic joining.
  These shared widgets apply to all eight localizations.
- **Build 94 stop signs:** Standalone stop-sign chips reuse the readable display
  symbols from the detailed Waqf table; Quran quotations keep their original
  combining signs. Library titles wrap, and duplicate Arabic subtitles are omitted.
- **Build 94 regressions:** 388 tests passed with both full-corpus fixtures
  supplied. Only the intentionally disabled manual example-discovery utility
  is skipped; no regression check is skipped.
- **Build 94 reader navigation:** Surah changes clear old content before async
  connectivity checks. Scroll restores and retries are scoped to their original
  load and scroll request, with old restore guards cancelled on navigation.
- **Build 93 highlighting fix:** Noon/tanween rules color the tanween marks
  separately from the neutral carrier letter. Following trigger letters retain
  their annotations. Pixel-geometry and reader/detail interaction regressions
  cover As-Sajdah 32:15 and other tanween cases. These fixes were not in build 92.
- **Build 92 sharing fix:** Explanatory rounded-zero and sukoon symbols are shown
  on illustrative letters (و۟ and بۡ), rather than as unattached combining marks,
  in guidance and text shares. Quran quotations retain their source characters.
  This fix was not included in build 91.
- **Build 91 changes:** Remove duplicate Arabic rule subtitles, align tip
  bullets to the first text baseline, and restore canonical rounded-zero marks
  where upstream Tajweed-tagged words substitute sukoon on silent letters.
  Full-corpus regression checks cover all 6,236 ayahs and preserve all other
  word characters and highlight offsets. These fixes were not in build 90.
- **Build 90 changes:** Render standalone rounded-zero and sukoon marks with
  the bundled Quran font and a neutral carrier in rule guidance and quiz
  explanations. This rendering fix is not included in uploaded build 89.
  Silent-letter highlights now use a distinct blue-cyan palette color rather
  than gray, shared by examples, reader highlights, and the legend. Rule examples
  default to the bundled Quran font.

## URLs

- **Support:** https://ahmed-ebaid.github.io/tajweed_app/support.html
- **Privacy Policy:** https://ahmed-ebaid.github.io/tajweed_app/privacy-policy.html
- **Terms of Use:** https://ahmed-ebaid.github.io/tajweed_app/terms-of-use.html
- **Marketing:** https://ebaidllc.com/

## Promotional text

Read the Quran with color-coded Tajweed guidance, listen to trusted reciters,
explore translations and Tafseer, and build a consistent learning practice.

## Keywords

quran,tajweed,recitation,tafseer,ayah,mushaf,arabic,islamic,memorization,muslim

## Description

Build a more confident Quran reading practice with Tajweed.

Tajweed combines a clear Ayah-by-Ayah reader and a text-rendered Mushaf with
color-coded Tajweed guidance. Tap highlighted text to understand the rule,
listen to recitations, and revisit the rule library whenever you need a
refresher.

READ AND UNDERSTAND

- Read the Quran Ayah by Ayah or in a 604-page Mushaf layout
- View translations in English, Arabic, Urdu, Turkish, French, Indonesian,
  German, and Spanish
- Explore verse-by-verse Tafseer from available sources
- Bookmark Ayahs and return to your reading position

LEARN TAJWEED

- See color-coded Tajweed rules directly in Quran text
- Open clear rule explanations and Quran examples
- Listen to focused pronunciation examples using Al-Husary Al-Muallim
- Practice with lessons and quizzes

LISTEN AND PRACTICE

- Choose from multiple Quran reciters
- Download selected recitations and Tafseer for offline use
- Track daily learning progress and streaks

SHARE

Share an Ayah, Tafseer passage, or Tajweed rule through your favorite apps.
Shared content identifies Tajweed Practice and includes the App Store link.

PRIVACY

No account is required. The app does not use advertising, analytics, or
cross-app tracking. Bookmarks, progress, and preferences remain on your device.

Quran text, translations, Tafseer, recitation metadata, audio, and content
updates are provided through Quran.Foundation APIs and services associated with
the Quran.com ecosystem. Tajweed Practice is independently operated by Ebaid LLC
and is not an official Quran.Foundation, Quran.com, or QuranReflect app.

## What's New

Quran-style small-head sukoon in learning and quiz examples. Corrected noon
and meem articulation points and clarified that the nasal cavity is the outlet
of ghunnah only. Clearer steps for starting with hamzat al-wasl, including
temporary-damma exceptions. Added an example for each of the five degrees
of Tafkhim.

## Previous improvements retained

Mushaf view now follows night mode, including its page background, text,
headers, and reading controls. The Tajweed color controls and related Mushaf
messages follow the selected app language, including Arabic.

A refreshed Home screen makes it easier to start or continue reading, with
clearer text and surah names. Corrects tanween highlighting, including ikhfa,
so neighboring letters are not highlighted. Home ayah numbers and lesson
progress follow your selected language.

Fixes word-detail highlighting: only the letters and marks belonging to the
selected Tajweed rule are colored, instead of the whole word. The detail
sheet retains the same annotated word used by both reader layouts.

When a Tajweed rule spans adjacent words, the word-detail header now shows the
complete linked phrase and highlights the rule on each side. This includes
cross-word Idgham, Ikhfa, Iqlab, and Madd Munfasil.

Madd al-Farq uses the same expandable row as the other Madd rules, sorted
inside their shared group rather than shown as a separate article card.
All educational article details, including Core Recitation Rules and More
Topics, offer localized text sharing with a correctly anchored iPad share sheet.

The Android 1.1.15 (88) release also includes all improvements since its
previous production version, 1.1.10 (76). See `play/listing.md`.

## Screenshot set

Use clean device captures with no personal notifications, debug banners, or
test data. Keep Quran text unchanged; marketing captions belong outside the app
capture and must not obscure Quran content.

1. **Home** — “Reflect with the Quran”
2. **Ayah reader** — “Read with clear Tajweed guidance”
3. **Tafseer and translations** — “Read, reflect, and understand”
4. **Mushaf view** — “A focused 604-page reading experience”
5. **Quiz** — “Practice what you learn”
6. **Rules Library** — “Explore every Tajweed rule”
7. **Rule detail and audio** — “Understand and hear each rule”
8. **Offline settings** — “Keep selected content available offline”
9. **Interactive word guidance** — “Tap highlighted text to learn the rule”
10. **Language selector** — “Read in eight supported languages”

Capture at least:

- one current large-iPhone portrait set; and
- one current 13-inch iPad portrait set because the binary supports iPad.

App preview video is optional. The 1024×1024 App Store icon is already included
in `ios/Runner/Assets.xcassets/AppIcon.appiconset`.

The reproducible simulator capture harness is
`integration_test/app_store_screenshots_test.dart`. It uses local fixture data
and does not bypass App Attest in production code.

For a first-image-only refresh, pass `--dart-define=HOME_ASSETS_ONLY=true` to
the capture harness and set `SCREENSHOT_OUTPUT_DIR` to the desired output
directory. Capture all eight languages separately on iPhone and iPad, then
replace only `01-home.png` in each localized screenshot set. Preserve the
remaining images and their order.

The build 82 refresh uses 1320×2868 iPhone captures and 2064×2752 iPad captures.
The Spanish iPad set had an eleventh image, an identical duplicate of
`08-settings.png`; the extra copy was backed up and removed to satisfy Apple's
ten-image limit. All other existing screenshots are retained.

## App Review notes

Tajweed Practice is independently owned and operated by Ebaid LLC.
Quran.Foundation Content API requests are routed through an Ebaid LLC
Cloudflare Worker and protected by Apple App Attest. No login is required, and
the App does not request microphone or speech-recognition permission.

To review the updated Mushaf, open any Surah, switch to page view, and rotate
the device to compare portrait and landscape alignment. Green Hizb markers in
the page margin are tappable and announce the numbered Hizb boundary. Ayah
markers follow the QCF V2 printed-line metadata.

## Manual App Store Connect confirmations

- Production Workers Logs are disabled. Cloudflare may process ordinary
  connection and App Attest information in real time, but the app does not
  retain request-level logs or transmit bookmarks, progress, or preferences.
- Complete age-rating and content-rights questionnaires.
- Confirm pricing, availability, review contact, and review phone number.
- Keep the approved screenshot sets and select build 61.
