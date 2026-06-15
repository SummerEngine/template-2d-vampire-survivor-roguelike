# Vampire-Survivors-like Game — Design Spec

**Date:** 2026-06-15
**Engine:** Summer Engine (Godot-based), GDScript, 2D
**Location:** `vampire survivors/` (fresh Godot project)

## 1. Overview

A top-down survival action game. The player walks around a large bounded
arena, enemies continuously spawn and chase the player, and the player
automatically fires projectiles at enemies. Touching enemies drains the
player's health; when it reaches zero the game ends. Survive as long as
possible.

### v1 Scope (strict)

In scope: 8-direction movement, centered camera, bounded world, timed enemy
spawning, enemy chase AI, contact damage, player death + game over + restart,
a data-driven weapon system with two weapons, generated sprites, minimal HUD.

Explicitly out of scope for v1: XP / leveling, upgrades, multiple enemy types,
pickups, difficulty scaling, audio, menus beyond game-over.

## 2. Setup & Dependencies

- The game is a **fresh Godot project** created in the `vampire survivors`
  folder (`project.godot`, `.godot/`, project structure).
- The Summer Engine instance is currently bound to the `test1` project. Image
  generation (`summer_generate_image`) and playtesting (`summer_play`,
  `summer_get_diagnostics`) require the engine pointed at **this** project.
- **Setup order:** (1) scaffold project files, (2) open the project in Summer
  Engine, (3) generate sprites, (4) playtest. Code/scenes can be authored as
  text files before the engine is switched over; running and asset generation
  cannot.

## 3. Architecture

### Scene tree (Main.tscn)

```
Game (Node2D)                — GameManager script (main.gd)
├── World (Node2D)
│   └── Walls (StaticBody2D) — 4 invisible boundary walls (world layer)
├── Player (CharacterBody2D, instanced)  — player.gd
│   ├── Sprite2D
│   ├── CollisionShape2D
│   ├── Camera2D            — child of player → player always centered
│   ├── Hurtbox (Area2D)    — detects enemy contact
│   └── WeaponSystem (Node) — weapon_system.gd
├── Enemies (Node2D)        — container for spawned enemies
├── Projectiles (Node2D)    — container for spawned projectiles
├── EnemySpawner (Node)     — enemy_spawner.gd + Timer (1s)
└── UI (CanvasLayer)
    ├── HUD (health, kills, timer)
    └── GameOverPanel (hidden until death)
```

### Components

**Player (`player.gd`, CharacterBody2D)**
- Reads WASD into an input vector, normalizes it, moves at `speed` (8-dir).
- Clamps position to world bounds (belt-and-suspenders with the walls).
- Holds `max_health` / `health`; `take_damage(amount)`; emits
  `health_changed(health)` and `died`.
- Hurtbox (Area2D) overlaps with enemies; while overlapping, applies enemy
  contact damage over time.
- Owns the Camera2D (centering) and the WeaponSystem.

**Enemy (`enemy.gd`, CharacterBody2D)**
- Each frame moves toward the player's current position at `speed`.
- Added to the `"enemies"` group so weapons can query targets.
- `health`, `take_damage(amount)`; on death emits `died` and frees itself.
- Deals `contact_damage` per second to the player (applied via the player's
  Hurtbox overlap logic).

**EnemySpawner (`enemy_spawner.gd`)**
- Timer fires every `spawn_interval` (1s).
- Picks a random point at least `min_spawn_distance` from the player and
  inside the world bounds; instances an Enemy there into the Enemies container.

**WeaponSystem (`weapon_system.gd`, Node on Player)**
- Holds an array of `WeaponDef` resources, each with an independent cooldown.
- When a weapon's cooldown elapses, it fires: spawns a Projectile into the
  Projectiles container, configured from the def, and sets the projectile's
  direction/target based on `targeting_mode`.

**WeaponDef (`weapon_def.gd`, Resource)**
- Fields: `fire_rate` (s), `targeting_mode` (enum: `CLOSEST_ENEMY`,
  `RANDOM_DIRECTION`), `damage`, `projectile_speed`, `homing` (bool),
  `lifetime` (s).
