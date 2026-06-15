extends Area2D

## An XP pickup. Sits still until the player's magnet calls attract_to(),
## then flies to the player and is collected.

@export var xp_value: int = 1
@export var fly_speed: float = 500.0

const COLLECT_DIST: float = 16.0

var _target: Node2D = null

func _ready() -> void:
	add_to_group("xp_gems")

func attract_to(p: Node2D) -> void:
	_target = p

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	global_position = global_position.move_toward(_target.global_position, fly_speed * delta)
	if global_position.distance_to(_target.global_position) <= COLLECT_DIST:
		get_tree().call_group("level_system", "add_xp", xp_value)
		queue_free()
