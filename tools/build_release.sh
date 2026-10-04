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
# Release builds can't use the internet without this permission.
MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  echo "Adding the INTERNET permission to $MANIFEST ..."
  sed -i '0,/<application/s||<uses-permission android:name="android.permission.INTERNET"/>\n    <application|' "$MANIFEST"
fi
grep -q 'android.permission.INTERNET' "$MANIFEST" || { echo "Could not add the INTERNET permission - add it by hand (docs/LAUNCH.md 2b)."; exit 1; }

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
if command -v aapt >/dev/null 2>&1; then
  aapt dump permissions "$OUT" | grep -q INTERNET && echo "OK: the APK has the INTERNET permission." \
    || echo "WARNING: the APK has NO internet permission!"
fi
echo "Install on your phone to test:  adb install -r release/flying_slipper-$NAME-$BUILD.apk"
