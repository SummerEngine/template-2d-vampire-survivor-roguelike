extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var spawner: Node = $EnemySpawner
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var weapon_system: Node = $Player/WeaponSystem
@onready var health_label: Label = $UI/HUD/HealthLabel
@onready var kills_label: Label = $UI/HUD/KillsLabel
@onready var time_label: Label = $UI/HUD/TimeLabel
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var result_label: Label = $UI/GameOverPanel/ResultLabel

var kills: int = 0
var survival_time: float = 0.0
var is_game_over: bool = false

func _ready() -> void:
	game_over_panel.visible = false
	spawner.setup(player, enemies)
	weapon_system.setup(projectiles)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	enemies.child_entered_tree.connect(_on_enemy_added)
	_on_player_health_changed(player.max_health, player.max_health)
	kills_label.text = "Kills: 0"
	_update_time()

func _process(delta: float) -> void:
	if is_game_over:
		if Input.is_physical_key_pressed(KEY_R):
			get_tree().paused = false
			get_tree().reload_current_scene()
		return
	survival_time += delta
	_update_time()

func _on_enemy_added(node: Node) -> void:
	if node.has_signal("died"):
		node.died.connect(_on_enemy_died)

func _on_enemy_died(_enemy) -> void:
	kills += 1
	kills_label.text = "Kills: %d" % kills

func _on_player_health_changed(current: float, maximum: float) -> void:
	health_label.text = "HP: %d / %d" % [int(ceil(current)), int(maximum)]

func _on_player_died() -> void:
	is_game_over = true
	result_label.text = "GAME OVER\nSurvived: %.1fs\nKills: %d\n\nPress R to restart" % [survival_time, kills]
	game_over_panel.visible = true
	get_tree().paused = true

func _update_time() -> void:
	time_label.text = "Time: %.1fs" % survival_time
