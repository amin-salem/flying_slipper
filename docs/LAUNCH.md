# Launch guide: دمپایی پرنده on Cafe Bazaar

Everything you need to go from "it runs on my phone" to "it's live on Bazaar".
Payments (Poolakey) and ads (Tapsell/Adivery) are separate steps and are not
covered here.

---

## 1. Playtest checklist (do this before anything else)

Play at least 20 runs on your phone and, if you can, on one cheap/old phone.
Tick each item:

**First minutes**
- [ ] Fresh install (uninstall first): the tutorial starts and every step works
- [ ] After the tutorial the real game starts and Dad appears after ~20 s
- [ ] The login calendar opens on the home screen and gives coins

**Gameplay**
- [ ] Jump feels responsive; holding jumps higher
- [ ] Every attack can be dodged: low slipper, high slipper, bounce, double,
      belt low, belt high, TV remote
- [ ] Never an impossible moment (high attack + obstacle at the same time)
- [ ] Coins never sit inside obstacles
- [ ] Rooms change at 450 m / 900 m with the doorway and the announcement
- [ ] Rotate the phone during a run: the game keeps going correctly
- [ ] Pause, continue, home, retry all work

**Characters & shop**
- [ ] Each power works: Sara double/triple jump, Omid early warning, sleepy
      kid slower world, football kick (ball glows when ready), Nowruz double
      coins, hero flies (hold while falling) and starts with a shield
- [ ] Upgrading a power spends coins and the effect gets stronger
- [ ] Missions progress and can be claimed
- [ ] Piggy bank fills; starter offer appears after the 3rd game over

**Sound & performance**
- [ ] Music loops without a gap; sounds play on time; Settings switches work
- [ ] No stutter after 5 minutes of play; phone doesn't get hot
- [ ] Leaving the app (home button) pauses the music; coming back resumes

Write down anything odd (with what you were doing) and send it to me.

---

## 2. Release signing (very important: do it once, keep the key forever)

Bazaar identifies your game by its **package name** and **signing key**. If
you lose the key you can never update the game again. Back it up in two
places (e.g. a USB stick + a private cloud folder).

### 2.1 Create the key
In a terminal (any folder outside the project):
```
keytool -genkey -v -keystore flying_slipper.jks -keyalg RSA -keysize 2048 -validity 10000 -alias slipper
```
It asks for a password and your name. Remember the password.

### 2.2 Tell the project about it
Create `android/key.properties` (this file is in `.gitignore`, it never goes to GitHub):
```
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=slipper
storeFile=/full/path/to/flying_slipper.jks
```

### 2.3 Use it in `android/app/build.gradle.kts`
At the very top of the file add:
```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```
Inside the `android { ... }` block add (before `buildTypes`):
```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = keystoreProperties["storeFile"]?.let { file(it) }
        storePassword = keystoreProperties["storePassword"] as String
    }
}
```
And in `buildTypes { release { ... } }` replace the debug signing line with:
```kotlin
signingConfig = signingConfigs.getByName("release")
```

### 2.4 Build the release APK
```
flutter build apk --release
```
The file is `build/app/outputs/flutter-apk/app-release.apk`. Install it on
your phone once more and play a run before uploading.

Every update: raise `version:` in `pubspec.yaml` (e.g. `1.5.0+7` → `1.5.1+8`;
the number after `+` must always go up), then build again.

---

## 3. App name on the phone
In `android/app/src/main/AndroidManifest.xml`:
```
android:label="دمپایی پرنده"
```

---

## 4. Store listing (Bazaar developer panel)

**Name:** دمپایی پرنده

**Short description** (one line):
> از دست دمپایی مامان و کمربند بابا فرار کن!

**Category:** بازی › آرکید (or اکشن)
**Age rating:** 3+ (cartoon slapstick, no real violence)

**Full description:**
> یه خرابکاری کردی… و حالا مامان با دمپایی و بابا با کمربند دنبالتن! 🩴
>
> بپر، جاخالی بده و تا جایی که می‌تونی فرار کن. هر چی بیشتر بدوی، مامان و بابا عصبانی‌تر میشن!
>
> ⭐ دمپایی پایین؟ بپر! دمپایی بالا؟ نپر! حواست به کمربند بابا و کنترل تلویزیون هم باشه
> ⭐ ۷ شخصیت با قدرت‌های ویژه: پرش دوبل سارا، شوت گل‌زن محله، عیدیِ بچه عید و پرواز ابرپسر
> ⭐ از اتاق نشیمن به آشپزخونه و حیاط فرار کن؛ عکس عروسی بابا و مامان، کارنامه‌ات و حوض حیاط رو ببین
> ⭐ ماموریت‌های روزانه، جایزه هر روز، قلک و تزئینات یلدا و نوروز
> ⭐ رکوردت رو با دوستات به اشتراک بذار و ببین کی بیشتر فرار می‌کنه!
>
> یه بازی ایرانی، خنده‌دار و آشنا برای همه خانواده 😄

**Keywords to mention in the text:** دمپایی، مامان، بابا، فرار، بازی ایرانی، دویدن، خنده‌دار

---

## 5. Screenshots (take 6, portrait)

Take them on your phone (power + volume-down) or from the computer:
```
adb exec-out screencap -p > shot1.png
```
Plan, with a caption to add on top of each (big, bold, Persian):

| # | What to capture | Caption |
|---|---|---|
| 1 | Mom winding up, red «بپر!» sign, kid running | از دمپایی مامان فرار کن! |
| 2 | Dad cracking his belt | بابا با کمربند اومد! |
| 3 | Shop › characters tab | ۷ شخصیت با قدرت ویژه |
| 4 | Kitchen or courtyard during a run | از آشپزخونه تا حیاط بدو |
| 5 | Missions sheet or login calendar | ماموریت و جایزه هر روز |
| 6 | Game-over card with a new record | رکوردت رو به دوستات نشون بده |

Tip: play in landscape for screenshot 4 if Bazaar shows landscape shots nicely.
Use the icon from `store_assets/bazaar_icon_512.png`.

---

## 6. Before you press "publish"
- [ ] Real Poolakey payments and real ads are in (separate step)
- [ ] Prices set in `lib/services/store_service.dart` (replace `[قیمت]`)
- [ ] Release APK signed with your key (section 2) and tested on the phone
- [ ] Version number raised
- [ ] Store texts, icon and 6 screenshots uploaded
- [ ] Key file backed up in two places
