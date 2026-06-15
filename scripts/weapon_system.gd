extends Node

@export var weapons: Array[WeaponDef] = []
@export var projectile_scene: PackedScene

var projectiles_container: Node2D
var _cooldowns: Array[float] = []

func setup(container: Node2D) -> void:
	projectiles_container = container

func _ready() -> void:
	_cooldowns.resize(weapons.size())
	for i in _cooldowns.size():
		_cooldowns[i] = 0.0

func _process(delta: float) -> void:
	if projectiles_container == null:
		return
	for i in weapons.size():
		_cooldowns[i] -= delta
		if _cooldowns[i] <= 0.0:
			_cooldowns[i] = weapons[i].fire_rate
			_fire(weapons[i])

func _fire(weapon: WeaponDef) -> void:
	var origin: Vector2 = get_parent().global_position
	var dir := Vector2.RIGHT
	var target: Node2D = null
	match weapon.targeting_mode:
		WeaponDef.TargetingMode.CLOSEST_ENEMY:
			target = Targeting.closest_enemy(get_tree(), origin)
			if target == null:
				return  # no enemy to home onto; skip this shot
			dir = (target.global_position - origin).normalized()
		WeaponDef.TargetingMode.RANDOM_DIRECTION:
			var a := randf() * TAU
			dir = Vector2(cos(a), sin(a))
	var proj := projectile_scene.instantiate()
	projectiles_container.add_child(proj)
	proj.global_position = origin
	proj.setup(dir, weapon.projectile_speed, weapon.damage, weapon.lifetime, weapon.homing, target)
