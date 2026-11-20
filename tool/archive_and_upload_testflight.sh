#!/bin/bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <build-number> [build-name]" >&2
  exit 2
fi

BUILD_NUMBER="$1"
BUILD_NAME="${2:-1.1.26}"
SESSION_FILES="/Users/ahmedebaid/.copilot/session-state/c789e607-eec9-413e-8c79-2a1e67bd0c85/files"
WHISPER_SRC="$SESSION_FILES/whisper.cpp-1.9.5"
GPU_LIBS="$SESSION_FILES/gpu-preview-device/native-cancellable-metal-precompiled-iphoneos"
ARCHIVE_PATH="build/ios/archive/Runner-${BUILD_NUMBER}.xcarchive"
IPA_DIR="build/ios/ipa${BUILD_NUMBER}"
EXPORT_PLIST="build/ios/ipa136/ExportOptions.plist"

# 1. Verify native Whisper headers and static libraries exist
test -f "$WHISPER_SRC/include/whisper.h"
test -f "$GPU_LIBS/src/libwhisper.a"
test -f "$GPU_LIBS/ggml/src/ggml-metal/libggml-metal.a"

# 2. Configure Flutter iOS Release with Quran ASR flags
flutter build ios --config-only --release \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER" \
  --dart-define=QURAN_ASR_EXPERIMENT=true \
  --dart-define=QURAN_ASR_RETAIN_DEBUG_AUDIO=true \
  --dart-define=QURAN_ASR_RETAIN_DEBUG_TRANSCRIPTS=true \
  --dart-define=QURAN_ASR_CLOUD_DIAGNOSTICS=true

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
