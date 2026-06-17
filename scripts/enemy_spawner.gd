extends Node

@export var start_interval: float = 1.5      # spawn cadence (sec) at level 1; higher = calmer early game
@export var decay_per_level: float = 0.887   # per-level multiplier; tuned so ~level 12 matches the old pace (~0.40s)
@export var min_spawn_interval: float = 0.2  # floor so it never spams every frame
@export var min_spawn_distance: float = 600.0
@export var max_spawn_distance: float = 1000.0
@export var world_half_size: float = 1500.0

const NORMAL := preload("res://scenes/enemy.tscn")
const FAST := preload("res://scenes/enemy_fast.tscn")
const GIANT := preload("res://scenes/enemy_giant.tscn")

var player: Node2D
var enemies_container: Node2D
var _timer: float = 0.0
var spawn_interval: float = 1.5  # live cadence, recomputed each level by set_level()
var rate_scale: float = 1.0  # <1 spawns less often (boss fights throttle this)

func setup(p: Node2D, container: Node2D) -> void:
	player = p
	enemies_container = container
	set_level(1)

## Recompute the spawn cadence from the player's level. Curve is designed so the
## early game (lv 1-5) is noticeably calmer than the old 0.92-per-level ramp,
## then converges back onto the original pace (~0.40s) by about level 12 and
## keeps tightening toward min_spawn_interval after that.
func set_level(level: int) -> void:
	var lvl := maxi(1, level)
	spawn_interval = maxf(min_spawn_interval, start_interval * pow(decay_per_level, lvl - 1))

## Temporarily scale how often enemies spawn (e.g. 0.2 = 20% while a boss is up).
func set_rate_scale(s: float) -> void:
	rate_scale = maxf(0.01, s)

func _process(delta: float) -> void:
	if not is_instance_valid(player) or enemies_container == null:
		return
	var effective: float = spawn_interval / rate_scale
	_timer += delta
	while _timer >= effective:
		_timer -= effective
		_spawn()

## 10% giant, 25% fast, 65% normal.
func _pick_scene() -> PackedScene:
	var r := randf()
	if r < 0.10:
		return GIANT
	if r < 0.35:
		return FAST
	return NORMAL

func _spawn() -> void:
	var angle := randf() * TAU
	var dist := randf_range(min_spawn_distance, max_spawn_distance)
	var pos := player.global_position + Vector2(cos(angle), sin(angle)) * dist
	var limit := world_half_size - 32.0
	pos = pos.clamp(Vector2(-limit, -limit), Vector2(limit, limit))
	var enemy := _pick_scene().instantiate()
	enemy.target = player
	# Position BEFORE adding to the tree so the enemy never registers at the
	# world origin (where the player starts) and hits the player on spawn.
	enemy.position = pos
	enemies_container.add_child(enemy)
