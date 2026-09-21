# Restructure Plan — five-layer architecture for FelonyFelines

> Epic spec produced from the codebase review (`ARCHITECTURE_REVIEW.md`) and the target blueprint (`ARCHITECTURE.md`). The game behaves identically; this restructure changes where code lives and who owns the facts.

---

## Problem Statement

Today the codebase is "all over the place": a single `Global` autoload is a flat namespace that ~78 call sites punch through (`Global.main`, `Global.enemies`, `Global.points`, `Global.brother_1/2`…); entities reach into sibling nodes and globals by string path; scene flow is a telegraph of hard-coded `SceneChanger` calls plus `Global` signals; weapon/bullet/ammo logic is spread across six files with a duplicate parallel chain; respawn, death, drops, and the split-screen all pull player internals directly. There is no test infrastructure, no domain vocabulary document, and no recorded decisions, so every change risks silently breaking another subsystem.

## Solution

Restructure the repo onto the five-layer architecture defined in `ARCHITECTURE.md`, keeping observed behavior identical:

- **Domain** owns game facts (`AppState` + sub-states, definitions, config assets).
- **Application** owns gameplay rules (deterministic services over `AppState`).
- **Infrastructure** adapter-wraps external systems (Newgrounds, camera FX, save).
- **Presentation** owns scenes, nodes, UI, input — entities become adapters.
- **Editor** owns authoring/debug tooling.

`Global` dissolves into `AppSession` (composition root) + `AppState` + services. `FlowController` becomes the only scene-transition authority. The split-screen becomes one deep module behind a small brother-facts seam. Rollout is incremental with every step runnable, ending with `Global` deleted and a first test suite in place.

## User Stories

1. As a developer, I want the codebase organized into five fixed layers, so that I can find where any responsibility lives without reading the whole project.
2. As a developer, I want dependencies to flow one way only (Domain ← Application ← Presentation), so that changing a lower layer never ripples upward into scene code.
3. As a developer, I want `Global` removed and replaced by `AppSession` plus typed state and services, so that I stop guessing what a global field refers to and who writes it.
4. As a developer, I want game facts (points, wave number, brother lives, ammo counts) owned by `AppState`, so that gameplay, UI, and tests all read one source of truth.
5. As a developer, I want a `WaveService` to own wave progression, spawning budgets, and enemy-count bookkeeping, so that wave logic is testable without a live level scene.
6. As a developer, I want scoring owned by `GameSessionState` and a score service, so that points stop being mutated from enemy death code.
7. As a developer, I want a `RespawnService` to own respawn eligibility and timing, so that reviving a downed brother is a rule I can test.
8. As a developer, I want a `CombatService` to own damage, heal, and death rules, so that `HealthManager` stops being a silent authority with no seam.
9. As a developer, I want a `WeaponService` to own weapon switching and ammo, so that the per-switch `ammo_changed` disconnect/reconnect dance in the player input handler disappears.
10. As a developer, I want a `LootService` plus a drop-table asset to own enemy drops, so that drops stop loading scenes by concatenating strings in state code.
11. As a developer, I want `FlowController` to be the only scene-transition authority, so that menu → level → game-over navigation is a state machine instead of a `Global` signal chain.
12. As a developer, I want the split-screen to read brothers through a small seam instead of `Global.brother_1/2` and player internals, so that a new brother type no longer breaks the camera rig.
13. As a developer, I want the dormant split-screen wrapper removed, so that there is exactly one way to set up the split-screen.
14. As a developer, I want the split-screen's camera geometry expressed as a pure function, so that I can unit test it headlessly.
15. As a developer, I want the split-screen and camera shake to behave exactly as today, including the intentional 10 px camera-offset quirk, unless a dedicated task reverses it.
16. As a developer, I want shake replaced by a camera-FX adapter with its own interface, so that camera-offset writing stops crashing on null cameras.
17. As a developer, I want Newgrounds behind an adapter, so that gameplay code never depends on the `ngio` library or its embedded secrets.
18. As a developer, I want weapons, enemies, waves, and drop weights authored as configuration assets, so that tuning doesn't require editing scripts.
19. As a developer, I want definitions to receive auto-generated stable IDs from their asset names, so that I don't hand-write IDs.
20. As a developer, I want editor tooling (ID normalization, scene-list build, flow diagnostics) shipped as an editor plugin, so that authoring and debugging don't require hand-edited data files.
21. As a developer, I want to run any scene in isolation with a working session and flow controller, so that I can debug one level without the full menu → level path.
22. As a developer, I want every migration step to leave the game runnable, so that the restructure ships in increments rather than one big bang.
23. As a developer, I want duplicated combatant states, aim lookups, and the player/PlayerNPC respawn block collapsed, so that a fix applies once instead of N times.
24. As a developer, I want the case-sensitivity reference bug and the dangling `_on_Main_all_dead` signal fixed during the restructure, so that the Godot port doesn't inherit them.
25. As a test author, I want a unit-test framework and a place to put tests, so that behavior changes stop going unverified.
26. As a test author, I want Application services tested against a constructed `AppState`, so that I never stand up a whole scene to test a rule.
27. As a maintainer, I want `Global` fully deleted at the end of the migration, so that nothing references it anymore.
28. As a developer, I want naming conventions documented per layer, so that new code follows the architecture without a reviewer teaching it.
29. As a maintainer, I want the game's domain vocabulary captured in `CONTEXT.md`, so that issues, specs, and agents speak the same terms.
30. As a developer, I want ADRs recording the decisions that close off alternatives, so that future reviews don't re-fight the same fights.

