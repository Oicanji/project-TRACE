class_name ZonePortal
extends Area2D

signal portal_triggered(portal: ZonePortal)

@export var target_zone_id: StringName = &""
@export var target_spawn_id: StringName = &"default"
@export var require_interact: bool = false
@export var interact_action: StringName = &"interagir"

var _player_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if not require_interact or not _player_inside:
		return
	if event.is_action_pressed(interact_action):
		portal_triggered.emit(self)


func _is_player(body: Node) -> bool:
	return body.is_in_group("player") or body.name == "Player"


func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	_player_inside = true
	if require_interact:
		set_process_unhandled_input(true)
	else:
		portal_triggered.emit(self)


func _on_body_exited(body: Node2D) -> void:
	if not _is_player(body):
		return
	_player_inside = false
	set_process_unhandled_input(false)
