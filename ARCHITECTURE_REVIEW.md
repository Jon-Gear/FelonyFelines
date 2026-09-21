# Architecture review — FelonyFelines

Date: 2026-09-21
Scope: depth review of the codebase, weighted toward the hand-rolled dynamic split-screen. Behaviour is to stay identical; the goal is testability and AI-navigability. The repo is mid-way through a Godot-4 port (runbook: `MIGRATION_GODOT4.md`); every deepening below also shrinks the port surface, because each module is then reached through fewer string-path seams. No `CONTEXT.md` or ADRs exist yet; domain terms used are the game's own — *brothers* (the two players), *wave*, *drops*.

Architecture vocabulary used here comes from the codebase-design skill: **module**, **interface**, **implementation**, **depth**, **deep**, **shallow**, **seam**, **adapter**, **leverage**, **locality**.

Legend: solid box = module, dashed line = seam, red stroke = leakage, dark box = deep module.

---

## Candidate A — Deepen the split-screen from a hand-wired rig into one module

**Recommendation:** Strong · in-process

**Files**

- `src/components/dynamic_splitscreen/SplitScreenCamera.gd`
- `src/components/dynamic_splitscreen/camera_controller.gd`
- `src/components/dynamic_splitscreen/SplitScreenCamera.tscn`
- `src/components/dynamic_splitscreen/split_screen_2d.gdshader`
- `src/environment/LaunchScene.tscn`
- `src/AutoLoad/Shake.gd`
- `src/AutoLoad/Global.gd`
- `src/entities/players/player/player.gd`

**Before**

The split-screen's interface is fully implicit. To use it you must know:

- the `Global.brother_1` / `Global.brother_2` handshake (players register via `Global.set("brother" + player_id, self)`, player.gd:46);
- the global `"camera"` group (SplitScreenCamera.tscn:46,65);
- the tscn's node paths (`$ViewportContainer/Viewport1`, etc., camera_controller.gd:10-14);
- the exact player internals the module reads: `player_visual_middle` (player.gd:21) and `health_manager.is_dead()` (camera_controller.gd:80-81,104-105).

Four leak edges run to Global, Shake, and both player subtrees. A 10 px bug sits in the middle: `get_player2_position()` uses brother-1's visual offset for camera2 (camera_controller.gd:46). The wrapper `SplitScreenCamera.gd` is a no-op (`current_world_path` is never set anywhere); if someone did set it, `setup()` would run twice. Understanding the concept means bouncing between the controller, the shader, the tscn, Global, Shake, and player.gd.

The deletion test: delete `SplitScreenCamera.gd`'s `_ready` — nothing changes. The controller is doing real work, but its shape is wrong: one 107-line script owns camera movement, split geometry, dead-brother handling, viewport sizing, and shader sync, all keyed off scene paths and globals.

**Solution**

Turn the rig into one deep module behind a small interface. The module collects the three facts it needs per brother (position, visual offset, alive), then owns camera movement, split geometry, the dead-brother fallback, viewport resize, and camera shake internally. The scene stays one instance; callers stop knowing the rest.

What sits behind the seam: a "tracked brother" — no longer `Global.brother_1` and player internals, but a node that answers position / visual offset / alive. Two adapters will justify the seam: real player nodes in prod, fakes in tests.

Behaviour preserved: same midpoint cameras (`camera1 = p1 + diff/2`, `camera2 = p2 - diff/2`, clamped to `max_separation`), same split geometry (perpendicular line through screen center), same dead-brother full-screen fallback in the shader, same resize handling, same shake hooks.

**Benefits**

- locality: split geometry + death handling concentrate in one module; the 10 px bug lives in one place to fix
- leverage: one interface for every future world scene, not a 6-file hand-wiring
- tests: geometry runs headless with fake tracked nodes — feed positions, assert camera transforms and shader state
- port: one file to port instead of ten string-connect sites

---

## Candidate B — Fold camera shake behind the split-screen seam

**Recommendation:** Worth exploring · in-process

**Files**

- `src/AutoLoad/Shake.gd`
- `src/components/dynamic_splitscreen/camera_controller.gd`

**Before**

Shake's interface is "a global you must hand cameras to". It mutates nodes it doesn't own inside the module, and cannot be tested outside a live scene tree. Its `_ready` group-scan can never assign — the condition is inverted, `if camera1 != null` with both starting null (Shake.gd:13-19) — and `_process` dereferences both cameras unguarded, so a single missing camera crashes (Shake.gd:27-30). Only a two-camera shape is supported.

**Solution**

Callers keep calling `Shake.shake(...)`, but the shake implementation lives in the module that owns the cameras and applies offsets to both of them — one place owns camera transforms.

**Benefits**

- locality: camera transform owned in one module
- tests: jitter is pure given intensity + duration
- removes the broken group-scan cruft
- no null camera, no crash

---

## Candidate C — Split the Global namespace into modules with small interfaces

**Recommendation:** Worth exploring · in-process

**Files**

- `src/AutoLoad/Global.gd`
- reachable from everywhere: `src/entities/enemies/GeneralStates/Death.gd` (6 Global refs), `src/environment/base_world/base_world.gd:34-42`, `src/entities/players/player/player.gd:46`

