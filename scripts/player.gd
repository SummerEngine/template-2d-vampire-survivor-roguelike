extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal died
signal took_damage

@export var speed: float = 200.0
@export var max_health: float = 100.0
@export var world_half_size: float = 1500.0  # world spans -1500..1500 on each axis
@export var body_radius: float = 16.0
@export var base_regen: float = 2.0  # HP per second, always on
@export var contact_hit_damage: float = 30.0  # damage per contact instance
@export var invuln_time: float = 2.0  # i-frames after a hit

var health: float
var bonus_regen: float = 0.0  # added by level-up upgrades
var _invuln_timer: float = 0.0

@onready var hurtbox: Area2D = $Hurtbox
@onready var magnet: Area2D = $Magnet
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)
	magnet.area_entered.connect(_on_magnet_area_entered)

func _on_magnet_area_entered(area: Area2D) -> void:
	if area.is_in_group("xp_gems"):
		area.attract_to(self)

func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A): dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): dir.x += 1.0
	# Pick a directional walk animation by dominant axis (idle when stopped).
	var desired_anim := "idle"
	if dir != Vector2.ZERO:
		if abs(dir.x) > abs(dir.y):
			desired_anim = "walk_right"
			anim.flip_h = dir.x < 0.0  # mirror the right set for leftward movement
		else:
			anim.flip_h = false
			desired_anim = "walk_down" if dir.y > 0.0 else "walk_up"
	else:
		anim.flip_h = false
	if anim.animation != desired_anim:
		anim.play(desired_anim)
	velocity = dir.normalized() * speed
	move_and_slide()
	# Belt-and-suspenders clamp in case the player slips past a wall.
	var limit := world_half_size - body_radius
	global_position = global_position.clamp(Vector2(-limit, -limit), Vector2(limit, limit))

func _process(delta: float) -> void:
	if _invuln_timer > 0.0:
		# Invincible: blink the sprite and count down; no contact damage.
		_invuln_timer -= delta
		anim.modulate.a = 0.3 if fmod(_invuln_timer, 0.2) < 0.1 else 1.0
		if _invuln_timer <= 0.0:
			anim.modulate.a = 1.0
	elif health > 0.0:
		# Take one 30-damage instance if any enemy is touching, then go invincible.
		for b in hurtbox.get_overlapping_bodies():
			if b.is_in_group("enemies"):
				take_damage(contact_hit_damage)
				took_damage.emit()
				_invuln_timer = invuln_time
				break
	# Slow health regeneration (baseline + upgrades), only while alive.
	if health > 0.0 and health < max_health:
		health = min(max_health, health + (base_regen + bonus_regen) * delta)
		health_changed.emit(health, max_health)

func add_max_health(amount: float) -> void:
	max_health += amount
	health_changed.emit(health, max_health)

func add_regen(amount: float) -> void:
	bonus_regen += amount

func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = max(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		died.emit()
