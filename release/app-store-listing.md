# App Store listing — Tajweed 1.1.3

## App information

- **App Store name:** Tajweed Practice
- **Device display name:** Tajweed
- **Subtitle:** Read, Listen & Learn Tajweed
- **Primary category:** Education
- **Secondary category:** Reference
- **Copyright:** © 2026 Ebaid LLC
- **Version:** 1.1.3
- **Build:** 65

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

Tajweed 1.1.3 sharpens the Tajweed colouring and finishes the translation work.

- Added Madd 'Arid lis-Sukun and Madd Lin, and split Madd Lazim into its types
- More accurate Tajweed colouring: Ikhfa now covers only the letter it applies
  to, and rules are no longer dropped on words carrying a shaddah
- Waqf signs now sit above the harakah instead of overlapping it
- The app follows your device language on first launch
- Al-Husary (Muallim) is now the default reciter
- Bookmark and ayah labels are translated instead of always showing English
- The onboarding guide is fully translated and now shows the real screens it
  describes
- Choosing a Tafsir source no longer hides the Tafsir you are reading

## Screenshot set

Use clean device captures with no personal notifications, debug banners, or
test data. Keep Quran text unchanged; marketing captions belong outside the app
capture and must not obscure Quran content.

1. **Home and progress** — “Build a consistent Quran practice”
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
