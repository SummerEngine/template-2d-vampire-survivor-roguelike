extends Node2D

const GEM_SCENE := preload("res://scenes/xp_gem.tscn")

# Pool of level-up upgrades. Each level-up shows 3 random distinct ones.
const UPGRADES := [
	{"id": "missiles", "label": "More Missiles", "desc": "Arrows fire 15% faster.", "icon": "res://assets/icons/missiles.png"},
	{"id": "homing", "label": "More Homing Orbs", "desc": "Homing orbs fire 15% faster.", "icon": "res://assets/icons/homing.png"},
	{"id": "speed", "label": "Movement Speed", "desc": "Move 15% faster.", "icon": "res://assets/icons/speed.png"},
	{"id": "maxhp", "label": "+50 Max HP", "desc": "Raise maximum HP by 50.", "icon": "res://assets/icons/maxhp.png"},
	{"id": "xprate", "label": "XP Surge", "desc": "Passively gain +1 XP every second.", "icon": "res://assets/icons/xprate.png"},
	{"id": "regen", "label": "Health Regen", "desc": "Regenerate +1.5 HP every second.", "icon": "res://assets/icons/regen.png"},
	{"id": "explode", "label": "Explosive Missiles", "desc": "Arrows explode on impact; blast grows each pick.", "icon": "res://assets/icons/explode.png"},
	{"id": "bounce", "label": "Bouncing Missiles", "desc": "Arrows bounce off walls one more time.", "icon": "res://assets/icons/bounce.png"},
	{"id": "saw", "label": "Spinning Saw", "desc": "Adds a saw blade that orbits you and shreds enemies it touches.", "icon": "res://assets/icons/saw.png"},
	{"id": "lightning", "label": "Storm Caller", "desc": "Lightning strikes a random enemy every 5s for massive damage. Stacks: +1 bolt per pick.", "icon": "res://assets/icons/lightning.png"},
]

@onready var player: CharacterBody2D = $Player
@onready var spawner: Node = $EnemySpawner
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var pickups: Node2D = $Pickups
@onready var weapon_system: Node = $Player/WeaponSystem
@onready var saw_system: Node = $Player/SawSystem
@onready var level_system: Node = $LevelSystem
@onready var lightning_system: Node = $LightningSystem

@onready var health_label: Label = $UI/HUD/HealthLabel
@onready var health_bar: ProgressBar = $UI/HUD/HealthBar
@onready var kills_label: Label = $UI/HUD/KillsLabel
@onready var time_label: Label = $UI/HUD/TimeLabel
@onready var level_label: Label = $UI/HUD/LevelLabel
@onready var xp_bar: ProgressBar = $UI/HUD/XPBar
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var result_label: Label = $UI/GameOverPanel/ResultLabel
@onready var main_menu_button: Button = $UI/GameOverPanel/MainMenuButton
@onready var level_up_panel: Control = $UI/LevelUpPanel
@onready var damage_flash: ColorRect = $UI/DamageFlash
@onready var cards: Array = [
	$UI/LevelUpPanel/CardRow/Card0,
	$UI/LevelUpPanel/CardRow/Card1,
	$UI/LevelUpPanel/CardRow/Card2,
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
	lightning_system.setup(self)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	player.took_damage.connect(_on_player_took_damage)
	damage_flash.modulate.a = 0.0
	enemies.child_entered_tree.connect(_on_enemy_added)
	level_system.xp_changed.connect(_on_xp_changed)
	level_system.leveled_up.connect(_on_leveled_up)
	for i in cards.size():
		cards[i].selected.connect(_on_option_selected.bind(i))
		cards[i].hover_changed.connect(_on_card_hover)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	_on_player_health_changed(player.max_health, player.max_health)
	kills_label.text = "Kills: 0"
	_update_time()

func _input(event: InputEvent) -> void:
	# Debug: press L to force a level-up (shows the reward cards).
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		if not is_game_over:
			level_system.debug_level_up()

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
	# Vacuum every XP gem on the map toward the player.
	get_tree().call_group("xp_gems", "attract_to", player)
	_pending_levelups += 1
	if not level_up_panel.visible:
		_show_levelup()

func _show_levelup() -> void:
	var pool := UPGRADES.duplicate()
	pool.shuffle()
	_current_choices = pool.slice(0, 3)
	for i in cards.size():
		var upg: Dictionary = _current_choices[i]
		var tex: Texture2D = load(upg["icon"]) as Texture2D
		cards[i].setup(tex, upg["label"], upg["desc"])
		cards[i].modulate = Color(1, 1, 1)
		cards[i].scale = Vector2.ONE
	get_tree().paused = true
	level_up_panel.visible = true

func _on_card_hover(card: Control, hovered: bool) -> void:
	for c in cards:
		c.modulate = Color(0.6, 0.6, 0.6) if (hovered and c != card) else Color(1, 1, 1)

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
		"saw":
			saw_system.add_saw()
		"lightning":
			lightning_system.enable()

func _resolve_choice() -> void:
	_pending_levelups -= 1
	if _pending_levelups > 0:
		return  # keep the panel up for the next queued level-up
	level_up_panel.visible = false
	get_tree().paused = false

func _on_player_took_damage() -> void:
	damage_flash.modulate.a = 0.5
	var tw := create_tween()
	tw.tween_property(damage_flash, "modulate:a", 0.0, 0.3)

func _on_player_health_changed(current: float, maximum: float) -> void:
	health_label.text = "HP: %d / %d" % [int(ceil(current)), int(maximum)]
	health_bar.max_value = maximum
	health_bar.value = current

func _on_player_died() -> void:
	is_game_over = true
	result_label.text = "GAME OVER\nSurvived: %.1fs\nKills: %d\n\nPress R to restart" % [survival_time, kills]
	game_over_panel.visible = true
	get_tree().paused = true

func _on_main_menu_pressed() -> void:
	# Death pauses the tree; clear it so the menu scene runs normally.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _update_time() -> void:
	time_label.text = "Time: %.1fs" % survival_time
