# Product Requirements Document — Partner Photo Coach

Version: 0.3 · Date: October 12, 2026 · Status: Draft for user audit
Prior versions: [versions/](versions/)

## 1. Document authority

This PRD defines product behavior. The companion TRD defines implementation and verification. Agreed decisions below reflect the conversation; proposed defaults require review and are not implied approvals. Changes to scope or behavior must update this document and its decision log. If implementation conflicts with this PRD, resolve the discrepancy before shipping. Performance numbers are targets, not demonstrated results.

## 2. Product purpose

An iOS camera app that helps a photographer take photos their partner likes through iterative, recipe-based live coaching. The initial audience is boyfriends photographing girlfriends; instructions should work for partners generally. Success means useful guidance and preferred photos, not compliance with universal beauty or composition scores.

Core loop: choose a shot recipe → observe the live scene → suggest one photographer adjustment → reassess → signal readiness → capture. Capture remains available regardless of coaching readiness.

## 3. Agreed decisions

| ID | Decision |
|---|---|
| D01 | Native iOS camera experience is the product direction; this is no longer a 3D game. |
| D02 | Begin with recipes and iterative live coaching. |
| D03 | No reference silhouettes, ghost images, or composition-matching overlays in the live viewfinder. Text coaching is allowed. |
| D04 | Coach the photographer first. Partner posing coaching is a later expansion. |
| D05 | A smooth camera and low-latency experience are central requirements. Native Camera comparability is an aspiration to measure, not a parity claim. |
| D06 | Xiaohongshu examples and tips inform the content direction. No custom training dataset or content reuse rights have been established. |
| D07 | Face enrollment, preferred-angle personalization, arbitrary reference interpretation, and cloud visual coaching are deferred. |
| D08 | Target is a public App Store product, English first. Localization and other storefronts come later. |
| D09 | Business model is freemium subscription: on-device coaching free; paid tier is expected to include cloud AI critique and possibly additional recipes. |
| D10 | Cloud AI photo critique is a planned later paid feature, not part of the prototype. It requires a server and explicit per-photo consent before any upload, and will amend §9 when scoped. |
| D11 | Minimum OS is iOS 18; hardware support decided after benchmarking. |
| D12 | Prototype coaching is text plus a light haptic when the shot becomes ready. |
| D13 | Capture flow is review-then-save. |
| D14 | Build order: camera preview baseline → Vision body tracking → framing evaluation and coaching. |
| D15 | Live coaching uses on-device Vision observations plus deterministic recipe rules. AI models are reserved for later post-capture critique. |
| D16 | Development and test devices: iPhone 16 through iPhone 18 Pro. Live coaching does not depend on Apple Intelligence (D15). The shipped support floor is still set by benchmarking (TRD §13, Phase 6). |

## 4. Initial scope — proposed defaults

One curated full-body standing/outfit recipe, one visible subject, portrait orientation, rear 1× camera, still photos, on-device coaching, no account. Automatic focus/exposure with tap-to-focus. Recipe selection may include a licensed/original example image outside the live camera. A light haptic signals readiness (D12). Voice, other haptics, zoom/lens switching, editing, automatic capture, burst selection, and post-capture critique are outside the first prototype.

The single recipe is a validation vehicle, not the final catalog. Camera startup defaults to the last recipe after the first selection. A recipe introduction provides short starting guidance; it is clearly distinguished from live observations.

## 5. Functional requirements

| ID | Requirement | Acceptance condition |
|---|---|---|
| F01 | Explain and select a recipe | User can understand the intended shot and begin without a tutorial. |
| F02 | Show an unobstructed camera preview | No reference overlay; shutter and essential camera controls remain accessible. |
| F03 | Give one active photographer instruction | Every instruction names a physical action; no competing instructions appear together. |
| F04 | Reassess after movement | Guidance changes only after sufficient reliable evidence; old advice expires. |
| F05 | Apply recipe-specific targets | Centering and thirds are optional recipe choices, not universal rules. |
| F06 | Allow capture at any coaching state | Coaching does not disable the shutter; hardware capture readiness may temporarily limit capture. |
| F07 | Support dismissing guidance | A user can skip a suggestion or pause coaching; dismissed advice does not immediately return. |
| F08 | Signal readiness and remain quiet | “Framing looks good” means supported checks pass, not that the photo is objectively flattering. |
| F09 | Handle uncertain observations | Suppress corrective advice when evidence is weak; explain briefly if sustained uncertainty prevents coaching. |
| F10 | Review and save | User can review a captured photo, save to Photos, discard, or return to shooting; failed saves preserve the photo for retry. |
| F11 | Handle permission/lifecycle failures | Explain denied camera access; handle interruptions and resumption without stale instructions. |

