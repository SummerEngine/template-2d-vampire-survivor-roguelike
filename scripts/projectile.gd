extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: float = 30.0
var lifetime: float = 2.0
var homing: bool = false
var target: Node2D = null

const TURN_RATE: float = 6.0  # radians/sec steering for homing

func setup(dir: Vector2, spd: float, dmg: float, life: float, home: bool, tgt: Node2D) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	lifetime = life
	homing = home
	target = tgt

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float) -> void:
	if homing:
		if not is_instance_valid(target):
			target = Targeting.closest_enemy(get_tree(), global_position)
		if is_instance_valid(target):
			var desired := (target.global_position - global_position).normalized()
			direction = direction.lerp(desired, TURN_RATE * delta).normalized()
	global_position += direction * speed * delta
	rotation = direction.angle()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
