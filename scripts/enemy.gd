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
	# Rotate to face the player. The bat sprite points "up" (-Y), so add 90 deg.
	rotation = dir.angle() + PI / 2.0
	move_and_slide()

func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health -= amount
	if health <= 0.0:
		died.emit(self)
		queue_free()