## 6. Initial coaching capabilities

Candidate checks: phone roll, subject size in frame, subject horizontal placement, and boundary margins when relevant landmarks are reliably visible. Ship only checks that pass validation.

| Condition | Candidate instruction | Constraint |
|---|---|---|
| Phone rolled beyond recipe tolerance | “Straighten your phone.” | Phone roll is not the same as a scene horizon. |
| Confident subject bounds exceed target size | “Step back a little.” | Use only when backward movement is appropriate; no inferred exact distance. |
| Subject too small | “Move a little closer.” | Suppress when the recipe intentionally emphasizes surroundings. |
| Subject horizontally displaced | “Aim slightly to your left/right.” | Screen-coordinate direction must be verified; this changes framing, not viewpoint. |
| Reliable feet near bottom edge | “Aim slightly lower to leave room below their feet.” | Missing feet alone cannot prove cropping. |

“Raise the camera,” “lower the camera,” “move left for a better angle,” and “don’t tilt down” are desired future capabilities, not unconditional first-pass promises. Phone pitch can be measured, but the correct pitch or camera height cannot be recovered from a generic reference alone. A validated recipe may give an authored starting instruction such as camera height, without claiming it is a measured correction.

## 7. Coach interaction policy

Priority: essential inclusion → recipe framing → orientation refinement. Select one corrective action; do not turn every small deviation into an instruction. Use tolerance bands, dwell time, and cooldowns. Re-evaluate while the user acts; do not require explicit completion taps. Acknowledge improvement briefly only when useful. Suppress reversals near thresholds. Explain persistent no-subject/multiple-subject conditions once, rather than repeatedly.

Proposed states: starting, observing, adjusting, ready, uncertain, paused, interrupted. Capturing/review are camera states independent of coaching. Ready can return to observing after meaningful scene changes.

## 8. Content policy

Recipes contain a shot goal, authored starting setup, supported measurable targets, priority rules, action wording, applicability limits, and provenance. Use original guidance and original/licensed imagery. Record permissions before displaying third-party content or using it for training. Studying techniques does not establish rights to reproduce posts. No scraping/training pipeline in this scope.

## 9. Quality and privacy

Analyze selected frames locally; do not upload or retain live analysis frames. No face identity enrollment. Save photos only through the defined user flow. Any diagnostic image collection requires explicit opt-in. Coaching must degrade before camera responsiveness does. Support readable text, VoiceOver-accessible controls, and status conveyed without color alone.

## 10. Validation and release gates

Proposed pilot: 8–12 couples, alternating recipe-thumbnail-only shooting and live coaching, counterbalanced to reduce learning effects. Partners choose preferred photos without knowing condition where practical. Record instruction comprehension, unnecessary corrections, reversals, time to a usable shot, and preference. This is a directional pilot, not statistical proof.

Provisional product gate: at least 80% of observed instructions understood without explanation; fewer than 10% judged incorrect or unhelpful; coached photos preferred in at least 60% of comparisons. Audit these thresholds before testing. Also require TRD camera/performance gates and no unresolved save-loss, stale-guidance, or interruption failures.

## 11. Open decisions

- Confirm whether example photos appear on recipe selection only. (First recipe confirmed: full-body outfit.)
- Confirm minimum iPhone hardware after benchmarking (iOS 18 floor agreed; test range iPhone 16–18 Pro per D16).
- Decide later voice priority.
- Decide whether auto-save becomes an option (review-then-save agreed for prototype).
- Define free vs. paid boundary and cloud critique scope before building the backend.
- Approve pilot method and product/performance thresholds.
- Decide which three or four live corrections survive the capability spike.

## 12. Decision log

| Date | Change | Status |
|---|---|---|
| October 11, 2026 | Recorded D01–D07 from discussion; proposed initial scope and gates | v0.1 draft; user audit pending |
| October 11, 2026 | Added D08–D14 (App Store, freemium, cloud critique later, iOS 18, haptic ready signal, review-then-save, build order); narrowed open decisions; D15 live coaching is on-device rules | v0.2 draft; v0.1 in versions/ |
| October 12, 2026 | Added D16 (test device range iPhone 16–18 Pro; no Apple Intelligence dependency) | v0.3 draft; v0.2 in versions/ |
