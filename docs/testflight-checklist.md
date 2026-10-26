# TestFlight checklist

Steps that happen outside the code, in order.

## 1. Accounts and identifiers (once)
- [ ] App Store Connect → Apps → **New App**: bundle ID `com.myers.Chalk`, name "Chalk", primary language, SKU.
- [ ] Developer portal → Identifiers: confirm `com.myers.Chalk` has **iCloud (CloudKit)** and **Push Notifications** enabled, with container `iCloud.com.myers.Chalk`.

## 2. App icon and launch screen
- [ ] Add your icon to `Assets.xcassets/AppIcon` (or an Icon Composer `.icon` file).
- [ ] Chalk target → Info → Launch Screen → **Background color** = `LaunchBackground` (asset already added; it's the theme's Night color).

## 3. CloudKit schema (after every model change, before shipping it)
1. Product → Scheme → Edit Scheme → Run → Arguments: add `-ChalkInitializeCloudKitSchema`.
2. Run a **Debug** build once on a device or simulator signed in to iCloud. It uploads every record type and field to the **development** environment.
3. Remove the launch argument again (it blocks syncing while it runs).
4. [CloudKit Console](https://icloud.developer.apple.com) → CloudKit Database → container `iCloud.com.myers.Chalk` → check the `CD_` record types (`CD_Program`, `CD_ExerciseSlot`, …) and their fields.
5. **Deploy Schema Changes** → review → Deploy. Production can only add fields from now on; nothing can be renamed or removed.

TestFlight and App Store builds use the **production** environment, so they can't sync until step 5 is done.

## 4. Privacy
- [ ] Host `docs/privacy-policy.md` (e.g. GitHub Pages) and set `AppLinks.privacyPolicy` in `Settings/SettingsView.swift`.
- [ ] App Store Connect → App Privacy: **Data Not Collected** (data lives in the user's own iCloud).
- [ ] App Store Connect → App Information: privacy policy URL, category Health & Fitness.

## 5. Build and upload
- [ ] Bump the build number (`CURRENT_PROJECT_VERSION`) for every upload.
- [ ] Product → Archive (any iOS device, Release) → Distribute App → App Store Connect → Upload.
- [ ] Export compliance is answered in Info.plist (`ITSAppUsesNonExemptEncryption = NO`).

## 6. TestFlight
- [ ] Add "What to Test" notes and beta app description.
- [ ] Internal testers first (no review). External testers need a quick Beta App Review.

## 7. Sync test on two real devices (same iCloud account)
- [ ] Create a program on device A → appears on B.
- [ ] Log a workout on A → B's Today moves to the next day and History shows it.
- [ ] Edit the same exercise on both while one is offline → reconnect → nothing lost or duplicated.
- [ ] Fresh install on B with A's data already in iCloud → onboarding steps aside with "Welcome back", no duplicate program.
- [ ] Archive / restore / delete on one device → reflected on the other.
