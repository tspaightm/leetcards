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

## Crashlytics

- [ ] **Validate Crashlytics end-to-end.** The setup is wired up but unverified — Crashlytics is silent until a real crash, so we don't know reports actually flow through.
  - Clean rebuild on Android: `flutter clean && flutter run` (Gradle plugin change requires it).
  - Add a temporary button somewhere that calls `FirebaseCrashlytics.instance.crash();`.
  - Tap it, then **kill and relaunch the app** (uploads happen on next launch, not at crash time).
  - Wait 5–10 min, check Firebase Console → Crashlytics for the report.
  - Remove the test button.

## Analytics

- [ ] Register custom event parameters in Firebase Console → Analytics → Custom Definitions so they're queryable in reports:
  - `tier_change`: `from_tier`, `to_tier`
  - `flashcard_completed`: parameters from [DatabaseService.dart:231](lib/Data/DatabaseService.dart#L231)
