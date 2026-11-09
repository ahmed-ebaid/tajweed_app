# App Store listing — Tajweed 1.1.24

## Reader-only TestFlight upload — 1.1.24 (108)

Complete Quran pages fit the available screen without vertical scrolling.
Words stay on their original printed lines, with ayah-marker positions and
Hizb marks preserved. Compact page metadata and fixed-line spacing work in
portrait and landscape, with light/dark themes, Tajweed colors, and pinch zoom.
Missing line metadata shows an explicit retry state instead of reflowing text.

This build excludes the experimental Hifz tab, memorization shortcut, speech
plugin, native Quran ASR, model assets, and microphone/speech permissions.
Hifz development is preserved separately on `aebaid-hifz-asr-lab`; it is not
part of this release candidate. Production endpoints and attestation remain
unchanged; no prelive, test-token, or ASR defines are used.

The signed IPA is version 1.1.24, build 108, with bundle identifier
`com.ebaidllc.tajweedpractice`. Uploaded on 2026-11-09; Apple processing is
`VALID` and internal testing is `IN_BETA_TESTING`. Membership in the existing
**Tajweed Testers** internal group and all eight localized testing notes were
re-read and verified. This is internal TestFlight testing only, not an App Store
review submission or public release. Production 1.1.23 remains `READY_FOR_SALE`;
Google Play is unchanged.

- **Apple build/delivery ID:** `c58180e0-1836-49b3-a8ed-4837190e1529`.
- **IPA SHA-256:**
  `b687c9485192bad864bbca0726ea981ca9e57a60e7c3e9765c34f830fe30c9a0`.
- **Validation:** 78 targeted layout, theme/localization, navigation, review,
  attestation, API, and audio regressions pass. Two additional actual-page
  checks cover pages 1, 2, 22, 255, 300, 528, 593, 600, and 604, including
  small portrait/landscape, printed word/marker order, and page 22's Hizb.
  The signed archive and packaged IPA were inspected for identity, production
  defines, and absence of Hifz/speech/ASR artifacts. Physical-device visual
  evaluation remains the purpose of this TestFlight build.

## Historical TestFlight Hifz improvements — 1.1.24 (107), testing only

Build 107 added a fifth, localized **Hifz** tab with surah selection,
visible-text Review, and continuous recitation practice. Final recognition
segments can reveal several completed ayahs in Quran order without Next taps;
recognition ending provides Resume, not an unlimited microphone promise.
On-demand opening-word hints and full-ayah reveals are marked as assisted.
The complete Reader Mushaf page is preserved, including neighboring surahs,
word/end-token line breaks, Juz and Hizb markers. Incomplete page data is rejected.
These changes are included in **build 107**, uploaded on 2026-11-08.
Apple processing is `VALID` and internal testing is `IN_BETA_TESTING`.
The existing **Tajweed Testers** internal group has automatic access to all
builds; build 107 membership was verified. All eight localized testing notes
were re-read and verified. External beta review was not submitted.
No App Store review submission or public release was made; production
1.1.23 remains `READY_FOR_SALE`. Google Play is unchanged.
- **Apple build/delivery ID:** `b3dd7cae-e8c0-4778-bff5-ff0d259f456b`.
- **IPA SHA-256:**
  `2614bc249f2a37d33d1945669715208d4ab1ebf59fcd40a87eba93407a52ab88`.
Validation: 165 targeted regression tests passed, including shared-page
geometry in portrait/landscape and light/dark mode, Hizb preservation,
opening-word hints, recognition cancellation, and actual Hifz-tab navigation.
Targeted analysis is clean; the arm64 iOS simulator and signed release IPA
builds succeed. Exported version 1.1.24 (107) and all eight localized native
permission resources were verified.
Physical-device speech accuracy remains unverified.

## Historical App Store Connect upload — 1.1.24 (106), testing only

- **Scope:** Experimental, opt-in Arabic word checking for full-surah
  memorization in Mushaf view, with hints, reference recitation, cross-page
  progression, Juz metadata, and eight-language controls and voice consent.
  Recognized words are checked; pronunciation and Tajweed are not graded.
- **Apple:** Signed IPA uploaded successfully on 2026-11-08. Delivery UUID:
  `c5e4db32-4210-492f-bf43-a0ddadf07b16`. Apple processing reached `VALID`;
  version 1.1.24 and build 106 were re-read and verified.
  No App Store review submission or production release was requested.