## Implementation Decisions

### Layers and layout

- The codebase is organized into five layers — Domain, Application, Infrastructure, Presentation, Editor — each a top-level area under `src/`, with a parallel `resources/` tree for configuration assets.
- Dependency rule is one-way: Domain is referenced by all; Application references Domain only; Presentation references Application and Domain; Infrastructure is referenced by Presentation when adapting external systems; Editor references Presentation + Domain and is never used at runtime.
- GDScript has no namespaces: layer membership is the folder, `class_name` is globally unique with a layer prefix when a natural name collides, and files are `snake_case.gd`.
- Naming conventions per layer are fixed and documented (Domain/Application snake_case fields and verb-phrase methods; Presentation Godot node conventions).

### AppSession (composition root)

- `AppSession` becomes the first autoload, owning configuration, `AppState`, one property per service, and the `FlowController`.
- It is the only place services are constructed; `build_runtime()` and `reset_runtime_state()` (re)build state and services; missing required configuration fails loudly at startup.
- Because it is an autoload, playing any scene directly (F6) already yields a session and a flow controller — no runtime-init self-bootstrapping dance is needed.

### AppState (Domain)

- One state bundle of typed sub-states: `GameSessionState` (points, wave number, enemy count), `BrothersState` (per-brother alive/lives), `WaveState` (phase, spawn budget), `FlowState` (phase enum), and a case-insensitive `Flags` set.
- Identity uses wrapped value types (brother, weapon, enemy-type IDs), never bare strings in service signatures.
- Consumption-style transitions keep an "available" and a "done" list so the state can answer history questions.
- `AppState` implements `to_dict()`/`from_dict()` for the save adapter.

### Services (Application)

- One service per workflow: `WaveService`, score handling via `GameSessionState`, `CombatService`, `RespawnService`, `WeaponService`, `LootService`, and the world-container queries the current `Global.get_closest_*`/`get_all_enemies` provide.
- Services are plain `RefCounted`, constructor-injected with `AppState` (+ config), deterministic, and expose prepare/select/query method families; mutation is the service's job.
- `ACCEL`/`FRICTION` move out of the global into per-entity/movement configuration.

### FlowController (Presentation)

- Owns the flow phase enum in `FlowState` and all scene transitions; the only advancement paths are `begin_step`, `complete_current_step`, and `notify_step_complete`.
- Scene loading sits behind a narrow seam (a loader contract) so the phase machine is testable without a real scene tree.
- Provides standalone-scene mode so any scene is a valid debug entry point.

### Feature modules

- The plugin-point pattern: `FeatureModule` resources register a handler (execute side) and a provider (present side) from the catalog; a registry walks the catalog.
- Representative modules: fire (spread/count as data, single path for player and enemy weapons), loot, wave, respawn.
- The `FlowController` and `AppSession` never branch on feature or definition IDs.

### Configuration assets (resources/)

