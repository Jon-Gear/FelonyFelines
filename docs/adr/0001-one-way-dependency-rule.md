# ADR-0001 — One-way dependency rule (Domain ← Application ← Presentation)

Status: **Accepted**

Deciders: Restructure spec (`RESTRUCTURE_PLAN.md`), issue Jon-Gear/FelonyFelines#14

Date: 2026-09-21

## Context

The codebase is a flat namespace: `Global.gd` is punched through from ~78 call
sites, entities reach siblings and globals by string path, and nothing records how
code should depend on what. Any change risks silently breaking a subsystem. The
restructure ("five-layer architecture", `ARCHITECTURE.md`) needs a fixed,
enforced dependency shape so that changing a lower layer never ripples upward into
scene code, and so future work lands predictably.

## Decision

The codebase is organized into five layers under `src/` — Domain, Application,
Infrastructure, Presentation, Editor — and dependencies flow **one way only**:
Domain is referenced by all; Application references Domain only; Presentation
references Application and Domain; Infrastructure is referenced by Presentation
when adapting external systems; Editor references Presentation + Domain and is
never referenced at runtime.

```
Domain ← Application ← Presentation
```

Concretely:

- Layer membership is the folder (GDScript has no namespaces); a script may only
  preload / `class_name`-reference symbols from layers it is allowed to see.
- A `presentation/` script must never `extends` an `application/` script; an
  `application/` service must never `preload()` a scene or touch `get_tree()`.
- Only `infrastructure/` may import third-party packages.

The full naming and layout rules are fixed in `docs/CONVENTIONS.md`.

## Consequences

- Finding where a responsibility lives no longer requires reading the whole
  project — it is implied by the folder.
- Lower layers stay migration-safe: changing Domain or Application never ripples
  into scene code.
- New code follows the rule by construction; reviewers stop teaching it per PR
  (user story 28).
- Enforcement is convention-based today (folder + review), not machine-checked.