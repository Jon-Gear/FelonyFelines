# Infrastructure layer

**What lives here:** adapters around external systems — talking to libraries and
plug-ins so the rest of the game never depends on their details. The only layer
allowed to import third-party packages.

**Who may reference it:** Presentation, when adapting an external system. Domain
and Application never see Infrastructure types.

Adapters speak in **game terms**, not library terms (e.g. `post_score(id, value)`,
not `ngio.request(...)`).

Examples (from ARCHITECTURE.md):

- `NewgroundsAdapter` — wraps the `ngio` plug-in (`login`, `post_score`,
  `log_event`)
- `SaveAdapter` — serializes `AppState.to_dict()` to the user data dir
- `AudioAdapter` — wraps `AudioServer` buses (`play_sfx(id)`, `set_bgm(id)`)
- `CameraFxAdapter` — owns `Camera2D` shake/juice (`shake(4, 0.5)`)

See `docs/CONVENTIONS.md` for the Infrastructure naming conventions and the full layer map.