extends Resource
class_name WeaponDef

enum TargetingMode { CLOSEST_ENEMY, RANDOM_DIRECTION }

@export var fire_rate: float = 1.0              # seconds between shots
@export var targeting_mode: TargetingMode = TargetingMode.CLOSEST_ENEMY
@export var damage: float = 30.0
@export var projectile_speed: float = 300.0
@export var homing: bool = false
@export var lifetime: float = 2.0

# Per-weapon projectile visuals. If projectile_texture is null the projectile
# scene's default sprite is kept.
@export var projectile_texture: Texture2D
@export var projectile_scale: float = 0.06
@export var projectile_rotation_offset_deg: float = 0.0
