# Felony Felines — Godot 3.5 → 4.7.2 Migration Runbook

Goal: the game runs on Godot **4.7.2** and behaves **exactly as it does now** (same
movement feel, same wave flow, same split-screen, same sounds, same levels).

Two decisions are baked into this runbook:

- **Newgrounds is dropped.** `addons/ngio` (autoload `Ngio`) is removed; the two
  score-posting calls are deleted. Nothing else about scoring/UI changes.
- **Mixing Desk addon is replaced** with engine-native `AudioStreamPlayer2D` +
  `AudioStreamRandomizer` nodes. The `SoundMachine` interface (`play_sound`,
  `get_sound`, `find`) is kept so no gameplay code changes.

Everything below is written against the *actual* current files, with
`file:line` references. Line numbers are from today's checkout.

---

## 1. Pre-flight (before opening the project in 4.x)

1. Make a backup of the whole folder (a git branch or a copy). Godot 4 will
   rewrite `project.godot`, regenerate `.import/`, create `.uid` files, and add
   `.godot/`. You do not want this to be irreversible.
2. Install Godot **4.7.2** (get from godotengine.org — the *standard* build is
   fine, we use the compatibility renderer).
3. Keep your **Godot 3.5.0** editor available. The TileMap export step (§9.2)
   and the "before" run for parity testing (`--path . --export-debug`, or F5)
   run there.
4. Snapshot the current behaviour by playing once per level (Level 2 is the
   one reachable through `Menu → LaunchScene`). Note: *"Level 1" currently does
   not load* — it references the missing `res://deleted enemies/player.tscn`;
   this is a pre-existing bug, see §12.4.

---

## 2. Housekeeping on the existing tree (do this in 3.5 first)

These are safe, improve determinism of the migration, and do not change gameplay:

| File / dir | Action |
|---|---|
| `src/entities/players/player/player.gd` vs `player.tscn:13` (`res://src/entities/players/player/Player.gd`, capital P) | The **path in the scene does not exist**; it only works on case-insensitive filesystems. Fix the ext_resource path to `res://src/entities/players/player/player.gd` (or rename file to `Player.gd`). **Do this before 4.x import** — Godot 4 is case-sensitive on every platform. |
| `src/environment/levels/Level_2.tscn:5` references `.../player/Player.tscn` (capital P) | Same bug; fix path to lowercase `player.tscn`. |
| `src/environment/levels/Level_1.tscn:3` references `res://deleted enemies/player.tscn` | Directory does not exist. Replace the ext_resource + `Sooltan3` instance with `res://src/entities/players/player/player.tscn` (id 1, `player_id = "_1"`); this also repairs Level 1. |
| `src/.../*.gd.uid` files with no `.gd` sibling (burglar prototypes, `Hitbox.gd`, `Hurtbox.gd`, shared enemy states under `src/entities/enemies/` that have no scene) | Dead stubs. Leave them (harmless) or delete. They are not referenced by any live scene. |
| `test folder/`, `test 3D folder/`, `Alice Production Test/` | Kept because `Ground.tscn` uses `res://test folder/tileset_repaint.png`. Keep if you want the art; otherwise re-point tilesets. No code references break either way. |
| `Walls.tres` (repo root) | **Required.** It is the actual Wall TileSet (autotile, `tile_size = 64×128`, convex shapes), loaded by `src/environment/tilesets/Walls.tscn:3`. Convert it like the other tilesets (§9.3) — do not delete. |
| `src/shaders/Shader.tres` | Unreferenced by scenes; leave or delete (verify with grep before deleting). |

---

## 3. First launch in Godot 4.7.2

1. Open the project from the Godot 4 project manager → "Import". Godot will
   rewrite `project.godot` (config_version 5) and re-import all assets.
   Expect a wall of errors — normal.
2. Then open **every scene** once and let the editor report/auto-fix trivial
   things. Do the scene work after the script pass (§4–8) so errors are fewer.
3. Do **not** trust the automatic `project.godot` migration for input or
   audio driver — verify against §5/§6.

---

## 4. project.godot — settings to force manually

The auto-migration leaves several 3.x settings wrong. Set these in
Project Settings (or the config file):

| Old (3.x) | New (4.7) |
|---|---|
| `window/stretch/mode="2d"` | `display/window/stretch/mode="canvas_items"` |
| `window/stretch/aspect="keep"` | keep (same key) |
| `window/size/fullscreen=true`, `test_width=1024`, `test_height=600` | `display/window/size/fullscreen=true`, `viewport_width=1024`, `viewport_height=600` |
| `rendering/quality/driver/driver_name="GLES2"` | **delete line**; set `rendering/renderer/rendering_method="gl_compatibility"` and `rendering/renderer/rendering_method.mobile="gl_compatibility"` |
| `rendering/2d/snapping/use_gpu_pixel_snap=true` | `rendering/2d/snap/snap_2d_transforms_to_pixel=true` **and** `snap_2d_vertices_to_pixel=true` |
| `rendering/environment/default_environment="res://default_env.tres"` | keep (resave the .tres in §9.5) |
| (nothing) | `rendering/textures/canvas_textures/default_texture_filter=0` (Nearest) for the pixel art, then force-reimport all textures |
| (nothing) | `layer_names/2d_render/layer_1..3`, `layer_names/2d_physics/layer_1..9` — should survive; verify names `world`, `player`, `enemy`, `player_kinematic_body`, `enemy_kinematic_body`, `player_hitbox`, `enemy_hitbox`, `projectile_area`, `player_hurtbox`, `enemy_hurtbox`, `item_pick_up_area` are intact |
| `boot_splash/*` | keep; confirm splash renders with filter off |

### Autoloads (project.godot `[autoload]`)

Keep:
```
Global="*res://src/AutoLoad/Global.gd"
SceneChanger="*res://src/AutoLoad/SceneChanger.tscn"
Shake="*res://src/AutoLoad/Shake.gd"
```
Remove the line `Ngio="*res://src/AutoLoad/ngio.gd"` and delete
`src/AutoLoad/ngio.gd`.

