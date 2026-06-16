extends Node2D

## Holds the player's orbiting saws. Starts empty; add_saw() adds one and
## re-spaces them evenly, each successive saw at a slightly larger radius.

const SAW_SCENE := preload("res://scenes/saw.tscn")

@export var base_radius: float = 70.0
@export var radius_step: float = 22.0
@export var orbit_speed: float = 3.0
@export var hit_damage: float = 10.0
@export var hit_interval: float = 0.2

var _saws: Array = []

func add_saw() -> void:
	var saw := SAW_SCENE.instantiate()
	add_child(saw)
	_saws.append(saw)
	_reconfigure()

func _reconfigure() -> void:
	var n := _saws.size()
	for i in n:
		var radius := base_radius + i * radius_step
		var start_angle := float(i) / float(n) * TAU
		_saws[i].configure(radius, start_angle, orbit_speed, hit_damage, hit_interval)