- v1 instances (`.tres`):
  - **HomingMissile** — `CLOSEST_ENEMY`, `homing = true`, fire 1s.
  - **RandomMissile** — `RANDOM_DIRECTION`, `homing = false`, fire 1s.

**Projectile (`projectile.gd`, Area2D)**
- Moves along `direction` at `speed`.
- If `homing` and a valid target exists, steers `direction` toward the target
  each frame (turn-rate limited so it arcs rather than snaps).
- On overlap with an enemy: calls `enemy.take_damage(damage)` and frees itself.
- Frees itself after `lifetime` seconds.

**GameManager (`main.gd`, Node2D root)**
- Wires references (player, spawner, containers, UI).
- Tracks `kills` (incremented on enemy death) and `survival_time`.
- Updates the HUD.
- On player `died`: pauses the tree, shows the GameOverPanel with survival
  time + kills.
- Listens for **R** to restart via `reload_current_scene()`.

## 4. Collision Layers

| Layer | Used by |
|---|---|
| 1 `player` | Player body + Hurtbox |
| 2 `enemies` | Enemy bodies |
| 3 `world` | Boundary walls |
| 4 `projectiles` | Projectile areas |

- **Enemies mask out layer 2** → enemies do not collide with each other
  (they overlap freely). They collide with world walls and the player.
- **Player Hurtbox** masks layer 2 (enemies) to detect contact.
- **Projectile** masks layer 2 (enemies) to detect hits.

## 5. Data Flow

- Player → `health_changed`, `died` → GameManager / HUD.
- Enemies live in the `"enemies"` group. WeaponSystem queries the group for
  the closest enemy when targeting `CLOSEST_ENEMY`.
- Enemy `died` → GameManager increments `kills`.
- Projectile detects its own collisions and applies damage directly.

## 6. Game Loop & States

- **Playing:** movement, spawning, chasing, auto-firing, damage all active.
- **Game over:** triggered by `health <= 0`. Tree paused, GameOverPanel shown
  with survival time + kills. **R** reloads the scene to restart.

## 7. Default Tuning

| Parameter | Value |
|---|---|
| World size | 3000 × 3000 px |
| Player speed | 200 px/s |
| Player max health | 100 |
| Enemy contact damage | 20 / sec while touching |
| Enemy speed | 80 px/s |
| Enemy health | 30 |
| Spawn interval | 1 s |
| Min spawn distance from player | ~600 px |
| HomingMissile | 30 dmg, ~300 px/s, fire 1 s |
| RandomMissile | 30 dmg, ~350 px/s, fire 1 s, ~2 s lifetime |

All values are exported / centralized so they can be tuned during playtesting.

## 8. File Layout

```
vampire survivors/
├── project.godot
├── main.tscn
├── scenes/
│   ├── player.tscn
│   ├── enemy.tscn
│   └── projectile.tscn
├── scripts/
│   ├── main.gd            (GameManager)
│   ├── player.gd
│   ├── enemy.gd
│   ├── enemy_spawner.gd
│   ├── weapon_system.gd
│   ├── weapon_def.gd      (Resource)
│   └── projectile.gd
├── resources/weapons/
│   ├── homing_missile.tres
│   └── random_missile.tres
└── assets/                (generated sprites)
```

## 9. Verification / Playtesting

Per the Summer Engine flow, after building: run the scene and read
diagnostics, iterate until clean, then walk through each feature:

1. Player moves in all 8 directions with WASD; camera stays centered.
2. Player cannot leave the world bounds.
3. Enemies spawn ~1/sec, never on top of the player, and chase the player.
4. Enemies overlap each other (no enemy-enemy collision).
5. Touching enemies drains health; reaching 0 triggers Game Over.
6. Game Over shows survival time + kills; R restarts.
7. Homing missile fires at the closest enemy and hits it; random missile
   fires in a random direction and damages enemies it collides with.
8. Sprites render for player, enemies, and projectiles.
