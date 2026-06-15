extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: float = 30.0
var lifetime: float = 2.0
var homing: bool = false
var target: Node2D = null
var rotation_offset: float = 0.0

const TURN_RATE: float = 6.0  # radians/sec steering for homing

## Configure from a WeaponDef. Call BEFORE add_child so _ready() sees final
## values (lifetime timer, etc.). $Sprite2D resolves on the instanced scene
## even before it enters the tree.
func setup(dir: Vector2, tgt: Node2D, weapon: WeaponDef) -> void:
	direction = dir.normalized()
	speed = weapon.projectile_speed
	damage = weapon.damage
	lifetime = weapon.lifetime
	homing = weapon.homing
	target = tgt
	rotation_offset = deg_to_rad(weapon.projectile_rotation_offset_deg)
	if weapon.projectile_texture != null:
		$Sprite2D.texture = weapon.projectile_texture
	$Sprite2D.scale = Vector2(weapon.projectile_scale, weapon.projectile_scale)

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
	rotation = direction.angle() + rotation_offset

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
