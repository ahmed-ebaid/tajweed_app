# Google Play listing — Tajweed Practice

Adapted from `release/app-store-listing.md`. Apple-specific wording is removed:
the share text references Google Play rather than the App Store, and the
attestation note describes Play Integrity rather than App Attest.

## Store settings

| Field | Value |
| --- | --- |
| App name | `Tajweed Practice` |
| Package | `com.ebaidllc.tajweed_practice` |
| Default language | English (United States) |
| App or game | App |
| Category | Education |
| Tags | Learning, Reference |
| Contains ads | No |
| In-app purchases | No |
| Content rating | Everyone (no violence, no user-generated content) |

## Contact details

| Field | Value |
| --- | --- |
| Email | Ebaid LLC support address |
| Website | https://ebaidllc.com/ |
| Privacy policy | https://ahmed-ebaid.github.io/tajweed_app/privacy-policy.html |
| Support | https://ahmed-ebaid.github.io/tajweed_app/support.html |

## App name (max 30)

```
Tajweed Practice
```

## Short description (max 80)

```
Read the Quran with color-coded Tajweed, audio recitations, and Tafseer.
```

## Full description (max 4000)

```
Build a more confident Quran reading practice with Tajweed.

Tajweed Practice combines a clear Ayah-by-Ayah reader and a text-rendered Mushaf with color-coded Tajweed guidance. Tap highlighted text to understand the rule, listen to recitations, and revisit the rule library whenever you need a refresher.

READ AND UNDERSTAND

• Read the Quran Ayah by Ayah or in a 604-page Mushaf layout
• View translations in English, Arabic, Urdu, Turkish, French, Indonesian, German, and Spanish
• Explore verse-by-verse Tafseer from available sources
• Bookmark Ayahs and return to your reading position

LEARN TAJWEED

• See color-coded Tajweed rules directly in Quran text
• Open clear rule explanations and Quran examples
• Listen to focused pronunciation examples using Al-Husary Al-Muallim
• Practice with lessons and quizzes

LISTEN AND PRACTICE

• Choose from multiple Quran reciters
• Download selected recitations and Tafseer for offline use
• Track daily learning progress and streaks

SHARE

Share an Ayah, Tafseer passage, or Tajweed rule through your favorite apps. Shared content identifies Tajweed Practice and includes a link to the app on Google Play.

PRIVACY

No account is required. The app does not use advertising, analytics, or cross-app tracking. Bookmarks, progress, and preferences remain on your device.

Quran text, translations, Tafseer, recitation metadata, audio, and content updates are provided through Quran.Foundation APIs and services associated with the Quran.com ecosystem. Tajweed Practice is independently operated by Ebaid LLC and is not an official Quran.Foundation, Quran.com, or QuranReflect app.
```

## Data safety questionnaire

The app collects and shares nothing, which makes this section short. Answers:

- **Does your app collect or share any of the required user data types?** No.
- **Is all of the user data collected by your app encrypted in transit?** Yes —
  all API traffic goes over HTTPS to the Cloudflare Worker.
- **Do you provide a way for users to request that their data is deleted?** Not
  applicable; no user data leaves the device.

Justification: bookmarks, progress, streaks, and preferences are stored locally
in Hive. The only network calls fetch Quran content. There is no account, no
analytics SDK, no advertising SDK, and no crash reporting SDK.

## Permissions

Present in the merged release manifest:

- `INTERNET` — fetch Quran text, translations, Tafseer, and audio.
- `ACCESS_NETWORK_STATE` — added by the networking plugins to detect
  connectivity before a request.
- `<package>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` — added automatically by
  AndroidX for its internal broadcast receivers.

None of these is a Play "sensitive" permission, so no declaration form is
required.

Note: recitation playback continues in the background on iOS but not on
Android. Android background playback needs a media foreground service
(`audio_service`), which this app does not yet integrate, so the listing copy
deliberately avoids claiming it.

## Screenshot captions

Captions are optional on Play and are not overlaid on the uploaded images. Use
these if promotional variants are produced later:

1. Home and progress — "Build a consistent Quran practice"
2. Ayah reader — "Read with clear Tajweed guidance"
3. Interactive word guidance — "Tap highlighted text to learn the rule"
4. Mushaf view — "A focused 604-page reading experience"
5. Tafseer and translations — "Read, reflect, and understand"
6. Quiz — "Practice what you learn"
7. Rules Library — "Explore every Tajweed rule"
8. Rule detail and audio — "Understand and hear each rule"

## Release notes (max 500)

```
• New Tafkheem, Tarqeeq, and Waqf & Ibtida learning pages
• Localized explanations, highlighted Quran examples, and focused audio
• New Hamzat al-Qat rule with quiz examples
• New six-step onboarding guide in all eight app languages
• Audio highlighting now follows the reciter's actual word timing
• Improved rule details, quizzes, captions, and audio controls
• Fixed Waqf symbol layout, Tarqeeq wording, and Arabic text
```
