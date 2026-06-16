extends CPUParticles2D

## One-shot purple shard burst for enemy death. Position via global_position;
## it emits once and frees itself.

func _ready() -> void:
	one_shot = true
	explosiveness = 1.0
	amount = 14
	lifetime = 0.5
	direction = Vector2(0, -1)
	spread = 180.0
	gravity = Vector2.ZERO
	initial_velocity_min = 120.0
	initial_velocity_max = 240.0
	scale_amount_min = 2.0
	scale_amount_max = 4.0
	color = Color(0.6, 0.2, 0.85)
	z_index = 50
	finished.connect(queue_free)
	emitting = true
