class_name MainMenu
extends Control

@export_file("*.tscn") var start_scene_path: String = "res://scenes/level_1_floresta.tscn"

@onready var _start_button: Button = $SafeMargin/BottomBar/ButtonRow/StartButton
@onready var _quit_button: Button = $SafeMargin/BottomBar/ButtonRow/QuitButton
@onready var _animation_player: AnimationPlayer = $AnimationPlayer

var _is_starting: bool = false


func _ready() -> void:
	get_tree().paused = false
	_start_button.grab_focus()
	if _animation_player.has_animation(&"intro"):
		_animation_player.play(&"intro")


func _on_start_button_pressed() -> void:
	if _is_starting:
		return
	if start_scene_path.is_empty() or not ResourceLoader.exists(start_scene_path):
		push_warning("MainMenu: start_scene_path inválida: %s" % start_scene_path)
		return

	_is_starting = true
	_start_button.disabled = true
	_quit_button.disabled = true

	if _animation_player.has_animation(&"start_fade"):
		_animation_player.play(&"start_fade")
		await _animation_player.animation_finished

	get_tree().call_deferred("change_scene_to_file", start_scene_path)


func _on_quit_button_pressed() -> void:
	if _is_starting:
		return
	get_tree().quit()
