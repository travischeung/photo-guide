# Partner Photo Coach — agent guide

iOS camera app that gives live, recipe-based text coaching to the photographer. Read before working:

- `docs/PRD.md` — product behavior and agreed decisions (D01–D16). Governs.
- `docs/TRD.md` — implementation, performance targets, phase plan (§13).
- `PROGRESS.md` — current phase, lanes, checklists. Source of truth for status.

## Working rules

- **Discuss before implementing.** Confirm direction with the user before starting a phase, lane, or anything not already agreed. Don't start work marked "waiting" in PROGRESS.md.
- **Update PROGRESS.md in the same change** as the work: checkboxes, status, dated log line.
- **Decisions go in the docs.** A change to scope or behavior updates the PRD/TRD and its decision log. On a version bump, first copy the current file to `docs/versions/YYYY-MM-DD-<DOC>-v<old>.md`.
- **Stay in your lane.** Parallel lanes own specific folders (see PROGRESS.md); don't edit another lane's files. Parallel lanes each work in their own git worktree.

## Git: every change goes through a PR

- **Never commit or push to `main` directly.** `main` changes only by merging a PR.
- Branch from up-to-date `main`: `<type>/<short-description>`, e.g. `feat/touch-down-shutter`, `docs/trd-v0.4`, `fix/sideways-preview`.
- **Commit and PR titles follow Conventional Commits:** `<type>(<scope>): <description>`.
  - Types: `feat` (new behavior), `fix` (bug fix), `chore` (tooling, config, housekeeping), `docs`, `refactor`, `test`, `perf`.
  - Scope: the task ID when one exists (e.g. `#12`), otherwise a short task title in kebab-case (e.g. `camera`, `recipe-schema`).
  - Description: imperative, lowercase, no trailing period, ≤ 72 chars total. Examples: `feat(#12): capture on shutter touch-down`, `fix(camera): keep preview upright on resume`, `docs(trd): record lane B ordering`.
  - The PR title becomes the squash-merge commit on `main`, so it must follow this format too.
- One logical change per PR, kept small. Include the matching PROGRESS.md/doc updates in the same PR.
- PR description: what and why, how it was verified (tests run, or "needs on-device check"), and anything left undone.
- The user reviews and merges (squash). Don't merge your own PR. Delete the branch after merge.

## Product constraints that must not drift

- No overlays, silhouettes, or ghost images in the viewfinder (D03). Coaching is text, plus a light haptic when the shot is ready (D12).
- One active instruction at a time; every instruction is a physical action (F03).
- The shutter is never blocked by coaching (F06). Coaching degrades before camera responsiveness does.
- Live coaching is on-device Vision + deterministic recipe rules; no AI models, no uploads (D15, §9 privacy).
- Preview is letterboxed 4:3 so it matches the captured photo; judge composition in photo coordinates.
- "Unknown" is never treated as "fail" (TRD §7). Missing landmarks ≠ cropping.

## Code

- `ios/PhotoCoach.xcodeproj` — plain Xcode project, synchronized folders (new files in `ios/PhotoCoach/` or `ios/PhotoCoachTests/` are picked up automatically). No third-party dependencies, no XcodeGen/Tuist.
- Swift 6 strict concurrency, SwiftUI, iOS 18.0 minimum, iPhone portrait only. Tests use Swift Testing.
- `CameraService` is an actor whose executor is the session queue; UI state lives in `@MainActor @Observable CameraModel`.
- Build/test on the simulator (it has no camera — camera behavior needs a physical iPhone, done by the user):

```sh
cd ios && xcodebuild test -project PhotoCoach.xcodeproj -scheme PhotoCoach \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'
```

Pin `OS=18.6`: there are two "iPhone 16" simulators, and 18.6 keeps tests on iOS 18. It doesn't prove the 18.0 minimum; test on an 18.0 runtime when one is installed.
