extends Node2D

## Holds the player's orbiting saws. Starts empty; add_saw() adds one and
## re-spaces them evenly, each at a slightly larger radius. Saws orbit at
## different (and overall slightly slower) speeds so they visibly desync, and a
## thin tether line links each saw back to the player. Where two saws happen to
## overlap the same enemy, the damage stacks (see saw.gd's global-frame gating).

const SAW_SCENE := preload("res://scenes/saw.tscn")

@export var base_radius: float = 70.0
@export var radius_step: float = 22.0
@export var orbit_speed: float = 2.6  # base rad/sec; each saw's actual speed varies below
@export var damage_per_sec: float = 50.0

@export var tether_width: float = 4.0
@export var tether_color: Color = Color(0.55, 0.45, 0.3, 0.9)  # visible rope/chain tone

var _saws: Array = []
var _tethers: Array = []

func add_saw() -> void:
	var saw := SAW_SCENE.instantiate()
	saw.z_index = 2  # blade stays above the tether rope
	add_child(saw)
	_saws.append(saw)
	# A rope/line that shows the saw is tethered to the player. z_index must be
	# >= 0: a negative z draws it BEHIND the ground sprites (z 0) and it vanishes.
	var line := Line2D.new()
	line.width = tether_width
	line.default_color = tether_color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = 1  # above the ground, below the blade
	add_child(line)
	_tethers.append(line)
	_reconfigure()

func _reconfigure() -> void:
	var n := _saws.size()
	for i in n:
		var radius := base_radius + i * radius_step
		var start_angle := float(i) / float(n) * TAU
		# Each successive saw is a bit slower, so no two share an orbit speed.
		var speed := orbit_speed * maxf(0.5, 1.0 - 0.12 * i)
		_saws[i].configure(radius, start_angle, speed, damage_per_sec)

func _process(_delta: float) -> void:
	# Stretch each tether from the player (local origin) out to its saw.
	for i in _saws.size():
		_tethers[i].points = PackedVector2Array([Vector2.ZERO, _saws[i].position])
