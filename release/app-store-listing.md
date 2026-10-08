# App Store listing — Tajweed 1.1.17

## App information

- **App Store name:** Tajweed Practice
- **Device display name:** Tajweed
- **Subtitle:** Read, Listen & Learn Tajweed
- **Primary category:** Education
- **Secondary category:** Reference
- **Copyright:** © 2026 Ebaid LLC
- **Version:** 1.1.17 (submitted for review); 1.1.16 remains live until approval.
- **Build:** 93 (live App Store version) / 94 (internal TestFlight).
- **Release stage:** 1.1.17 (94) submitted to Apple, verified
  `WAITING_FOR_REVIEW`. Build 93 remains live until approval.
- **Release setting:** Automatic release after approval.
- **Submission:** 4ece26fa-df40-4f2f-b590-b720a4e702c0
- **App Store version ID:** 36636462-e787-4e73-8e93-3f5906d4b61c
- **Store assets:** All 160 inherited screenshots verified unchanged; What's New
  updated in all eight store languages.
- **TestFlight status:** 1.1.17 (94) uploaded, Apple-validated (`VALID`), and
  available to the internal Tajweed Testers group (`IN_BETA_TESTING`).
  What to Test notes are verified in all eight languages.
- **TestFlight build ID:** 5a4f04c6-0054-4843-82df-687ef3c9ef9f
- **Public release:** 1.1.16 (93) remains `READY_FOR_SALE`. Version 1.1.17's
  build attachment is verified as build 94; automatic release follows approval.
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

Clearer Tajweed examples with larger text, improved hamza visibility, and
spacing that adapts to text size. Improved rule layouts and explanations in
all eight languages. Corrected Quranic sukoon in Hamzat al-Wasl teaching
examples and more readable shared guidance. Fixed reading-position jumps
when changing surahs in ayah-by-ayah mode.

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
