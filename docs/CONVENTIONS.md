# Naming and layout conventions

> The codebase is organized into **five layers** under `src/` — Domain, Application,
> Infrastructure, Presentation, Editor — plus a parallel **configuration-assets
> tree** under `resources/` and a scene tree under `scenes/`. This document fixes
> the layout and the per-layer naming conventions. It is the naming contract every
> script must follow.

Status: **accepted** · companion to `ARCHITECTURE.md`, `RESTRUCTURE_PLAN.md`,
and ADR-0001 (`docs/adr/0001-one-way-dependency-rule.md`).

---

## 1. The layout

```
project.godot
CONTEXT.md            ← domain glossary (brother, wave, drop, split-screen, fire, …)
src/
  domain/           ← game data concepts, facts, configuration vocabulary
  application/      ← gameplay rules (services over AppState)
  infrastructure/   ← adapters around external systems (ngio, save, audio, camera FX)
  presentation/     ← scenes, nodes, UI, input, entities (Godot glue)
  editor/           ← editor plugins / @tool authoring and debug tooling
resources/          ← configuration assets (.tres): catalogs, definitions, rules, conditions, presets, ui
scenes/             ← scene roles (*.tscn) grouped by role: menu/, levels/, ui/
docs/
  CONVENTIONS.md    ← this file
  TESTING.md        ← test framework and the assert-behavior convention
  adr/              ← recorded architecture decisions (ADR-xxxx-*.md)
```

| Layer | Folder | Responsibility | What goes here |
|---|---|---|---|
| **Domain** | `src/domain/` | Game data concepts | `AppState` + sub-states, configuration `Resource` scripts, catalogs, wrapped-ID types, enums |
| **Application** | `src/application/` | Gameplay rules | `RefCounted` services (wave, score, combat, respawn, weapon, loot), feature-module wiring |
| **Infrastructure** | `src/infrastructure/` | External-system adapters | `NewgroundsAdapter`, `SaveAdapter`, `AudioAdapter`, `CameraFxAdapter` |
| **Presentation** | `src/presentation/` | Scene / UI code | `AppSession`, `FlowController`, scene controllers, entity nodes, UI, input |
| **Editor** | `src/editor/` | Authoring / debug tooling | `EditorPlugin`, docks, normalize-IDs pass, preset editors, `@tool` scripts |

### Dependency rule

Dependencies flow **one way only** — a layer never reaches "up" into a layer above
it:

```
Domain ← Application ← Presentation
```

- **Domain** is referenced by all; it references nothing outside itself.
- **Application** references Domain only; never nodes, scenes, or `get_tree()`.
- **Presentation** references Application and Domain (and Infrastructure adapters).
- **Infrastructure** is referenced by Presentation when adapting external systems;
  it is the only layer allowed to import third-party packages.
- **Editor** references Presentation + Domain; it is **never referenced at runtime**.

A script that lives in `presentation/` never `extends` a script in `application/`;
a service in `application/` never `preload()`s a scene or touches `get_tree()`.

---

## 2. GDScript file and class naming (all layers)

GDScript has no namespaces: **layer membership is the folder**. Conventions:

- File name: `snake_case.gd` matching the class (`app_session.gd`, `flow_controller.gd`).
- `class_name`: PascalCase, globally unique. When the same natural name would
  appear in two layers, prefix it with the role (`GameSessionState` in Domain vs
  `GameSessionService` in Application).
- A script in `src/domain/` must not depend on scripts in other layers. A script
  may only `preload()` / `class_name`-reference symbols from layers it is allowed
  to see (see dependency rule).

---

## 3. Per-layer conventions

### Domain (`src/domain/`) — **facts**

Fields and state are `snake_case` (`is_dead`, `wave_num`, `enemy_count`); classes
are PascalCase. State classes hold their behavior in methods (`begin()`,
`advance(...)`, `mark_done(...)`, `reset()`) — not just passive data bags.