---

## 5. Input map

The auto-migration usually maps keys to `keycode` but the punctuation keys
(`.`/`,`) and `F` were bound with `physical_scancode` in 3.x. Verify every
action below in **Project Settings → Input Map** after import; the table gives
the intent, and §5.2 has a paste-ready block if you prefer to write the file.

### 5.1 Action → key/joypad table

| Action | Keyboard (Godot 4 key) | Joypad |
|---|---|---|
| `up_1` | **Arrow Up** (`KEY_UP`) | device 0, axis 1 = −1 |
| `left_1` | **Arrow Left** | device 0, axis 0 = −1 |
| `down_1` | **Arrow Down** | device 0, axis 1 = +1 |
| `right_1` | **Arrow Right** | device 0, axis 0 = +1 |
| `action_1` | **F** (physical) | device 0, button 7 (RB) |
| `up_2` | **W** (`KEY_W`) | device 1, axis 1 = −1 |
| `left_2` | **A** | device 1, axis 0 = −1 |
| `down_2` | **S** | device 1, axis 1 = +1 |
| `right_2` | **D** | device 1, axis 0 = +1 |
| `action_2` | **Space** | device 1, button 7 |
| `next_weapon_1` | **.** (physical) | device 0, button 5 (LB) |
| `prev_weapon_1` | **,** (physical) | device 0, button 4 |
| `next_weapon_2` | **E** | device 1, button 5 |
| `prev_weapon_2` | **Q** | device 1, button 4 |
| `reparent` | **R** | — |
| `pause` | **Escape** | — |

Deadzone is 0.5 everywhere (prev_weapon_2 was 0.51 — keep 0.5, it never
mattered).

### 5.2 Paste-ready `[input]` section (Godot 4 serialization)

```ini
[input]

up_1={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194320,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":0,"axis":1,"axis_value":-1.0,"script":null)
 ]
}
down_1={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194322,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":0,"axis":1,"axis_value":1.0,"script":null)
 ]
}
left_1={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194319,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":0,"axis":0,"axis_value":-1.0,"script":null)
 ]
}
right_1={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194321,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":0,"axis":0,"axis_value":1.0,"script":null)
 ]
}
action_1={
"deadzone": 0.5,
"events": [Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":0,"button_index":7,"pressure":0.0,"pressed":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":70,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
 ]
}
up_2={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":87,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":1,"axis":1,"axis_value":-1.0,"script":null)
 ]
}
left_2={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":65,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":1,"axis":0,"axis_value":-1.0,"script":null)
 ]
}
down_2={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":83,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":1,"axis":1,"axis_value":1.0,"script":null)
 ]
}
right_2={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":68,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":1,"axis":0,"axis_value":1.0,"script":null)
 ]
}
action_2={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":32,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":1,"button_index":7,"pressure":0.0,"pressed":false,"script":null)
 ]
}
next_weapon_1={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":46,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":0,"button_index":5,"pressure":0.0,"pressed":false,"script":null)
 ]
}
prev_weapon_1={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":44,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":0,"button_index":4,"pressure":0.0,"pressed":false,"script":null)
 ]
}
next_weapon_2={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":69,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":1,"button_index":5,"pressure":0.0,"pressed":false,"script":null)
 ]
}
prev_weapon_2={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":81,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":1,"button_index":4,"pressure":0.0,"pressed":false,"script":null)
 ]
}
reparent={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":82,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
 ]
}
pause={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194305,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
 ]
}
```

`keycode` values used: W=87, A=65, S=83, D=68, E=69, Q=81, R=82, Space=32;
arrows Left=4194319, Up=4194320, Right=4194321, Down=4194322; Escape=4194305.

---

## 6. Script-to-script migration (GDScript 2)

Two GDScript 2 facts drive most changes:

- `yield(x, "sig")` is **removed**. Use `await x.sig` (or `await get_tree().process_frame`).
- `Object.connect(sig, target, method)` old 3-arg form is gone. Use `sig.connect(callable)` / `sig.disconnect(callable)`.
- `node.instance()` → `node.instantiate()`.
- `rand_range(a, b)` → `randf_range(a, b)`.
- `Vector2.linear_interpolate(to, w)` → `Vector2.lerp(to, w)`.
- `set_shader_param` → `set_shader_parameter`.
- `set_collision_layer_bit(i, v)` → `set_collision_layer_value(layer(i+1), v)`.

### 6.1 Autoloads

**`src/AutoLoad/Global.gd`**
- `:48-51` frame_freeze:
```gdscript
func frame_freeze(time_scale, duration):
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration * time_scale).timeout
	Engine.time_scale = 1.0
```
- `:110`,`:129`,`:143`: type hints `: KinematicBody2D` → `: CharacterBody2D`.
- Rest unchanged (`reparent`, `get_closest_player`, `get_farthest_player`, ITEM_DROP_WEIGHTS, signals, `random_vector2` all fine).

**`src/AutoLoad/SceneChanger.gd`**
- `:12` `get_tree().change_scene(scene)` → `get_tree().change_scene_to_file(scene)`.
- `:11` `_new_scene()` is a method call from the AnimationPlayer; unchanged.

**`src/AutoLoad/Shake.gd`** — no changes needed. (`Camera2D`, groups, `offset` all unchanged.)

**`src/AutoLoad/ngio.gd`** — **delete the file.** Remove the autoload line (§4).

### 6.2 Shared scripts

**`src/scripts/State.gd`** — no changes.

**`src/scripts/StatesMachine.gd`**
- `:15` `yield(owner, "ready")` → `await owner.ready`.
- Rest unchanged.

**`src/scripts/AnimationMachine.gd`** — no changes (uses `play/seek/get_animation`).

