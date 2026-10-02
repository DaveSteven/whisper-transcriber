#!/bin/zsh
set -eu
cd "${0:A:h}"
cache_key="$(/usr/bin/printf '%s' "$PWD" | /usr/bin/shasum | /usr/bin/cut -c1-12)"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache-$cache_key/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache-$cache_key/swiftpm"
scratch="$PWD/.build/work-$cache_key"
swift build -c release --disable-sandbox --scratch-path "$scratch" -debug-info-format none
bin_dir="$(swift build -c release --disable-sandbox --scratch-path "$scratch" --show-bin-path)"
binary="$bin_dir/WhisperTranscriber"
[[ -x "$binary" ]] || { echo "Missing build output: $binary" >&2; exit 1; }
app="dist/Whisper Transcriber.app"
/bin/rm -rf "$app"
/bin/mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks"
/bin/cp "$binary" "$app/Contents/MacOS/WhisperTranscriber"
/bin/cp Info.plist "$app/Contents/Info.plist"
/bin/cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
/bin/cp Resources/mlx_transcribe.py "$app/Contents/Resources/mlx_transcribe.py"
/bin/cp -R Vendor/build-apple/whisper.xcframework/macos-arm64_x86_64/whisper.framework "$app/Contents/Frameworks/whisper.framework"
/usr/bin/codesign --force --sign - "$app/Contents/Frameworks/whisper.framework"
/usr/bin/codesign --force --sign - "$app"
echo "Built: $PWD/$app"
