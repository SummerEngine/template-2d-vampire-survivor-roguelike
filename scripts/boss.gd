extends "res://scripts/enemy.gd"

## Fully-automated boss. Stalks the player and, on a cooldown, picks one of three
## telegraphed attacks based on range: CHARGE (dash), JUMP (leap + shockwave),
## BARRAGE (rings of fireballs). Reuses enemy.gd for
## health / hit-flash / damage numbers / death / the "died" signal.
##
## "Animation" is a static pose texture per state (idle / attack / cast / jump)
## driven by procedural squash-stretch, waddle, hop and lunge on the Visual node,
## so the boss reads as alive without per-frame sprite art.

const TEX_IDLE := preload("res://assets/boss_idle.png")
const TEX_ATTACK := preload("res://assets/boss_attack.png")
const TEX_CAST := preload("res://assets/boss_cast.png")
const TEX_JUMP := preload("res://assets/boss_jump.png")
const PROJECTILE := preload("res://scenes/boss_projectile.tscn")
const SHOCKWAVE := preload("res://scripts/boss_shockwave.gd")
const LAND_MARKER := preload("res://scripts/boss_land_marker.gd")
const CHARGE_TELL := preload("res://scripts/boss_charge_tell.gd")

enum S { STALK, CHARGE_WIND, CHARGE, JUMP_WIND, JUMP_AIR, JUMP_LAND, BARRAGE, RECOVER }

@export var stalk_speed: float = 60.0
@export var move_cooldown: float = 2.0      # rest between specials

@export var charge_wind: float = 0.6
@export var charge_dur: float = 0.45
@export var charge_speed: float = 600.0

@export var jump_wind: float = 0.5
@export var jump_air: float = 0.6
@export var jump_land_time: float = 0.4
@export var jump_max_dist: float = 600.0
@export var jump_damage: float = 40.0
@export var jump_shock_radius: float = 230.0

@export var barrage_wind: float = 0.5
@export var barrage_waves: int = 3
@export var barrage_per_wave: int = 10
@export var barrage_wave_gap: float = 0.35
@export var projectile_speed: float = 300.0
@export var projectile_damage: float = 28.0

@export var recover_time: float = 0.6
@export var world_half_size: float = 1500.0

@onready var spr: Sprite2D = $Visual

var base_scale: Vector2 = Vector2.ONE
var _state: int = S.STALK
var _t: float = 0.0
var _cool: float = 0.0
var _anim: float = 0.0

var _charge_dir: Vector2 = Vector2.ZERO
var _jump_from: Vector2 = Vector2.ZERO
var _jump_to: Vector2 = Vector2.ZERO
var _wave: int = 0
var _land_marker: Node2D = null
var _charge_tell: Node2D = null

func _ready() -> void:
	super()  # enemy._ready: health, "enemies" group, own flash material
	add_to_group("boss")
	base_scale = spr.scale
	_cool = 1.0  # let the spawn/roar read before the first special
	_set_tex(TEX_IDLE)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		return
	match _state:
		S.STALK: _do_stalk(delta)
		S.CHARGE_WIND: _do_charge_wind(delta)
		S.CHARGE: _do_charge(delta)
		S.JUMP_WIND: _do_jump_wind(delta)
		S.JUMP_AIR: _do_jump_air(delta)
		S.JUMP_LAND: _do_jump_land(delta)
		S.BARRAGE: _do_barrage(delta)
		S.RECOVER: _do_recover(delta)
	move_and_slide()

# ---------------------------------------------------------------- STALK / pick

func _do_stalk(delta: float) -> void:
	_set_tex(TEX_IDLE)
	var to := target.global_position - global_position
	velocity = to.normalized() * stalk_speed
	_walk_anim(delta)
	_cool -= delta
	if _cool <= 0.0:
		_choose_move(to.length())

func _choose_move(dist: float) -> void:
	var opts: Array = ["jump"]  # always available — also a gap closer
	if dist <= 650.0:
		opts.append("charge")
	if dist >= 220.0:
		opts.append("barrage")
		opts.append("barrage")
	match opts[randi() % opts.size()]:
		"charge": _enter_charge()
		"jump": _enter_jump()
		"barrage": _enter_barrage()

func _walk_anim(delta: float) -> void:
	_anim += delta
	var breathe := 0.04 * sin(_anim * 3.0)
	spr.scale = base_scale * Vector2(1.0 - breathe, 1.0 + breathe)
	spr.position.y = -absf(sin(_anim * 7.0)) * 5.0
	spr.rotation = deg_to_rad(3.0 * sin(_anim * 3.5))

# ---------------------------------------------------------------- CHARGE

func _enter_charge() -> void:
	_state = S.CHARGE_WIND
	_t = charge_wind
	_set_tex(TEX_ATTACK)
	# Lock the dash direction up front and show a beam down that line so the
	# player can sidestep it.
	_charge_dir = (target.global_position - global_position).normalized()
	_charge_tell = CHARGE_TELL.new()
	add_child(_charge_tell)
	_charge_tell.setup(_charge_dir, charge_speed * charge_dur)

func _do_charge_wind(delta: float) -> void:
	velocity = Vector2.ZERO
	_t -= delta
	var k := 1.0 - _t / charge_wind
	spr.scale = base_scale * Vector2(1.0 + 0.15 * k, 1.0 - 0.12 * k)  # crouch back
	if _t <= 0.0:
		_clear_charge_tell()
		spr.scale = base_scale
		_state = S.CHARGE
		_t = charge_dur