**`src/scripts/SoundMachine.gd`**
- `:18` `rand_range(0.8, 1.5)` → `randf_range(0.8, 1.5)`.
- `find()`/`play_sound()`/`get_sound()` unchanged. (The nodes it finds become plain `AudioStreamPlayer2D`s — see §10.)

### 6.3 Entity base (the important one for feel parity)

**`src/entities/base_templates/base_entity/base_entity.gd`**
- `:2` `extends KinematicBody2D` → `extends CharacterBody2D`.
- `:62` `_physics_process`: add `motion_mode = CharacterBody2D.MOTION_MODE_FLOATING` once (best: `_ready()`, or set in the scene at line 94).
- `:60`, `:67`, `:68` `linear_interpolate` → `lerp`.
- `:71` `move_and_slide(actual_velocity)` → `velocity = actual_velocity` then `move_and_slide()`.
- `:56` `hurtbox.connect("area_entered", self, "_on_Hurtbox_area_entered")` → `hurtbox.area_entered.connect(_on_Hurtbox_area_entered)`.
- `:89` `hit_effect.instance()` → `hit_effect.instantiate()`.
- `:52` `$Debug.has_node("Line2D")` fine.

This class is registered in `_global_script_classes` as `Entity` (Godot 4 will
drop that table and rely on `class_name` on the scripts; the old
`class_name` came from the project file. If any script references the global
`Entity` type, add `class_name Entity` at the top of this file.)

**`src/entities/base_templates/base_entity/functions/HealthManager.gd`**
- `:26-27`:
```gdscript
	health_changed.connect(health_bar.set_value)
	max_health_changed.connect(health_bar.set_max)
```
- Everything else unchanged.

**`src/entities/base_templates/base_entity/functions/SpriteDirectionManager.gd`**
- `:16` `abs(vec.aspect())` → `abs(vec.x / vec.y)` (`aspect()` == x/y was removed).
- `:18` `res[int(ass > 1.0)] = 0` still parses in GDScript 2; you may write `res[int(ass > 1.0)] = 0` unchanged.
- Rest unchanged.

**`src/entities/base_templates/base_entity/functions/NavigationManager.gd`**
- `:26` replace get_simple_path with NavigationServer2D:
```gdscript
func get_target_path(target_position):
	var map = NavigationServer2D.region_get_map(Global.navigation.get_rid())
	path = NavigationServer2D.map_get_path(map, owner.global_position, target_position, false)
	can_update_path = false
```
  (`Global.navigation` will point at a `NavigationRegion2D` — §9.4.)
- `:13`, `:21`: `path.remove(0)` → `path.remove_at(0)` (PackedVector2Array).
- `path` uses global coords; `get_next_direction_to_target`/`get_next_target` unchanged otherwise.

### 6.4 NPC / enemies

**`src/entities/base_templates/base_npc/base_npc.gd`**
- `:16-17`:
```gdscript
	attack_range.body_entered.connect(_on_AttackRange_body_entered)
	attack_range.body_exited.connect(_on_AttackRange_body_exited)
```
- `:66-67` and `:88-89` (`space_state.intersect_ray`):
```gdscript
	var query := PhysicsRayQueryParameters2D.create(position, pos, collision_mask)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
```
  (second site: `global_position` as the `from`.)
- `result.position` → `result.position` (Point2 still called `position` in Godot 4 — fine).

**`src/entities/enemies/EnemyGunner/EnemyGunner.gd`**
- `:12` `bullet_spawner.connect("shot_fired", self, "shot_fired")` → `bullet_spawner.shot_fired.connect(shot_fired)`.
- Rest unchanged.

**`src/entities/enemies/EnemyBall/EnemyBaller.gd`** — no yield/signal changes; unchanged.

**`src/entities/enemies/EnemyImp/EnemyImp.gd`** — unchanged.

**`src/entities/enemies/GeneralStates/Death.gd`**
- `:31` `load(scene).instance()` → `load(scene).instantiate()`.
- `:39` `points_effect_packed.instance()` → `points_effect_packed.instantiate()`.

**`src/entities/enemies/GeneralStates/Idle.gd`** — *unreferenced* (no scene uses it). Optionally delete.

**Enemy state scripts** (`*/states/*.gd`) — `yield` conversions:
- `src/entities/enemies/EnemyBall/states/AttackBall.gd:49` `yield(owner.animation_machine.find("Animations"), "animation_finished")` → `await owner.animation_machine.find("Animations").animation_finished`.
- `src/entities/enemies/EnemyGunner/states/Pain.gd:8` → `await owner.animation_machine.get_node("Animations").animation_finished`.
- `src/entities/enemies/EnemyImp/states/AttackImp.gd:18` → `await owner.animation_machine.find("Animations").animation_finished`.
- `src/entities/enemies/EnemyImp/states/Pain.gd:5` → `await owner.animation_machine.get_node("Animations").animation_finished`.
- All `Idle*`/`Chase*`/`Attack*` body scripts: no other changes.

### 6.5 Player

**`src/entities/players/player/player.gd`**
- `:47` `connect("player_died", Global, "player_died")` → `player_died.connect(Global.player_died)`.
- `:58-71` rework the two activity blocks; each
  `cur_weapon.connect("ammo_changed", ammo_bar, "update_ammo_bar")` /
  `disconnect(...)` becomes
  `cur_weapon.ammo_changed.connect(ammo_bar.update_ammo_bar)` /
  `cur_weapon.ammo_changed.disconnect(ammo_bar.update_ammo_bar)`.
- `:105` `yield(get_animation_player("Movement"), "animation_finished")` → `await get_animation_player("Movement").animation_finished`.
- `:121`, `:132` `set_collision_layer_bit(1, false)` → `set_collision_layer_value(2, false)`; `... bit(1, true)` → `set_collision_layer_value(2, true)`.

**`src/entities/players/player/states/Move.gd`** — `:6`,`:12` yields → awaits.
**`src/entities/players/player/states/Death.gd`** — `:6` → `await owner.animation_machine.get_node("Movement").animation_finished`.
**`src/entities/players/player/Pain.gd`** — `:8` → `await owner.animation_machine.get_node("Movement").animation_finished`.
**`src/entities/players/player/states/Idle.gd`** — `:5` → `await owner.get_animation_player("Movement").animation_finished`.