- Root configuration asset (entry scene, starting wave, default catalog, initial state preset), catalogs, weapon/enemy/wave definition assets, drop-table assets, rule/condition strategy assets, debug presets.
- Definitions auto-generate stable IDs from asset names via an editor normalization pass (Godot has no `OnValidate`).
- The current hard-coded values (weapon drop weights, enemy spawn lists, wave counts) are lifted into these assets without changing their values.

### Infrastructure adapters

- `NewgroundsAdapter` (wraps the ngio call path; `app_id`/`aes_key` move to config/environment, not source), `CameraFxAdapter` (replaces the shake autoload; owns camera offsets), `SaveAdapter` (serializes `AppState`).

### Split-screen

- Collapsed into one deep module behind a small seam: per-brother facts (position provider, visual offset, alive), not `Global.brother_1/2` and not player internals.
- The dormant wrapper is deleted; setup happens once; shake is an internal detail of the module.
- Camera geometry becomes a pure core; the midpoint/clamp/split-line/dead-brother behavior and the deliberate 10 px quirk are preserved.

### Entities and states

- Entity scripts stay Presentation adapters: physics, animation, input; they delegate rule changes to services.
- Rollout decision: `HealthManager` stays authoritative for its entity's health during this restructure and reports through `CombatService`; flipping to `AppState`-authoritative health is explicitly deferred and optional.
- Duplicated combatant states, the repeated aim raycast, and the player/PlayerNPC respawn block are collapsed; a shared brother base replaces the duplicated `_turn_*`/`respawn_player` code.
- The shared ammo API duplicated across weapons and the medkit is unified.

### Tooling and docs

- `src/editor/` editor plugin: ID normalization, build scene list, flow/state diagnostics dock, config/preset asset editors.
- New `CONTEXT.md` establishing the domain glossary (brother, wave, drop, split-screen, fire).
- ADRs recorded for the load-bearing decisions (e.g., keep `HealthManager` authoritative; preserve the 10 px quirk; one-way dependency rule).

## Testing Decisions

- Introduce GUT (Godot Unit Test) as the test framework, with tests living outside `src/` in a dedicated test area wired through GUT's runtime.
- A good test asserts **external behavior only**: construct a fresh `AppState` fixture, invoke a service or flow method, and assert on the returned result or the resulting `AppState` delta — never on internal wiring, node paths, or globals.
- **Primary seam:** the services-over-`AppState` interface. Every Application rule (wave, score, combat, respawn, weapon switch, loot) is tested here without a scene tree.
- **Secondary seam:** the flow controller's loader contract, so `FlowController` phase transitions are tested headlessly.
- **Internal seam (already present once extracted):** the split-screen geometry core, tested as pure math.
- Modules tested first: `WaveService`, score/`GameSessionState`, `WeaponService` switching and ammo, `LootService` drops against a drop-table asset, `RespawnService` eligibility, split-screen geometry, ID normalization helpers.
- Prior art: none — the project has no tests today. These tests become the reference pattern for all future specs.

## Out of Scope

- The Godot 4 port itself (separate runbook, `MIGRATION_GODOT4.md`); the restructure merely reduces its surface.
- New gameplay features, balance changes, bullet physics, shaders, art.
- Flipping entity health to `AppState`-authoritative (deferred, optional).
- Building the full feature-module catalog for every system (additive, incremental).
- Newgrounds internals and audio design.
- Any change to split-screen visible behavior except the intentional quirk if a dedicated task reverses it.

## Further Notes

- The golden rule of this restructure: **the game still plays exactly the same at every checkpoint.**
- Suggested migration order (each step runnable): (1) `AppSession` + `AppState` skeleton beside `Global` and re-point `Global.*` call sites; (2) services (wave/score/combat/respawn/weapon/loot) + brother registry; (3) `FlowController` takes over scene changes; (4) split-screen moves to the brother-facts seam; (5) weapons/items/bullets refactor; (6) data-driven configuration + editor plugin; (7) delete `Global`.
- The repo has not been through skills setup; the triage labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`) are created here so specs can be labelled from the start.
- No `CONTEXT.md` and no ADRs exist today; both are created as part of this work so future reviews and agents have vocabulary and recorded decisions to lean on.