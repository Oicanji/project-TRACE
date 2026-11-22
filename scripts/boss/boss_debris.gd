class_name BossDebris
extends Area2D

const HIT_BURST_SCENE: PackedScene = preload("res://components/hit_burst.tscn")

@export_range(300.0, 1600.0, 20.0) var fall_speed: float = 860.0
@export_range(0.3, 2.0, 0.05) var telegraph_time: float = 0.78

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _girder_visual: Node2D = $GirderVisual
@onready var _warning_line: Line2D = $WarningLine
@onready var _warning_marker: Polygon2D = $WarningMarker
@onready var _telegraph_timer: Timer = $TelegraphTimer

var _floor_y: float = 520.0
var _falling: bool = false
var _impacted: bool = false


func _ready() -> void:
	_set_hazard_active(false)
	_girder_visual.visible = false
	_telegraph_timer.wait_time = telegraph_time
	_telegraph_timer.start()


func configure_drop(floor_y: float, delay: float = 0.78) -> void:
	_floor_y = floor_y
	telegraph_time = delay
	if is_node_ready():
		_update_warning_geometry()
		_telegraph_timer.start(telegraph_time)


func _process(_delta: float) -> void:
	if not _falling and not _impacted:
		_update_warning_geometry()
		var pulse: float = 0.35 + 0.55 * absf(sin(Time.get_ticks_msec() * 0.025))
		_warning_line.default_color = Color(1.0, 0.25, 0.22, pulse)
		_warning_marker.color = Color(1.0, 0.3, 0.22, pulse)


func _physics_process(delta: float) -> void:
	if not _falling or _impacted:
		return
	global_position.y += fall_speed * delta
	if global_position.y >= _floor_y - 26.0:
		_impact()


func _update_warning_geometry() -> void:
	var dist_to_floor: float = maxf(20.0, _floor_y - global_position.y)
	_warning_line.set_point_position(1, Vector2(0.0, dist_to_floor))
	_warning_marker.position = Vector2(0.0, dist_to_floor - 4.0)


func _set_hazard_active(active: bool) -> void:
	set_deferred("monitoring", active)
	set_deferred("monitorable", active)
	if is_instance_valid(_collision):
		_collision.set_deferred("disabled", not active)


func _on_telegraph_timer_timeout() -> void:
	if _impacted:
		return
	_falling = true
	_warning_line.visible = false
	_warning_marker.visible = false
	_girder_visual.visible = true
	_set_hazard_active(true)


func _impact() -> void:
	if _impacted:
		return
	_impacted = true
	_set_hazard_active(false)

	var burst: Node2D = HIT_BURST_SCENE.instantiate() as Node2D
	if burst:
		burst.global_position = Vector2(global_position.x, _floor_y - 8.0)
		var parent_scene: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
		if parent_scene:
			parent_scene.add_child(burst)
		if burst.has_method("configure"):
			burst.call("configure", Color(1.0, 0.45, 0.25, 1.0), 1.15, 16)

	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.has_method("apply_camera_shake"):
		player.call("apply_camera_shake", 3.5)

	call_deferred("queue_free")


func _on_body_entered(body: Node2D) -> void:
	if _falling and not _impacted and (body is StaticBody2D or body is TileMapLayer):
		_impact()