func _clear_charge_tell() -> void:
	if is_instance_valid(_charge_tell):
		_charge_tell.queue_free()
	_charge_tell = null

func _do_charge(delta: float) -> void:
	velocity = _charge_dir * charge_speed
	spr.scale = base_scale * Vector2(1.12, 0.9)  # stretch in motion
	_t -= delta
	if _t <= 0.0:
		_enter_recover()

# ---------------------------------------------------------------- JUMP

func _enter_jump() -> void:
	_state = S.JUMP_WIND
	_t = jump_wind
	_set_tex(TEX_JUMP)
	# Lock the landing spot NOW (at the start of the wind-up), not at take-off, so
	# the player has the whole wind-up + air time to walk out of the marked zone.
	var to: Vector2 = target.global_position
	var off: Vector2 = to - global_position
	if off.length() > jump_max_dist:
		to = global_position + off.normalized() * jump_max_dist
	var lim := world_half_size - 80.0
	_jump_to = to.clamp(Vector2(-lim, -lim), Vector2(lim, lim))
	_land_marker = LAND_MARKER.new()
	get_parent().add_child(_land_marker)
	_land_marker.global_position = _jump_to
	_land_marker.setup(jump_shock_radius)

func _do_jump_wind(delta: float) -> void:
	velocity = Vector2.ZERO
	_t -= delta
	var k := 1.0 - _t / jump_wind
	spr.scale = base_scale * Vector2(1.0 + 0.22 * k, 1.0 - 0.2 * k)  # deep squash
	if _t <= 0.0:
		_jump_from = global_position
		_state = S.JUMP_AIR
		_t = jump_air

func _do_jump_air(delta: float) -> void:
	_t -= delta
	var p := clampf(1.0 - _t / jump_air, 0.0, 1.0)
	global_position = _jump_from.lerp(_jump_to, p)
	velocity = Vector2.ZERO
	spr.position = Vector2(0, -sin(p * PI) * 150.0)  # visual hop arc
	spr.scale = base_scale * Vector2(0.9, 1.14)      # stretched airborne
	if _t <= 0.0:
		global_position = _jump_to
		spr.position = Vector2.ZERO
		_land()

func _land() -> void:
	_state = S.JUMP_LAND
	_t = jump_land_time
	spr.scale = base_scale * Vector2(1.3, 0.72)  # impact squash
	if is_instance_valid(_land_marker):
		_land_marker.queue_free()
	_land_marker = null
	var sw := SHOCKWAVE.new()
	get_parent().add_child(sw)
	sw.global_position = global_position
	sw.setup(target, jump_damage, jump_shock_radius)
	get_tree().call_group("game", "shake", 16.0, 0.4)

func _do_jump_land(delta: float) -> void:
	velocity = Vector2.ZERO
	spr.scale = spr.scale.move_toward(base_scale, delta * 3.0)
	_t -= delta
	if _t <= 0.0:
		spr.scale = base_scale
		_enter_recover()

# ---------------------------------------------------------------- BARRAGE

func _enter_barrage() -> void:
	_state = S.BARRAGE
	_set_tex(TEX_CAST)
	_wave = 0
	_t = barrage_wind

func _do_barrage(delta: float) -> void:
	velocity = Vector2.ZERO
	_t -= delta
	if _wave == 0:
		# Charging throb (no white flash): swell and quiver while winding up.
		var k := clampf(1.0 - _t / barrage_wind, 0.0, 1.0)
		var swell := 1.0 + 0.10 * k + 0.03 * sin(_t * 30.0)
		spr.scale = base_scale * swell
	if _t <= 0.0:
		if _wave < barrage_waves:
			_fire_wave(_wave)
			_wave += 1
			_t = barrage_wave_gap
		else:
			_enter_recover()

func _fire_wave(i: int) -> void:
	var n := barrage_per_wave
	var off := float(i) * (TAU / float(n)) / float(barrage_waves)  # rotate rings to fill gaps
	for k in n:
		var a := float(k) * TAU / float(n) + off
		var dir := Vector2(cos(a), sin(a))
		var pr := PROJECTILE.instantiate()
		get_parent().add_child(pr)
		pr.global_position = global_position + dir * 70.0
		pr.setup(dir, projectile_speed, projectile_damage)
	spr.scale = base_scale * Vector2(1.1, 1.1)  # recoil pop

# ---------------------------------------------------------------- RECOVER

func _enter_recover() -> void:
	_state = S.RECOVER
	_t = recover_time
	_set_tex(TEX_IDLE)
	spr.rotation = 0.0

func _do_recover(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 1400.0 * delta)
	spr.scale = spr.scale.move_toward(base_scale, delta * 2.5)
	spr.position = spr.position.move_toward(Vector2.ZERO, delta * 500.0)
	_t -= delta
	if _t <= 0.0:
		spr.scale = base_scale
		spr.position = Vector2.ZERO
		_cool = move_cooldown
		_state = S.STALK

# ---------------------------------------------------------------- helpers

func _set_tex(tex: Texture2D) -> void:
	if spr.texture != tex:
		spr.texture = tex
