# Release checklist

Steps that have actually bitten us, in the order they need doing. Tick each one
per release for both stores.

## Carry-over from 1.1.3

- [ ] **Confirm the Settings screen shows the new version.** 1.1.0 stayed on that
      screen through 1.1.1, 1.1.2 and 1.1.3 because the string was a hand-edited
      constant. It is now `lib/core/constants/app_version.dart`, and
      `test/unit/app_version_test.dart` fails the build when it disagrees with
      `pubspec.yaml` — but that test only guards the repo, and **build 65 shipped
      before the fix landed**, so 1.1.3 still displays 1.1.0. Open Settings on a
      real device for the next release and read the number.

## Version

- [ ] Bump `version:` in `pubspec.yaml` (`<marketing>+<build>`; the build number
      has to increase for every upload, even a rejected one).
- [ ] Bump `appVersion` in `lib/core/constants/app_version.dart` to the marketing
      version. `flutter test test/unit/app_version_test.dart` proves the two agree.
- [ ] `flutter test` and `flutter analyze` clean.

## iOS

- [ ] `flutter build ipa --release`.
- [ ] Upload with `altool --upload-app`. It prints `-1005 "network connection was
      lost"` partway through on a normal, successful run — those are internal
      retries. Read to the end and look for `UPLOAD SUCCEEDED`.
- [ ] Wait for the build to leave `PROCESSING` and reach `VALID`.
- [ ] Create the App Store version, then attach the build to it.
- [ ] Write What's New for all eight locales: `en-US, ar-SA, de-DE, es-ES, fr-FR,
      id, tr, ur-PK`. Note that `id` and `tr` carry **no** region suffix. Apple
      copies the previous version's description, keywords and screenshots
      forward, so What's New is usually the only field to fill in.
- [ ] Submit for review.

  If `POST reviewSubmissionItems` returns HTTP 500 `UNEXPECTED_ERROR`, the
  submission itself was very likely created and is simply sitting there with no
  items. **Re-`GET` the submission and its items before retrying** — creating a
  second one leaves a stray empty submission behind.

- [ ] **Decide the release type before you submit.** This app has defaulted to
      `AFTER_APPROVAL`, which means Apple puts the version **on sale
      automatically** the moment review passes — nobody presses a button, and
      there is no pause to catch a late problem. 1.1.3 went live this way on
      2026-09-08.

      If you want to hold the version back, set `releaseType` to `MANUAL` **on
      the version, before submitting**:

      ```
      PATCH /v1/appStoreVersions/{id}
      { "data": { "id": "{id}", "type": "appStoreVersions",
                  "attributes": { "releaseType": "MANUAL" } } }
      ```

      Then release it deliberately once you have verified the build. The three
      values are `MANUAL` (you press the button), `AFTER_APPROVAL` (auto-release
      on approval), and `SCHEDULED` (a date you set).

- [ ] Confirm what you actually chose:

      ```
      GET /v1/apps/{app_id}/appStoreVersions?fields[appStoreVersions]=versionString,appStoreState,releaseType
      ```

      Note the `fields[...]` parameter 404s on a single `appStoreVersions/{id}`
      — query the collection as above, or omit `fields` entirely.

- [ ] To check from outside App Store Connect whether a version is really live:

      ```
      curl -s "https://itunes.apple.com/lookup?id=6794283460&country=us"
      ```

      Read `version` and `currentVersionReleaseDate`.

## Android

- [ ] `flutter build appbundle --release`, signed with the upload keystore.
- [ ] Upload to the Play Console track and reuse the same localized release notes.
- [ ] **Decide how it publishes, same as iOS.** Play has two independent
      controls, and neither is the App Store's `releaseType`:

      - *Managed publishing* (Publishing overview). When it is **off**, an
        approved release goes live on its own. Turn it **on** to hold approved
        changes until you click Publish. Verify the current setting in the
        Console rather than assuming — it is a per-app setting.
      - *Staged rollout* percentage on the production track. Shipping at less
        than 100% limits blast radius and can be halted.

## Both stores

- [ ] Update `release/app-store-listing.md` and `release/play/listing.md`.
- [ ] Re-read `docs/privacy-policy.html`, `docs/terms-of-use.html` and
      `docs/support.html` if anything about data handling or platform
      integrations changed. Play and the App Store point at these same URLs, so
      wording that names only one platform is a policy problem rather than a
      cosmetic one.
- [ ] Install the release build on a real iOS device and a real Android device
      and open Settings, the reader, and the onboarding guide before submitting.

## Keys

- [ ] Back up `~/.config/tajweed/upload-keystore.jks` (plus its password) and
      `~/.config/tajweed/signing/dist.key` — they exist on one machine only.

      Losing the upload keystore is recoverable, not fatal. The app ships as an
      app bundle and is therefore enrolled in Play App Signing, so Google holds
      the *app signing* key and what is on this machine is only the *upload* key.
      If it is lost, generate a new keystore and ask Play Console support to
      reset the accepted upload certificate.

      Back it up anyway: a reset takes days, and a new app signed with this same
      keystore would have no reset path until its first upload registers it with
      Google.

      (The "lose the key and the listing is dead forever" warning you will read
      elsewhere describes apps predating Play App Signing, where the developer
      held the single key Google verified updates against. It does not apply
      here.)

