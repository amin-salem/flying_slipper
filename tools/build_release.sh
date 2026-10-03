#!/usr/bin/env bash
# Builds the signed release APK for Cafe Bazaar.
#   ./tools/build_release.sh                 # live server (Liara)
#   API_URL=https://api.yourgame.ir ./tools/build_release.sh
set -e
cd "$(dirname "$0")/.."

if [ ! -f android/key.properties ]; then
  echo "android/key.properties is missing - create your signing key first (docs/LAUNCH.md, section 2)."
  exit 1
fi
BUILD=$(grep '^version:' pubspec.yaml | sed 's/.*+//')
NAME=$(grep '^version:' pubspec.yaml | sed 's/version: *//; s/+.*//')
API=${API_URL:-https://flyingslippers.liara.run}
echo "Building version $NAME (build $BUILD) for server $API ..."

flutter pub get
flutter build apk --release \
  --obfuscate --split-debug-info=build/symbols \
  --dart-define=APP_BUILD="$BUILD" \
  --dart-define=API_URL="$API"

OUT=build/app/outputs/flutter-apk/app-release.apk
mkdir -p release
cp "$OUT" "release/flying_slipper-$NAME-$BUILD.apk"
echo
echo "Done: release/flying_slipper-$NAME-$BUILD.apk  ($(du -h "$OUT" | cut -f1))"
echo "Install on your phone to test:  adb install -r release/flying_slipper-$NAME-$BUILD.apk"