- **IPA SHA-256:**
  `8e866a29551d7a1678684fe1a74255ef6cfbf7336c2ccfd9ea0414acb3f00f3f`.
- **Validation:** 110 targeted regression tests passed. The exported IPA
  contains version 1.1.24, build 106, and all eight localized microphone and
  speech-recognition permission resources. Physical-device recitation accuracy
  and permission/audio-interruption trials remain outstanding.
- **Google Play:** No upload or track changes.

## Production submission — 1.1.23 (105)

- **Scope:** Fixes native review scheduling when eligible readers immediately
  leave Home. Pending requests wait during onboarding, modal routes, quizzes,
  reader audio, and backgrounding. Eligibility is captured at launch, and the
  120-day attempt cooldown is unchanged. The store still controls display.
- **Apple:** Submitted on 2026-11-02; verified `WAITING_FOR_REVIEW` with
  automatic release after approval (`AFTER_APPROVAL`). Build 105 is attached.
  Eight localized release notes and all 160 inherited screenshots were verified.
  The build is assigned to the internal TestFlight group.
- **Google Play:** Signed bundle 105 uploaded to production with status
  `completed`; versionCode, all eight localized notes, and bundle SHA-256 were
  re-read and verified. Other tracks, including internal testing, and listing
  screenshots are unchanged. Public availability and review approval have not
  been established by this API status.
- **Android safeguards:** Built using
  `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER=312770688680 release/build_android_release.sh appbundle`.
  The project number is also the embedded production default; the guarded
  wrapper and Gradle validation reject an incorrect override.
- **Validation:** 31 release-gate tests passed, including review launch,
  eligibility, version consistency, and all 14 attestation regression tests.
  Both signed release artifacts built successfully. Physical-device review
  popup display is not verified; native API invocation does not prove display.
- **Apple version ID:** `02a4a57e-4c40-4de7-9ac7-bd2921b36fc6`.
- **Apple build ID:** `3a240849-253e-4b1a-9540-7e7508ee300b`.
- **Apple submission ID:** `4beca315-7c5d-47ad-ba18-04b76136f385`.
- **Artifacts (SHA-256):** Android bundle
  `c0382b5fbeab8a3d933f97ae1ed02bed123557a786b94cfb9e3d02ed75f4cffe`;
  iOS IPA
  `6000f9b3764d1fc268f6d5f638b8b7129f94fd83170356a487621c2384141853`.

## Production submission — 1.1.22 (104)

- **Apple:** Submitted on 2026-11-01; verified `WAITING_FOR_REVIEW` with
  automatic release after approval (`AFTER_APPROVAL`). Build 104 is attached.
  Eight localized release notes and 160 unchanged inherited screenshots were
  verified. TestFlight access remains available.
- **Google Play:** The exact internal-testing bundle 104 was promoted to
  production without rebuilding. VersionCode `104`, status `completed`, and
  eight localized production notes were verified after commit. Other tracks
  and screenshots are unchanged. Review approval and public availability
  have not been established by this API status.
- **Android safeguards:** Bundle SHA-256 matches the guarded artifact below,
  built with `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER=312770688680`. All 14
  attestation regression tests passed again before promotion.
- **Apple version ID:** `d208a2fa-6386-4399-9b95-19ceccc8d253`.
- **Apple submission ID:** `8f784e07-9400-4086-a888-a0863a87ae5e`.

## Daily lesson localization correction — 1.1.22 (104), testing only

- **Scope:** Replaces raw rule keys such as `rule_qalqalah` with shared
  localized rule names in lesson buttons and titles. All seven lesson labels
  are covered in eight languages. Quran translation fallback is unchanged.
- **Distribution:** Google Play internal versionCode `104` is committed and
  verified with eight localized testing notes; production and other tracks
  are unchanged. iOS build 104 is `VALID` and `IN_BETA_TESTING` in the internal
  tester group, with eight localized notes verified. Apple production version
  states are unchanged. No production submission.
- **TestFlight build ID:** `5e7d6eb2-9175-408f-8a19-9da0b7195521`.
- **Android configuration:** Guarded signed build with explicit
  `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER=312770688680`.
- **Validation:** 31 targeted version, attestation, lesson, and Home tests
  passed. Both signed artifacts built successfully.
- **Artifacts (SHA-256):** Android bundle
  `5dda8d612d967f5a500f588c50f3be2932db8e4911dd4502f80bd0c2164525bc`;
  iOS IPA
  `411f1a5014a0a1a86ab7051d3568b282aed07955d2d4041a6b6f9c101ee67300`.

