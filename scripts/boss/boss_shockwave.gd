class_name BossShockwave
extends Area2D

@export_range(80.0, 900.0, 10.0) var speed: float = 280.0
@export_range(0.5, 10.0, 0.1) var lifetime: float = 3.5

@onready var _visual: Polygon2D = $Visual
@onready var _inner_glow: Polygon2D = $InnerGlow
@onready var _lifetime_timer: Timer = $LifetimeTimer

var direction: float = -1.0
var _despawning: bool = false


func _ready() -> void:
	_apply_facing()
	if lifetime > 0.0 and is_instance_valid(_lifetime_timer):
		_lifetime_timer.wait_time = lifetime
		_lifetime_timer.start()


func configure(move_dir: float, move_speed: float) -> void:
	direction = -1.0 if move_dir < 0.0 else 1.0
	speed = move_speed
	if is_node_ready():
		_apply_facing()


func _apply_facing() -> void:
	var sx: float = -1.0 if direction < 0.0 else 1.0
	if is_instance_valid(_visual):
		_visual.scale.x = sx
	if is_instance_valid(_inner_glow):
		_inner_glow.scale.x = sx


func _physics_process(delta: float) -> void:
	if _despawning:
		return
	global_position.x += direction * speed * delta


func _despawn() -> void:
	if _despawning:
		return
	_despawning = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	call_deferred("queue_free")


func _on_body_entered(body: Node2D) -> void:
	if _despawning:
		return
	if body is StaticBody2D or body is TileMapLayer:
		_despawn()


func _on_lifetime_timeout() -> void:
	_despawn()
