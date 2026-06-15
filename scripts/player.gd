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
