# Progress

Phase plan and exit criteria: [TRD §13](docs/TRD.md#13-delivery-sequence). Timeboxes are hard: at the limit, stop and report.

| # | Phase | Status | Started | Done |
|---|---|---|---|---|
| 0 | Setup | Done | 2026-10-12 | 2026-10-12 |
| 1 | Camera spike | In progress | 2026-10-12 | |
| 2 | Capability spike | Not started | | |
| 3 | Recipe content spike (user-led) | Not started | | |
| 4 | Coach loop | Not started | | |
| 5 | Expand and self-test | Not started | | |
| 6 | Performance gate | Not started | | |
| 7 | Pilot | Not started | | |

## Lanes (parallel work)

Lanes B–D start only after the user validates Phase 1 on device. Each lane works on its own branch/worktree, touches only its folders, and merges via PR.

| Lane | Work | Owns | Needs device | Status |
|---|---|---|---|---|
| A | Phase 1 on-device pass → Phase 2 capability spike | `ios/PhotoCoach/` camera files | Yes (user) | Active — on-device pass pending |
| B | Pure logic ahead of Phase 4: recipe schema + validator (TRD §7), coach state machine + temporal policy (§8), photo-coordinate transforms (§6); unit tests on synthetic inputs | `ios/PhotoCoach/Recipe/`, `ios/PhotoCoach/Coach/`, matching test folders | No | Waiting on Phase 1 validation |
| C | Research: Vision body-pose vs person-rectangle reliability for full-body shots on iOS 18+ (ankles/feet, distance, low light) | `docs/research/` | No | Waiting on Phase 1 validation |
| D | Design mockups: recipe picker, coaching text, ready state, review screen | Artifacts (no repo files) | No | Not scheduled — after Phase 4 exists, or earlier on request |
| — | Phase 3 recipe content | — | No | User-led, when ready |

Lane B pulls Phase 4 logic ahead of Phase 2 (a change to TRD §13 order). Record it in the TRD when the lane starts.

## Phase 0 — Setup

- [x] `ios/PhotoCoach.xcodeproj`: SwiftUI app + Swift Testing target, iOS 18.0, iPhone only, portrait, no dependencies
- [x] Tests pass on iPhone 16 simulator (iOS 18.6); app launches
- [x] Set signing team (free personal team) in Xcode and run on a physical iPhone

## Phase 1 — Camera spike

Timebox: 3–5 days (hard stop by 2026-10-17). Exit: TRD §13 row 1.

Code (`ios/PhotoCoach/`):
- [x] `CameraService`: actor on its own serial queue; rear 1× wide, `.photo` preset, photo output (HEVC, zero shutter lag default, responsive capture when supported), video data output attached but idle so later coaching overhead compares like for like
- [x] Native preview layer, letterboxed 4:3 so preview = photo composition; tap-to-focus/expose with explicit reset to continuous center on subject-area change
- [x] Shutter with immediate dim acknowledgment; disabled while capturing
- [x] Review screen: Save / Retake; photo held until saved or discarded; save failure keeps photo and offers Retry; Photos denial offers Settings
- [x] Camera denied → explanation + Open Settings; interruptions show "Camera paused"; media-services reset restarts session
- [x] Instrumentation: `metrics` log lines + Points of Interest signposts (FirstFrame, ShutterTap, WillCapture); DEBUG overlay with fps/dropped
- [x] Builds clean (Swift 6) for device and simulator; launches in simulator (no camera there)

On-device checks (iPhone, you):
- [ ] Preview appears, upright, smooth; tap-to-focus square + focus change
- [ ] Capture → review → Save lands in Photos (portrait orientation, check resolution in log)
- [ ] Retake discards; deny Photos access → Settings path; airplane-mode/full-storage save failure if reproducible
- [ ] Deny camera (Settings → Photo Coach) → explanation screen
- [ ] Interruption: incoming call/FaceTime or Control Center, background/foreground → "Camera paused" then resumes
- [ ] 10 minutes running: fps holds ~30, dropped stays ~0, phone not hot

Baseline (coaching off) — fill from Xcode console, filter `metrics`. Run each 5–10×:

| Metric | iPhone model | Values (ms) | Notes |
|---|---|---|---|
| Cold launch → first frame | | | Force-quit before each run |
| Warm launch → first frame | | | Background then reopen — not logged yet; see open items |
| Tap → capture start | | | |
| Tap → photo ready | | | |
| Steady fps / drops | | | |

Side-by-side with Apple Camera (same phone, scene, 1×, Photo mode): shutter feel, preview smoothness, photo resolution/format, sharpness, color. Notes:

-

Open items / found during spike:
- Shutter fires on touch-up (SwiftUI Button). Apple recommends capturing on touch-down for zero shutter lag; evaluate whether the difference is felt.
- Warm-start (resume from background) timing isn't logged yet; add if the cold numbers look fine.
- Photo resolution is the AVFoundation default; Apple Camera may default to 24 MP. Compare and decide.

## Log

- 2026-10-12: Phase plan recorded (TRD v0.3, PRD D16). Blank app created and verified in simulator.
- 2026-10-12: Phase 0 done (confirmed on device). Phase 1 started: camera, review/save, and instrumentation code in; on-device checks and baseline pending.
- 2026-10-12: Phase 1 code pushed (edcccda). Added CLAUDE.md for agent onboarding and a lanes plan; lanes B and C wait on Phase 1 on-device validation.
