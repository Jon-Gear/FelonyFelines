# Configuration assets (`resources/`)

Parallel to the `src/` layer tree. All game data is authored as custom `Resource`
classes instantiated as `.tres` assets here, referenced from a single root
configuration (`app_config.tres`). This keeps the game data-driven and hot-editable
without touching code.

```
resources/
  app_config.tres            ← the root config (resolved by AppSession) — planned, not yet shipped
  catalogs/default_catalog.tres ← planned, not yet shipped
  definitions/
    weapons/                 ← weapon definitions (id, damage, fire spec, drop weight)
    enemies/                 ← enemy definitions (id, hp, drop percent, behavior params)
    waves/                   ← wave definition assets
    items/
  rules/                     ← rule/strategy assets ("can this happen now?")
  conditions/                ← strategy assets ("is this done?")
  presets/                   ← initial-state presets for debugging
  ui/                        ← .theme / fonts / shared UI resources
```

This ticket ships the **tree** (folders + this README). The `.tres` assets land with
the tickets that author them (`app_config.tres` with the AppSession ticket,
definitions/catalogs with the data-driven configuration ticket); CONTEXT.md marks
them "none yet" until then.

Naming conventions:

- `.tres` assets are grouped by subsystem and named `kebab-case.tres`.
- Generated string IDs fall back to the asset file name
  (`IdUtils.normalize(name)` = `name.strip_edges().to_lower().replace(" ", "-")`)
  via the editor normalize-IDs pass.
- All ID comparisons are case-insensitive; service signatures use wrapped-ID value
  types from Domain, never bare strings.

See `docs/CONVENTIONS.md` for the full naming and layout rules.