# Plant Pal

Plant Pal is a small iPhone app for two people who want to take care of one plant together. You each water it once a day. When both of you show up, the day counts as thriving: the streak grows, wilt heals a step, and eventually new pots and species unlock. If a day ends with someone missing, the streak resets and the plant droops. It never scolds you past a crisis, and the next thriving day starts the comeback.

The plant is drawn in SwiftUI. It sways while it's well, leans when it's thirsty, and gets a little shower when somebody waters it.

## What you can do

- Name the plant and the two people looking after it.
- Water from the home screen. On one shared phone, each person has their own button. On two phones, you water as yourself and see whether your pal has sipped yet.
- Watch it move through seed, sprout, seedling, leafy, budding, and bloom.
- Unlock pots (terracotta, ceramic, moss, galaxy, seashell, golden) and species (Sproutling, Sunbloom, Moonfern, Rosythorn, Bubbleshroom, Starlily).
- Pair with an invite code once iCloud sync is on, or trade a plant postcard when it isn't. A postcard is a chunk of text. Paste it and both sips are kept.
- Add a practice pal on one phone so you can see a thriving day before a friend joins. A real pal replaces them.
- Get a daily local reminder. That stays on the phone and does not need push notifications.
- Put the plant on the Home Screen and the Lock Screen. With the App Group capability, the water button records your sip without opening the app. Without it, the button opens Plant Pal.

Days follow the time zone of the person who started the plant, so "today" means the same thing on both phones.

## Requirements

- A Mac with Xcode 16 or later
- An iPhone running iOS 17 or later
- A free Apple ID is enough to install it on your own phone from Xcode

A paid Apple Developer Program membership is only needed later, for App Groups (live widgets), iCloud sync, and TestFlight. The project does not turn those capabilities on, so a personal team can sign the app.

## Open the project

The Xcode project is already generated and committed. You do not need XcodeGen to open it.

1. Clone this repo.
2. Open `PlantPal.xcodeproj`.
3. Wait for Xcode to resolve the local Swift packages `PlantPalKit` and `PlantPalCore`. They live in `Packages/` and do not download anything.

