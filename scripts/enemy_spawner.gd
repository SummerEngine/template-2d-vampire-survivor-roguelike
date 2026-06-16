extends Node

@export var spawn_interval: float = 1.0
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

func setup(p: Node2D, container: Node2D) -> void:
	player = p
	enemies_container = container

## Make enemies spawn a bit more often (lower interval), with a floor.
func increase_spawn_rate(factor: float) -> void:
	spawn_interval = max(min_spawn_interval, spawn_interval * factor)

func _process(delta: float) -> void:
	if not is_instance_valid(player) or enemies_container == null:
		return
	_timer += delta
	while _timer >= spawn_interval:
		_timer -= spawn_interval
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
