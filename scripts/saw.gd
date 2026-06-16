extends Area2D

## A saw blade that orbits the player and deals continuous contact damage to
## enemies it overlaps. Damage is applied EVERY frame (no tick sampling, so it
## never misses a fast sweep past an enemy) and uses a feedback-free hit (no
## knockback, no damage numbers) since it hits constantly. Drawn procedurally.

const SPIN_SPEED: float = 12.0  # visual blade spin, rad/sec

var orbit_radius: float = 70.0
var angle: float = 0.0
var orbit_speed: float = 3.0        # rad/sec around the player
var damage_per_sec: float = 50.0    # continuous DPS to overlapping enemies

func configure(p_radius: float, p_angle: float, p_speed: float, p_dps: float) -> void:
	orbit_radius = p_radius
	angle = p_angle
	orbit_speed = p_speed
	damage_per_sec = p_dps
	position = Vector2.from_angle(angle) * orbit_radius

func _physics_process(delta: float) -> void:
	angle += orbit_speed * delta
	position = Vector2.from_angle(angle) * orbit_radius
	rotation += SPIN_SPEED * delta
	var dmg := damage_per_sec * delta
	for b in get_overlapping_bodies():
		if b.is_in_group("enemies") and b.has_method("take_damage_continuous"):
			# Accumulates damage; enemy pops a number ~every 0.3s. No knockback.
			b.take_damage_continuous(dmg)
