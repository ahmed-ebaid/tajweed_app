# Google Play store assets

Generated assets for the Play Console listing of `com.ebaidllc.tajweed_practice`.

| File | Play requirement | Status |
| --- | --- | --- |
| `play-icon-512.png` | 512×512, 32-bit PNG, alpha allowed, ≤1024 KB | 512×512, 44 KB |
| `play-feature-graphic-1024x500.png` | 1024×500, JPEG or 24-bit PNG, **no alpha** | 1024×500, no alpha, 58 KB |
| `screenshots/*.png` | 2–8 per device type, 320–3840 px, **no alpha**, longest side ≤ 2× shortest | 8 files, 1080×1920 (1.78:1) |

## Regenerating

### Icon and feature graphic

```bash
sips -s format png -z 512 512 assets/app_icon/app_icon_1024.png \
  --out release/play/play-icon-512.png
python3 tool/make_play_feature_graphic.py
```

The feature graphic auto-fits its text and aborts rather than emitting a
silently clipped image, so changing `TITLE` or `SUBTITLE` is safe.

### Screenshots

The emulator must be forced to a Play-legal aspect ratio first. The
`tajweed_play` AVD is natively 1080×2400, which is 2.22:1 and **exceeds Play's
2:1 maximum** — screenshots taken at that size are rejected. The same issue
makes `assets/onboarding/*` (414×900 = 2.17:1) unusable as store screenshots.

```bash
adb -s emulator-5554 shell wm size 1080x1920   # 16:9 = 1.78:1
adb -s emulator-5554 shell wm density 420

SCREENSHOT_OUTPUT_DIR=build/play-screenshots flutter drive \
  --driver=test_driver/app_store_screenshots_driver.dart \
  --target=integration_test/app_store_screenshots_test.dart \
  -d emulator-5554 --dart-define=SCREENSHOT_LOCALE=en

adb -s emulator-5554 shell wm size reset       # restore the AVD afterwards
```

Captures land in `build/play-screenshots/` as 32-bit PNGs. Play rejects alpha
on screenshots, so they are flattened to 24-bit RGB when copied here. The
`08-settings` and `10-languages` captures are deliberately omitted — Play caps
phone screenshots at 8 and those two are the weakest sells.

## Not generated here

- **Listing text** — adapt `release/app-store-listing.md` to Play's limits:
  title ≤30, short description ≤80, full description ≤4000 characters.
- **Tablet screenshots** — optional, but without them the listing is not
  surfaced as tablet-optimised.
