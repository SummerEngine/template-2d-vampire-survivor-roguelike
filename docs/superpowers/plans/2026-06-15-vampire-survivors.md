# Vampire-Survivors-like Game Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a top-down survival game where a WASD-controlled, always-centered player survives in a bounded arena against endlessly spawning, chasing enemies while auto-firing two data-driven weapons.

**Architecture:** Godot 2D / GDScript. A `Game` root (GameManager) owns the player, an enemy spawner, runtime containers for enemies and projectiles, and a UI layer. The player carries a child `Camera2D` (auto-centering), a `Hurtbox` Area2D for contact damage, and a `WeaponSystem` that fires `Projectile` scenes from `WeaponDef` resource configs. Enemies chase via direct movement and never collide with each other (collision masks). Verification is done live in Summer Engine (play + diagnostics + playtest), not via a unit-test framework.

**Tech Stack:** Summer Engine (Godot 4.x), GDScript, Summer Engine MCP for scene building / image generation / play / diagnostics.

---

## Verification conventions (used by every task)

Where a task says **"Verify in engine"**, the executor performs:
1. `summer_play` (or `summer_open_scene` then play) to run the current scene.
2. `summer_get_diagnostics` — confirm zero script/parse/runtime errors. Fix and re-run until clean.
3. The task-specific playtest observation (movement, spawning, etc.), confirmed via `summer_screenshot` and/or console output.
4. `summer_stop` when done.

Commit messages end with:
```
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

---

## Task 0: Project scaffold & engine switch

**Files:**
- Create: `vampire survivors/project.godot`
- Create: `vampire survivors/.gitignore`
- Create: `vampire survivors/icon.svg`
- Create dirs: `scenes/`, `scripts/`, `resources/weapons/`, `assets/`

- [ ] **Step 1: Write `project.godot`**

```ini
config_version=5

[application]

config/name="vampire survivors"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.3", "Forward Plus")
config/icon="res://icon.svg"

[layer_names]

2d_physics/layer_1="player"
2d_physics/layer_2="enemies"
2d_physics/layer_3="world"
2d_physics/layer_4="projectiles"
```

- [ ] **Step 2: Write `.gitignore`**

```gitignore
.godot/
*.tmp
*.bak
```

- [ ] **Step 3: Add an icon**

Copy the icon from the existing project so imports don't complain:
Run: `cp "../test-1/icon.svg" "icon.svg"`
(If that fails, create a 1-line placeholder SVG `<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="#88c"/></svg>`.)

- [ ] **Step 4: Init git and first commit**

```bash
git init
git add .
git commit -m "chore: scaffold vampire survivors Godot project"
```

- [ ] **Step 5: Switch Summer Engine to this project (MANUAL / blocking)**

The engine is currently bound to `test1`. The user must open the
`vampire survivors` project in the Summer Engine app so MCP tools target it.
Confirm with `summer_get_project_context`: `project_path` must end in
`vampire survivors`. **Do not proceed to scene-building or play steps until
this check passes.** (File-writing steps for scripts can proceed regardless.)

- [ ] **Step 6: Verify in engine**

`summer_get_project_context` → `project_path` ends with `vampire survivors`,
`health.ok == true`.

---

## Task 1: Targeting helper + player movement + centered camera + world bounds

This task delivers a runnable scene: a player you can drive in 8 directions with WASD, a camera that keeps the player centered, and walls that bound a 3000×3000 world.

**Files:**
- Create: `scripts/targeting.gd`
- Create: `scripts/player.gd`
- Create: `scripts/main.gd`
- Create (via engine): `scenes/player.tscn`, `main.tscn`

- [ ] **Step 1: Write `scripts/targeting.gd` (shared closest-enemy helper, used later too)**

```gdscript
class_name Targeting
extends RefCounted

## Returns the nearest node in the "enemies" group to `from`, or null.
static func closest_enemy(tree: SceneTree, from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for e in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best
```

- [ ] **Step 2: Write `scripts/player.gd`**

```gdscript
extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal died

@export var speed: float = 200.0
@export var max_health: float = 100.0
@export var world_half_size: float = 1500.0  # world spans -1500..1500 on each axis
@export var body_radius: float = 16.0

var health: float

@onready var hurtbox: Area2D = $Hurtbox

func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)