## Daily lesson focus — 1.1.22 (103), testing only

- **Status:** Released to internal TestFlight and Google Play internal testing
  on 2026-11-01. Apple build 103 is `VALID` and `IN_BETA_TESTING`; Play internal
  versionCode `103` and all eight testing-note translations were re-read.
  Production and other Play tracks were verified unchanged. No App Store
  review submission or Google production promotion was made for this version.
- **Lesson focus:** Today’s lesson highlights one authored word or phrase
  while preserving Tajweed colors. A localized, dismissible banner explains
  the rule; tapping the highlighted example or rule button opens details.
  Focus clears on dismissal, tab changes, bookmarks, surah selection, or
  switching to Mushaf mode.
- **Android configuration:** Built through the guarded release script with
  explicit `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER=312770688680`.
- **Validation:** The implementation passed 422 tests with two fixture/manual
  skips and its real Home-to-Reader simulator integration test. Release 103
  passed 31 targeted version, attestation, corpus, and lesson-UI tests. Both
  signed artifacts built successfully; iOS alternate icons remain registered.
  Physical-device testing is pending.
- **TestFlight build ID:** `8a1591fe-a4dc-4356-9afa-dc9c736a1285`.
- **Artifacts (SHA-256):** Android bundle
  `35b421a12927de7cf8f9493001d80f56b59f66b7e87a4f88e8b5c8be6ee48e17`;
  iOS IPA
  `d0ae351317d986f5e22ea419bd3b16aedcaec227c46f61954e8505ece7dc6abf`.

## Production submission — 1.1.21 (102)

- **Apple:** Submitted on 2026-10-30; verified `WAITING_FOR_REVIEW` with
  automatic release after approval (`AFTER_APPROVAL`). Build 102 is attached.
  All eight localized release notes and 160 inherited screenshots were
  verified. Internal TestFlight access remains available.
- **Google Play:** Promoted the exact internal-testing bundle 102 to
  production; versionCode `102`, rollout status `completed`, and eight
  localized production release notes were re-read successfully. This API
  status does not establish review approval or public availability. Other
  tracks and listing screenshots were verified unchanged.
- **Android safeguards:** No rebuild during promotion. Google Play's bundle
  SHA-256 matches the guarded release artifact recorded below, built with
  `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER=312770688680`. All 14 attestation
  regression tests passed again before completing the release record.
  Physical-device verification of this build remains pending.
- **Apple version ID:** `ae1718d6-8393-4544-97b7-5322a0ce0259`.
- **Apple submission ID:** `3b4a3ee4-c747-4e92-9390-c167c019d8eb`.

## Hijri date, feedback, and seasonal icons — 1.1.21 (102)

- **Status:** Available to the internal TestFlight group and Google Play
  internal testing on 2026-10-30. Apple processing is `VALID` and internal
  state is `IN_BETA_TESTING`. Play internal versionCode `102` and all eight
  localized testing notes were re-read after committing the edit. Production
  tracks and App Store version states were verified unchanged; no production
  submission was made.
- **Hijri date:** Home shows a localized date in all eight languages.
  iOS uses Apple's `Calendar(identifier: .islamicUmmAlQura)`; Android uses
  ICU `IslamicCalendar` with `ISLAMIC_UMALQURA`. Both use the current device
  time zone, with local midnight rollover and refresh on resume. This is a
  system-calculated calendar, not a local moon-sighting announcement or a
  sunset-based day boundary. Native failures are logged and the date is
  hidden rather than replaced with a different calculation.
- **Review and feedback:** After one minute of foreground reading on each
  of three distinct days, a later launch can request the native store review
  sheet. Attempts have a 120-day cooldown; stores control whether the sheet
  appears, and TestFlight does not display Apple's review request. Settings
  provides direct store-rating and email/support links in every language.
- **Seasonal icons:** iOS automatically selects Ramadan, Eid al-Fitr
  (1–3 Shawwal), and Eid al-Adha (8–13 Dhu al-Hijjah) icons using the same
  system calendar. A localized Settings switch restores the normal icon.
  Android keeps its normal icon to avoid removing launcher shortcuts.
  Explicit iPhone/iPad icon slots and all three alternate registrations
  were verified in the signed iOS archive. Superseded Apple build 101 was
  expired after an archive check found that Xcode had omitted its icons;
  build 102 fixes that packaging issue.
