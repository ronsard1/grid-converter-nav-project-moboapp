# GridNav — Flutter app (Android APK)

Grid ↔ lat/lon converter (Rwanda national grid, UTM, Arc datums) and navigation exercise planner:
routes per syndicate, route maps, leader summary, syndicate slips, control board.
**Works with no internet. All data stays on the phone.**

---

## How the app is built (simple picture)

```
┌──────────── Flutter app (lib/main.dart) ─────────────┐
│  WebView showing the GridNav screens (assets/www)    │  ← maths, planner, papers (already tested)
│        ▲ asks for phone features via "GridNavNative" │
│        ▼                                             │
│  print → Android print / Save as PDF   (printing)    │
│  share → WhatsApp, email, Drive        (share_plus)  │
│  save / pick → choose folder or file   (file_picker) │
│  gps   → phone GPS, offline            (geolocator)  │
│  open  → Google Maps links             (url_launcher)│
│  Back button → closes dialogs, goes back a screen    │
└──────────────────────────────────────────────────────┘
Data: saved inside the app on the phone (no account, no Firebase).
```

- `lib/main.dart`: the Flutter part. It's short, and each feature is one function.
- `assets/www/`: the screens. `js/geo.js` is the conversion maths, `js/routes.js` the planner, `js/print.js` the papers, `js/native.js` the link to Flutter.

---

## Two ways to get the APK

- **GitHub builds it** (no tools needed): upload this folder to a GitHub repository. `.github/workflows/build-apk.yml` makes GitHub build the APK and put it on the repository's **Releases** page. Full guide: *GridNav: build the APK with GitHub, step by step*.
- **Your computer builds it** (Flutter + emulator): the steps below.

Both use the same signing key (`tool/ci/gridnav-test.keystore`) only when built on GitHub. Pick one way and stick to it, because an APK signed with a different key can't update the other.

---

## Quickest way on Windows: one command

In the VS Code terminal, inside this folder:
```
powershell -ExecutionPolicy Bypass -File setup.ps1
```
It runs every step below in order and opens the folder with the APK at the end. If a step fails it stops, and everything it printed is saved in **setup-log.txt**: send that file to get help.

## Build it on your computer (step by step)

Open a terminal **in the `gridnav_flutter` folder** (where `pubspec.yaml` is). You need internet for steps 1–4 only.

**1. Create the Android part** (Flutter generates it; your files are kept):
```
flutter create --platforms=android --org rw.gridnav --project-name gridnav .
```

**2. Download the packages:**
```
flutter pub get
```

**3. Put the map library and fonts inside the app**, so the phone needs no internet:
```
dart run tool/get_libs.dart
```

**4. Set the app name and the GPS and internet permissions:**
```
dart run tool/setup_android.dart
```

**5. App icon** (optional, but makes it look right):
```
dart run flutter_launcher_icons
```

**6. Try it on the emulator.** Start your emulator, then:
```
flutter run
```
- To test GPS on the emulator: in its side bar **⋯ (Extended controls) → Location**, type latitude `-2.2385`, longitude `30.1825` (Ten Classrooms, Gako), then **Set location**.
- If you change a file in `assets/www`, press **R** (capital) in the terminal to restart the app with the change.

**7. Make the APK for your phone:**
```
flutter build apk --release
```
The file is created at `build/app/outputs/flutter-apk/app-release.apk`.

**8. Install on the phone**, either way:
- **USB:** connect the phone (with *Developer options → USB debugging* on) and run `flutter install`, or
- **Copy the file:** send `app-release.apk` to the phone (USB cable, WhatsApp to yourself, Google Drive), open it, allow **Install unknown apps**, then **Install**. If *Play Protect* warns, tap *More details → Install anyway*.

---

## Test checklist on the phone

1. Open with internet: add a map (Rwanda national grid → Bugesera), add a few points, convert both ways.
2. Turn on **airplane mode** and close the app completely.
3. Open again: everything is still there. Convert, make routes, open the route map, print to PDF, use the control board. GPS also works in airplane mode (outside, give it a minute).
4. Save icon (top right) → **Share backup** to yourself on WhatsApp. Keep it safe.

Only the photo/topo **background map** needs internet. Areas you've viewed stay saved for a while. The grid route map on the Exercise screen never needs internet.

---

## Updating the app later (keep your data)

1. In `pubspec.yaml`, raise the number after `+` in `version: 1.0.0+1`, e.g. `1.0.1+2`.
2. `flutter build apk --release` and install the new APK **over** the old one. Don't uninstall first, because uninstalling deletes the app's data.
3. Always build on **the same computer**. The APK is signed with that computer's key, and Android only accepts updates signed with the same key. If you change computers, save a backup first, then uninstall, install, and restore.

For publishing on the Play Store you need your own release key: see Flutter's guide "Build and release an Android app".

---

## If something goes wrong

| Message | What to do |
|---|---|
| `No file or variants found for asset: assets/www/vendor/...` | Run step 3 again (`dart run tool/get_libs.dart`) with internet. |
| `minSdkVersion ... cannot be smaller than ...` | Open `android/app/build.gradle` (or `.kts`) and set `minSdk = 21` (or the number the message asks for). |
| `Your project is configured with Android NDK ...` | Copy the `ndkVersion = "..."` line from the message into `android/app/build.gradle` inside `android { }`. |
| GPS says permission refused | Phone **Settings → Apps → GridNav → Permissions → Location → Allow**. |
| Print screen doesn't open | The phone needs the Android print service: in *Settings → Connected devices → Printing*, turn on *Default print service*. "Save as PDF" is always there. |
| Something else | Copy the red error lines and send them to me. |

---

## Check the calculations (optional, needs Node.js)
```
node web_tests/geo.test.js
node web_tests/routes.test.js
```
