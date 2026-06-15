extends Node2D

const GEM_SCENE := preload("res://scenes/xp_gem.tscn")

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
@onready var missiles_button: Button = $UI/LevelUpPanel/VBox/MissilesButton
@onready var homing_button: Button = $UI/LevelUpPanel/VBox/HomingButton
@onready var speed_button: Button = $UI/LevelUpPanel/VBox/SpeedButton

var kills: int = 0
var survival_time: float = 0.0
var is_game_over: bool = false
var _pending_levelups: int = 0

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
	missiles_button.pressed.connect(_on_pick_missiles)
	homing_button.pressed.connect(_on_pick_homing)
	speed_button.pressed.connect(_on_pick_speed)
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
		var gem := GEM_SCENE.instantiate()
		pickups.add_child(gem)
		gem.global_position = enemy.global_position

func _on_xp_changed(current: int, needed: int, lvl: int) -> void:
	level_label.text = "Lv %d" % lvl
	xp_bar.max_value = needed
	xp_bar.value = current

func _on_leveled_up(_lvl: int) -> void:
	_pending_levelups += 1
	if not level_up_panel.visible:
		_show_levelup()

func _show_levelup() -> void:
	get_tree().paused = true
	level_up_panel.visible = true

func _on_pick_missiles() -> void:
	weapon_system.scale_fire_rate(false, 0.85)
	_resolve_choice()

func _on_pick_homing() -> void:
	weapon_system.scale_fire_rate(true, 0.85)
	_resolve_choice()

func _on_pick_speed() -> void:
	player.speed *= 1.15
	_resolve_choice()

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
