extends CharacterBody2D

signal died(enemy)

const DAMAGE_NUMBER := preload("res://scripts/damage_number.gd")
const DEATH_BURST := preload("res://scripts/death_burst.gd")
const KNOCK_STRENGTH: float = 260.0
const KNOCK_DECAY: float = 900.0  # how fast the jut fades (units/sec)

@export var speed: float = 80.0
@export var max_health: float = 30.0
@export var contact_damage: float = 20.0  # (unused now; player takes a flat hit) kept for compat
@export var rotates: bool = true  # true: face movement (bats); false: stay upright + walk anim (giant)

@onready var visual: CanvasItem = $Visual

var health: float
var target: Node2D
var _knockback: Vector2 = Vector2.ZERO

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	# Own copy of the flash material so each enemy flashes independently.
	if visual.material != null:
		visual.material = visual.material.duplicate()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var dir := (target.global_position - global_position).normalized()
	if rotates:
		# Face the player (bat sprite points up, so +90 deg).
		rotation = dir.angle() + PI / 2.0
	velocity = dir * speed + _knockback
	move_and_slide()
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCK_DECAY * delta)

func take_damage(amount: float, from_pos: Vector2 = Vector2.INF) -> void:
	if health <= 0.0:
		return
	health -= amount
	_spawn_damage_number(amount)
	_flash()
	if from_pos != Vector2.INF:
		var away := global_position - from_pos
		if away.length() > 0.01:
			_knockback = away.normalized() * KNOCK_STRENGTH
	if health <= 0.0:
		_spawn_death_burst()
		died.emit(self)
		queue_free()

func _flash() -> void:
	if visual.material == null:
		return
	visual.material.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(_set_flash, 1.0, 0.0, 0.12)

func _set_flash(v: float) -> void:
	if visual.material != null:
		visual.material.set_shader_parameter("flash", v)

func _spawn_damage_number(amount: float) -> void:
	var num := DAMAGE_NUMBER.new()
	get_parent().add_child(num)
	num.global_position = global_position
	num.show_damage(int(round(amount)))

func _spawn_death_burst() -> void:
	var burst := DEATH_BURST.new()
	get_parent().add_child(burst)
	burst.global_position = global_position