`project.yml` describes the same targets. On a Mac with [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed, `xcodegen generate` from the repo root rebuilds the project. The checked-in `PlantPal.xcodeproj` is the one to open day to day.

## Install it on your iPhone with a free Apple ID

A personal team (the free Apple ID you add in Xcode) can install Plant Pal for about 7 days at a time. Run it again from Xcode when it expires.

1. Install Xcode from the Mac App Store and open it once so it finishes installing the extra components.
2. In Xcode, open **Settings → Accounts** and sign in with your Apple ID. Xcode creates a Personal Team.
3. Open `PlantPal.xcodeproj`.
4. Select the **PlantPal** target, then **Signing & Capabilities**.
5. Check **Automatically manage signing**.
6. Choose your Personal Team.
7. Set the bundle identifier to something unique to you, for example `com.yourname.plantpal`. `com.plantpal.app` may already be registered to someone else.
8. Select the **PlantPalWidget** target and set the same team. Set its bundle identifier to your app id plus `.widget`, for example `com.yourname.plantpal.widget`. The widget id needs to start with the app id.
9. Leave **Signing & Capabilities** alone besides the team and bundle id. Do not add App Groups, iCloud, or Push Notifications. A personal team cannot sign those, and adding them makes the run fail.
10. Plug in your iPhone and trust the computer if it asks.
11. On the iPhone, turn on **Developer Mode** under **Settings → Privacy & Security**. The phone restarts.
12. In Xcode's scheme menu, pick **PlantPal** and your iPhone (not a simulator, if you want it on the device). A simulator also works if you only want to look around.
13. Press Run.
14. If the phone says the developer is untrusted, open **Settings → General → VPN & Device Management**, trust your Apple ID, and open Plant Pal again.

The app is portrait only. The first launch asks for your name, a plant name, and whether you share one phone or two.

### Add the widgets

After the app is installed:

- Home Screen: touch and hold the background, tap **+**, search for **Plant Pal**, and add the small or medium widget.
- Lock Screen: touch and hold the Lock Screen, tap **Customize**, then add the circular, rectangular, or inline Plant Pal widget.

On a free Apple ID the widget can open the app, and the water button deep-links into watering. It cannot read the live plant until App Groups are signed, because a personal team cannot create the shared container. The **Us** tab says which of those two states you're in.

### Reminders

On the **Us** tab, turn on the daily sip reminder and pick a time. iOS asks for notification permission. If you decline, you can allow Plant Pal later in **Settings → Notifications**. The reminder is scheduled on the phone. It does not use a server.

## Water together

**Same phone.** Enter both names during setup. Each person taps their own button once a day. The widget's water button records a sip for the person who created the plant on that phone. The other person waters in the app.

**Two phones, no paid account.** Start the plant, choose two phones, and skip iCloud. Send the postcard (the share button) to your pal. They install Plant Pal, choose **I have a code or a postcard**, and paste it. After each of you waters, send a fresh postcard so the other phone can merge. Merging keeps both sips, so neither of you overwrites the other.

**Two phones with iCloud.** This needs the paid setup in the next section. One person creates the plant with iCloud on and shares the 6-character code. The other enters it. After that, watering uploads on its own, and opening the app (or refreshing the widget) picks up the other sip. Both phones need to be signed into iCloud.

While you are still the only partner, your own daily sip counts as a thriving day so the seed doesn't wilt just because your friend hasn't joined. After the second person joins, a thriving day means both of you watered.

You can add a practice pal from Home or Us if you want to try the two-person rules on one phone first.

## App Groups and iCloud (paid Apple Developer Program)

These capabilities are in the repo, and they are not attached to the targets. That is what lets a free personal team install the app. Turn them on only after you enroll in the [Apple Developer Program](https://developer.apple.com/programs/).

| Capability | What it unlocks | Entitlements file |
| --- | --- | --- |
| App Groups | Home Screen and Lock Screen widgets show the live plant, and the water button writes the sip without opening the app | `Config/AppGroup.entitlements` |
| App Groups + iCloud / CloudKit | The above, plus invite codes and sync between two phones | `Config/AppGroupCloudKit.entitlements` |

The ids the code already uses:

- App Group: `group.com.plantpal.shared`
- CloudKit container: `iCloud.com.plantpal.app`

Both are placeholders you register on your team. If you need different ids, change them in the entitlements file and in `Packages/PlantPalKit/Sources/PlantPalKit/SyncConfig.swift`, then use the same strings in Xcode.

### Turn them on

1. Select the paid team on **both** the PlantPal and PlantPalWidget targets.
2. On each target, set **Build Settings → Code Signing Entitlements** to `Config/AppGroup.entitlements` or `Config/AppGroupCloudKit.entitlements`.
   You can instead press **+ Capability** and add App Groups and iCloud yourself. If you do that, the group id and the container id still have to match the table above. Add the same capabilities to the widget target, or the widget will keep its own empty copy of the plant.
3. For iCloud, choose **CloudKit** and the container `iCloud.com.plantpal.app`. Xcode can create the container when you add the capability.
4. Run the app from Xcode on a phone that is signed into iCloud.
5. On the **Us** tab, switch sync from **This phone** to **iCloud**.

The first successful upload creates a `Plant` record in the CloudKit **Development** database. The record name is `plant-` plus the invite code, so joining does not need a queryable index. The fields are `payload` and `inviteCode`. In the [CloudKit Console](https://icloud.developer.apple.com/), deploy that schema to **Production** before you ship a TestFlight or App Store build. Production will not create the record type on its own.

There is no API key to paste in. CloudKit uses your Apple ID and the container. If you never flip the sync switch, the app never talks to iCloud.

## Move to TestFlight later

TestFlight needs the paid program. A free personal team cannot upload builds.

1. Enroll at [developer.apple.com/programs](https://developer.apple.com/programs/).
2. In [App Store Connect](https://appstoreconnect.apple.com/), create an iOS app whose bundle id matches the PlantPal target.
3. If you want widgets to stay in sync and codes to work for testers, turn on App Groups and iCloud as above, with the paid team selected, before you archive.
4. Set the version and build number in the target if you are shipping a newer build. They start at 1.0 (1).
5. Choose **Any iOS Device (arm64)** as the run destination.
6. **Product → Archive**.
7. In the Organizer, **Distribute App → App Store Connect → Upload**.
8. Export compliance is already answered: `ITSAppUsesNonExemptEncryption` is false, because the app only uses system HTTPS and does not add its own encryption.
9. Privacy: Plant Pal does not collect data. `PrivacyInfo.xcprivacy` in the app and the widget declares that, and declares `UserDefaults` access for the plant saved on device (reason `CA92.1`).
10. When the build finishes processing, add internal testers (your App Store Connect users) or an external group. External testing needs a short Beta App Review.
11. Testers install from the TestFlight app. The widget extension is inside the same archive, so they can add it after installing.

CloudKit testers need the production schema deployed, and they need to be signed into iCloud. The widget and the app both read the same App Group, so both targets must keep that entitlement in the archived build.

## Project layout

```
PlantPal.xcodeproj          App and widget targets
project.yml                 XcodeGen spec for the same project
PlantPal/                   SwiftUI app
PlantPalWidget/             Home Screen and Lock Screen widgets
Packages/PlantPalCore/      Growth rules, postcards, merging (Foundation only)
Packages/PlantPalKit/       Drawing, shared store, CloudKit, water intent
Config/                     Optional entitlements, not wired up by default
Scripts/make_icon.py        Regenerates the app icon
```

The shared plant is stored as JSON. When the App Group exists, the app and the widget both use `group.com.plantpal.shared`. Otherwise the app keeps it in its own container and the widget shows an empty sprout.

## Tests

The growth rules have unit tests: thriving days, wilt, streaks, unlocks, time zones, postcards, and merges.

```bash
cd Packages/PlantPalCore
swift test
```

## Troubleshooting

**"Personal development teams do not support the App Groups / iCloud / Push Notifications capability."**
A capability was added to a target. Remove it, and clear **Code Signing Entitlements** if it points at `Config/`. Push Notifications are not used.

**"Failed to register bundle identifier" or a profile error for `com.plantpal.app`.**
Change both bundle ids to ones your Apple ID can register, and keep the widget id prefixed with the app id.

**The widget signs, but it never matches the plant in the app.**
The App Group entitlement is not on the build. With a free team that is expected. The widget button opens the app instead.

**iCloud sync says it isn't available.**
The iCloud capability is missing, the container id doesn't match `SyncConfig`, or the phone isn't signed into iCloud. This Phone mode and postcards still work.

**The app will not open after about a week.**
Free provisioning lasts about 7 days. Connect the phone and press Run again.

**Xcode says you have too many apps for a personal team.**
Delete an old app you installed with that Apple ID, then run again.

**"Untrusted Developer" on the phone.**
Settings → General → VPN & Device Management → trust the Apple ID you used in Xcode.
