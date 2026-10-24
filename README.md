# Sway for iOS

Native SwiftUI rewrite of the Expo app in `../mobile`. iOS 18+, no third-party dependencies.

## Run

Open `Sway.xcodeproj` in Xcode and run the `Sway` scheme, or:

```bash
xcodebuild -project Sway.xcodeproj -scheme Sway -destination 'generic/platform=iOS Simulator' build
```

The project uses folder-synced groups, so new files under `Sway/` are picked up without editing the project.

## API

The base URL comes from the `API_BASE_URL` build setting:

- Debug: `http://localhost:3100` (local networking is allowed in `Config/Info.plist`)
- Release: `https://api.gowithsway.com`

## Layout

- `Sway/App` – app entry and tab bar
- `Sway/Models` – diary entries and the public prescription payload
- `Sway/Services` – API client, session (prescription code), local diary store, reminders
- `Sway/Views` – Today, Diary, Exercises and Settings screens
- `Sway/Resources/Localizable.xcstrings` – English and Portuguese strings

## Behaviour notes

- Diary entries are saved to `Application Support/diary.json` first and synced to `POST /pub/bladder-bowel-diary` afterwards. Unsynced entries retry on launch, on pull to refresh and from the Retry button.
- The payload matches what the Expo app sent, except `drinkType`, which is now a stable key (`water`, `coffee`, `tea`, `other`) instead of the translated label.
- Water and exercise reminders are real daily local notifications, configured in Settings.
