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

- [ ] Release type is `AFTER_APPROVAL`, so approval does **not** put it on sale.
      Someone has to release it by hand.

## Android

- [ ] `flutter build appbundle --release`, signed with the upload keystore.
- [ ] Upload to the Play Console track and reuse the same localized release notes.

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

- [ ] `~/.config/tajweed/upload-keystore.jks` (plus its password) and
      `~/.config/tajweed/signing/dist.key` exist on one machine only. Losing the
      upload keystore means the Play listing cannot be updated again under the
      same package name. Back them up somewhere durable.