- **Android configuration:** Signed bundle built through
  `PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER=312770688680 release/build_android_release.sh appbundle`.
- **Validation:** 416 Flutter tests passed, with two fixture/manual skips.
  Native integration tests passed on both the iOS simulator and Android
  emulator, including known Umm al-Qura dates and local midnight boundaries.
  Analysis has no errors; existing warnings remain. Physical-device testing
  of this build is still pending.
- **TestFlight build ID:** `61871910-c5dc-4da0-890b-a4fd77ec4eed`.
- **Artifacts (SHA-256):** Android bundle
  `c9fc5d271126769c10705729b1f99dfae82f053985d538a8be0d3909e39abd1b`;
  iOS IPA
  `837a8397b4d8778b8de836c9dadbb48f727056635d308fa5b38249177ab14d5f`.

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
- **Version:** 1.1.21 (Apple `READY_FOR_SALE`); 1.1.22 (submitted for review).
- **Build:** 102 (live App Store version) / 104 (submitted for review).
- **Release stage:** 1.1.22 verified `WAITING_FOR_REVIEW`.
  All eight localized release notes and 160 inherited screenshots verified.
- **Release setting:** Automatic release after approval.
- **Submission:** 8f784e07-9400-4086-a888-a0863a87ae5e
- **App Store version ID:** d208a2fa-6386-4399-9b95-19ceccc8d253
- **Store assets:** All 160 inherited screenshots verified unchanged; What's New
  updated in all eight store languages.
- **TestFlight status:** 1.1.22 (104) is Apple-validated (`VALID`) and
  `IN_BETA_TESTING` in the internal Tajweed Testers group. Localized What to
  Test notes are configured in all eight languages.
- **TestFlight build ID:** 5e7d6eb2-9175-408f-8a19-9da0b7195521
- **Public release:** Apple 1.1.21 (102) verified `READY_FOR_SALE` before
  submission; 1.1.22 (104) is awaiting review. Google production is configured
  for build 104; public availability has not been verified.
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
publicly released builds through 1.1.23 (105), and the reader-only TestFlight
builds 1.1.24 (108–109), do not request microphone or speech-recognition permission.

### Reader refinement — TestFlight build 109

Version 1.1.24 (109) refines the shared Mushaf renderer with uniform page
lettering, tighter line spacing, centered ornamental surah headings, a lighter
basmala, and a reserved Hizb margin that keeps markers clear of Quran words.
Printed word and ayah-marker line assignments remain unchanged. Page numbers
and Juz labels follow the selected app language. Optional full-screen reading
hides both reader and bottom toolbars only in Quran page view.

This is an internal TestFlight upload, not a public App Review submission.
Hifz, Quran ASR, microphone and speech-recognition permissions remain excluded.

To review the updated Mushaf, open any Surah, switch to page view, and rotate
the device to compare portrait and landscape alignment. Green Hizb markers in
the page margin are tappable and announce the numbered Hizb boundary. Ayah
markers follow the QCF V2 printed-line metadata.

### Historical experimental memorization — build 106, excluded from build 108

Build 106 adds opt-in Arabic voice word checking to full-surah Mushaf practice,
with hints and the Reader's existing reference recitation. Microphone and iOS
speech-recognition purpose strings are localized in all eight languages.
Voice access is requested only after a consent explanation that the device
provider may process audio remotely. Recordings and transcripts are not saved
or sent to Ebaid LLC or Quran.Foundation. This is not Tajweed grading.

Open the Reader overflow menu in either reading mode and select “Memorize this
surah.” Practice starts at ayah 1, advances across the surah's Mushaf pages,
and offers an ayah selector for the whole surah. Incomplete surah data is
rejected rather than reporting partial-page practice as surah completion.

Before any public release, validate Arabic accuracy and long-ayah/pause behavior on
physical iOS and Android devices, verify denied permissions and audio
interruptions, publish the revised privacy/terms pages, and review both stores'
privacy/data-safety disclosures for the platform voice processing. Build 106
has been uploaded to App Store Connect for testing only; it has not been
submitted for App Store review.

## Manual App Store Connect confirmations

- Production Workers Logs are disabled. Cloudflare may process ordinary
  connection and App Attest information in real time, but the app does not
  retain request-level logs or transmit bookmarks, progress, or preferences.
- Complete age-rating and content-rights questionnaires.
- Confirm pricing, availability, review contact, and review phone number.
- Keep the approved screenshot sets and select build 61.