- Identity uses **wrapped value types**, never bare strings, in signatures:
  `WeaponId`, `EnemyTypeId` (expose `_to_string()`, `==`, and equality against the
  raw value).
- Definitions are data `Resource`s: stable `id` + `display_name`, per-definition
  data, rule (strategy) arrays, and scene/variant references where a definition
  maps to scene content.
- Global discrete facts live in a case-insensitive flag set
  (`has_flag / set_flag / clear_flag`).

### Application (`src/application/`) — **rules**

Same `snake_case` field style. Methods are **verb phrases** (`prepare_selectable`,
`advance_wave`, `evaluate`, `complete_current_step`).

- Services are plain `RefCounted`, constructor-injected with `AppState` (+ config).
- Methods fall into *prepare/select/query* families where a feature presents
  choices; mutation is the service's job — never return a result enum and let the
  caller mutate.
- Deterministic: same `AppState` + same inputs → same result (except explicit RNG,
  injected or internally owned).

### Presentation (`src/presentation/`) — **Godot glue**

Godot node conventions: `@export` for inspector-editable fields, `@onready` for
node references, `_ready()` / `_process()` / `_physics_process()` lifecycle, and
signals named for what happened (`shot_fired`, `player_died`, `all_dead`).

- Entity scripts are **adapters over `AppState`**: they own physics, animation,
  `Camera2D`, inputs, and visuals; authoritative life/spawn/damage/ammo facts live
  in state and are changed through services. They never hold a second copy of a
  fact state owns.
- Movement helpers (`move_and_slide`, knockback) are the one acceptable piece of
  game logic on a node: it is physics, which only lives at this layer.
- Views (Controls) never mutate state directly — they call services or flow methods.
- Signals cross the seam *upward* (entity → controller → flow); never use them for
  service-to-service chatter.

### Infrastructure (`src/infrastructure/`) — **adapters**

Adapter singletons per external system expose a small, **game-shaped** interface,
never the library's types (`post_score(id, value)` behind `NewgroundsAdapter`, not
`ngio.request(...)`). Only this layer may import third-party packages.

### Editor (`src/editor/`) — **tooling**

Every editor file guards runtime sections with `if Engine.is_editor_hint():` or
lives in an `EditorPlugin`. It is never referenced at runtime.

---

## 4. Configuration assets (`resources/`)

- `.tres` assets are grouped by subsystem and named `kebab-case.tres`
  (`default_catalog.tres`, `app_config.tres`). The tree is shipped; the asset
  files land with the tickets that author them.
- Root configuration `app_config.tres` (planned with the AppSession ticket)
  carries `entry_scene`, `starting_wave`, `default_catalog`, and
  `initial_state_preset`.
- Definitions auto-generate stable IDs from the asset file name
  (`IdUtils.normalize(name)` = `name.strip_edges().to_lower().replace(" ", "-")`)
  via the editor **normalize-IDs pass** (Godot has no `OnValidate`).
- All ID comparisons are case-insensitive; service signatures use wrapped-ID types
  from Domain, never bare strings.

## 5. Scenes (`scenes/`)

Scene groups mirror content roles (`scenes/menu`, `scenes/levels`, `scenes/ui`);
scene names match configuration entries exactly. The `FlowController` decides which
scene loads next; scenes report completion via `complete_current_step` /
`notify_step_complete`.

## 6. Other rules

- Always validate required constructor dependencies (`assert` in debug) and
  missing required configuration (`push_error` with a message that says exactly
  what is missing).
- Signals are used for crossing the seam upward only, never service-to-service
  chatter.
- "Is this a fact/concept, an enum, or a config asset?" → **Domain**. "Is this a
  rule/workflow that orchestrates state?" → **Application**. "Does it touch a
  scene, node, physics body, UI, or third-party system?" → **Presentation /
  Infrastructure**. "Does it only help author/debug?" → **Editor**.
- Tests live outside `src/` in `tests/`, run under GUT, and assert behavior only —
  construct state, invoke a module, assert the result; never assert wiring. See
  `docs/TESTING.md`.