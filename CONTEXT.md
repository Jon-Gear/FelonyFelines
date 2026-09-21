# Context — FelonyFelines domain vocabulary

> The shared understanding of the game's domain: the words the code, the issues,
> and the agents must agree on. New terms join the table below when they become
> load-bearing. The glossary is *behavior-neutral* shorthand; the code is the truth.

## The game in one paragraph

FelonyFelines is a local co-op action game. Two cat brothers ("brothers") face
enemy waves spawned by the world, pick up weapons and medkits, and use a dynamic
split-screen that splits once the brothers get far apart (with a deliberate 10 px
camera-offset quirk preserved). Points accumulate per wave; the round ends when
both brothers are dead.

## Canonical terms

| Term | Definition | Load-bearing references (today) | Restructured home (target) |
|---|---|---|---|
| **brother** | One of the two playable cats. Brother 1 (red) and brother 2 (blue). Each is a `player` entity tracked by its `health_manager`; both share respawn rules at the world level. Not to be confused with `PlayerNPC`. | `Global.brother_1` / `Global.brother_2` (registered in `setup_player()`, player.gd:46), `HealthManager`, `Respawn` radius, `base_world.all_players_dead()` | **Domain:** `BrothersState` (per-brother alive / armed-with) **Presentation:** player entity adapters |
| **wave** | A round of enemies. `base_world` advances `wave_num`, each spawner adds `wave_num` enemies, `enemy_count` tracks survivors. Waves are timed by `WaveTimer`; score = `points`. | `Global.wave_num`, `Global.enemy_count`, `Global.points`, `base_world.update_wave()`, `UILayer.update_board()` | **Domain:** `WaveState`, `GameSessionState` **Application:** `WaveService`, `ScoreService` |
| **drop** | An item a killed enemy can leave, rolled by weight. Drop weights live in one table and drive a weighted random pick on enemy death. | `Global.ITEM_DROP_WEIGHTS`, `GeneralStates/Death.gd` (weights loop), `ItemPickup` | **Domain:** drop-table configuration asset **Application:** `LootService` |
| **split-screen** | The dynamic two-camera viewport rig. Reads each brother's position, visual offset, and alive state; splits once separation exceeds `max_separation`; falls back to one view when a brother is dead. Preserves the intentional 10 px camera-offset quirk (patch in camera2's position calculation) — see ADR-0003. | `camera_controller.gd`, `SplitScreenCamera.gd` (dormant wrapper, see ADR-0004), `split_screen_2d.gdshader`, `Shake` | **Presentation:** one deep split-screen module behind a small brother-facts seam (ADR-0004) **Infrastructure:** `CameraFxAdapter` |
| **fire** | The gunplay mechanic: a firing rate (`shot_delay`), bullet count, speed, and spread. Weapons *fire* bullets through a bullet emitter; the same machinery covers player and enemy weapons. | `BulletSpawner` (`shot_fired`, `shot_delay`), `BulletEmitterSingle`, `BulletEmitterSpread`, `BaseRangeWeapon` | **Application:** `WeaponService` + `FireModule` (spread/count as data) |
| **world** | A level scene: the container holding entity buckets (players, enemies, projectiles, items, spawners) and the navigation. Owns wave bookkeeping today. | `base_world.gd` (`Global.main`, `Global.entity_world`, …), `LaunchScene.tscn`, `NavigationTileMap.tscn` | **Presentation:** scene controllers; entity buckets owned by session |
| **round / all_dead** | End condition. Emitted when *both* brothers are dead (`player_died` → `Global.player_died()` → `all_dead`), triggers death screen, final score, and Newgrounds score posts. | `Global.player_died()`, `base_world.all_players_dead()`, `Menu` / `DeathScreen` | **Application:** `RespawnService`, `GameSessionState` **Presentation:** `FlowController` phases (`GAME_OVER`) |
| **lives / respawn** | A brother that takes lethal damage goes down instead of dying outright; a respawn radius governs revival, and reviving restores full health. | `HealthManager`, `player.respawn_player()`, `Respawn` component, `Global.player_died()` | **Application:** `CombatService`, `RespawnService` |
| **ammo** | Per-weapon magazine count. Finite ammo; the ammo bar is bound to the weapon's `ammo_changed` signal (the switch-time disconnect/reconnect dance today). | `WeaponManager`, `Ammo_Bar`, `return_ammo_count()`, `ammo_changed` | **Application:** `WeaponService` (slot + ammo) |
| **app config** | The root configuration resource: entry scene, starting wave, default catalog, initial state preset. | none yet (scaffolded as `resources/app_config.tres`) | **Domain:** `AppConfig`; resolved by `AppSession` |
| **catalog** | A collection of definition resources with `get_by_id(id)` / `for_scene(name)` lookups — the place features register from. | none yet | **Domain:** `Catalog` resources under `resources/catalogs/` |

## Anti-terms

| Don't say | Because |
|---|---|
| "player" (as a *role* in issues) | There are *players* and there is the **PlayerNPC** AI actor; "brother" names the playable pair. `Global` also loosely calls every node under `players` a "player". Prefer **brother** for the red/blue pair. |
| "health" | Brothers carry `health_manager` (current + max). In the restructure, authoritative health lives in state and changes flow through `CombatService`; the `HealthManager` node stays authoritative *for its entity* during the migration (see ADR-0002). |
| "splitscreen" vs "split screen" | The canonical canopy term is **split-screen** (hyphenated), module path `src/components/dynamic_splitscreen/` today. |

## Where domain knowledge lives

- `CONTEXT.md` (this file) — the glossary of load-bearing terms.
- `docs/adr/` — recorded decisions that close off alternatives.
- `docs/CONVENTIONS.md` — per-layer naming and layout rules that encode the domain
  vocabulary into new code.
- The code itself — the source of truth for *how* the game behaves today.