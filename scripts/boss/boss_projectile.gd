class_name BossProjectile
extends Area2D

@export_range(100.0, 1200.0, 10.0) var speed: float = 340.0
@export_range(0.5, 10.0, 0.1) var lifetime: float = 4.5

@onready var _lifetime_timer: Timer = $LifetimeTimer
@onready var _outer_glow: Node2D = get_node_or_null("OuterGlow") as Node2D
@onready var _core: Node2D = get_node_or_null("Core") as Node2D

var _impacted: bool = false


func _ready() -> void:
	if lifetime > 0.0 and is_instance_valid(_lifetime_timer):
		_lifetime_timer.wait_time = lifetime
		_lifetime_timer.start()


func configure(move_speed: float) -> void:
	speed = move_speed


func _physics_process(delta: float) -> void:
	if _impacted:
		return
	var dir: Vector2 = Vector2.RIGHT.rotated(global_rotation)
	global_position += dir * speed * delta
	if is_instance_valid(_outer_glow):
		_outer_glow.rotation += 7.5 * delta
	if is_instance_valid(_core):
		_core.rotation -= 5.0 * delta


func _despawn() -> void:
	if _impacted:
		return
	_impacted = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	call_deferred("queue_free")


func _on_body_entered(body: Node2D) -> void:
	if _impacted:
		return
	if body is StaticBody2D or body is TileMapLayer:
		_despawn()


func _on_area_entered(area: Area2D) -> void:
	if _impacted:
		return
	if area.is_in_group("player"):
		_despawn()


func _on_lifetime_timeout() -> void:
	_despawn()


func _on_screen_exited() -> void:
	_despawn()
