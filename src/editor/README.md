# Editor layer

**What lives here:** Godot editor plugins and `@tool` scripts for authoring, build
automation, and debugging aids. Never referenced at runtime; every file either
lives in an `EditorPlugin` or guards its runtime sections with
`if Engine.is_editor_hint():`.

**This layer references Presentation + Domain only**, and is never used at runtime.

Examples (from ARCHITECTURE.md):

- **Normalize-IDs pass** — walks `resources/definitions/**` and backfills missing
  definition IDs from file names (the `OnValidate` stand-in; Godot has none)
- **Scene-list installer** — appends `scenes/*.tscn` to the build list; menu items
  for rebuilding the scene list
- **Flow / state diagnostics dock** — reads `FlowController.inspector_*` live in
  play mode, with play-mode buttons (`Start New`, `Reset Progression`, `Skip`)
- **Config / preset resource editors** — `AppConfig` editor, "Apply Preset To
  Live Session", `AppStateDebugPreset` inspector

See `docs/CONVENTIONS.md` for the Editor naming conventions and the full layer map.