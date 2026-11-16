#!/bin/bash
set -euo pipefail

# Explicit external paths keep model weights and native build artifacts out of Git.
if [ "$#" -lt 4 ]; then
  echo "Usage: $0 whisper.cpp-source converted-model.bin build-directory simulator|device [xcodebuild arguments...]" >&2
  exit 2
fi
source_dir="$1"
model="$2"
build_dir="$3"
target="$4"
shift 4
case "$target" in
  simulator) sdk=iphonesimulator; destination='generic/platform=iOS Simulator'; default_configuration=Debug ;;
  device) sdk=iphoneos; destination='generic/platform=iOS'; default_configuration=Profile ;;
  *) echo "Target must be simulator or device." >&2; exit 2 ;;
esac
configuration="${QURAN_ASR_CONFIGURATION:-$default_configuration}"
case "$configuration" in
  Debug) native_condition=DEBUG ;;
  Profile)
    if [ "$target" != device ]; then
      echo "Profile mode requires a physical iPhone." >&2
      exit 2
    fi
    native_condition=QURAN_ASR_PROFILE ;;
  *) echo "Only Debug or Profile lab builds are supported; Release is forbidden." >&2; exit 2 ;;
esac
test -f "$source_dir/include/whisper.h"
test -f "$model"
mkdir -p "$build_dir"
build_dir="$(cd "$build_dir" && pwd)"
source_dir="$(cd "$source_dir" && pwd)"
model="$(cd "$(dirname "$model")" && pwd)/$(basename "$model")"
script_dir="$(cd "$(dirname "$0")" && pwd)"
patched_source="$build_dir/whisper-cancellable-source"
mkdir -p "$patched_source"
rsync -a --exclude .git "$source_dir/" "$patched_source/"
# Always patch a fresh upstream file; fail rather than silently using an
# incompatible Whisper version.
cp "$source_dir/src/whisper.cpp" "$patched_source/src/whisper.cpp"
patch --batch --forward -d "$patched_source" -p1 < "$script_dir/whisper-cancellable-encoder.patch"
source_dir="$patched_source"
gpu_previews="${QURAN_ASR_GPU_PREVIEWS:-0}"
case "$gpu_previews" in
  0|1) ;;
  *) echo "QURAN_ASR_GPU_PREVIEWS must be 0 or 1." >&2; exit 2 ;;
esac
if [ "$gpu_previews" = 1 ] && { [ "${QURAN_ASR_METAL:-0}" != 1 ] || [ "$target" != device ]; }; then
  echo "GPU previews require QURAN_ASR_METAL=1 and a physical-device build." >&2
  exit 2
fi
precompiled_metal="${QURAN_ASR_PRECOMPILED_METAL:-0}"
case "$precompiled_metal" in
  0|1) ;;
  *) echo "QURAN_ASR_PRECOMPILED_METAL must be 0 or 1." >&2; exit 2 ;;
esac
if [ "$precompiled_metal" = 1 ] && { [ "${QURAN_ASR_METAL:-0}" != 1 ] || [ "$target" != device ]; }; then
  echo "Precompiled Metal requires QURAN_ASR_METAL=1 and a physical-device build." >&2
  exit 2
fi
case "${QURAN_ASR_METAL:-0}" in
  0)
    metal=OFF
    metal_condition=0
    native="$build_dir/native-cancellable-$sdk"
    metal_link_flags="" ;;
  1)
    metal=ON
    metal_condition=1
    native="$build_dir/native-cancellable-metal-$sdk"
    metal_link_flags="-framework Metal -framework MetalKit -framework Foundation -force_load \"$native/ggml/src/ggml-metal/libggml-metal.a\"" ;;
  *) echo "QURAN_ASR_METAL must be 0 or 1." >&2; exit 2 ;;
esac
metal_embed="$metal"
if [ "$precompiled_metal" = 1 ]; then
  metal_embed=OFF
  native="$build_dir/native-cancellable-metal-precompiled-$sdk"
  metal_link_flags="-framework Metal -framework MetalKit -framework Foundation -force_load \"$native/ggml/src/ggml-metal/libggml-metal.a\""
