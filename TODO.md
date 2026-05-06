# TODO

Cross-cutting tasks that don't have a natural home in code. For code-local reminders, use `// TODO:` comments.

## iOS

- [ ] **Crashlytics: add dSYM upload Run Script in Xcode.** Required for symbolicated iOS crash reports. Without it, stack traces show hex addresses instead of method names. Crashlytics still collects reports without this — it just makes them readable.
  - Open `ios/Runner.xcworkspace` in Xcode (macOS only).
  - Runner target → Build Phases → + → New Run Script Phase, name "Upload Crashlytics Symbols".
  - Script: `"${PODS_ROOT}/FirebaseCrashlytics/run"`
  - Input Files:
    - `${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}`
    - `$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)`
  - Then `cd ios && pod install`.

## Auth

- [ ] **Enable Apple Sign-In on Android (once Apple Developer account is paid).** Currently hidden on Android via `_showApple` gate in [LoginPage.dart:20](lib/Login/LoginPage.dart#L20). To enable:
  1. Apple Developer Console: create a **Service ID** (e.g. `io.leetcards.app.web`), enable "Sign in with Apple" on it. Configure Domain `leetcards-5a25d.firebaseapp.com` and Return URL `https://leetcards-5a25d.firebaseapp.com/__/auth/handler`.
  2. Generate a private key (`.p8`) for Sign in with Apple — note the Key ID and your Team ID.
  3. Firebase Console → Authentication → Sign-in method → Apple → enable. Paste Service ID, Team ID, Key ID, and `.p8` contents.
  4. Code: in `_providerSignIn` for `apple.com` ([AuthService.dart:233](lib/Login/AuthService.dart#L233)), branch — iOS/macOS keeps the native `_getAppleCredentialNative` flow; Android uses `_auth.signInWithProvider(AppleAuthProvider())`.
  5. Flip `_showApple` in [LoginPage.dart:20](lib/Login/LoginPage.dart#L20) to always be true.

- [ ] **Register Play App Signing key SHA-1 in Firebase after first Play Store upload.** Google's Play App Signing re-signs your AAB with a key Google generates. Until you register *that* SHA-1 in Firebase, Google Sign-In and GitHub will fail for users who install from the Play Store (only sideloaded APKs signed with the upload key will work).
  - After first upload: Play Console → Setup → App signing → copy the **App signing key certificate** SHA-1.
  - Firebase Console → Project Settings → Your apps → Android → Add fingerprint → paste it, save, redownload `google-services.json`, ship next update.

## Firestore

- [ ] **Add security rule for `flashcard_feedback` collection.** Mirrors the existing `feedback` rule but also requires `cardId` and `cardType` fields. In Firebase Console → Firestore → Rules, add inside `match /databases/{database}/documents`:
  ```
  match /flashcard_feedback/{id} {
    allow create: if request.resource.data.message is string
                  && request.resource.data.message.size() > 0
                  && request.resource.data.message.size() < 5000
                  && request.resource.data.cardId is string
                  && request.resource.data.cardType is string;
    allow read, update, delete: if false;
  }
  ```

## Web

- [ ] **Generate properly sized PWA icons before shipping web.** All four icon slots in [web/icons/](web/icons/) currently hold the same 109 KB `app_icon.png` copy. Works in browsers (they scale), but suboptimal:
  - Icon-192 / Icon-512 should be exact-sized PNGs for performance and crispness.
  - Icon-maskable-192 / Icon-maskable-512 need ~20% safe-area padding so OS masks (circle/squircle on Android home screens) don't clip the logo.
  - Easy fix: add `web: true` to the `flutter_launcher_icons` block in [pubspec.yaml](pubspec.yaml) and run `flutter pub run flutter_launcher_icons` — same tool already configured for Android/iOS.
  - Also worth a fresh look at `web/favicon.png` — 109 KB is large for a favicon (typical is 5–10 KB at 32×32 or 64×64).

