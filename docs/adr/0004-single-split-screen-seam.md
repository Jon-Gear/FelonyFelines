# ADR-0004 — One split-screen module behind one brother-facts seam

Status: **Accepted**

Deciders: Restructure spec (`RESTRUCTURE_PLAN.md`, user stories 12–15), issue
Jon-Gear/FelonyFelines#14

Date: 2026-09-21

## Context

The dynamic split-screen rig is hand-wired and has two setup paths. Two cameras +
a shader live in `SplitScreenCamera.tscn`; `SplitScreenCamera.gd` is a no-op
wrapper whose `current_world_path` is never set anywhere, so if someone did set it
the controller's `setup()` would run twice. The actual work happens in
`camera_controller.gd`, which bounces between scene paths
(`$ViewportContainer/Viewport1`, …), the global `"camera"` group, `Global.brother_1/2`
and player internals (`player_visual_middle`, `health_manager.is_dead()`). Four
leak edges run to Global, Shake, and both player subtrees. Standing up a second
world scene means re-wiring the same six-file handshake; a new brother type breaks
the rig.

## Decision

The split-screen is collapsed into **one deep module behind a small seam**. The
seam exposes the three facts the module needs per brother: position provider,
visual offset, and alive. No `Global.brother_1/2`, no player internals, no
`"camera"` group handshake.

- The dormant wrapper (`SplitScreenCamera.gd`) is deleted; setup happens exactly
  once.
- Camera shake becomes an internal detail of the module (folded into a
  `CameraFxAdapter`), so camera transforms are owned in one place.
- Camera geometry becomes a pure core: midpoint cameras, split line, dead-brother
  fallback, clamping to `max_separation`, and the 10 px quirk of ADR-0003 are
  preserved and unit-testable headlessly.
- Real player nodes in prod and fakes in tests both satisfy the seam (adapter
  pattern).

## Consequences

- One interface for every future world scene instead of a 6-file hand-wiring; a
  new brother type no longer breaks the camera rig (user story 12).
- The 10 px quirk lives in exactly one place to fix (under ADR-0003's rules).
- Deletes dead code: the wrapper that never runs and the group-scan shake logic
  (`Shake.gd`) whose condition is inverted.
- There is exactly one way to set up the split-screen (user story 13).