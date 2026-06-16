extends Node

@export var spawn_interval: float = 1.0
@export var min_spawn_interval: float = 0.2  # floor so it never spams every frame
@export var min_spawn_distance: float = 600.0
@export var max_spawn_distance: float = 1000.0
@export var world_half_size: float = 1500.0
@export var enemy_scene: PackedScene

var player: Node2D
var enemies_container: Node2D
var _timer: float = 0.0

func _ready() -> void:
	# Self-wire default so the spawner works without an editor-set export.
	if enemy_scene == null:
		enemy_scene = preload("res://scenes/enemy.tscn")

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

func _spawn() -> void:
	var angle := randf() * TAU
	var dist := randf_range(min_spawn_distance, max_spawn_distance)
	var pos := player.global_position + Vector2(cos(angle), sin(angle)) * dist
	var limit := world_half_size - 32.0
	pos = pos.clamp(Vector2(-limit, -limit), Vector2(limit, limit))
	var enemy := enemy_scene.instantiate()
	enemy.target = player
	# Position BEFORE adding to the tree so the enemy never registers at the
	# world origin (where the player starts) and hits the player on spawn.
	# Enemies container sits at the origin, so local position == world position.
	enemy.position = pos
	enemies_container.add_child(enemy)