**Before**

Global is a shared namespace, not a module: its interface is "set any key from anywhere". One enemy one-acter reaches it six times (`Global.points`, `Global.main.update_points`, `Global.UI_layer.update_board`, `Global.enemy_count`, `Global.items.add_child`, `Global.misc.add_child`, Death.gd:37-57). The codebase has 78 `Global.*` references. `Global.player_died()` reaches into specific player node children (`brother_1.respawn_radius.deactivate_respawn_radius`, Global.gd:53-57). Every test or port must stand up the whole game. The deletion test shows it "earns its keep" only in the sense that deleting it would scatter complexity across dozens of callers — which is exactly the sign of a seam that was never drawn.

**Solution**

Separate the three concerns Global holds into modules with small interfaces:

- **GameSession** — points, waves, enemy count, drop weights, score posting
- **BrotherRegistry** — the alive/live brothers, feeding the split-screen seam
- **WorldContainers** — spawn targets (enemies, items, projectiles, misc), wired in at level start instead of reached by string

**Benefits**

- locality: score/wave logic stops scattering across state files
- tests: level logic runs without the singleton
- kills the string-key set/get handshake
- feeds the split-screen's brother seam

---

## Candidate D — Collapse the weapon-fire chain into a fire module

**Recommendation:** Worth exploring · in-process

**Files**

- `src/entities/players/player/player.gd` (`_input`, ammo re-wiring at 58-71)
- `src/components/weapon_manager/WeaponManager.gd`
- `src/entities/items/base_templates/base_range_weapon/BaseRangeWeapon.gd`
- `src/components/bullet-related/BulletSpawner.gd`
- `src/components/bullet-related/BulletEmitter.gd`
- `src/components/bullet-related/bullet_emitters/BulletEmitterSpread.gd`
- `src/components/bullet-related/Bullet.gd`
- `src/entities/enemies/EnemyGunner/EnemyGunner.gd` (parallel chain)

**Before**

Firing is a 6-file chain with no owner: `player._input` → `WeaponManager` → `BaseRangeWeapon` → `BulletSpawner` → `BulletEmitter` → `Bullet`. The player disconnects/reconnects the `ammo_changed` signal on every weapon switch (player.gd:58-71). "Spread 3" is a whole subclass (`BulletEmitterSpread`) with no logic beyond a parameter. `EnemyGunner` runs a second, parallel chain off its own `bullet_spawner`. To trace "a bullet leaves a weapon" you read six files.

**Solution**

Make spread a parameter of one fire module. Weapons call one method with a spec (count, spread, tag); the module owns spawn position, cooldown, projectile owner tags, and the ammo signal fan-out. The subclass and the player's re-wiring disappear.

**Benefits**

- leverage: player and enemy fire share one module
- locality: firing bugs fix once, everywhere
- interface shrinks: delete the spread subclass
- tests: call fire(spec), assert bullets appear, no scene needed

---

## Candidate E — Collapse the duplicated combatant states and aim loops

**Recommendation:** Speculative · in-process

**Files**

- `src/entities/enemies/EnemyGunner/states/{Idle,Chase,Pain}.gd`
- `src/entities/enemies/EnemyImp/states/{Idle,Chase,Pain}.gd`
- `src/entities/enemies/EnemyBall/states/{ChaseBall,AttackBall}.gd`, `IdleBaller.gd`
- `src/entities/players/player/states/*.gd`, `src/entities/players/npc/states/*.gd`
- `src/entities/base_templates/base_npc/base_npc.gd:57-100`

**Before**

States poke the owner by string node paths and near-duplicate each other across five entities (Idle, Pain, Death per enemy; player vs PlayerNPC duplicate `respawn_player` and `_turn_*` blocks verbatim). The aim raycast is written twice, 40 lines apart, differing by one line: `is_target_in_aim` vs `aim` (base_npc.gd:57-100). A behaviour change (death, aim, pain direction) must be applied in N places, and tests need a full entity scene.

**Solution**

One combatant-behaviour module with a small interface (target, in_aim, attack). Entities supply only parameters and their own animations.

**Benefits**

- deletion test: copies vanish, logic concentrates
- locality: aim + death fix once
- states stop naming owner internals
- tests: behaviour drives a fake combatant

---

## Top recommendation

**Deepen the split-screen (Candidate A).**

It is the module where the interface is most implicit and the leaks most tangled; it is the thing reported as the biggest friction; and its deepening pulls the others forward — it replaces the `brother_1/2` handshake (candidate C), absorbs the camera shake (candidate B), and hands the project its first headless-testable module.

Behaviour stays identical: same midpoint cameras, same clamped separation, same split geometry, same dead-brother fallback — including the deliberate 10 px quirk, unless that is deliberately fixed.

---

## Next step

Pick a candidate to explore. Once one is chosen, we walk the decision tree: constraints, dependencies, the shape of the deepened module, what sits behind the seam, what tests survive. Decisions worth recording get captured as ADRs in `docs/adr/` and domain terms added to `CONTEXT.md` as they crystallize.