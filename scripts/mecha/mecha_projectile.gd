class_name MechaProjectile
extends Area2D

const HIT_BURST_SCENE: PackedScene = preload("res://components/hit_burst.tscn")

@export_range(100.0, 2000.0, 10.0) var speed: float = 720.0
@export_range(1, 20, 1) var damage: int = 1
@export_range(0.2, 10.0, 0.1) var lifetime: float = 2.0
@export_range(3, 18, 1) var trail_points: int = 8

@onready var _lifetime_timer: Timer = $LifetimeTimer
@onready var _outer_glow: Polygon2D = $OuterGlow
@onready var _core: Polygon2D = $Core
@onready var _bloom_halo: Sprite2D = get_node_or_null("BloomHalo") as Sprite2D
@onready var _trail: Line2D = get_node_or_null("Trail") as Line2D

var is_charged: bool = false
var _impacted: bool = false
var _trail_history: Array[Vector2] = []


func _ready() -> void:
	if lifetime > 0.0 and is_instance_valid(_lifetime_timer):
		_lifetime_timer.wait_time = lifetime
		_lifetime_timer.start()
	_apply_visual_style()
	if is_instance_valid(_trail):
		_trail_history.clear()
		_trail_history.append(global_position)
		_trail.points = PackedVector2Array(_trail_history)


func configure_shot(shot_damage: int, shot_speed: float, shot_scale: float, charged: bool) -> void:
	damage = shot_damage
	speed = shot_speed
	scale = Vector2(shot_scale, shot_scale)
	is_charged = charged
	if is_node_ready():
		_apply_visual_style()


func _apply_visual_style() -> void:
	if not is_instance_valid(_outer_glow) or not is_instance_valid(_core):
		return
	if is_charged:
		_outer_glow.color = Color(1.0, 0.82, 0.24, 0.98)
		_core.color = Color(1.0, 0.99, 0.9, 1.0)
		if is_instance_valid(_bloom_halo):
			_bloom_halo.modulate = Color(1.5, 1.05, 0.3, 0.9)
		if is_instance_valid(_trail):
			_trail.width = 13.0
			_trail.default_color = Color(1.0, 0.82, 0.28, 0.85)
	else:
		_outer_glow.color = Color(0.28, 0.9, 1.0, 0.92)
		_core.color = Color(0.94, 0.99, 1.0, 1.0)
		if is_instance_valid(_bloom_halo):
			_bloom_halo.modulate = Color(0.45, 1.25, 1.5, 0.78)
		if is_instance_valid(_trail):
			_trail.width = 8.0
			_trail.default_color = Color(0.35, 0.92, 1.0, 0.72)


func _physics_process(delta: float) -> void:
	if _impacted:
		return
	var direction: Vector2 = Vector2.RIGHT.rotated(global_rotation)
	global_position += direction * speed * delta
	_update_trail()


func _update_trail() -> void:
	if not is_instance_valid(_trail):
		return
	_trail_history.push_front(global_position)
	while _trail_history.size() > trail_points:
		_trail_history.pop_back()
	_trail.points = PackedVector2Array(_trail_history)


func _spawn_impact_burst(tint: Color, burst_scale: float, count: int) -> void:
	var burst: Node2D = HIT_BURST_SCENE.instantiate() as Node2D
	if burst == null:
		return
	burst.global_position = global_position
	var parent_scene: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if parent_scene:
		parent_scene.add_child(burst)
	if burst.has_method("configure"):
		burst.call("configure", tint, burst_scale, count)


func _deal_damage_to(target: Node, weakpoint_hit: bool) -> void:
	if not is_instance_valid(target):
		return

	if target.has_method("tomar_dano_detalhado"):
		var was_crit: bool = bool(target.call("tomar_dano_detalhado", damage, is_charged, global_position, weakpoint_hit))
		if was_crit:
			_spawn_impact_burst(Color(1.0, 0.86, 0.25, 1.0), 1.45 if is_charged else 1.1, 24 if is_charged else 16)
		else:
			_spawn_impact_burst(Color(0.55, 0.88, 1.0, 1.0), 1.05 if is_charged else 0.72, 14 if is_charged else 9)
		return

	var is_crit: bool = weakpoint_hit
	if not is_crit and target.has_method("is_weakpoint_hit"):
		is_crit = bool(target.call("is_weakpoint_hit", global_position))
	var final_damage: int = damage * 2 if is_crit else damage

	if target.has_method("tomar_dano_critico"):
		target.call("tomar_dano_critico", final_damage, is_crit)
	elif target.has_method("tomar_dano"):
		target.call("tomar_dano", final_damage)

	var tint: Color = Color(1.0, 0.85, 0.28, 1.0) if (is_crit or is_charged) else Color(0.42, 0.94, 1.0, 1.0)
	_spawn_impact_burst(tint, 1.2 if (is_crit or is_charged) else 0.8, 16 if is_crit else 10)


func _despawn(spawn_terrain_burst: bool = false) -> void:
	if _impacted:
		return
	_impacted = true
	if spawn_terrain_burst:
		var tint: Color = Color(1.0, 0.82, 0.3, 1.0) if is_charged else Color(0.45, 0.92, 1.0, 1.0)
		_spawn_impact_burst(tint, 0.95 if is_charged else 0.65, 10)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	call_deferred("queue_free")


func _on_body_entered(body: Node2D) -> void:
	if _impacted or body.is_in_group("player"):
		return
	if body.has_method("tomar_dano_detalhado") or body.has_method("tomar_dano_critico") or body.has_method("tomar_dano"):
		var hit_weakpoint: bool = false
		for area: Area2D in get_overlapping_areas():
			if area.is_in_group("enemy_weakpoint"):
				hit_weakpoint = true
				break
		_deal_damage_to(body, hit_weakpoint)
		_despawn(false)
		return
	var enemy_hitbox: Node = body.get_node_or_null("Hitbox")
	if enemy_hitbox and enemy_hitbox.is_in_group("enemy"):
		return
	_despawn(true)


func _on_area_entered(area: Area2D) -> void:
	if _impacted:
		return
	if area.is_in_group("enemy_weakpoint"):
		_deal_damage_to(area.get_parent(), true)
		_despawn(false)
		return
	if area.is_in_group("enemy"):
		var enemy_root: Node = area.get_parent()
		if enemy_root and (enemy_root.has_method("tomar_dano_detalhado") or enemy_root.has_method("tomar_dano_critico") or enemy_root.has_method("tomar_dano")):
			_deal_damage_to(enemy_root, false)
		_despawn(false)


func _on_lifetime_timeout() -> void:
	_despawn(false)


func _on_screen_exited() -> void:
	_despawn(false)