**`src/entities/players/npc/PlayerNPC.gd`**
- `:70` yield → await (same as player respawn).
- `:82`, `:90` `set_collision_layer_bit(1, ...)` → `set_collision_layer_value(2, ...)`.

**NPC state scripts** (`npc/states/`):
- `Idle.gd:7` and `Move.gd:7` yields → awaits.
- `Attack.gd`, `Death.gd` (if it has a yield, same pattern), `Move.gd` rest unchanged.

### 6.6 Weapons / items

**`src/components/weapon_manager/WeaponManager.gd`**
- `:50` `yield(new_weapon, "tree_entered")` → `await new_weapon.tree_entered`.
- Rest unchanged.

**`src/entities/items/base_templates/base_item/base_item.gd`** — unchanged (uses `$Position2D/...` node paths; the `Position2D` node is renamed to `Marker2D` **in the scene**, not the code string, so these paths keep working).

**`src/entities/items/base_templates/base_melee_weapon/BaseMeleeWeapon.gd`** — unchanged.

**`src/entities/items/base_templates/base_range_weapon/BaseRangeWeapon.gd`**
- `:13` `bullet_spawner.connect("shot_fired", self, "shot_fired")` → `bullet_spawner.shot_fired.connect(shot_fired)`.

**`src/entities/items/medkit/Medkit.gd`** — unchanged.

### 6.7 Bullets

