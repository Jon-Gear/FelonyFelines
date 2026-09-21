# Testing conventions

> Tests live outside `src/` in `tests/`, run under **GUT** (Godot Unit Test), and
> assert **behavior only**. This is the reference pattern every later restructure
> ticket follows: *construct state, invoke a module, assert the result.*

Status: **accepted** · companion to `ARCHITECTURE.md`, `RESTRUCTURE_PLAN.md`, and
`docs/CONVENTIONS.md`.

---

## 1. Harness

- Framework: **GUT 7.4.3** (the Godot 3.x line), vendored at `addons/gut/`. The
  project targets Godot 3.5 today; GUT is upgraded alongside the Godot 4 port.
  It is dev-only tooling: the one sanctioned third-party package outside
  Infrastructure (ADR-0001), and it never ships (see §3).
- Tests live in `tests/unit/`, one `test_*.gd` file per module under test. Each
  file `extends "res://addons/gut/test.gd"` (path form, so it resolves without
  the editor having registered `GutTest`).
- `.gutconfig.json` at the project root points GUT at `res://tests/unit` with the
  `test_` prefix, so the default run needs no arguments.

### Run from the editor

The **Gut** editor plugin is enabled in `project.godot`. Open the GUT panel from
the bottom dock, confirm the directory is `res://tests/unit`, and press **Run**.

### Run from the command line

```
godot -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit
```

Omit the `-g*` flags to fall back to `.gutconfig.json`:

```
godot -s addons/gut/gut_cmdln.gd
```

`-gexit` makes the runner quit with a non-zero status on failure, which is what a
CI step should check. The `linux_headless` build is enough for command-line runs.

## 2. The convention — assert behavior, never wiring

A good test:

1. **constructs** the input it needs (a plain dictionary, a fresh state object),
2. **invokes** the module under test (a pure helper or a service over state), and
3. **asserts** on the returned result or the resulting state delta.

A good test never asserts on node paths, autoloads, signal connections, scene
trees, or *which* internal method was called. If a rule can only be exercised by
standing up a scene, that is a sign the rule should be extracted into a module
the test can call directly.

Reference examples:

- `tests/unit/test_id_utils.gd` — calls `IdUtils.normalize(name)` and asserts the
  returned string.
- `tests/unit/test_drop_weights.gd` — calls `DropWeights.normalize(weights)` and
  asserts the returned table, including that the input is left untouched.

Both helpers live in `src/domain/` and are pure: no nodes, no `get_tree()`, no
autoloads. That is what makes them testable headlessly.

## 3. Test-only code does not ship

Both export presets in `export_presets.cfg` carry
`exclude_filter="tests/*,addons/gut/*"`, so the suite and the test framework are
kept out of release builds.
