extends Area2D

## A saw blade that orbits the player and deals constant contact damage to
## enemies it overlaps. Configured by SawSystem. Drawn procedurally (placeholder
## art until a real sprite is generated).

const SPIN_SPEED: float = 12.0  # visual blade spin, rad/sec

var orbit_radius: float = 70.0
var angle: float = 0.0
var orbit_speed: float = 3.0   # rad/sec around the player
var hit_damage: float = 10.0
var hit_interval: float = 0.2  # apply damage to overlapping enemies this often

var _tick: float = 0.0

func configure(p_radius: float, p_angle: float, p_speed: float, p_damage: float, p_interval: float) -> void:
	orbit_radius = p_radius
	angle = p_angle
	orbit_speed = p_speed
	hit_damage = p_damage
	hit_interval = p_interval
	position = Vector2.from_angle(angle) * orbit_radius
	queue_redraw()

func _physics_process(delta: float) -> void:
	angle += orbit_speed * delta
	position = Vector2.from_angle(angle) * orbit_radius
	rotation += SPIN_SPEED * delta
	_tick += delta
	if _tick >= hit_interval:
		_tick -= hit_interval
		for b in get_overlapping_bodies():
			if b.is_in_group("enemies") and b.has_method("take_damage"):
				b.take_damage(hit_damage, global_position)

func _draw() -> void:
	var r := 18.0
	var teeth := 10
	# saw teeth (dark) poking out past the body
	for i in teeth:
		var a0 := float(i) / teeth * TAU
		var a1 := (float(i) + 0.5) / teeth * TAU
		var a2 := (float(i) + 1.0) / teeth * TAU
		draw_colored_polygon(PackedVector2Array([
			Vector2.from_angle(a0) * (r * 0.78),
			Vector2.from_angle(a1) * r,
			Vector2.from_angle(a2) * (r * 0.78),
		]), Color(0.5, 0.52, 0.58))
	draw_circle(Vector2.ZERO, r * 0.8, Color(0.74, 0.76, 0.82))   # body
	draw_circle(Vector2.ZERO, r * 0.5, Color(0.58, 0.6, 0.66))    # inner
	draw_circle(Vector2.ZERO, 5.0, Color(0.25, 0.26, 0.3))        # hub