**`src/components/bullet-related/Bullet.gd`**
- `:38-39` — `current_body` is a Walls/Plants TileMap. In 3.x `get_cellv` returns the raw tile id (0 = *any* wall/plant cell in that tileset's lowest id) or −1 for empty, and the bullet dies when `== 0`. After the Walls/Plants conversion to `TileMapLayer` with a single TileSet source (§9.3), every populated cell reads back as source id 0, so the faithful check is "cell is not empty":
```gdscript
	var tile_pos = current_body.local_to_map(position)
	var tile_in_front = current_body.get_cell_source_id(tile_pos + Vector2i(0, 1))
	if tile_in_front != -1:
		queue_free()
```
  Parity note: if bullets prove more/less eager to die than in 3.5 (because 3.x only matched raw tile id 0, not all ids, in the *unrebuilt* data), tighten to `current_body.get_cell_atlas_coords(...) == Vector2i(0, 0)` and re-diff. Keep the node names `Walls`/`Plants` (§9.3) since the bullet matches `body.get_name()`.
- `:34` `position += dir * speed * delta` fine.

**`src/components/bullet-related/BulletEmitter.gd`** (`shoot_single`, bullet instantiation)
- `instance()` → `instantiate()`.

**`src/components/bullet-related/BulletSpawner.gd`**
- `extends Position2D` → `extends Marker2D`.
- `.instance()` → `.instantiate()`.

**`src/components/bullet-related/bullet_emitters/BulletEmitterSingle.gd`** — `rand_range` → `randf_range`.

**`src/components/bullet-related/bullet_emitters/BulletEmitterSpread.gd`** — unchanged.

### 6.8 Components

**`src/components/dynamic_splitscreen/camera_controller.gd`**
- `:30` `viewport2.world_2d = viewport1.world_2d` still valid in 4 (Viewport keeps `world_2d`). Keep.
- `:33` `get_viewport().connect("size_changed", self, "_on_size_changed")` → `get_viewport().size_changed.connect(_on_size_changed)`.
- `:35-36` `view.material.set_shader_param(...)` → `view.material.set_shader_parameter(...)` (all 8 occurrences `:35-36,79-85,101`).
- `:64-65` `camera1.get_camera_screen_center()` → `camera1.get_screen_center_position()` (both cameras).
- `:96-100` `$ViewportContainer.rect_size`, `...2.rect_size`, `view.rect_size` → `.size` (Control).
- `:44` (get_player2_position) note: `player2.global_position + player1.player_visual_middle` uses player1's offset — pre-existing quirk, **keep as is** for parity (do not "fix").

**`src/components/dynamic_splitscreen/SplitScreenCamera.gd`** — whatever it does with the viewport textures/sizes: apply the same `rect_size→size`, `set_shader_param→set_shader_parameter`, `get_camera_screen_center→get_screen_center_position` renames; verify `ViewportTexture` orientation (§9.6).

**`src/components/spawners/enemy/EnemySpawner.gd`**
- `:1` extends Position2D → Marker2D.
- `:17` `rand_range` → `randf_range`.
- `:24` `.instance()` → `.instantiate()`.

**`src/components/dust_spawner/DustSpawner.gd`**
- `:1` extends Position2D → Marker2D.
- `:15` `.instance()` → `.instantiate()`.

**`src/components/dust_spawner/dust_types/player/Dust.gd`** — unchanged.

**`src/components/item_pickup/ItemPickup.gd`** — unchanged.

**`src/components/pickup_range/PickUpRange.gd`** — unchanged (`$AnimationPlayer.play("Animate")`).

**`src/components/respawn_radius/Respawn.gd`**
- `:16`, `:22` `progress_sprite.material.set_shader_param("progress", ...)` → `set_shader_parameter`.
- `:13` `material.duplicate()` — fine.

**`src/components/base_effect/Effect.gd`** — unchanged.

### 6.9 UI / screens

**`src/UI/healthBar.gd`**
- `extends TextureProgress` stays (TextureProgress exists in 4).
- `:11`, `:14` `gradient.interpolate(ratio)` → `gradient.sample(ratio)`.
- `:19` `tween.interpolate_property(self, "value", value, new_value, duration, Tween.TRANS_ELASTIC, Tween.EASE_OUT)` / `tween.start()` →
```gdscript
	var tw = create_tween()
	tw.tween_property(self, "value", new_value, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
```
  The `$Tween` node in the scene becomes a passive child — can stay or be deleted.

**`src/UI/player_healthbar/Ammo_Bar.gd`** — unchanged.

**`src/environment/UILayer.gd`**
- `:14` `info_text.bbcode_text = "[wave ...]"` → `info_text.text = "[wave amp=10 freq=2][color=black]WAVE: %s \nPOINTS: %s \nLEFT: %s" % [...]` and ensure `bbcode_enabled` is true in the scene (`LaunchScene.tscn:48` already has it).

**`src/ScreenEffects/PointEffect.gd`**
- `:30` `back_label.bbcode_text = "[tornado radius=2 freq=10]..."` → `back_label.text = "[tornado radius=2 freq=10]..."`.
- `[tornado]` still exists in Godot 4 RichTextLabel. Verify visually.

**`src/menu/Menu.gd`** — unchanged.

**`src/menu/DeathScreen.gd`** — `:23` `bbcode_text = ...` → `text = ...`.

**`src/UI/pause/Pause.gd`** — unchanged.

### 6.10 World

**`src/environment/base_world/base_world.gd`**
- `:30` **delete** the `Ngio.request(...)` line (decision #1).
- `:86-87` **delete** both `Ngio.request("ScoreBoard.postScore", ...)` lines.
- `:49` `Global.connect("all_dead", self, "all_players_dead")` → `Global.all_dead.connect(all_players_dead)`.
- `:65`, `:81` `yield(timer, "timeout")` → `await timer.timeout` (two sites).
- Nothing else changes (node paths unchanged).

---

## 7. GDScript — known-risk notes

- `export(float) var ... setget` still parses in GDScript 2 (legacy export). Keep to minimise churn.
- Old-style `.connect(signal, target, method)` is the only hard syntax break besides `yield`.
- `extends "res://....gd"` string form is still valid in 4.
- The `.gd.uid` files and `.uid` stubs: Godot 4 generates its own; delete any that point at missing files so the editor stops warning.
- After editing, run a script-syntax check: open each script in the 4.7 editor (Output shows parse errors per file).

---

## 8. Scene and resource migration, globally

### 8.1 Universal text-level pass (safe, do to every `.tscn`/`.tres` under `src/`)

Run this **before** hand-editing scenes. It only touches text patterns that are
identical in the old serialization:

```python
#!/usr/bin/env python3
import re, pathlib
ROOT = pathlib.Path("src")

RENAMES = [
    (r'format=2', r'format=3'),                       # scene header only; .tres has no format= line
    (r'type="Position2D"', r'type="Marker2D"'),
    (r'type="YSort"', r'type="Node2D"'),              # then add y_sort_enabled (below)
    (r'type="Navigation2D"', r'type="NavigationRegion2D"'),
    (r'type="VisibilityNotifier2D"', r'type="VisibleOnScreenNotifier2D"'),
    (r'type="KinematicBody2D"', r'type="CharacterBody2D"'),
    (r'type="DynamicFont"', r'UNSUPPORTED'),          # catch; replace by hand (fonts)
    (r'bbcode_text = ', r'text = '),
    (r'custom_fonts/normal_font', r'theme_override_fonts/font'),
    (r'margin_left =', r'offset_left ='),
    (r'margin_top =', r'offset_top ='),
    (r'margin_right =', r'offset_right ='),
    (r'margin_bottom =', r'offset_bottom ='),
    (r'rect_size =', r'size ='),
    (r'rect_position =', r'position ='),
    (r'PoolIntArray(', r'PackedInt32Array('),
    (r'PoolRealArray(', r'PackedFloat32Array('),
    (r'PoolVector2Array(', r'PackedVector2Array('),
    (r'PoolColorArray(', r'PackedColorArray('),
    (r'PoolStringArray(', r'PackedStringArray('),
    (r'index="\d+"', r''),                            # instance-ordering attr removed
    (r'own_world = true', r''),
    (r'disable_3d = true', r''),
    (r'usage = \d+', r''),
    (r'flags/(filter|mipmaps|repeat|srgb) = [^\n]+', r''),  # .tres texture flags (only if inside resources)
]

for path in ROOT.rglob('*'):
    if path.suffix not in ('.tscn', '.tres'):
        continue
    text = path.read_text()
    for pat, repl in RENAMES:
        text = re.sub(pat, repl, text)
    # YSort -> Node2D must toggle y_sort
    text = re.sub(r'(type="Node2D" parent="[^"]*(EntityWorld|Objects|Items|Spawners|Players|Projectiles|Enemies|Misc)[^"]*")',
                  r'\1\ny_sort_enabled = true', text)
    path.write_text(text)

print("done")
```

Notes:
- `index="N"` removal is safe because the file order in 3.2+ serialization
  already matches the implied index order.
- Don't run Pool→Packed globally on project.godot (it's fine to leave it).
- After this pass, open each scene in the 4.7 editor and fix the leftovers by hand:
  parse errors will point at them.

### 8.2 Sub-resource `id=` format

Godot 4 wants string ids for sub-resources (`[sub_resource type="X" id="1"]`
is accepted and re-saved as e.g. `Gradient_1` on the next save). No action
needed — the editor rewrites ids on save. Similarly `ExtResource( N )` stays.

### 8.3 Scene-by-scene notes (beyond the global pass)

| Scene | What to fix by hand |
|---|---|
| `src/entities/base_templates/base_entity/base_entity.tscn` | `type="CharacterBody2D"` node: add `motion_mode = 1`; replace VisualShader subresources (id 1-6) with `ShaderMaterial` referencing the new `hit_flash.gdshader` (§9.7) keeping uniform `active=false`; replace the 4 ran_cont nodes under `SoundMachine` (§10); keep healthbar/areas as is. |
| `src/entities/base_templates/base_npc/base_npc.tscn` | SoundMachine `Attack` node → audio conversion (§10). |
| `src/entities/players/player/player.tscn` | fix `Player.gd` ext_resource path (capital P → lowercase); same VisualShader replacement as base_entity; `Pickup` node → audio conversion (§10); node `anims/...` and animation tracks unchanged. |
| `src/entities/items/base_templates/base_item/base_item.tscn`, `Medkit.tscn`, `weapons/melee/axe/Axe.tscn` | Position2D renames by global pass; ran_cont (2d **and** nonspatial variants in Axe) → audio conversion (§10); verify `$Position2D/SoundMachine/...` code paths still resolve. |
| `src/UI/HealthBar/HealthBar.tscn` | `Tween` node: leave; `gradient` Gradient + `twinkle` animation unchanged; the `[connection] value_changed` line stays. |
| `src/UI/player_healthbar/PlayerHealthBar.tscn` | `texture_progress_offset`, `fill_mode` still valid. No change beyond global pass. |
| `src/components/dynamic_splitscreen/SplitScreenCamera.tscn` | per §9.6 (Viewport flags, TextureRect stretch, flips). |
| `src/environment/base_world/base_world.tscn` | `Navigation2D` node → `NavigationRegion2D` (global pass does the type); see §9.4 for the region setup; `TileMap` child of it becomes the navigation baked in 4 (or removed). |
| `src/environment/levels/Level_1.tscn`, `Level_2.tscn` | TileMap conversion (§9.2/9.3); Level_1 player instance fix (§2); `WorldEnvironment` + `post-processing/Default.tres` (§9.5); `.Index` attrs already stripped. |
| `src/environment/tilesets/{Ground,Path,Walls,Plants,GroundYellow}.tscn` | These are `TileSet` scenes used as TileMap instances. Convert as §9.3. |
| `src/environment/NavigationTileMap.tscn` | Delete or convert — the nav region recipe (§9.4) replaces it. |
| `src/environment/LaunchScene.tscn` | DynamicFont → FontFile (§9.8); `bbcode`→`text` (global pass); `Info` label `theme_override_fonts/font` + `theme_override_font_sizes/font_size = 32`; `Cameras` node (editor-only visibility) fine. |
| `src/menu/Menu.tscn`, `src/menu/DeathScreen.tscn`, `src/UI/pause/Pause.tscn` | Font swap if they carry `DynamicFont`; verify `RichTextLabel` text/bbcode. |
| `assets/fonts/cowboys.tres`, `assets/fonts/windows_command_font.tres` | Recreate as FontFile resources (§9.8). |

---

## 9. The four conversion recipes

### 9.1 Visual Shader → text shader (hit flash)

The `VisualShader` subresources in `base_entity.tscn` and `player.tscn` share
exactly one graph (a white flash driven by uniform `active`). Create
`src/components/hit/hit_flash.gdshader`:

```glsl
shader_type canvas_item;
uniform bool active;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (active) {
		COLOR = vec4(1.0, 1.0, 1.0, tex.a);
	} else {
		COLOR = tex;
	}
}
```

Then in the two scenes: add `[ext_resource path="res://src/components/hit/hit_flash.gdshader" type="Shader" id=X]`, delete the 6 VisualShaderNode sub-resources, and replace them with:

```
[sub_resource type="ShaderMaterial" id=7]
resource_local_to_scene = true
shader = ExtResource( X )
shader_param/active = false
```

(An unused `active` uniform is fine; nothing sets it at runtime today.)

### 9.2 TileMap `tile_data` export (run once in **Godot 3.5**)

Godot 4 cannot read `tile_data = PackedInt32Array(...)` autotile data. Export
the real data with a throwaway tool scene run in 3.5:

```gdscript
# tools/export_tilemaps.gd  (attach to an autoload or run from a test scene in 3.5)
extends Node
var out := {}

func _ready() -> void:
	for path in ["res://src/environment/levels/Level_1.tscn",
	             "res://src/environment/levels/Level_2.tscn"]:
		var level = load(path).instance()
		add_child(level)
		yield(get_tree(), "idle_frame")
		_dump_tree(level, ".")
		level.queue_free()
	File.new().open("res://tools/tilemaps.json", File.WRITE).store_string(JSON.print(out, "\t"))

func _dump_tree(node: Node, prefix: String) -> void:
	if node is TileMap:
		var entries := []
		for cell in node.get_used_cells():
			entries.append({
				"x": cell.x, "y": cell.y,
				"tile": node.get_cell(cell.x, cell.y),
				"auto": node.get_cell_autotile_coord(cell.x, cell.y),
				"flip_x": node.is_cell_x_flipped(cell.x, cell.y),
				"flip_y": node.is_cell_y_flipped(cell.x, cell.y),
				"transpose": node.is_cell_transposed(cell.x, cell.y),
			})
		out[node.get_path()] = entries
	for child in node.get_children():
		_dump_tree(child, prefix)
```

This gives you, per TileMap: cell coords, raw tile index, **autotile coord**
(which of the 64×64 cells within the autotile region), and flips — everything
needed to rebuild pixel-identically.

### 9.3 Rebuild TileSets/TileMaps in Godot 4

For each old tileset (`Ground`, `Path`, `Walls`, `Plants`, `GroundYellow`):

1. Create a **`TileSetAtlasSource`** from the same atlas PNG, `texture_region_size = 64×64` (matches `autotile/tile_size`).
2. Add each needed atlas cell as a plain alternative; the *icon/autotile* sub-regions in 3.x are just ordinary atlas cells in 4. **Do not** re-creates Godot 3 terrains.
3. Add the tile's **physics**: Ground/Path/Walls had none in `shapes = []` — if the 3.x data shows `shapes` populated, re-apply them on the atlas tile. (From current files they are empty; the levels' collision comes from `OneWayCollision` StaticBody2D polygons and the `Walls` Ground2 tilemap's purpose — verify a tap shows the same blocking.)
4. Rebuild each level's TileMaps as **`TileMapLayer`** nodes (add cells to the layer) and apply cells from the §9.2 JSON:
```gdscript
# inside Godot 4, one-time rebuild snippet
# layer is a TileMapLayer; src is your TileSetAtlasSource; map = {Vector2i → atlas cell Vector2i}
for key in map:
	layer.set_cell(key, 0, map[key], 0)
```
   Autotile coord from §9.2 → atlas cell (tile_index's 64×64 block offset + autotile coord within it), plus x/y flips → use `set_cell(..., flip_h, flip_v, transpose)` (available on the TileMap API; for TileMapLayer use `set_cell` with flags in `TileData` — apply `flip_h`/`flip_v` via layer's `set_cell` variant or a custom TileData).

Concretely, the mapping for each entry from §9.2:
- atlas source cell = base of the tile_index region + autotile coord.
- Then `flip_x`, `flip_y`, `transpose` copied verbatim.

Verify by toggling "Tile shapes" display and by screenshot comparison with 3.5.

**Walls/Plants special case:** `Bullet.gd` checks one cell "below" the bullet via the tilemap; with `TileMapLayer`, use §6.7 code. Make sure the rebuilt Walls/Plants layers keep the exact same `tile_map` node name `Walls`/`Plants` (Bullet matches `body.get_name()`).

### 9.4 Navigation2D → NavigationRegion2D

Current state: `base_world.tscn:22` has a `Navigation2D` node with an instanced
`NavigationTileMap.tscn` (tile 0 carries a 64×64 `NavigationPolygon`). Level_1
has **no** tile_data override for it (so no nav regions → `get_simple_path`
returns a straight line — enemies walk straight at players). Level_2 stamps
nav tiles across the floor (`Level_2.tscn:25-27`), so it pathfinds.

Replacement:
1. Change node to `NavigationRegion2D` (type rename is in the global pass), give it the name still `Navigation2D` **or** update `base_world.gd:16` to `$World/Navigation2D` accordingly.
2. Give the region a `NavigationPolygon` resource:
   - **Level_2:** bake from the exported nav cells — build `NavigationPolygon` where `vertices` = the 4 corners per cell and `polygons` = one quad per cell (use `NavigationServer2D`'s bake path or a helper; a per-cell-quad polygon list is exact). The `NavigationPolygon` vertex count is fine for this size.
     Simpler fallback (slightly different path shape, same reachability): one quad covering the bounding box of the nav cells. Because the floor is one connected room, pathing remains visually identical in practice; keep the exact per-cell union first and diff gameplay.
   - **Level_1:** leave the region's polygon empty (mirrors "no navigation").
3. `NavigationManager.gd` (§6.3) uses `Global.navigation.get_rid()` + `NavigationServer2D.map_get_path(..., false)` — `optimize=false` reproduces the omits-funnel straight/edge paths of 3.x.
4. Delete `NavigationTileMap.tscn` (or stop instancing it in `base_world.tscn`).

### 9.5 Environment / post-processing

`src/environment/post-processing/Default.tres` (Environment) and root
`default_env.tres`: open in 4.7, let it resave. Verify glow/HDR settings
visually (same as 3.5 screenshot). If any 3.x-only Environment property errors,
drop just that key.

### 9.6 Split screen (the trickiest runtime part)

`SplitScreenCamera.tscn`:
- Viewport nodes: keep `size`, `handle_input_locally = false`, `audio_listener_enable_2d`, `render_target_update_mode` (numeric 3/0 map 1:1). Drop `disable_3d`, `usage`, `own_world` (global pass handles).
- `ViewportContainer`: `stretch = true` — keep.
- `TextureRect` `View`: `expand = true` → set `stretch_mode = 1` (STRETCH_SCALE); keep `flip_v = true` **initially**, then test — Godot 4's ViewportTexture Y-orientation differs from 3.x; if the composite screen renders upside down, flip the value.
- `camera_controller.gd`: applied in §6.8 (`rect_size→size`, `set_shader_parameter`, `get_screen_center_position`).
- `split_screen_2d.gdshader` works unchanged (canvas_item + two samplers). In the exported gdshader, `uniform sampler2D viewport1 : hint_albedo;` is fine in 4.

### 9.7 (empty / placeholder)

### 9.8 Fonts

All 6 `DynamicFont`/`DynamicFontData` uses (LaunchScene, DeathScreen,
PointEffect, `cowboys.tres`, `windows_command_font.tres`) die with 3.x.

1. In 4.7, the `.ttf`/`.otf` files reimport automatically as `FontFile` — no resource needed.
2. Replace `[sub_resource type="DynamicFont" ...]`+`DynamicFontData` blocks with `[ext_resource path="res://assets/fonts/windows_command_prompt.ttf" type="FontFile" id=N]`.
3. On the label: `theme_override_fonts/font = ExtResource(N)` and `theme_override_font_sizes/font_size = <old DynamicFont size>`.
4. Fonts to use: `assets/fonts/windows_command_prompt.ttf` (used by levels / HUD) and `assets/fonts/Cowboys 2.0.otf` (LaunchScene info text). Keep letter spacing defaults identical (no kerning options were set).

---

## 10. Replace the Mixing Desk addon (decision #2)

Files that reference the addon: `base_entity.tscn`, `base_npc.tscn`,
`base_item.tscn`, `Medkit.tscn`, `Axe.tscn`, `player.tscn`, and the editor
plugin entry in `project.godot` (`[editor_plugins] enabled=...mixing-desk...`).

Delete the whole `addons/mixing-desk/` folder and the `[editor_plugins]` section.

**Node replacement pattern** (same for every ran_cont node). Given (example)
```
[node name="Pickup" type="Node2D" parent="SoundMachine"]   script = ext(ran_cont)
  ├─ AudioStreamPlayer2D  stream = s1
  └─ AudioStreamPlayer2D2 stream = s2
```
replace the wrapper node and its children with one node:
```
[node name="Pickup" type="AudioStreamPlayer2D" parent="SoundMachine"]
stream = SubResource( PickupRandomizer )
```
where the resource is an `AudioStreamRandomizer` with `streams_pool = [s1, s2]`,
`random_pitch = false`. Keep the **same node name** so `SoundMachine.find()`
and direct paths like `$Position2D/SoundMachine/Eat` (Medkit.gd) keep working.

Why `random_pitch = false`: today `ran_cont` nodes are pure containers; the
pitch randomization happens in `SoundMachine.play_sound` by assigning
`pitch_scale` before `.play()`. With the outer node becoming the player, that
assignment still applies; leaving the randomizer flat reproduces the exact
same distribution (no double-randomization). Direct `.play()` calls
(`attack_sound.play()`, `item_drop_sound.play()`, `dmg/...`) also behave as
before (no randomization).

Per scene, the concrete ran_cont inventory:

| Scene | Nodes → AudioStreamPlayer2D | Streams to move into the randomizer (same list) |
|---|---|---|
| `base_entity.tscn` | `Damage`, `Pain`, `Death`, `Footstep` | Damage → `EFX SD Heads Hit Together 02.wav`; Death → `Ilmarinen,blacksmith...wav`; Pain/Footstep have **no child player** today → create AudioStreamPlayer2D with empty stream (they're never played with content; `damage_sound`/`death_sound` are used, `pain_sound` only commented) |
| `base_npc.tscn` | `Attack` | its child player stream |
| `base_item.tscn` | `ItemDrop` | its child player stream |
| `Medkit.tscn` | `Eat` | its child stream |
| `Axe.tscn` | `Swoosh` (+ any nonspatial ran_cont node) | same |
| `player.tscn` | `Pickup` | `Pop 31.wav`, `Pop 41.wav` |

After the swap, `SoundMachine.gd` needs no structural change — only the
`randf_range` fix in §6.2.

---

## 11. Assets & import settings

- Force reimport (`Project → Tools → ... reimport all`) after setting
  `rendering/textures/canvas_textures/default_texture_filter=Nearest`.
- Texture import settings worth keeping identical to current:
  `flags/filter=false` (Nearest), `mipmaps=false`, `repeat=0`, `srgb=2`
  (unchanged semantics; verify on a sprite at zoom).
- `.wav` files: reimport normally; verify loop settings were default.
- `icon.png`, `splashscreen.png`: untouched.
- `PhysicsColliderDefault.tres` (CapsuleShape2D resource): open in 4.7 and
  save; shape data is version-stable.

---

## 12. Order of operations + verification checklist

Suggested execution order (each step ends with a runnable milestone):

1. **Housekeeping** (§2), backup.
2. Open in 4.7 → let it migrate project.godot; apply §4 settings, §5 input map, remove autoload/plugin; delete `addons/mixing-desk`, `ngio.gd`. *(Milestone: editor opens with zero project-level errors.)*
3. Run the §8.1 text pass on all .tscn/.tres.
4. Apply script edits §6 file-by-file.
5. Build `hit_flash.gdshader` (§9.1) and fix base_entity/player scenes; fix fonts (§9.8); fix split screen (camera_controller + SplitScreenCamera.tscn).
6. Run the §9.2 export in 3.5 → build §9.3 TileSetAtlasSources + TileMapLayer rebuild; nav region §9.4; Bullet.gd tile check updated.
7. Sound conversion §10.
8. **Playtest parity** — for each player count (2), each level:
   - menu → level loads; wave timers and spawn counts identical;
   - run/idle accel & friction feel identical (verify `FRICTION/ACCEL` in Global.gd unchanged; `MOTION_MODE_FLOATING` + `move_and_slide()` confirmed);
   - each weapon: melee (Axe/Stick) swing + knockback; Revolver/Shotgun/Minigun fire rate, ammo decrement, self-knockback, spread; Medkit heal;
   - enemy behaviour: Ball dash ("Pain" front/back), Gunner burst + hit-animation, Imp dash + `frame_freeze` on hit; death drops (weights intact), points/PointEffect text, wave advance;
   - split screen splits/merges, dead-player camera takeover, respawn radius anim + shader progress;
   - pause menu (esc) works with tree paused;
   - death → auto-return to Menu (NGIO lines gone; no errors in Output);
   - no script errors in Output; `GLES3→compatibility` visual diff: compare screenshots with 3.5 (lighting is `Environment`/glow only — expected close).
9. Export: pick a preset (e.g. Windows), run `--headless --export-debug` and smoke-test the built executable.

### Known parity risks (watch these)

| Risk | Why | Mitigation |
|---|---|---|
| CharacterBody2D collision behaviour | `motion_mode` floating is the nearest analogue to 3.x KinematicBody2D; safe-mode differs slightly on slopes | We have no slopes; verify slide along `OneWayCollision` walls |
| `move_and_slide` velocity retention | 3.x discarded `velocity`; 4 applies `velocity` each frame; we overwrite it every physics frame | Exact parity because `velocity = intended+knockback` recomputed each tick |
| TileMap autotile rebuild | Atlas cells vs terrain bitmasks | §9.3 maps exact cells; screenshot diff |
| Nav pathing | `map_get_path optimize=false` vs `get_simple_path` | Keep `false`; compare Level_2 enemy routes to a 3.5 recording |
| Viewport texture Y-flip | Orientation differs between engines | Toggle `flip_v`; visual check |
| `RichTextLabel` [tornado]/[wave] | Effects still exist; subtle render diffs | Visual check |
| Shake offsets | unchanged API | fine |
| Import flags (srgb/filter) | Nearest must hold | global setting + reimport |

---

## 13. Optional cleanups (behaviour-neutral, only if you want)

- Delete the unused `src/entities/enemies/GeneralStates/Idle.gd` and all
  `.gd.uid` stubs pointing at missing files.
- Rename `player.gd`/`Player.tscn` references consistently (`player.tscn`).
- Re-enable the commented-out `show_death_screen()` flow later if wanted —
  out of scope for "works exactly as now".