extends Resource
class_name WeaponDef

enum TargetingMode { CLOSEST_ENEMY, RANDOM_DIRECTION }

@export var fire_rate: float = 1.0              # seconds between shots
@export var targeting_mode: TargetingMode = TargetingMode.CLOSEST_ENEMY
@export var damage: float = 30.0
@export var projectile_speed: float = 300.0
@export var homing: bool = false
@export var lifetime: float = 2.0
