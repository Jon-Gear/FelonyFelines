# Domain layer

**What lives here:** game data concepts — what things *are* and what facts the game
tracks. Pure data/state classes, enums, wrapped-ID types, and the configuration
vocabulary (`Resource` *definitions*, not behaviors).

**Everything else depends on this layer.** Domain scripts never reference Application,
Presentation, Infrastructure, or Editor symbols, and never touch `get_tree()`,
scenes, or nodes.

Examples (from ARCHITECTURE.md):

- `AppState` and its sub-states (`GameSessionState`, `BrothersState`, `WaveState`,
  `FlowState`, `Flags`)
- wrapped-ID value types (`WeaponId`, `EnemyTypeId`)
- configuration `Resource` scripts, catalogs, rule/condition strategy assets

See `docs/CONVENTIONS.md` for the Domain naming conventions and the full layer map.