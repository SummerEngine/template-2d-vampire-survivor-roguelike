extends Node2D

const GEM_SCENE := preload("res://scenes/xp_gem.tscn")

# Pool of level-up upgrades. Each level-up shows 3 random distinct ones.
const UPGRADES := [
	{"id": "missiles", "label": "More Missiles (faster arrows)"},
	{"id": "homing", "label": "More Homing Orbs (faster orbs)"},
	{"id": "speed", "label": "More Movement Speed"},
	{"id": "maxhp", "label": "+50 Max HP"},
	{"id": "xprate", "label": "+1 XP per second"},
	{"id": "regen", "label": "Faster Health Regen"},
	{"id": "explode", "label": "Explosive Missiles (bigger blast)"},
	{"id": "bounce", "label": "Bouncing Missiles (+1 bounce)"},
]

@onready var player: CharacterBody2D = $Player
@onready var spawner: Node = $EnemySpawner
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var pickups: Node2D = $Pickups
@onready var weapon_system: Node = $Player/WeaponSystem
@onready var level_system: Node = $LevelSystem

@onready var health_label: Label = $UI/HUD/HealthLabel
@onready var health_bar: ProgressBar = $UI/HUD/HealthBar
@onready var kills_label: Label = $UI/HUD/KillsLabel
@onready var time_label: Label = $UI/HUD/TimeLabel
@onready var level_label: Label = $UI/HUD/LevelLabel
@onready var xp_bar: ProgressBar = $UI/HUD/XPBar
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var result_label: Label = $UI/GameOverPanel/ResultLabel
@onready var level_up_panel: Control = $UI/LevelUpPanel
@onready var option_buttons: Array[Button] = [
	$UI/LevelUpPanel/VBox/Option0,
	$UI/LevelUpPanel/VBox/Option1,
	$UI/LevelUpPanel/VBox/Option2,
]

var kills: int = 0
var survival_time: float = 0.0
var is_game_over: bool = false
var _pending_levelups: int = 0
var _current_choices: Array = []

func _ready() -> void:
	game_over_panel.visible = false
	level_up_panel.visible = false
	spawner.setup(player, enemies)
	weapon_system.setup(projectiles)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	enemies.child_entered_tree.connect(_on_enemy_added)
	level_system.xp_changed.connect(_on_xp_changed)
	level_system.leveled_up.connect(_on_leveled_up)
	for i in option_buttons.size():
		option_buttons[i].pressed.connect(_on_option_selected.bind(i))
	_on_player_health_changed(player.max_health, player.max_health)
	kills_label.text = "Kills: 0"
	_update_time()

func _process(delta: float) -> void:
	if is_game_over:
		if Input.is_physical_key_pressed(KEY_R):
			get_tree().paused = false
			get_tree().reload_current_scene()
		return
	if get_tree().paused:
		return  # level-up menu open: freeze the timer too
	survival_time += delta
	_update_time()

func _on_enemy_added(node: Node) -> void:
	if node.has_signal("died"):
		node.died.connect(_on_enemy_died)

func _on_enemy_died(enemy) -> void:
	kills += 1
	kills_label.text = "Kills: %d" % kills
	if is_instance_valid(enemy):
		# Deferred: enemies die inside a physics collision callback, and adding
		# an Area2D (the gem) during the physics flush is not allowed.
		_spawn_gem.call_deferred(enemy.global_position)

func _spawn_gem(pos: Vector2) -> void:
	var gem := GEM_SCENE.instantiate()
	pickups.add_child(gem)
	gem.global_position = pos

func _on_xp_changed(current: int, needed: int, lvl: int) -> void:
	level_label.text = "Lv %d" % lvl
	xp_bar.max_value = needed
	xp_bar.value = current

func _on_leveled_up(_lvl: int) -> void:
	# Ramp difficulty: enemies spawn slightly more often each level.
	spawner.increase_spawn_rate(0.92)
	_pending_levelups += 1
	if not level_up_panel.visible:
		_show_levelup()

func _show_levelup() -> void:
	var pool := UPGRADES.duplicate()
	pool.shuffle()
	_current_choices = pool.slice(0, 3)
	for i in option_buttons.size():
		option_buttons[i].text = _current_choices[i]["label"]
	get_tree().paused = true
	level_up_panel.visible = true

func _on_option_selected(index: int) -> void:
	_apply_upgrade(_current_choices[index]["id"])
	_resolve_choice()

func _apply_upgrade(id: String) -> void:
	match id:
		"missiles":
			weapon_system.scale_fire_rate(false, 0.85)
		"homing":
			weapon_system.scale_fire_rate(true, 0.85)
		"speed":
			player.speed *= 1.15
		"maxhp":
			player.add_max_health(50.0)
		"xprate":
			level_system.add_xp_rate(1.0)
		"regen":
			player.add_regen(1.5)
		"explode":
			weapon_system.add_explosion(false, 60.0, 30.0)
		"bounce":
			weapon_system.increase_bounce(false, 1)

func _resolve_choice() -> void:
	_pending_levelups -= 1
	if _pending_levelups > 0:
		return  # keep the panel up for the next queued level-up
	level_up_panel.visible = false
	get_tree().paused = false

func _on_player_health_changed(current: float, maximum: float) -> void:
	health_label.text = "HP: %d / %d" % [int(ceil(current)), int(maximum)]
	health_bar.max_value = maximum
	health_bar.value = current

func _on_player_died() -> void:
	is_game_over = true
	result_label.text = "GAME OVER\nSurvived: %.1fs\nKills: %d\n\nPress R to restart" % [survival_time, kills]
	game_over_panel.visible = true
	get_tree().paused = true

func _update_time() -> void:
	time_label.text = "Time: %.1fs" % survival_time
