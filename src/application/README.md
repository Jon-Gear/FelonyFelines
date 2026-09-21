# Application layer

**What lives here:** gameplay rules — the workflows and use cases. Plain `RefCounted`
service classes that take `AppState` (+ configuration) and mutate it. No scene
nodes, no physics bodies, no UI, no `get_tree()`.

**This layer references Domain only.** Application scripts may preload Domain
symbols; they never reference Presentation, Infrastructure, or Editor.

Examples (from ARCHITECTURE.md):

- `WaveService`, `ScoreService`, `CombatService`, `RespawnService`,
  `WeaponService`, `LootService`
- feature-module wiring, request/result payload types

Services stay deterministic: same `AppState` + same inputs → same result. Mutation
is the service's job; results are returned, callers do not mutate state.

See `docs/CONVENTIONS.md` for the Application naming conventions and the full layer map.