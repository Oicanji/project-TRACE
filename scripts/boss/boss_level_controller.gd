class_name BossLevelController
extends Node2D

const HUMAN_SOUL_SCENE: PackedScene = preload("res://components/human_soul_drop.tscn")

@export_file("*.tscn") var start_scene_path: String = "res://scenes/level_1_floresta.tscn"
@export_file("*.tscn") var ending_scene_path: String = "res://scenes/ending_slideshow.tscn"
@export var arena_floor_y: float = 520.0

@onready var _player: Node2D = $MechaPlayer as Node2D
@onready var _boss: Node2D = $ColossalBoss as Node2D
@onready var _end_delay_timer: Timer = $EndDelayTimer
@onready var _end_screen: CanvasLayer = $EndScreen
@onready var _retry_button: Button = $EndScreen/Backdrop/CenterContainer/Buttons/RetryButton
@onready var _fade_rect: ColorRect = get_node_or_null("FadeLayer/FadeRect") as ColorRect

var _match_ended: bool = false
var _player_won: bool = false
var _soul_collected: bool = false
var _last_boss_pos: Vector2 = Vector2(1060.0, 364.0)


func _ready() -> void:
	_end_screen.visible = false
	if is_instance_valid(_fade_rect):
		_fade_rect.color = Color(1.0, 0.99, 0.94, 0.0)
		_fade_rect.visible = false

	if _boss and _boss.has_signal("morreu"):
		_boss.morreu.connect(_on_boss_defeated)
	if _player and _player.has_signal("morreu"):
		_player.morreu.connect(_on_player_defeated)


func _physics_process(_delta: float) -> void:
	if is_instance_valid(_boss):
		_last_boss_pos = _boss.global_position


func _on_boss_defeated() -> void:
	if _match_ended:
		return
	_match_ended = true
	_player_won = true
	_spawn_freed_human_soul()


func _spawn_freed_human_soul() -> void:
	var soul: Area2D = HUMAN_SOUL_SCENE.instantiate() as Area2D
	if soul == null:
		_start_ending_transition()
		return

	soul.global_position = _last_boss_pos + Vector2(0.0, -58.0)
	add_child(soul)
	if soul.has_method("configure_drop"):
		soul.call("configure_drop", arena_floor_y)
	if soul.has_signal("coletada"):
		soul.coletada.connect(_on_soul_collected)


func _on_soul_collected() -> void:
	if _soul_collected:
		return
	_soul_collected = true

	if is_instance_valid(_player) and _player.has_method("absorver_alma_humana"):
		_player.call("absorver_alma_humana", Color(1.0, 0.86, 0.28, 1.0))

	_end_delay_timer.start(1.65)


func _on_player_defeated() -> void:
	if _match_ended:
		return
	_match_ended = true
	_player_won = false
	_end_delay_timer.start(0.75)


func _on_end_delay_timer_timeout() -> void:
	if _player_won:
		_start_ending_transition()
		return

	_end_screen.visible = true
	_retry_button.grab_focus()


func _start_ending_transition() -> void:
	if ending_scene_path.is_empty() or not ResourceLoader.exists(ending_scene_path):
		return
	if is_instance_valid(_fade_rect):
		_fade_rect.visible = true
		var tween: Tween = create_tween()
		tween.tween_property(_fade_rect, "color:a", 1.0, 0.85).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(_go_to_ending_scene)
	else:
		_go_to_ending_scene()


func _go_to_ending_scene() -> void:
	get_tree().call_deferred("change_scene_to_file", ending_scene_path)


func _on_retry_button_pressed() -> void:
	get_tree().call_deferred("reload_current_scene")


func _on_start_button_pressed() -> void:
	if not start_scene_path.is_empty() and ResourceLoader.exists(start_scene_path):
		get_tree().call_deferred("change_scene_to_file", start_scene_path)
