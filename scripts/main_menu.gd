extends Control

# Main menu for the auto-shooter roguelike template.
# This scene is the project's main scene; Play loads the gameplay scene.

@onready var options_panel: Control = $OptionsPanel
@onready var volume_slider: HSlider = $OptionsPanel/Center/Panel/Margin/VBox/VolumeRow/VolumeSlider
@onready var fullscreen_check: CheckButton = $OptionsPanel/Center/Panel/Margin/VBox/FullscreenRow/FullscreenCheck

func _ready() -> void:
	options_panel.visible = false
	# Play a soft tick when hovering any menu button.
	for b in [$Buttons/PlayButton, $Buttons/OptionsButton, $Buttons/QuitButton,
			$OptionsPanel/Center/Panel/Margin/VBox/BackButton]:
		b.mouse_entered.connect(func(): Sfx.play("ui_hover"))
	# Sync the controls with the current audio/window state.
	var master_idx := AudioServer.get_bus_index("Master")
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_idx))
	fullscreen_check.button_pressed = (
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)

func _on_play_pressed() -> void:
	Sfx.play("ui_click")
	get_tree().change_scene_to_file("res://main.tscn")

func _on_options_pressed() -> void:
	Sfx.play("ui_click")
	options_panel.visible = true

func _on_back_pressed() -> void:
	Sfx.play("ui_click")
	options_panel.visible = false

func _on_quit_pressed() -> void:
	Sfx.play("ui_click")
	get_tree().quit()

func _on_volume_changed(value: float) -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_idx, linear_to_db(value))

func _on_fullscreen_toggled(pressed: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED
	)
