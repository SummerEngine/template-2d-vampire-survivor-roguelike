extends Node

@export var weapons: Array[WeaponDef] = []
@export var projectile_scene: PackedScene

var projectiles_container: Node2D
var _cooldowns: Array[float] = []

func setup(container: Node2D) -> void:
	projectiles_container = container

func _ready() -> void:
	# Self-wire defaults so the system works without editor-set exports.
	if weapons.is_empty():
		weapons = [
			preload("res://resources/weapons/homing_missile.tres"),
			preload("res://resources/weapons/random_missile.tres"),
		]
	if projectile_scene == null:
		projectile_scene = preload("res://scenes/projectile.tscn")
	# Duplicate the WeaponDefs so runtime upgrades don't mutate the shared
	# (cached) .tres resources, which would otherwise persist across restarts.
	for i in weapons.size():
		weapons[i] = weapons[i].duplicate()
	_cooldowns.resize(weapons.size())
	for i in _cooldowns.size():
		_cooldowns[i] = 0.0

## Multiply the fire rate (lower interval = faster) of every weapon whose
## homing flag matches. Used by the level-up upgrades.
func scale_fire_rate(homing_flag: bool, factor: float) -> void:
	for w in weapons:
		if w.homing == homing_flag:
			w.fire_rate *= factor

## Enable/grow explosion radius on matching weapons. First call sets `base`,
## later calls add `increment`.
func add_explosion(homing_flag: bool, base: float, increment: float) -> void:
	for w in weapons:
		if w.homing == homing_flag:
			if w.explosion_radius <= 0.0:
				w.explosion_radius = base
			else:
				w.explosion_radius += increment

## Add wall bounces to matching weapons.
func increase_bounce(homing_flag: bool, amount: int) -> void:
	for w in weapons:
		if w.homing == homing_flag:
			w.bounce_count += amount

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
	proj.setup(dir, target, weapon)
	projectiles_container.add_child(proj)
	proj.global_position = origin