fi
cmake -S "$source_dir" -B "$native" \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$sdk" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
  -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=OFF \
  -DGGML_METAL="$metal" -DGGML_METAL_EMBED_LIBRARY="$metal_embed" \
  -DGGML_METAL_TARGET_OS=ios -DGGML_BLAS=OFF \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
cmake --build "$native" -j 2
action="${QURAN_ASR_BUILD_ACTION:-build}"
case "$action" in
  build|build-for-testing) ;;
  *) echo "Build action must be build or build-for-testing." >&2; exit 2 ;;
esac
bundle_id=com.ebaidllc.tajweedpractice.quranailab
# Lab flags are passed to this invocation, never saved in release settings.
xcrun xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration "$configuration" -sdk "$sdk" -destination "$destination" \
  -derivedDataPath "$build_dir/app" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  "QURAN_ASR_BUNDLE_IDENTIFIER=$bundle_id" \
  "SWIFT_ACTIVE_COMPILATION_CONDITIONS=\$(inherited) $native_condition QURAN_ASR_NATIVE" \
  "GCC_PREPROCESSOR_DEFINITIONS=\$(inherited) $native_condition=1 QURAN_ASR_NATIVE=1 QURAN_ASR_USE_METAL=$metal_condition QURAN_ASR_GPU_PREVIEWS=$gpu_previews" \
  "HEADER_SEARCH_PATHS=\$(inherited) \"$source_dir/include\" \"$source_dir/ggml/include\"" \
  "OTHER_LDFLAGS=\$(inherited) -lc++ -framework Accelerate -framework AVFoundation -force_load \"$native/src/libwhisper.a\" \"$native/ggml/src/libggml.a\" \"$native/ggml/src/libggml-base.a\" \"$native/ggml/src/libggml-cpu.a\" $metal_link_flags" \
  "$@" "$action"
app="$build_dir/app/Build/Products/$configuration-$sdk/Runner.app"
actual_id="$(/usr/bin/plutil -extract CFBundleIdentifier raw "$app/Info.plist")"
if [ "$actual_id" != "$bundle_id" ]; then
  echo "Unexpected bundle identifier; refusing to package a non-lab app." >&2
  exit 1
fi
/usr/bin/plutil -replace CFBundleDisplayName -string "Tajweed AI Lab" "$app/Info.plist"
for localized_names in "$app"/*.lproj/InfoPlist.strings; do
  if [ -f "$localized_names" ]; then
    /usr/bin/plutil -replace CFBundleDisplayName -string "Tajweed AI Lab" "$localized_names"
  fi
done
cp "$model" "$app/quran-tiny.bin"
if [ "$precompiled_metal" = 1 ]; then
  cp "$native/bin/default.metallib" "$app/default.metallib"
  if [ -f "$native/bin/ggml-tensor.metallib" ]; then
    cp "$native/bin/ggml-tensor.metallib" "$app/ggml-tensor.metallib"
  fi
fi
if [ -n "${QURAN_ASR_REFERENCE_WAV:-}" ]; then
  cp "$QURAN_ASR_REFERENCE_WAV" "$app/quran-asr-reference.wav"
elif [ -f "$app/quran-asr-reference.wav" ]; then
  rm "$app/quran-asr-reference.wav"
fi
unsigned=false
for argument in "$@"; do
  if [ "$argument" = CODE_SIGNING_ALLOWED=NO ]; then unsigned=true; fi
done
if [ "$target" = device ] && [ "$unsigned" = false ]; then
  identity="$(/usr/bin/codesign -dvv "$app" 2>&1 | /usr/bin/sed -n 's/^Authority=//p' | head -1)"
  if [ -z "$identity" ]; then
    echo "Device build has no signing identity; cannot sign the added model resource." >&2
    exit 1
  fi
  /usr/bin/codesign --force --sign "$identity" --preserve-metadata=identifier,entitlements,flags "$app"
fi
if [ "$target" = device ] && [ "$unsigned" = true ]; then
  echo "Unsigned device build: compilation only; signing is required before installation."
fi
printf '\nExperimental app: %s\n' "$app"
