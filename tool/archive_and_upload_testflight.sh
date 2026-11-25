#!/bin/bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: [STORE_BUILD=1] $0 <build-number> [build-name]" >&2
  exit 2
fi

BUILD_NUMBER="$1"
BUILD_NAME="${2:-1.1.27}"
SESSION_FILES="/Users/ahmedebaid/.copilot/session-state/c789e607-eec9-413e-8c79-2a1e67bd0c85/files"
WHISPER_SRC="$SESSION_FILES/whisper.cpp-1.9.5"
GPU_LIBS="$SESSION_FILES/gpu-preview-device/native-cancellable-metal-precompiled-iphoneos"
ARCHIVE_PATH="build/ios/archive/Runner-${BUILD_NUMBER}.xcarchive"
IPA_DIR="build/ios/ipa${BUILD_NUMBER}"
EXPORT_PLIST="build/ios/ipa136/ExportOptions.plist"

tool/check_app_version.sh "$BUILD_NAME"

# 1. Verify native Whisper headers and static libraries exist
test -f "$WHISPER_SRC/include/whisper.h"
test -f "$GPU_LIBS/src/libwhisper.a"
test -f "$GPU_LIBS/ggml/src/ggml-metal/libggml-metal.a"

# 2. Configure Flutter iOS Release with Quran ASR flags. STORE_BUILD=1 drops
# the test-only flags (TajweedFormer, take sharing, audio retention, cloud
# take uploads and Hifz mistake alerts) for a binary that can go to the App
# Store.
TEST_DEFINES=(
  --dart-define=QURAN_ASR_CLOUD_DIAGNOSTICS=true
  --dart-define=QURAN_ASR_RETAIN_DEBUG_AUDIO=true
  --dart-define=QURAN_ASR_RETAIN_DEBUG_TRANSCRIPTS=true
)
if [ "${STORE_BUILD:-0}" = "1" ]; then
  TEST_DEFINES=()
fi
flutter build ios --config-only --release \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER" \
  --dart-define=QURAN_ASR_EXPERIMENT=true \
  ${TEST_DEFINES[@]+"${TEST_DEFINES[@]}"}

# 3. Archive with QURAN_ASR_TESTFLIGHT + QURAN_ASR_NATIVE + Metal GPU libraries
xcodebuild archive \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -sdk iphoneos \
  -destination generic/platform=iOS \
  -archivePath "$ARCHIVE_PATH" \
  "SWIFT_ACTIVE_COMPILATION_CONDITIONS=\$(inherited) QURAN_ASR_TESTFLIGHT QURAN_ASR_NATIVE" \
  "GCC_PREPROCESSOR_DEFINITIONS=\$(inherited) QURAN_ASR_TESTFLIGHT=1 QURAN_ASR_NATIVE=1 QURAN_ASR_USE_METAL=1 QURAN_ASR_GPU_PREVIEWS=1" \
  "HEADER_SEARCH_PATHS=\$(inherited) \"$WHISPER_SRC/include\" \"$WHISPER_SRC/ggml/include\"" \
  "OTHER_LDFLAGS=\$(inherited) -lc++ -framework Accelerate -framework AVFoundation -framework Metal -framework MetalKit -framework Foundation -force_load \"$GPU_LIBS/src/libwhisper.a\" \"$GPU_LIBS/ggml/src/libggml.a\" \"$GPU_LIBS/ggml/src/libggml-base.a\" \"$GPU_LIBS/ggml/src/libggml-cpu.a\" -force_load \"$GPU_LIBS/ggml/src/ggml-metal/libggml-metal.a\"" \
  -quiet

# 4. Copy quran-tiny.bin and Metal shaders into Runner.app
APP_BUNDLE="$ARCHIVE_PATH/Products/Applications/Runner.app"
cp build/ios/archive/Runner-136.xcarchive/Products/Applications/Runner.app/quran-tiny.bin \
   build/ios/archive/Runner-136.xcarchive/Products/Applications/Runner.app/default.metallib \
   build/ios/archive/Runner-136.xcarchive/Products/Applications/Runner.app/ggml-tensor.metallib \
   "$APP_BUNDLE/"

# 5. Guard check: fail immediately if QuranASRChannel or whisper symbols are missing!
if [ "$(strings "$APP_BUNDLE/Runner" | grep -c "QuranASRChannel" || true)" -eq 0 ]; then
  echo "FATAL: QuranASRChannel is missing from $APP_BUNDLE/Runner!" >&2
  exit 1
fi
if [ "$(strings "$APP_BUNDLE/Runner" | grep -c "whisper_init_from_file_with_params" || true)" -eq 0 ]; then
  echo "FATAL: whisper symbols are missing from $APP_BUNDLE/Runner!" >&2
  exit 1
fi
test -s "$APP_BUNDLE/quran-tiny.bin"
test -s "$APP_BUNDLE/default.metallib"
test -s "$APP_BUNDLE/ggml-tensor.metallib"
if [ "${STORE_BUILD:-0}" = "1" ] &&
  strings "$APP_BUNDLE/Frameworks/App.framework/App" | grep -q "TajweedFormer recognition (test)"; then
  echo "FATAL: store build still contains the TajweedFormer test switch!" >&2
  exit 1
fi
if [ "${STORE_BUILD:-0}" = "1" ] &&
  strings "$APP_BUNDLE/Frameworks/App.framework/App" | grep -q "asr-diagnostics/upload"; then
  echo "FATAL: store build can still upload recitation takes!" >&2
  exit 1
fi
echo "Verified QuranASRChannel, whisper symbols, quran-tiny.bin, and Metal shaders in $APP_BUNDLE"

# 6. Export IPA and upload to App Store Connect
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -exportPath "$IPA_DIR" \
  -allowProvisioningUpdates \
  -quiet

xcrun altool --upload-app \
  --type ios \
  -f "$IPA_DIR/Tajweed.ipa" \
  --apiKey 43T77UX45N \
  --apiIssuer 934ab4d4-8cef-4710-b011-cf5cfcede345
