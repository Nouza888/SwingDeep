# SwingDeep / GolfScan AI

ゴルフスイング動画から姿勢を解析し、改善レポートを作るiPhoneアプリです。

## Current snapshot

- Snapshot date: 2026-07-10
- App version: 2.0.0 (`CFBundleVersion` 20260710)
- Recovery policy: local December 2025 source as the recovery base, with selected May 2026 GitHub changes integrated
- Minimum target: iOS 17.0
- Verified with: Xcode 26.4.1 / iOS Simulator SDK 26.4 / arm64
- Firebase Apple SDK: 12.16.0
- MediaPipeTasksVision: 0.10.35

The repository now contains the iOS project, dependency lockfile, Firebase Functions source, privacy manifest, and reproducible XcodeGen definition. The pre-integration archives are intentionally kept outside this repository.

## Architecture

- Pose inference: on device with MediaPipe Pose Landmarker
- Technical metrics: deterministic Swift rules shared across coach personas
- Coach wording: generated separately through Firebase Callable Functions and Gemini
- Persistence: SwiftData on device
- Firebase configuration: optional for local on-device startup; required for cloud reports, Analytics, and Crashlytics

The app can start without `GoogleService-Info.plist`. In that state, on-device features remain available and cloud report generation is disabled.

## Setup

1. Install Xcode 26.2 or later and CocoaPods 1.16.2.
2. Run `pod install` at the repository root.
3. Open `SwingDeep.xcworkspace`, not the `.xcodeproj` directly.
4. Choose your Apple Development Team and confirm the bundle identifier.
5. For cloud reports, download the matching `GoogleService-Info.plist` from Firebase and add it to the `SwingDeep` target. The file is ignored by Git.

`SwingDeep.xcodeproj` is committed for immediate use. When the target structure changes, regenerate it with XcodeGen 2.45.4 and run `pod install` again:

```sh
xcodegen generate
pod install
```

## Firebase Functions

The backend source is under `functions/` and targets Node.js 20.

```sh
cd functions
npm ci
npm run build
cd ..
cp .firebaserc.example .firebaserc
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions
```

The iOS client uses the Firebase Callable wire format over `URLSession`. This avoids a linker collision between the Firebase Functions client SDK and MediaPipe while preserving the existing backend contract.

## Current release blockers

- The provisional bundle identifier `com.noz.SwingDeep` must be confirmed against Apple Developer and Firebase.
- A production `GoogleService-Info.plist` and Apple signing team are not included.
- A final 1024px App Store icon is not included.
- Physical-device video analysis and end-to-end cloud report generation have not yet been verified.
- Firebase App Check, authentication, and server-side rate limiting are not yet implemented.
- Video lifecycle cleanup and several known analysis-flow issues remain in the backlog.

See [docs/RECOVERY_STATUS.md](docs/RECOVERY_STATUS.md) for the recovery decisions and [docs/verification/2026-07-10.md](docs/verification/2026-07-10.md) for verification evidence.

## License

No project-level open-source license has been granted. Third-party components and model provenance are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