func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A): dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): dir.x += 1.0
	velocity = dir.normalized() * speed
	move_and_slide()
	# Belt-and-suspenders clamp in case the player slips past a wall.
	var limit := world_half_size - body_radius
	global_position = global_position.clamp(Vector2(-limit, -limit), Vector2(limit, limit))

func _process(delta: float) -> void:
	# Contact damage: any enemy overlapping the hurtbox deals damage over time.
	for b in hurtbox.get_overlapping_bodies():
		if b.is_in_group("enemies") and "contact_damage" in b:
			take_damage(b.contact_damage * delta)

func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = max(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		died.emit()
```

- [ ] **Step 3: Write a minimal `scripts/main.gd` (expanded in later tasks)**

```gdscript
extends Node2D

@onready var player: CharacterBody2D = $Player

func _ready() -> void:
	pass
```

- [ ] **Step 4: Build `scenes/player.tscn` via engine MCP**

Use `summer_create_scene` / `summer_add_node` / `summer_set_prop` / `summer_save_scene`.
Node tree and properties (placeholder visuals — a colored shape until Task 5 sprites):

```
Player (CharacterBody2D)          script=res://scripts/player.gd
                                  collision_layer=1, collision_mask=4
├── Sprite2D                      (temporary: leave texture empty; Task 5 fills it)
├── CollisionShape2D              shape=CircleShape2D, radius=16
├── Camera2D                      (no offset; centers on Player)
├── Hurtbox (Area2D)             collision_layer=0, collision_mask=2, monitoring=true
│   └── CollisionShape2D          shape=CircleShape2D, radius=20
└── WeaponSystem (Node)          (script + exports added in Task 4; create the empty node now)
```

Save the scene.

- [ ] **Step 5: Build `main.tscn` via engine MCP**

```
Game (Node2D)                     script=res://scripts/main.gd, process_mode=Always(3)
├── World (Node2D)
│   └── Walls (StaticBody2D)      collision_layer=4, collision_mask=0
│       ├── CollisionShape2D (top)    shape=RectangleShape2D size=(3200,40), position=(0,-1500)
│       ├── CollisionShape2D (bottom) shape=RectangleShape2D size=(3200,40), position=(0,1500)
│       ├── CollisionShape2D (left)   shape=RectangleShape2D size=(40,3200), position=(-1500,0)
│       └── CollisionShape2D (right)  shape=RectangleShape2D size=(40,3200), position=(1500,0)
├── Player (instance of res://scenes/player.tscn)  position=(0,0), process_mode=Pausable(1)
├── Enemies (Node2D)             process_mode=Pausable(1)
├── Projectiles (Node2D)         process_mode=Pausable(1)
├── EnemySpawner (Node)          process_mode=Pausable(1)   (script added Task 2)
└── UI (CanvasLayer)             (HUD/GameOver added Task 3)
```

Set the main scene to `res://main.tscn` (already in project.godot). Save.

> **Why these process_modes:** the root `Game` runs even when the tree is
> paused (so it can read the restart key on game over). Gameplay nodes are
> explicitly `Pausable` so pausing the tree freezes them.

- [ ] **Step 6: Verify in engine**

Play `main.tscn`. Diagnostics clean. Observe:
- WASD moves the player up/down/left/right and diagonally (8-dir, equal speed).
- The player stays centered on screen as it moves (camera follows).
- The player cannot pass the world edges (stops at the walls).

- [ ] **Step 7: Commit**

```bash
git add scripts/targeting.gd scripts/player.gd scripts/main.gd scenes/player.tscn main.tscn
git commit -m "feat: player movement, centered camera, bounded world"
```

---

## Task 2: Enemies, spawner, chase AI, no enemy-enemy collision

**Files:**
- Create: `scripts/enemy.gd`
- Create: `scripts/enemy_spawner.gd`
- Create (via engine): `scenes/enemy.tscn`
- Modify (via engine): `main.tscn` (attach spawner script + exports)

- [ ] **Step 1: Write `scripts/enemy.gd`**

```gdscript
extends CharacterBody2D

signal died(enemy)

@export var speed: float = 80.0
@export var max_health: float = 30.0
@export var contact_damage: float = 20.0  # per second while touching the player

var health: float
var target: Node2D

func _ready() -> void:
	health = max_health
	add_to_group("enemies")

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	var dir := (target.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()

func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health -= amount
	if health <= 0.0:
		died.emit(self)
		queue_free()
```

- [ ] **Step 2: Write `scripts/enemy_spawner.gd`**

```gdscript
extends Node

@export var spawn_interval: float = 1.0
@export var min_spawn_distance: float = 600.0
@export var max_spawn_distance: float = 1000.0
@export var world_half_size: float = 1500.0
@export var enemy_scene: PackedScene

var player: Node2D
var enemies_container: Node2D
var _timer: float = 0.0

func setup(p: Node2D, container: Node2D) -> void:
	player = p
	enemies_container = container

func _process(delta: float) -> void:
	if not is_instance_valid(player) or enemies_container == null:
		return
	_timer += delta
	while _timer >= spawn_interval:
		_timer -= spawn_interval
		_spawn()

func _spawn() -> void:
	var angle := randf() * TAU
	var dist := randf_range(min_spawn_distance, max_spawn_distance)
	var pos := player.global_position + Vector2(cos(angle), sin(angle)) * dist
	var limit := world_half_size - 32.0
	pos = pos.clamp(Vector2(-limit, -limit), Vector2(limit, limit))
	var enemy := enemy_scene.instantiate()
	enemy.target = player
	enemies_container.add_child(enemy)
	enemy.global_position = pos
```

- [ ] **Step 3: Build `scenes/enemy.tscn` via engine MCP**

```
Enemy (CharacterBody2D)           script=res://scripts/enemy.gd
                                  collision_layer=2, collision_mask=4   # collides with world only
├── Sprite2D                      (placeholder; Task 5 fills texture)
└── CollisionShape2D              shape=CircleShape2D, radius=14
```

> **Collision mask = 4 (world only)** is what makes enemies pass through each
> other and through the player body (so they swarm and overlap). Contact
> damage comes from the player's Hurtbox, not from physical collision.

Save the scene.

- [ ] **Step 4: Wire the spawner in `main.tscn` via engine MCP**

- Attach `res://scripts/enemy_spawner.gd` to the `EnemySpawner` node.
- Set its exported `enemy_scene` to `res://scenes/enemy.tscn`.
- (Leave other exports at defaults: 1.0s / 600 / 1000 / 1500.)

- [ ] **Step 5: Wire spawner setup in `scripts/main.gd`**

Replace the file contents with:

```gdscript
extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var spawner: Node = $EnemySpawner
@onready var enemies: Node2D = $Enemies

func _ready() -> void:
	spawner.setup(player, enemies)
```

- [ ] **Step 6: Verify in engine**

Play `main.tscn`. Diagnostics clean. Observe:
- An enemy appears roughly once per second, never on top of the player
  (always at a distance), inside the world.
- Enemies move toward the player continuously.
- Multiple enemies overlap each other freely (no pushing/blocking between them).

- [ ] **Step 7: Commit**

```bash
git add scripts/enemy.gd scripts/enemy_spawner.gd scenes/enemy.tscn main.tscn scripts/main.gd
git commit -m "feat: enemy spawning and chase AI with no enemy-enemy collision"
```

---

## Task 3: Health/contact damage, HUD, game over + restart

Contact damage is already applied by `player.gd` (Task 1, Step 2). This task adds the HUD, the death flow, kill/time tracking, and restart.

**Files:**
- Modify: `scripts/main.gd`
- Modify (via engine): `main.tscn` (UI nodes)

- [ ] **Step 1: Build UI nodes in `main.tscn` via engine MCP**

Under the existing `UI (CanvasLayer)`:

```
UI (CanvasLayer)
├── HUD (Control)                anchors=full rect
│   ├── HealthLabel (Label)      position=(16,16),  text="HP"
│   ├── KillsLabel  (Label)      position=(16,44),  text="Kills: 0"
│   └── TimeLabel   (Label)      position=(16,72),  text="Time: 0.0s"
└── GameOverPanel (Control)      anchors=full rect, visible=false
    ├── Background (ColorRect)    anchors=full rect, color=(0,0,0,0.6)
    └── ResultLabel (Label)       anchors=center, horizontal/vertical align=center,
                                  text="GAME OVER"
```

Save the scene.

- [ ] **Step 2: Rewrite `scripts/main.gd` with the full GameManager**

```gdscript
extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var spawner: Node = $EnemySpawner
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var health_label: Label = $UI/HUD/HealthLabel
@onready var kills_label: Label = $UI/HUD/KillsLabel
@onready var time_label: Label = $UI/HUD/TimeLabel
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var result_label: Label = $UI/GameOverPanel/ResultLabel

var kills: int = 0
var survival_time: float = 0.0
var is_game_over: bool = false

func _ready() -> void:
	game_over_panel.visible = false
	spawner.setup(player, enemies)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	enemies.child_entered_tree.connect(_on_enemy_added)
	_on_player_health_changed(player.max_health, player.max_health)
	kills_label.text = "Kills: 0"
	_update_time()

func _process(delta: float) -> void:
	if is_game_over:
		if Input.is_physical_key_pressed(KEY_R):
			get_tree().paused = false
			get_tree().reload_current_scene()
		return
	survival_time += delta
	_update_time()

func _on_enemy_added(node: Node) -> void:
	if node.has_signal("died"):
		node.died.connect(_on_enemy_died)

func _on_enemy_died(_enemy) -> void:
	kills += 1
	kills_label.text = "Kills: %d" % kills

func _on_player_health_changed(current: float, maximum: float) -> void:
	health_label.text = "HP: %d / %d" % [int(ceil(current)), int(maximum)]

func _on_player_died() -> void:
	is_game_over = true
	result_label.text = "GAME OVER\nSurvived: %.1fs\nKills: %d\n\nPress R to restart" % [survival_time, kills]
	game_over_panel.visible = true
	get_tree().paused = true

func _update_time() -> void:
	time_label.text = "Time: %.1fs" % survival_time
```

> **Note:** `Game` root is `process_mode=Always` (Task 1), so `_process`
> keeps running while paused to catch the R key. Gameplay nodes are
> `Pausable`, so they freeze on game over.

- [ ] **Step 3: Verify in engine**

Play `main.tscn`. Diagnostics clean. Observe:
- HUD shows HP, Kills, Time; Time counts up.
- Standing in a group of enemies drains HP visibly.
- When HP hits 0, gameplay freezes, the GameOver panel shows survival time +
  kills, and pressing R restarts a fresh run (HP full, time reset, no enemies).

- [ ] **Step 4: Commit**

```bash
git add scripts/main.gd main.tscn
git commit -m "feat: HUD, contact-damage death flow, game over and restart"
```

---

## Task 4: Data-driven weapon system + projectiles

**Files:**
- Create: `scripts/weapon_def.gd`
- Create: `scripts/weapon_system.gd`
- Create: `scripts/projectile.gd`
- Create: `resources/weapons/homing_missile.tres`
- Create: `resources/weapons/random_missile.tres`
- Create (via engine): `scenes/projectile.tscn`
- Modify (via engine): `scenes/player.tscn` (attach WeaponSystem script + exports)
- Modify: `scripts/main.gd` (call `weapon_system.setup`)

- [ ] **Step 1: Write `scripts/weapon_def.gd`**

```gdscript
extends Resource
class_name WeaponDef

enum TargetingMode { CLOSEST_ENEMY, RANDOM_DIRECTION }

@export var fire_rate: float = 1.0              # seconds between shots
@export var targeting_mode: TargetingMode = TargetingMode.CLOSEST_ENEMY
@export var damage: float = 30.0
@export var projectile_speed: float = 300.0
@export var homing: bool = false
@export var lifetime: float = 2.0
```

- [ ] **Step 2: Write `scripts/projectile.gd`**

```gdscript
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: float = 30.0
var lifetime: float = 2.0
var homing: bool = false
var target: Node2D = null

const TURN_RATE: float = 6.0  # radians/sec steering for homing

func setup(dir: Vector2, spd: float, dmg: float, life: float, home: bool, tgt: Node2D) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	lifetime = life
	homing = home
	target = tgt

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float) -> void:
	if homing:
		if not is_instance_valid(target):
			target = Targeting.closest_enemy(get_tree(), global_position)
		if is_instance_valid(target):
			var desired := (target.global_position - global_position).normalized()
			direction = direction.lerp(desired, TURN_RATE * delta).normalized()
	global_position += direction * speed * delta
	rotation = direction.angle()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
```

- [ ] **Step 3: Write `scripts/weapon_system.gd`**

```gdscript
extends Node

@export var weapons: Array[WeaponDef] = []
@export var projectile_scene: PackedScene

var projectiles_container: Node2D
var _cooldowns: Array[float] = []

func setup(container: Node2D) -> void:
	projectiles_container = container

func _ready() -> void:
	_cooldowns.resize(weapons.size())
	for i in _cooldowns.size():
		_cooldowns[i] = 0.0

func _process(delta: float) -> void:
	if projectiles_container == null:
		return
	for i in weapons.size():
		_cooldowns[i] -= delta
		if _cooldowns[i] <= 0.0:
			_cooldowns[i] = weapons[i].fire_rate
			_fire(weapons[i])

func _fire(weapon: WeaponDef) -> void:
	var origin: Vector2 = get_parent().global_position
	var dir := Vector2.RIGHT
	var target: Node2D = null
	match weapon.targeting_mode:
		WeaponDef.TargetingMode.CLOSEST_ENEMY:
			target = Targeting.closest_enemy(get_tree(), origin)
			if target == null:
				return  # no enemy to home onto; skip this shot
			dir = (target.global_position - origin).normalized()
		WeaponDef.TargetingMode.RANDOM_DIRECTION:
			var a := randf() * TAU
			dir = Vector2(cos(a), sin(a))
	var proj := projectile_scene.instantiate()
	projectiles_container.add_child(proj)
	proj.global_position = origin
	proj.setup(dir, weapon.projectile_speed, weapon.damage, weapon.lifetime, weapon.homing, target)
```

- [ ] **Step 4: Write `resources/weapons/homing_missile.tres`**

```
[gd_resource type="Resource" script_class="WeaponDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/weapon_def.gd" id="1"]

[resource]
script = ExtResource("1")
fire_rate = 1.0
targeting_mode = 0
damage = 30.0
projectile_speed = 300.0
homing = true
lifetime = 3.0
```

- [ ] **Step 5: Write `resources/weapons/random_missile.tres`**

```
[gd_resource type="Resource" script_class="WeaponDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/weapon_def.gd" id="1"]

[resource]
script = ExtResource("1")
fire_rate = 1.0
targeting_mode = 1
damage = 30.0
projectile_speed = 350.0
homing = false
lifetime = 2.0
```

- [ ] **Step 6: Build `scenes/projectile.tscn` via engine MCP**

```
Projectile (Area2D)               script=res://scripts/projectile.gd
                                  collision_layer=8, collision_mask=2, monitoring=true
├── Sprite2D                      (placeholder; Task 5 fills texture)
└── CollisionShape2D              shape=CircleShape2D, radius=6
```

Save the scene.

- [ ] **Step 7: Wire the WeaponSystem node in `scenes/player.tscn` via engine MCP**

- Attach `res://scripts/weapon_system.gd` to the existing `WeaponSystem` node.
- Set exported `weapons` to an array of two resources:
  `[res://resources/weapons/homing_missile.tres, res://resources/weapons/random_missile.tres]`.
- Set exported `projectile_scene` to `res://scenes/projectile.tscn`.

Save the scene.

- [ ] **Step 8: Call `weapon_system.setup` from `scripts/main.gd`**

Add a `weapon_system` reference and set it up. In `scripts/main.gd`, add to the
`@onready` block:

```gdscript
@onready var weapon_system: Node = $Player/WeaponSystem
```

and add this line at the end of `_ready()`:

```gdscript
	weapon_system.setup(projectiles)
```

- [ ] **Step 9: Verify in engine**

Play `main.tscn`. Diagnostics clean. Observe:
- About once per second a projectile flies toward the **closest** enemy and
  curves to follow it (homing), damaging/killing it on contact.
- About once per second a second projectile launches in a **random** direction
  and damages any enemy it strikes.
- Killing an enemy increments the Kills counter (from Task 3).
- With no enemies present, the random missile still fires; the homing one does not.

- [ ] **Step 10: Commit**

```bash
git add scripts/weapon_def.gd scripts/weapon_system.gd scripts/projectile.gd resources/weapons/homing_missile.tres resources/weapons/random_missile.tres scenes/projectile.tscn scenes/player.tscn scripts/main.gd
git commit -m "feat: data-driven weapon system with homing and random projectiles"
```

---

## Task 5: Generated sprites

Replace placeholder visuals with generated art for player, enemy, and projectile.

**Files:**
- Create: `assets/player.png`, `assets/enemy.png`, `assets/projectile.png` (via `summer_generate_image` + import)
- Modify (via engine): `scenes/player.tscn`, `scenes/enemy.tscn`, `scenes/projectile.tscn` (assign textures)

- [ ] **Step 1: Generate the three sprites**

Use `summer_generate_image` for each (top-down, transparent background, simple
readable silhouette):
- Player: "top-down 2D game character, hero with a small weapon, transparent background, clean readable silhouette, centered"
- Enemy: "top-down 2D game monster, menacing, distinct from hero color, transparent background, centered"
- Projectile: "small glowing missile/orb projectile sprite, top-down, transparent background, centered"

Import each into `assets/` (use `summer_import_asset` / the import flow returned
by the generate call).

- [ ] **Step 2: Assign textures via engine MCP**

- `scenes/player.tscn` → `Sprite2D.texture = res://assets/player.png`
- `scenes/enemy.tscn` → `Sprite2D.texture = res://assets/enemy.png`
- `scenes/projectile.tscn` → `Sprite2D.texture = res://assets/projectile.png`

Scale each Sprite2D so it roughly matches its collision radius (player/enemy
~32px across, projectile ~12px). Save all three scenes.

- [ ] **Step 3: Verify in engine**

Play `main.tscn`. Diagnostics clean. Observe: player, enemies, and projectiles
render with their sprites at sensible sizes; hero and enemy are visually
distinct.

- [ ] **Step 4: Commit**

```bash
git add assets/ scenes/player.tscn scenes/enemy.tscn scenes/projectile.tscn
git commit -m "feat: generated sprites for player, enemy, and projectile"
```

---

## Task 6: Full playtest pass & tuning

**Files:** (tuning edits only, as needed)

- [ ] **Step 1: Run the full verification checklist (from the spec, section 9)**

Play `main.tscn` and confirm each item, capturing a screenshot or two:
1. Player moves in all 8 directions; camera stays centered.
2. Player cannot leave the world bounds.
3. Enemies spawn ~1/sec, never on the player, and chase.
4. Enemies overlap each other (no enemy-enemy collision).
5. Touching enemies drains health; 0 HP → Game Over.
6. Game Over shows survival time + kills; R restarts.
7. Homing missile hits the closest enemy; random missile fires randomly and
   damages enemies on contact.
8. Sprites render for player, enemies, projectiles.

- [ ] **Step 2: Tune if needed**

If anything feels off (too easy/hard, too fast/slow), adjust the exported
values on `Player`, `Enemy`/`scenes/enemy.tscn`, `EnemySpawner`, or the two
`.tres` weapon configs. Re-verify the affected behavior.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "chore: final playtest pass and tuning"
```

---

## Self-review notes (author)

- **Spec coverage:** movement/camera/bounds (T1), spawning/chase/no-enemy-collision (T2), contact damage/health/death/game-over/restart/HUD (T3), data-driven weapons + both projectiles (T4), generated sprites (T5), full playtest (T6). All spec sections 1–9 mapped.
- **Type consistency:** `take_damage(amount)` on both Player and Enemy; `Enemy.contact_damage`, `Enemy.died(enemy)`; `Targeting.closest_enemy(tree, from)` used by both weapon_system and projectile; `WeaponDef.TargetingMode {CLOSEST_ENEMY, RANDOM_DIRECTION}`; `proj.setup(dir, spd, dmg, life, home, tgt)` matches caller; `weapon_system.setup(container)` / `spawner.setup(player, container)` match `main.gd` calls.
- **Process modes:** root `Always`, gameplay nodes `Pausable` — required for restart-while-paused; called out in T1/T3.
