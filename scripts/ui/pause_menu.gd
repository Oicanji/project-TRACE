class_name PauseMenu
extends CanvasLayer

signal pause_opened
signal pause_closed

@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/main_menu.tscn"
@export var pause_action: StringName = &"pausar"
@export var allow_pause: bool = true

@onready var _root: Control = $Root
@onready var _resume_button: Button = $Root/SafeMargin/MenuAnchor/MenuPanel/PanelPadding/ButtonList/ResumeButton
@onready var _restart_button: Button = $Root/SafeMargin/MenuAnchor/MenuPanel/PanelPadding/ButtonList/RestartButton
@onready var _main_menu_button: Button = $Root/SafeMargin/MenuAnchor/MenuPanel/PanelPadding/ButtonList/MainMenuButton
@onready var _quit_button: Button = $Root/SafeMargin/MenuAnchor/MenuPanel/PanelPadding/ButtonList/QuitButton
@onready var _transition_anim: AnimationPlayer = $TransitionAnimPlayer
@onready var _ambient_anim: AnimationPlayer = $AmbientAnimPlayer

var _is_open: bool = false
var _is_transitioning: bool = false
var _saved_time_scale: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root.visible = false
	if _ambient_anim.has_animation(&"idle"):
		_ambient_anim.play(&"idle")


func _exit_tree() -> void:
	if _is_open:
		_is_open = false
		if get_tree():
			get_tree().paused = false
		Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if not allow_pause or _is_transitioning:
		return
	if event.is_echo():
		return
	if not event.is_action_pressed(pause_action):
		return
	if not _is_open and _is_blocked_by_scene_state():
		return

	get_viewport().set_input_as_handled()
	toggle_pause()


func toggle_pause() -> void:
	if _is_open:
		close_pause()
	else:
		open_pause()


func open_pause() -> void:
	if _is_open or _is_transitioning:
		return

	_is_open = true
	_is_transitioning = true
	_saved_time_scale = Engine.time_scale
	Engine.time_scale = 1.0
	get_tree().paused = true

	visible = true
	_root.visible = true
	_set_buttons_disabled(false)
	_resume_button.grab_focus()

	if _transition_anim.has_animation(&"abrir"):
		_transition_anim.play(&"abrir")
		await _transition_anim.animation_finished

	_is_transitioning = false
	pause_opened.emit()


func close_pause() -> void:
	if not _is_open or _is_transitioning:
		return

	_is_transitioning = true
	_set_buttons_disabled(true)

	if _transition_anim.has_animation(&"fechar"):
		_transition_anim.play(&"fechar")
		await _transition_anim.animation_finished

	visible = false
	_root.visible = false
	_is_open = false
	_is_transitioning = false
	Engine.time_scale = _saved_time_scale if _saved_time_scale > 0.0 else 1.0
	get_tree().paused = false
	pause_closed.emit()


func _is_blocked_by_scene_state() -> bool:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return false

	var death_screen: Node = current_scene.get_node_or_null("DeathScreen")
	if death_screen != null:
		if death_screen.has_method("is_triggered") and bool(death_screen.call("is_triggered")):
			return true
		if death_screen is CanvasLayer and (death_screen as CanvasLayer).visible:
			return true

	var end_screen: CanvasLayer = current_scene.get_node_or_null("EndScreen") as CanvasLayer
	if end_screen != null and end_screen.visible:
		return true

	return false


func _set_buttons_disabled(disabled: bool) -> void:
	_resume_button.disabled = disabled
	_restart_button.disabled = disabled
	_main_menu_button.disabled = disabled
	_quit_button.disabled = disabled


func _on_resume_button_pressed() -> void:
	close_pause()


func _on_restart_button_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_set_buttons_disabled(true)
	_is_open = false
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().call_deferred("reload_current_scene")


func _on_main_menu_button_pressed() -> void:
	if _is_transitioning:
		return
	if main_menu_scene_path.is_empty() or not ResourceLoader.exists(main_menu_scene_path):
		push_warning("PauseMenu: main_menu_scene_path inválida: %s" % main_menu_scene_path)
		return

	_is_transitioning = true
	_set_buttons_disabled(true)
	_is_open = false
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", main_menu_scene_path)


func _on_quit_button_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_set_buttons_disabled(true)
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().quit()
