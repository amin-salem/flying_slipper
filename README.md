# دمپایی پرنده — Flying Slipper

A small runner game made with Flutter. Everything runs on the phone; no server is needed.

**Updating from an older version?** Unzip this version over the old folder (replace files), delete the old `lib/game/drawings.dart` if it is still there, then run:
```
flutter clean
flutter pub get
flutter run
```
You don't need to run `flutter create` again. Turn on a VPN for the first build after an update, because new Android libraries are downloaded from Google.

---

## How to run it on your phone (step by step)

### 1. Unzip the project
Unzip `flying_slipper.zip` into a simple folder **with no spaces or Persian letters in the path**, for example:

```
C:\games\flying_slipper
```

### 2. Open a terminal in that folder
- **Windows:** open the folder in File Explorer, click the address bar, type `cmd` and press Enter.
- **Mac/Linux:** right-click the folder and choose "Open in Terminal".

### 3. Let Flutter add the Android parts
Copy this command, paste it in the terminal and press Enter:

```
flutter create --org com.yourname --project-name flying_slipper --platforms android .
```

(Don't forget the dot at the end.) This adds the `android` folder. It does **not** replace the game files.

Change `yourname` to something of your own (English letters only). It becomes part of your app's ID on Cafe Bazaar, like `com.yourname.flying_slipper`, and can't be changed after you publish.

### 4. Download the game's libraries

```
flutter pub get
```

### 5. Prepare your phone
1. On your Android phone open **Settings → About phone**.
2. Tap **Build number** 7 times until it says you are a developer.
3. Go back to Settings, open **Developer options** and turn on **USB debugging**.
4. Connect the phone to the computer with a USB cable. On the phone, tap **Allow** when it asks about USB debugging.

Check that Flutter sees the phone:

```
flutter devices
```

You should see your phone's name in the list.

### 6. Run the game

```
flutter run
```

The first time takes several minutes. Then the game opens on your phone. 🎉
While it's running, press `r` in the terminal to reload after changing code, or `q` to quit.

### 7. Make an APK file (to install or share)

```
flutter build apk --release
```

The file appears at:

```
build\app\outputs\flutter-apk\app-release.apk
```

Copy it to any Android phone and install it.

---

## Common problems

**The first build fails while downloading (Gradle, "Could not resolve", 403, timeout).**
The first build downloads Android tools from Google's servers, which often block Iranian internet connections. Turn on a VPN for the first build only; after that everything is cached on your computer.

**`flutter` is not recognized.**
Flutter isn't on your PATH. Run `flutter doctor` from the folder where Flutter is installed, or re-add Flutter's `bin` folder to PATH.

**Something else is wrong.**
Run `flutter doctor` and send me the output.

---

## Launching on Cafe Bazaar
See **docs/LAUNCH.md**: playtest checklist, signing your release APK, store texts and screenshot plan.

## App icon
The icon is already inside the project (`android/app/src/main/res/mipmap-*`), including the adaptive version that newer Android phones cut into circles, squircles and so on. Unzipping over your folder replaces Flutter's default blue icon. If the old icon still shows on the phone, uninstall the app once and run `flutter run` again.

For Cafe Bazaar, upload `store_assets/bazaar_icon_512.png` (512×512). `store_assets/icon.svg` is the editable source, and `tools/make_icon.py` re-renders every size.

## Change the app name shown on the phone
Open `android\app\src\main\AndroidManifest.xml` and change:

```
android:label="flying_slipper"
```
to
```
android:label="دمپایی پرنده"
```

---

## What's real and what's a test right now

| Part | Status |
|---|---|
| Game, coins, best score, characters, power-ups, daily reward | ✅ Real, saved on the phone |
| Sound effects and music (on/off in Settings) | ✅ Real, files in `assets/sfx` and `assets/music` |
| Ads (continue, double coins, free coins, between games) | 🧪 Test ad: a 3-second fake screen. File: `lib/services/ad_service.dart` |
| Purchases (starter pack, coins, remove ads, VIP) | 🧪 Test store: free, nothing is charged. File: `lib/services/store_service.dart` |
| Prices | Shown as `[قیمت] تومان`. Set them in `lib/services/store_service.dart` |

Later we'll swap the two test files for **Tapsell** (ads) and **Cafe Bazaar Poolakey** (payments). The rest of the game won't need changes.

## How to play
- Play in portrait, or **turn the phone sideways during a run** for a wider view. Menus stay in portrait.
- **Tap** to jump. **Hold** to jump higher. Tapping just before you land still counts.
- Things on the rug: vase, bouncing ball, books, samovar — jump over them.
- Mom winds up before every throw, and a sign tells you what's coming:
  - red **«بپر!»** – low slipper: jump
  - teal **«نپر!»** – high slipper: stay on the ground
  - orange **«صبر کن...»** – it bounces off the rug: jump late
  - **«دوتا!»** – two low slippers in a row: jump twice
- Dodge a slipper by a hair for **«جاخالی!» +3 coins** and a slow-motion moment.
- After about 20 seconds **Dad shows up** (with his belt!) and Mom and Dad take turns. Dad twirls his belt and cracks it along the floor (**jump**) or at head height (**stay down**), and sometimes throws the TV remote.
- Every kid has a **special power**: Sara double-jumps, Omid sees attacks earlier, the sleepy kid slows the world, the football kid kicks obstacles away, the Nowruz kid gets double coins, and the superhero can fly and starts with a shield.
- **Pillow (بالش):** blocks one hit. **Grandma (مادربزرگ):** clears the screen and calms Mom down.
- The further you run, the angrier Mom gets: faster game, trickier throws.

## Sounds
All sounds and the music were generated by `tools/make_sounds.py` (a santur and tombak style 6/8 loop in dastgah Shur). To change them, edit that file and run:
```
python tools/make_sounds.py
```
(needs Python with numpy and scipy, plus ffmpeg). Or just replace any `.ogg` file in `assets/sfx` or `assets/music` with your own, keeping the same name.

## Files
```
lib/
  main.dart                 app start (right-to-left Persian)
  theme.dart                colors, buttons, Persian numbers
  game/world.dart           game rules (jumping, throws, coins, particles, difficulty)
  game/game_painter.dart    draws each frame (room, rug, obstacles, effects)
  game/characters.dart      the 7 characters, Mom and the slipper
  screens/home_screen.dart  home screen
  screens/game_screen.dart  gameplay + game over
  screens/shop_screen.dart  shop (coins, characters, power-ups)
  services/save_data.dart   saving on the phone
  services/audio.dart       sound effects and music
  services/ad_service.dart  ads (test for now)
  services/store_service.dart  purchases (test for now)
assets/fonts/               Vazirmatn Persian font (free, OFL license)
assets/sfx/, assets/music/  sounds and music
tools/make_sounds.py        script that generated the sounds
tools/make_icon.py          script that draws the app icon
store_assets/               icon for Cafe Bazaar (512×512) and big versions
```

## Game server (optional)

The server code is in [`server/`](server/README.md) (Python + FastAPI). Without a server the game works offline exactly as before.

**Connect the app to a server running on your computer:**

1. Start the server: `cd server && uvicorn app.main:app --reload --host 0.0.0.0`
2. Find your computer's IP address on Wi-Fi (`hostname -I`), for example `192.168.1.5`.
3. Android blocks plain `http://` by default. For testing, open `android/app/src/debug/AndroidManifest.xml` and add `android:usesCleartextTraffic="true"` to an `<application>` tag:
   ```xml
   <manifest xmlns:android="http://schemas.android.com/apk/res/android">
       <uses-permission android:name="android.permission.INTERNET"/>
       <application android:usesCleartextTraffic="true"/>
   </manifest>
   ```
4. Run the app with the server address:
   ```bash
   flutter run -d R5CRC0PR5WT --dart-define=API_URL=http://192.168.1.5:8000
   ```

**For the release build** (Cafe Bazaar), the server must use HTTPS. Add the internet permission to `android/app/src/main/AndroidManifest.xml`, above `<application`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```
Then build it:
```bash
flutter build apk --release --dart-define=API_URL=https://api.yourgame.ir --dart-define=APP_BUILD=13
```
`APP_BUILD` must match the number after `+` in `pubspec.yaml`. The server uses it for forced updates.
