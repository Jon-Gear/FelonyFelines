# Programming Architecture (Godot 4 · GDScript)

> **Purpose:** the starting architecture blueprint for this project, translated from the Unity model to Godot 4 + GDScript. It defines how code is organized into layers, how the app session is composed, how state and configuration work, and the conventions every script must follow. Follow this document when scaffolding the project and when writing every new feature.

> The vocabulary is intentionally generic. Where a name is written verbatim (`AppSession`, `AppState`, `FlowController`, `FeatureModule`) that is the canonical name to use. Everything else (`<Subsystem>`, `<Module>`, `<Feature>`) is a placeholder you fill in per feature. GDScript has no namespaces and no assemblies; **layer membership is encoded by folder**, and file names are `snake_case.gd` with a PascalCase `class_name`. Where the reference model said "namespace", read "folder".

> This document is the *target*. The current tree predates it (see Appendix A for how today's files map onto the layers and where `Global.gd` dissolves).
 
---

## 1. The five layers (the core of the model)

The entire codebase is organized into five layers under one `src/` tree. Dependencies flow **one way only**; a layer never reaches "up" into a layer above it.

| Layer | Folder | Responsibility | What goes here |
|---|---|---|---|
| **Domain** | `src/domain/` | **Game data concepts**: what things *are*, what facts the game tracks, and the configuration vocabulary. Pure data/state classes, enums, ID types, and `Resource` *definitions* (not behaviors). | `AppState` (and sub-states), configuration `Resource` scripts, catalogs, rule/condition data assets, enums, wrapped-ID types |
| **Application** | `src/application/` | **Gameplay rules**: the workflows and use cases. Plain `RefCounted` service classes that take `AppState` (+ configuration) and mutate it. No scene nodes, no physics bodies, no UI. | Services, feature-module wiring, request/result payload types |
| **Infrastructure** | `src/infrastructure/` | **External system adapters**: talking to libraries/plug-ins so the rest of the game never depends on their details. | Adapters for Newgrounds (`ngio`), audio, save systems, input post-processing, camera FX rigs |
| **Presentation** | `src/presentation/` | **Scene / UI code**: Nodes that live in scenes, drive scenes, render UI, and translate input / external events into Application calls. Every `KinematicBody2D`/`CharacterBody2D` entity lives here as an adapter over state. | `AppSession`, `FlowController`, scene controllers, entity nodes, UI, input handlers |
| **Editor** | `src/editor/` | **Editor tooling**: Godot editor plugins and `@tool` scripts for authoring, build automation, debugging aids. Every file guarded or compiled only in the editor. | `EditorPlugin`, custom docks/windows, build helpers, preset editors, a play-mode state monitor |

```
                ┌──────────────────────────┐
                │  Presentation            │  AppSession, FlowController, Node scripts, scenes, UI, input, entities
                └──────────┬───────────────┘
                           │ references
                ┌──────────▼───────────────┐
                │  Application             │  services / workflows (RefCounted)
                └──────────┬───────────────┘
                           │ references
                ┌──────────▼───────────────┐
                │  Domain                  │  AppState + configuration (Resource / plain data)
                └──────────────────────────┘
    Infrastructure ── referenced by Presentation when adapting external systems
    Editor         ── references Presentation + Domain; NEVER referenced at runtime
```

- **Domain is the foundation.** Everything else stands on it. If a type is a *fact about the game world* (a concept, a rule data asset, an enum of what state can be), it lives in Domain even when it is a Godot `Resource` (`.tres`).
- **Application is orchestration.** Services hold no node or scene references and are fully deterministic against `AppState`.
- **Presentation is Godot-facing glue.** Nodes, physics bodies, scene loads, UI, and input. Entity scripts (base_entity, player, enemies, weapons) are Presentation *adapters*: they own physics and visuals and forward state changes to Application; they never hold authoritative game facts.
- **Infrastructure hides third parties.** The rest of the game should not know "this is Newgrounds" through its main flow — only through an adapter contract.
- **Editor is authoring tooling.** Every editor file lives under `src/editor/` and checks `Engine.is_editor_hint()` where it runs inside the engine.

### Folder layout

```
project.godot
src/
  domain/             application/    infrastructure/    presentation/    editor/
resources/            ← .tres configuration assets (definitions, catalogs, rules, presets, UI)
scenes/               ← scene roles (*.tscn), grouped by role
```

Configuration lives in `.tres` assets under `resources/` — the Godot equivalent of Unity's `Resources/<Project>/`. Authoring them is data-driven and hot-editable without touching code.

---

## 2. Class names, folders, and conventions

- GDScript has **no namespaces and no per-layer assemblies**. Layer membership is the folder under `src/`. `class_name` must be globally unique, so:
  - File name: `snake_case.gd` matching the class (`app_session.gd`, `flow_controller.gd`).
  - `class_name`: PascalCase. When the same natural name would appear in two layers, prefix it (`GameSessionState` in Domain vs `GameSessionService` in Application).
- **Folder and role always agree.** A script that lives in `presentation/` must not `extends` a script in `application/`. A service in `application/` must never `preload()` a scene or touch `get_tree()`.
- One naming convention per layer, consistently:
  - Domain: snake_case state fields (`is_dead`, `wave_num`), PascalCase classes.
  - Application: same field style; methods are verb phrases (`prepare_selectable`, `advance_wave`, `evaluate`).
  - Presentation: Godot node conventions (`@export`, `@onready`, `_ready`, signals like `shot_fired`).
- Dependencies are expressed by **preload-ed class constants** in the owning layer only. A Presentation script may preload Application and Domain symbols; an Application script may preload Domain symbols; a Domain script preloads nothing outside Domain.

---

## 3. The AppSession (the composition root)

`AppSession` is the app's **singleton composition root**. It is an **autoload Node** (first in `project.godot > [autoload]`), the Godot equivalent of the `DontDestroyOnLoad` mono-singleton. It **owns the `AppState` and all services**, and is the only place services are constructed (manual composition — no DI framework). Everything that needs a service goes through `AppSession.<Service>`.

Files: `src/presentation/session/app_session.gd` (autoload), plus `app_state.gd` in Domain.

Required shape:

- **Autoload singleton** — always alive, outlives every scene. It replaces the current `Global` autoload.
- **`_ready()` → `build_runtime()`** — the compose method. Resolves configuration, constructs a fresh `AppState`, news up each service passing `State` (+ config), loads feature modules from `resources/`, and applies the default catalog.
- **Owns:**
  - `configuration` — the root configuration (a custom `Resource`). Resolved from an autoload field, falling back to `load("res://resources/app_config.tres")`.
  - `state` — the `AppState`.
  - One read-only property per service, e.g. `var wave_service: WaveService`.
  - The `FlowController` (a Node).
- **`reset_runtime_state()`** — rebuilds the runtime (`build_runtime`) and re-binds the flow controller. Used by "start new game" and editor "apply preset" flows.
- **Direct scene play is native to Godot:** because `AppSession` is an autoload, playing *any* scene (F6 / "Run Current Scene") already has a session and a flow controller. No `RuntimeInitializeOnLoadMethod` analogue is needed — the flow controller decides, from the entry-scene name in configuration, whether to run the full game or a single scene in isolation.
- **`editor_…` hooks:** `if Engine.is_editor_hint():` sections and `@tool` entry points used by editor tools to swap the live state (presets, reset, debugging) without polluting the runtime interface.

`build_runtime()` throws guarded errors (`push_error` + early `return`, or `assert` in debug) when required configuration cannot be resolved — fail loudly and early at startup, not mid-gameplay.

### AppSession responsibilities checklist

- Exists once per app (autoload).
- Resolves configuration; builds `AppState` + services.
- Is the **only** place services are constructed.
- Can rebuild its runtime (reset, presets, new game).
- Works when any scene is played directly.
- Pumps live state into the `FlowController`.

---

## 4. AppState

A plain `RefCounted` class holding the whole playthrough state as a bundle of typed sub-states. Services read and mutate it directly (no event bus, no reactive store — simple and predictable). For persistence, `AppState` implements `to_dict()` / `from_dict()`; a save adapter serializes that (see Infrastructure).

Shape:

```
AppState
├── GameSessionState          wave_num, points, enemy_count, drops_loot
├── BrothersState             per-brother: alive, armed with <weapon id>
├── WaveState                 phase, spawn budget, elapsed
├── Flags                     Dictionary<String,bool>  (case-insensitive global flags)
├── <FeatureHubState>         per registered feature module
└── Flow                      FlowState (phase + progress of the app flow)
```

Guidelines for sub-states:

- Each sub-state is its own class with **behavior in its methods** (`begin()`, `advance(...)`, `mark_done(...)`, `reset()`) — not just a passive data bag.
- **Identity uses value-type wrappers, not raw strings.** GDScript has no `struct`; wrap IDs in small classes (`WeaponId`, `EnemyTypeId`) exposing `_to_string()`, `==`, and equality against the raw value (or encode as `StringName` with a doc note). Bare `String` keys are forbidden in service signatures.
- State transitions that "consume" something (e.g. `consume_drop`, `mark_discussed`) move from an *available* list to a *done* list — keep both so the state can answer "is X done?" against history.
- Global discrete facts live in a **case-insensitive flag set** (`has_flag / set_flag / clear_flag`), stored in the `Flags` dictionary with a canonical lowercase key.
- Keep an explicit enum of flow **phases** (see FlowController) in `FlowState` so debug tools can show exactly where the app is.

> When scaffolding: your `AppState` should be one class composed of typed sub-states; identifiers wrapped; flow progress tracked in a phase enum.

---

## 5. Configuration = `Resource` assets in `resources/`

All game data is authored as custom `Resource` classes instantiated as `.tres` assets under `resources/`, referenced from a single root configuration. This makes the game data-driven and hot-editable without touching code.

Typical tree:

```
resources/
  app_config.tres            ← the root config (resolved by AppSession)
  catalogs/default_catalog.tres
  definitions/
    weapons/                 ← weapon definitions (per weapon: id, damage, fire spec, drop weight)
    enemies/                 ← enemy definitions (id, hp, drop percent, behavior params)
    waves/                   ← wave definition assets
    items/
  rules/                     ← rule/strategy assets ("can this happen now?")
  conditions/                ← strategy assets ("is this done?")
  presets/                   ← initial-state presets for debugging
  ui/                        ← .theme / fonts / shared UI resources
```

**Root configuration** (`AppConfig : Resource`) exported fields:
- `entry_scene` (String/`PackedScene`),
- `starting_wave`,
- `default_catalog` (a `Catalog` resource),
- `initial_state_preset` (an `AppStateDebugPreset` resource),
- find/query helpers against the above.

**Catalog** (`Catalog : Resource`) — an array of definition resources plus lookups `get_by_id(id)` / `for_scene(scene_name)`.

**Definitions are data Resources:**
- stable `id` + `display_name` + description,
- per-definition data (damage, spread, duration, cost…),
- *rules* (strategy) arrays,
- scene/variant references where a definition maps to scene content (e.g. `scene_path` for enemy/weapon/level scenes),
- **auto-generated fallback IDs.** Godot has no `OnValidate`; the Editor layer provides a *normalize-IDs* pass (EditorPlugin button / dock) that backfills missing IDs from the asset file name, lowercased, spaces → dashes.

**Rules are Strategy resources** — an abstract `<Thing>Rule : Resource` with `evaluate(context) -> RuleResult`. Concrete subclasses (`TimeWindowRule`, `RequiredFlagRule`, `ForbiddenFlagRule`, `OncePerWaveRule`, `PrerequisiteRule`…) are authored as assets and composed onto definitions. `RuleResult` is a small readonly-shaped class (`is_available` + `reason`).

**Conditions** use the same strategy pattern for "is this stage complete?" (`EnemiesDeadCondition`, `WaveCompletedCondition`, `FlagCondition`, `BrothersAliveCondition`), evaluated against a progress snapshot (state + counts).

---

## 6. Services (Application layer)

Plain `RefCounted` classes constructed in `AppSession`, holding `AppState` and configuration. They expose small methods; transient session-loop state lives in private fields; persistent/progress state is always written into `AppState`. **Services never reference scenes, nodes, UI, or each other directly** — they receive exactly what they need via their constructor.

Conventions:

- One service per workflow/system: `WaveService`, `ScoreService`, `LootService`, `CombatService`, `WeaponService`, `RespawnService`.
- Constructor takes `AppState` (required, non-null) and any configuration it needs (also validated non-null).
- Methods fall into *prepare/select/query* families where a feature presents choices:
  - `prepare_selectable(...)` builds a short **ordered/sampled** selection from everything available;
  - `select(index)` / `select_random()` consume one and return it (typically also marking it *done* in state);
  - `can_…`, `has_…`, `get_…` are query-only.
- Mutating methods update `AppState` and return nothing meaningful; mutation is the service's job — never return a result enum and let the caller mutate.
- Deterministic: same `AppState` + same inputs → same result (except explicit RNG, injected or owned internally by a dedicated randomizer).

Current game flows that become services, spelled out:

| Flow | Service | What it owns |
|---|---|---|
| Points, waves, enemy budget | `WaveService` | advance `WaveState`, spawn budgets, `enemy_count`, score events |
| Eating a brother's death + respawn | `RespawnService` | which brother is down, respawn eligibility (from `RespawnRule`), revive |
| Weapon switching / ammo | `WeaponService` | current slot per brother, ammo, swap gesture, ammo-consumed events |
| Drops on death | `LootService` | drop rolls from `LootRule`, spawn definitions, instantiate through a spawn adapter |
| Damage reconciles state | `CombatService` | apply damage to `BrothersState`/enemy lives, deaths, friendly-fire rules |

---

## 7. Features and modules (the composition pattern)

New features should be **additive**: you add a module + assets + a scene, and the core loop stays untouched. The pattern has three parts:

```
<FeatureType>Module (Resource, authored under resources/definitions or registered in code)
   · stable module_id
   · register(<definition>, <catalog>, <services…>)
   · try_create_request_for_scene(<definition>, <catalog>, scene_name) -> Request? (or null)

register() wires two things:
   1. a Handler (execute side)   — resolves a Request → Run / RuntimeData
   2. a Provider (present side)  — enumerates the selectable Options for the player/UI
```

### The pipeline

```
<Definition> (data, Domain)
     │  definition.module_id → <FeatureType>Module
     │        register() →  Service.register(handler)  +  QueryService.register(option_provider)
     ▼
Selection (UI/input) → <Input> (typed) wrapped in a <Request>
     ▼
Service.evaluate(request)
     ├─ global rules (can this start at all? e.g. wave limits)
     ├─ definition.rules (strategy assets)
     └─ handler.resolve(context, definition, input) → StartResult(run)
     ▼
state.current = run        (run: id, scene, start context, typed runtime-data payload)
     ▼
FlowController loads the run's scene → Presentation drives the scene
     ▼
Completion → CompleteResult(duration, effects(state)) → Service.complete_current(run)
     ▼
        effects applied to state, progress/consumables advanced, history appended
```

### The pieces

- **`<Input>`** — typed payload (`SelectionKey`, `matches(other)`, plus per-feature fields). A "no input" singleton exists for features with nothing to choose.
- **`<Request>`** — generic wrapper pairing a definition with a typed input.
- **`<Handler>`** — validates the input, evaluates definition + entity rules, and returns a **StartResult** (`success(run)` / `failed(reason)`). Generic base per input type.
- **`<Provider>`** — yields concrete **Options** (`display_name`, request, `is_available`, `unavailable_reason`) for a query service to collect and present.
- **`<QueryService>`** — aggregates options from all registered providers; offers `get_options()` / `find_option(id, key)`.
- **`<ModuleRegistry>`** — maps module IDs → modules; walks the catalog and calls `module.register(...)`. **This is the plugin point**: adding a new feature type never touches the central loop.
- **Results** — small readonly-shaped result classes (`StartResult`, `CompleteResult { run, duration, should_advance }`).

> Rule of thumb: the `FlowController` and `AppSession` **never branch on feature IDs or definition IDs**. If a new feature needs to be recognized, it enters through a module + catalog entry.

---

## 8. The FlowController (scene-flow state machine)

`FlowController` (Presentation) is a Node that **orders scenes and drives the app forward**. It is constructed by `AppSession` and lives outside every level scene. It holds the current phase in `FlowState.phase` and drives transitions with `await` on signals/timers (Godot's coroutine). Every "next thing" in the app (entry, menu → level, wave → wave, level → menu, background systems) funnels through it.

Design:

- **A phase enum in Domain (`FlowState`)** names every distinct spot in the flow: `ENTRY → MENU → WAVE_SETUP → WAVE_ACTIVE → RESOLVING → GAME_OVER` plus a debug `STANDALONE_SCENE` phase.
- **Public methods are the only way to advance the flow:**
  - `start_new()`, `reset_all()`, `skip_to_next_step()`;
  - `begin_step(request)` — validates the current phase, sets a `Loading` phase, starts a transition routine (`notify_step_transitioning` emitted);
  - `complete_current_step(result)` — the single completion entry point (scenes and controllers call this when done);
  - `notify_step_complete()` — generic "the current scene/sequence is done, continue", resolves the next transition **based on the current phase**.
- **Transition mechanism:** one active routine at a time (a `replacing` guard cancels the previous). Routines:
  1. wait for the active scene's blocking presenter to finish (wave timer, animation, sequence, UI),
  2. resolve the next step via configuration (catalogs, conditions),
  3. load the scene through `SceneChanger`/`SceneTree.change_scene_to_file` (single mode).
- **Diagnostics:** mirror live values into `inspector_*` fields (`sync_inspector()`) updated each frame so the Inspector shows current phase/progress without extra queries; a play-mode editor monitor reads the same fields.
- **Standalone scene mode:** when Play begins in a non-entry scene (F6 on a level), `start_standalone_scene(scene_name)` synthesizes a valid flow, including recognizing and starting a matching feature from the catalog. **Any** `.tscn` becomes a valid debug entry point.
- **Scene helpers self-install:** on `get_tree().node_added`/`scene_changed`, install any missing scene-level controller/view the loaded scene needs.
- This replaces the current hard-coded `base_world` ↔ `UILayer` ↔ `Menu` ↔ `DeathScreen` telegraph through `Global`.

---

## 9. Presentation: scenes, controllers, entities, and entry points

### Scene conventions

- Each scene is self-contained: scene-local controllers vend by the scene or self-install via `FlowController`.
- Scenes live under `scenes/` grouped by role: `scenes/menu`, `scenes/levels`, `scenes/ui` (isolated UI test scenes).
- The `FlowController` decides which scene loads next; scenes tell it "I'm done" via `complete_current_step` / `notify_step_complete`.

### Controllers

- **`<Feature>SceneController`** — self-installs onto the active feature scene when the loaded scene matches the current run. Exposes the current run + typed runtime data (`get_run_data()`), and a `complete()` that reports back to the flow.
- **`<Selection>Presenter`** — reads a `QueryService.get_options()`, converts each option to a presentation-agnostic **selection item** (`id`, `display_text`, `category`, `is_enabled`, `requirement_label`, `payload`, `on_selected`), and routes the choice back through `FlowController.begin_step(option)`.

### Entity nodes are adapters

`base_entity` / `base_npc` / `player` / enemies / weapons stay as Node scripts, but become **thin adapters over `AppState`**:

- They own physics, animation, `Camera2D`, inputs, and visuals.
- Authoritative life/spawn/damage/ammo facts live in `AppState`; entities call the matching service (`combat_service.apply_damage(self, value)`) and read the result back.
- They never hold a second copy of a fact the state owns (no duplicate `health` var next to a health sub-state); the current `HealthManager` inside each entity becomes a node adapter over `CombatService` + `BrothersState`, not an owner of truth.
- Movement helpers (`move_and_slide`, knockback) are the one acceptable piece of "game logic" on the node: it's physics, which only lives at this layer.

### Views (Godot Controls)

- Scene/UI presented by Control nodes bound to `AppState` through a presenter/controller; no view mutates state directly — it calls services or flow methods.
- Shared UI (health bars, ammo bar, wave/points board, pause, split-screen composite) lives in `scenes/ui/` and is wired as scenes, not as global autoload state.

### Entry points

`AppSession` and `FlowController` are the *only* public gateways. Scene scripts and UI reach services exclusively through `AppSession.<Service>`, never by constructing a service or `get_node`-ing one. Input handlers, animation events, and UI callbacks are thin — they forward to a service or flow method.

---

## 10. Infrastructure layer

Purpose: adapt external systems so a future swap (library, platform, input scheme) does not ripple through the codebase.

Patterns:

- **Adapter singletons per system** (autoload or scene-local Node) that wrap the third-party facility and expose a small, game-shaped interface:
  - `NewgroundsAdapter` — wraps the `ngio` plug-in (`login`, `post_score`, `log_event`); game code never sees `ngio` types.
  - `SaveAdapter` — serializes `AppState.to_dict()` to the user data dir via `FileAccess`/`ConfigFile`; exposes `save(state)`, `load() -> Dictionary?`.
  - `AudioAdapter` — wraps `AudioServer` buses so sound hooks are named (`play_sfx(id)`, `set_bgm(id)`).
  - `CameraFxAdapter` — owns `Camera2D` shake/juice so presentation asks for "shake(4, 0.5)" and never touches camera nodes directly (absorbs the current `Shake` autoload bug surface).
  - `InputAdapter` (optional) — if raw input needs post-processing beyond Godot's `InputMap`.
- Keep the adapter's vocabulary in **game terms**, not library terms. Other layers code against the contract, not the library's types.
- Something currently stubbed carries a comment reserving the seam — but the file still lives in `infrastructure/` with the right name.
- Domain/Application never import third-party packages; only `infrastructure/` may.

---

## 11. Editor layer

All editor code lives in `src/editor/` (an `EditorPlugin` under the working tree — the Godot equivalent of `#if UNITY_EDITOR`), plus `@tool` scripts standing in for custom inspectors. Tool set to replicate:

- **Build / scene-list installer** — `EditorPlugin` bootstraps: appends `scenes/*.tscn` to `EditorSettings`/build list on load; menu items `Rebuild Scene List`, `Debug Play Current Scene` (Godot F6 already does this natively — keeps it), `Play Full Game From Entry Scene`.
- **`AppSession` inspector** — since `AppSession` is an autoload, the **`AppConfiguration` resource editor** plays this role: config + state-preset fields, inline preset editing, an "Apply Preset To Live Session" button *enabled only while a game is running in the editor*.
- **Normalize-IDs pass** — an `EditorPlugin` button that walks `resources/definitions/**` and backfills missing definition IDs from file names (the `OnValidate` stand-in; Godot has no `OnValidate` in GDScript).
- **Flow diagnostics** — a debug dock that reads `FlowController.inspector_*` live (repaints on a timer in play mode): session + `AppState` sub-state dumps, phase/progress, and play-mode buttons (`Start New`, `Reset Progression`, `Skip To Next Step`).
- **Preset editor** — custom inspector for the `AppStateDebugPreset` resource (start point + per-subsystem initial values, conversion helpers to keep serialized `String` ↔ value-type IDs consistent).
- **Isolated UI test drivers** — a builder script that assembles a plain `scenes/ui/<Shell>UITest.tscn`, plus a driver node that exercises a view outside the real flow.

---

## 12. Debug: presets and direct scene play

- **`AppStateDebugPreset`** (Domain/Debug) — a `Resource` that can `create_app_state()` from exported fields: start point (wave, level, session start), per-subsystem initial values, flags. It is the authoring surface for *"where do I want the app to start when I hit Play."*
- `AppSession` resolves the preset (field on the session, else `app_config.initial_state_preset`) and builds `State` from it in `build_runtime()`.
- **Direct scene play** — autoload session + `FlowController.start_standalone_scene()` replicate this. F6 on any level scene gives a session, a flow, and the right scene helper auto-installed: full game from entry, isolated debug otherwise.

---

## 13. Naming & authoring conventions

- GDScript files: `snake_case.gd`; `class_name` PascalCase, globally unique; layer prefix disambiguates collisions.
- `.tres` assets grouped by subsystem under `resources/<subsystem>/`, names `kebab-case.tres`.
- Generated string IDs fall back to the asset file name (`name.trim().to_lower().replace(" ", "-")`) via the normalize-IDs editor pass.
- All ID comparisons are case-insensitive; wrapped ID classes exist in Domain — no bare strings in service signatures.
- Scene groups mirror content roles (`scenes/menu`, `scenes/levels`, `scenes/ui`); scene names match configuration entries exactly.
- Always validate required constructor dependencies (`assert` in debug) and missing required configuration (`push_error` with a message that says exactly what is missing).
- Signals are used for *crossing the seam upward* (entity → controller → flow), never for service-to-service chatter.

---

## 14. Scaffolding a new project (checklist)

### Steps

1. **Create the layer folders**: `src/domain`, `src/application`, `src/infrastructure`, `src/presentation`, `src/editor`; parallel `resources/` tree; `scenes/` grouped by role.
2. **Define the `AppState` bundle** (`domain/state`): one class of typed sub-states; wrapped ID value types (`domain/ids`); the flow phase enum.
3. **Define the configuration vocabulary** (`domain/config` + sibling): `AppConfig` root (entry scene, starting wave, default catalog, initial preset), `Catalog`, definition Resources, `Rule` / `Condition` strategy assets + `RuleResult`.
4. **Write the services** (`application`): one per workflow, constructor takes `AppState` (+ config), small methods, no node/scene access.
5. **Build the `AppSession`** (`presentation/session`): autoload, owns config/state/one property per service, `build_runtime()`/`reset_runtime_state()`, loud guards, `editor_…` hooks.
6. **Add the `FlowController`** (`presentation`): phase state machine in `FlowState`, `await`-based transitions through `SceneChanger`, debug methods, `sync_inspector()` diagnostics, standalone-scene mode.
7. **Expose features to the app**: one `FeatureModule` per feature type (register handler + provider from the catalog), never branching on IDs in the loop.
8. **Add Infrastructure adapters** for every external system with game-shaped interfaces (Newgrounds, save, audio, camera FX).
9. **Add Editor tooling**: `EditorPlugin` (scene-list, normalize-IDs, flow dock), config/preset resource editors, UI test drivers.
10. **Add the initial authoring assets** under `resources/`: root config, catalogs, definitions, rules/conditions, presets, UI resources.
11. **Port the current game into the layers** (see Appendix A) — this is the migration, and it can land one flow at a time while everything still behaves identically.

### Rule of thumb when extending

- "Is this a *fact/concept about the game world*, an enum, or a config asset?" → **Domain**.
- "Is this a *rule/workflow* that orchestrates state?" → **Application**.
- "Does this touch a *scene, a node, a physics body, the UI, or a third-party system*?" → **Presentation / Infrastructure**.
- "Does this only help me *author/debug*?" → **Editor**.
- "Do I need the flow to *pick this without knowing its ID*?" → register it through a **Module** from the catalog; never add a central `switch` on IDs.
- "Does UI or an external system need to trigger this?" → expose it through **AppSession/FlowController**, never let callers touch `AppState` internals directly.
- "Does a feature need several concrete variants of a behavior?" → define a **Strategy** `Resource` (`Rule`, `Condition`) rather than branching in a service.

---

## Appendix A — where today's code lands

The current `src/` predates this model. `Global.gd` dissolves rather than maps: it is rehomed as the `AppSession` (composition), `AppState` sub-states (facts), and services (rules). The split-screen stays behavior-identical but becomes a presentation sub-scene that reads brothers from `BrothersState`, not from `Global.brother_1/2`.

| Today | Layer | Becomes |
|---|---|---|
| `src/AutoLoad/Global.gd` | — | **dissolves**: `AppSession` + `AppState` + `GameSession/Wave/Score/Respawn` services |
| `Global.brother_1/2`, `player.gd:46` (`Global.set("brother…")`) | Domain + Presentation | `BrothersState` + registry; split-screen reads positions/alive through it |
| `src/components/dynamic_splitscreen/*` | Presentation | one deep sub-scene behind a small interface (see `ARCHITECTURE_REVIEW.md` candidate A) |
| `src/AutoLoad/Shake.gd` | Infrastructure | `CameraFxAdapter` (`shake(4, 0.5)`); null-bug surface dies with the global |
| `src/AutoLoad/ngio.gd` | Infrastructure | `NewgroundsAdapter` |
| `src/AutoLoad/SceneChanger.gd` | Presentation | `FlowController` scene loading |
| `src/entities/base_entity` + `functions/HealthManager`, `NavigationManager`, `SpriteDirectionManager` | Presentation / Application | entity node stays as adapter; `HealthManager` logic → `CombatService` + `BrothersState`; `NavigationManager` stays node-local physics helper |
| `src/entities/enemies/*`, `states/*`, `GeneralStates/Death.gd` | Presentation / Application | entity + state nodes; death/loot/wave logic → `LootService`/`WaveService`; `Global.points/wave num/enemy_count` → `GameSessionState` |
| `src/components/weapon_manager` + `bullet-related/*` | Presentation / Application | `WeaponService` + `FireModule` (spread as data; see review candidate D) |
| `src/environment/base_world.gd`, `UILayer.gd`, `LaunchScene.tscn` | Presentation | `WaveController` + `UiScene`; wave timer/board driven through `WaveService`/`GameSessionState` |
| `src/menu/*`, `DeathScreen.gd` | Presentation | `FlowController` phases (`MENU`, `GAME_OVER`) |
| `src/scripts/StatesMachine.gd`, `State.gd` | Presentation | keep — node-local controller, unchanged |

Migration order (behavior-neutral): (1) `AppSession` + `AppState` skeleton next to `Global`; (2) re-point `Global.points/wave` reads at `WaveService`; (3) brother registry feeds the split-screen; (4) `FlowController` takes over scene changes; (5) delete `Global`. Each step keeps the game runnable.