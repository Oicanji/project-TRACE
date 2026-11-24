class_name DeathScreen
extends CanvasLayer

signal death_screen_opened

@export var player: Node
@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/main_menu.tscn"
@export_range(0.0, 3.0, 0.05) var open_delay: float = 0.45

@onready var _root: Control = $Root
@onready var _retry_button: Button = $Root/SafeMargin/MenuAnchor/MenuPanel/PanelPadding/ButtonList/RetryButton
@onready var _main_menu_button: Button = $Root/SafeMargin/MenuAnchor/MenuPanel/PanelPadding/ButtonList/MainMenuButton
@onready var _quit_button: Button = $Root/SafeMargin/MenuAnchor/MenuPanel/PanelPadding/ButtonList/QuitButton
@onready var _open_delay_timer: Timer = $OpenDelayTimer
@onready var _transition_anim: AnimationPlayer = $TransitionAnimPlayer
@onready var _ambient_anim: AnimationPlayer = $AmbientAnimPlayer

var _triggered: bool = false
var _is_open: bool = false
var _is_leaving: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root.visible = false
	_open_delay_timer.one_shot = true

	if _ambient_anim.has_animation(&"idle"):
		_ambient_anim.play(&"idle")

	_bind_player()


func _exit_tree() -> void:
	if _is_open:
		_is_open = false
		if get_tree():
			get_tree().paused = false
		Engine.time_scale = 1.0


func is_triggered() -> bool:
	return _triggered or _is_open


func _bind_player() -> void:
	if player == null and get_parent() != null:
		player = get_parent().get_node_or_null("Player")
		if player == null:
			player = get_parent().get_node_or_null("MechaPlayer")
	if player == null and get_tree() != null:
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		return

	if "auto_reload_on_death" in player:
		player.set("auto_reload_on_death", false)

	if player.has_signal("morreu") and not player.morreu.is_connected(_on_player_morreu):
		player.morreu.connect(_on_player_morreu)


func _on_player_morreu() -> void:
	trigger_death_screen()


func trigger_death_screen() -> void:
	if _triggered:
		return
	_triggered = true

	if open_delay > 0.0:
		_open_delay_timer.start(open_delay)
	else:
		open_death_screen()


func _on_open_delay_timer_timeout() -> void:
	open_death_screen()


func open_death_screen() -> void:
	if _is_open:
		return

	_is_open = true
	Engine.time_scale = 1.0
	get_tree().paused = true

	visible = true
	_root.visible = true
	_set_buttons_disabled(false)
	_retry_button.grab_focus()

	if _transition_anim.has_animation(&"abrir"):
		_transition_anim.play(&"abrir")

	death_screen_opened.emit()


func _set_buttons_disabled(disabled: bool) -> void:
	_retry_button.disabled = disabled
	_main_menu_button.disabled = disabled
	_quit_button.disabled = disabled


func _on_retry_button_pressed() -> void:
	if _is_leaving:
		return
	_is_leaving = true
	_set_buttons_disabled(true)
	_is_open = false
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().call_deferred("reload_current_scene")


func _on_main_menu_button_pressed() -> void:
	if _is_leaving:
		return
	if main_menu_scene_path.is_empty() or not ResourceLoader.exists(main_menu_scene_path):
		push_warning("DeathScreen: main_menu_scene_path inválida: %s" % main_menu_scene_path)
		return

	_is_leaving = true
	_set_buttons_disabled(true)
	_is_open = false
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", main_menu_scene_path)


func _on_quit_button_pressed() -> void:
	if _is_leaving:
		return
	_is_leaving = true
	_set_buttons_disabled(true)
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().quit()
