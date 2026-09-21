# Presentation layer

**What lives here:** scene / UI code — nodes that live in scenes, drive scenes,
render UI, and translate input / external events into Application calls. Every
entity node (`base_entity`, `base_npc`, `player`, enemies, weapons) lives here as
an *adapter* over `AppState`, not as an owner of authoritative game facts.

**This layer references Application and Domain** (plus Infrastructure adapters).
It is the only layer allowed to hold scene nodes and call `get_tree()`.

Examples (from ARCHITECTURE.md):

- `AppSession` (composition root autoload), `FlowController`
- scene controllers, entity nodes, UI, input handlers

Today's pre-restructure code mostly lives under `src/entities`, `src/components`,
`src/environment`, `src/UI`, `src/menu`, `src/AutoLoad`, `src/scripts`,
`src/shaders`, and `src/ScreenEffects`; the migration re-homes it into these five
layers without changing behavior.

See `docs/CONVENTIONS.md` for the Presentation naming conventions and the full layer map.