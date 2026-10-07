# App Store listing — Tajweed 1.1.16

## App information

- **App Store name:** Tajweed Practice
- **Device display name:** Tajweed
- **Subtitle:** Read, Listen & Learn Tajweed
- **Primary category:** Education
- **Secondary category:** Reference
- **Copyright:** © 2026 Ebaid LLC
- **Version:** 1.1.16
- **Build:** 89
- **Release stage:** App Store Connect / TestFlight only; not submitted for review.

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

Corrects silent-letter quiz examples and explains the difference between
the rounded-zero sign and sukoon. Expands Hamzat al-Wasl guidance with
starting-vowel examples, completes Spanish rule explanations and tips,
and improves rule-label layout on narrow screens.

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
