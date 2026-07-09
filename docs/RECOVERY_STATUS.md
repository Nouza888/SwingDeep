# Recovery status — 2026-07-10

## Baselines preserved

- GitHub baseline: `a44c0b33daccaf686f99465af148946a9a92b691` (2026-05-06)
- Local recovery import commit: `17177ad`
- Local pre-integration archives: stored outside this Git repository with SHA-256 checksums

## Integration decisions

### Kept from the local recovery source

- Richer SwiftData models and backward-compatible report decoding
- Existing views, services, and video workflow
- Six normalized metrics used by the deterministic evaluator and report layer
- Firebase Functions TypeScript source and drill libraries
- Local Pose Landmarker model

### Integrated from the later GitHub work

- Firebase initialization through `UIApplicationDelegateAdaptor`
- Asset catalog skeleton
- Three-item MVP evaluation, adding deterministic head-stability feedback to the local analyzer
- Simplified separation between on-device analysis and cloud wording

### Reconstructed on 2026-07-10

- `SwingDeep.xcodeproj`, `SwingDeep.xcworkspace`, and `project.yml`
- CocoaPods dependency definition and lockfile
- App privacy manifest and usage descriptions
- Firebase deployment configuration
- Safe startup when Firebase configuration is absent
- Missing `chatBubble` view extension
- Callable Functions transport over `URLSession` to avoid duplicate `GTMSessionFetcher` symbols

## Deliberately not imported

- Invalid `\\uXXXX` strings from the May GitHub rewrite
- The reduced May SwiftData schema, which could break stored history
- The May `VideoViewModel` rewrite, which did not address the known performance and cache issues
- Template `Item.swift`, `.DS_Store`, generated Functions output, and `node_modules`
- Unreferenced `guide_silhouette_ex.png`

## Known technical debt retained for later safe changes

1. Move video/Pose processing off the main actor.
2. Validate `address < impact` and minimum phase spacing.
3. Replace dictionary `first(where:)` landmark lookup with deterministic nearest-frame lookup.
4. Replace fixed 30fps stepping with asset frame timing.
5. Persist a real video reference or delete copied videos after analysis.
6. Allow deterministic reports and history save when the cloud wording layer is unavailable.
7. Align the V2 iOS/backend response contract and preserve drill metadata.
8. Add App Check, authentication or another abuse-control boundary, and server-side rate limiting.

These items were not bundled into the recovery commit because they require behavior tests and privacy decisions rather than mechanical restoration.
