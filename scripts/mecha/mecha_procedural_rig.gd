class_name MechaProceduralRig
extends Node2D

@export_group("Suspension")
@export var spring_stiffness: float = 190.0
@export var spring_damping: float = 14.0
@export var wheel_radius: float = 7.5
@export var engine_bob_amp: float = 0.85

@onready var _hull: Node2D = $Hull
@onready var _wheel_left: Node2D = $Hull/TreadBase/WheelLeft
@onready var _wheel_mid: Node2D = $Hull/TreadBase/WheelMid
@onready var _wheel_right: Node2D = $Hull/TreadBase/WheelRight
@onready var _tread_lugs: Node2D = $Hull/TreadBase/TreadLugs
@onready var _chassis_spring: Node2D = $Hull/ChassisSpring
@onready var _thruster_flame: Polygon2D = get_node_or_null("Hull/ChassisSpring/ThrusterFlame") as Polygon2D
@onready var _cat_pilot: Node2D = $Hull/ChassisSpring/CatPilot
@onready var _cat_tail: Line2D = get_node_or_null("Hull/ChassisSpring/CatPilot/CatTail") as Line2D
@onready var _cat_body: Polygon2D = get_node_or_null("Hull/ChassisSpring/CatPilot/CatBody") as Polygon2D
@onready var _cat_head: Node2D = $Hull/ChassisSpring/CatPilot/CatHead
@onready var _cat_head_shape: Polygon2D = get_node_or_null("Hull/ChassisSpring/CatPilot/CatHead/HeadShape") as Polygon2D
@onready var _ear_left: Node2D = $Hull/ChassisSpring/CatPilot/CatHead/EarLeft
@onready var _ear_right: Node2D = $Hull/ChassisSpring/CatPilot/CatHead/EarRight
@onready var _ear_left_outer: Polygon2D = get_node_or_null("Hull/ChassisSpring/CatPilot/CatHead/EarLeft/Outer") as Polygon2D
@onready var _ear_right_outer: Polygon2D = get_node_or_null("Hull/ChassisSpring/CatPilot/CatHead/EarRight/Outer") as Polygon2D
@onready var _eyes: Node2D = $Hull/ChassisSpring/CatPilot/CatHead/Eyes
@onready var _porthole: Polygon2D = get_node_or_null("Hull/ChassisSpring/CyanPorthole") as Polygon2D
@onready var _barrel_band: Polygon2D = get_node_or_null("TurretPivot/Barrel/EnergyBand") as Polygon2D
@onready var _mecha_light: PointLight2D = get_node_or_null("LuzMecha") as PointLight2D
@onready var _turret_pivot: Node2D = $TurretPivot
@onready var _turret_core: Node2D = $TurretPivot/TurretPod/TurretCore
@onready var _blink_timer: Timer = $BlinkTimer

var _ghost_shell_points: PackedVector2Array = PackedVector2Array([
	Vector2(-23, 10), Vector2(-25, 5), Vector2(-24.5, -2), Vector2(-21.5, -8.5),
	Vector2(-16, -13.5), Vector2(-8, -16.5), Vector2(2, -17), Vector2(11.5, -15),
	Vector2(19, -10), Vector2(24, -3), Vector2(26, 4.5), Vector2(24.5, 10),
	Vector2(22, 21.5), Vector2(-22, 21.5)
])

var _chassis_rest_pos: Vector2 = Vector2.ZERO
var _turret_base_y: float = -16.0
var _cat_rest_pos: Vector2 = Vector2.ZERO

# Spring-damper state for hull bounce and squash/stretch
var _spring_y: float = 0.0
var _spring_vy: float = 0.0
var _squash_x: float = 1.0
var _squash_y: float = 1.0
var _ear_angle: float = 0.0
var _ear_vel: float = 0.0

var _wheel_angle: float = 0.0
var _tread_offset: float = 0.0
var _engine_phase: float = 0.0
var _tail_phase: float = 0.0
var _blink_remaining: float = 0.0
var _hurt_react_remaining: float = 0.0
var _ghost_cooldown: float = 0.0
var _charge_ratio: float = 0.0
var _jump_charge_ratio: float = 0.0
var _jump_tremble_remaining: float = 0.0
var _jump_tremble_strength: float = 0.0
var _is_dashing: bool = false
var _facing: float = 1.0
var _soul_empowered: bool = false
var _soul_color: Color = Color(0.97, 0.98, 1.0, 1.0)


func _ready() -> void:
	_chassis_rest_pos = _chassis_spring.position
	_turret_base_y = _turret_pivot.position.y
	_cat_rest_pos = _cat_pilot.position
	if is_instance_valid(_blink_timer):
		_blink_timer.wait_time = randf_range(2.2, 4.5)
		_blink_timer.start()


func update_rig(
	delta: float,
	velocity: Vector2,
	on_floor: bool,
	floor_tilt: float,
	facing: float,
	aim_angle: float,
	charge_ratio: float,
	dashing: bool,
	jump_charge_ratio: float = 0.0
) -> void:
	_facing = -1.0 if facing < 0.0 else 1.0
	_charge_ratio = clampf(charge_ratio, 0.0, 1.0)
	_jump_charge_ratio = clampf(jump_charge_ratio, 0.0, 1.0)
	_is_dashing = dashing

	# 1. Spin all 3 round bogie wheels & animate tread lugs along rounded track
	var ground_vx: float = velocity.x if on_floor else velocity.x * 0.35
	var local_vx: float = ground_vx * _facing
	var d_angle: float = (local_vx * delta) / maxf(wheel_radius, 1.0)
	_wheel_angle += d_angle
	_wheel_left.rotation = _wheel_angle
	_wheel_mid.rotation = _wheel_angle
	_wheel_right.rotation = _wheel_angle

	_tread_offset = fposmod(_tread_offset + local_vx * delta * 0.55, 1.0)
	_update_tread_lugs()

	# 2. Spring-damper vertical suspension & squash/stretch recovery
	var spring_acc: float = -spring_stiffness * _spring_y - spring_damping * _spring_vy
	_spring_vy += spring_acc * delta
	_spring_y = clampf(_spring_y + _spring_vy * delta, -8.0, 9.0)

	var stretch_relax: float = 1.0 - exp(-12.0 * delta)
	var target_sx: float = 1.12 if dashing else (1.0 + _charge_ratio * 0.05 + _jump_charge_ratio * 0.20)
	var target_sy: float = 0.88 if dashing else (1.0 - _charge_ratio * 0.04 - _jump_charge_ratio * 0.24)
	_squash_x = lerpf(_squash_x, target_sx, stretch_relax)
	_squash_y = lerpf(_squash_y, target_sy, stretch_relax)

	# Engine idle chug + driving bounce + charged jump crouch & tremble
	var drive_factor: float = clampf(absf(velocity.x) / 120.0, 0.0, 1.0)
	_engine_phase += delta * lerpf(6.5, 18.0, drive_factor)
	var chug_y: float = sin(_engine_phase) * engine_bob_amp * (1.35 if on_floor and drive_factor > 0.1 else 0.75)
	var crouch_y: float = _jump_charge_ratio * 4.5

	if _jump_tremble_remaining > 0.0:
		_jump_tremble_remaining = maxf(0.0, _jump_tremble_remaining - delta)

	var tremble_offset: Vector2 = Vector2.ZERO
	var active_tremble: float = 0.0
	if _jump_charge_ratio > 0.08:
		active_tremble = maxf(active_tremble, lerpf(0.5, 2.2, _jump_charge_ratio))
	if _jump_tremble_remaining > 0.0:
		active_tremble = maxf(active_tremble, _jump_tremble_strength * (_jump_tremble_remaining / 0.16))
	if active_tremble > 0.01:
		tremble_offset = Vector2(
			randf_range(-active_tremble, active_tremble),
			randf_range(-active_tremble * 0.45, active_tremble * 0.45)
		)

	# Chassis pitch from acceleration/speed + floor slope
	var accel_tilt: float = clampf(-local_vx * 0.00055, -0.09, 0.09)
	var hull_target_rot: float = (0.14 * _facing) if dashing else floor_tilt
	_hull.rotation = lerpf(_hull.rotation, hull_target_rot, 1.0 - exp(-10.0 * delta))

	_chassis_spring.position = _chassis_rest_pos + Vector2(0.0, _spring_y + chug_y + crouch_y) + tremble_offset
	_chassis_spring.scale = Vector2(_squash_x, _squash_y)
	_chassis_spring.rotation = lerpf(_chassis_spring.rotation, accel_tilt, 1.0 - exp(-10.0 * delta))

	# Keep turret riding smoothly on the spring-suspended hull!
	_turret_pivot.position.y = _turret_base_y + (_spring_y + chug_y + crouch_y) * 0.85 + tremble_offset.y

	# 3. Alive White Cat Pilot inside cockpit (head tracking, spring ears, blinking & charging squint)
	_cat_pilot.position = _cat_rest_pos + Vector2(-local_vx * 0.008, _spring_y * 0.35 - chug_y * 0.45)

	# Head tilts gently toward aim elevation
	var aim_dir: Vector2 = Vector2.RIGHT.rotated(aim_angle)
	var local_aim_y: float = aim_dir.y
	var target_head_rot: float = clampf(local_aim_y * 0.32, -0.28, 0.22)
	_cat_head.rotation = lerpf(_cat_head.rotation, target_head_rot, 1.0 - exp(-12.0 * delta))

	# Ear spring secondary motion (ears fold back on dash/speed, perk up when charging)
	var target_ear: float = (-0.42 if dashing else clampf(-local_vx * 0.0018, -0.22, 0.15)) + _charge_ratio * 0.14
	var ear_acc: float = 160.0 * (target_ear - _ear_angle) - 11.0 * _ear_vel
	_ear_vel += ear_acc * delta
	_ear_angle = clampf(_ear_angle + _ear_vel * delta, -0.65, 0.35)
	_ear_left.rotation = _ear_angle - 0.12
	_ear_right.rotation = _ear_angle + 0.12

	# Blink + hurt shock + charge focus squint
	if _blink_remaining > 0.0:
		_blink_remaining = maxf(0.0, _blink_remaining - delta)
	if _hurt_react_remaining > 0.0:
		_hurt_react_remaining = maxf(0.0, _hurt_react_remaining - delta)

	var eye_sx: float = 1.32 if _hurt_react_remaining > 0.0 else 1.0
	var eye_sy: float = 1.42 if _hurt_react_remaining > 0.0 else (0.12 if _blink_remaining > 0.0 else lerpf(1.0, 0.56, _charge_ratio))
	_eyes.scale.x = lerpf(_eyes.scale.x, eye_sx, 1.0 - exp(-24.0 * delta))
	_eyes.scale.y = lerpf(_eyes.scale.y, eye_sy, 1.0 - exp(-26.0 * delta))
	if _hurt_react_remaining > 0.0:
		_eyes.modulate = Color(1.5, 1.5, 1.5, 1.0)
	elif _charge_ratio >= 0.99:
		_eyes.modulate = Color(1.4, 1.15, 0.45, 1.0)
	else:
		_eyes.modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Swishing cat tail behind cockpit seat
	if is_instance_valid(_cat_tail):
		_tail_phase += delta * (12.0 if dashing or _charge_ratio > 0.2 else 4.2)
		var wag: float = sin(_tail_phase) * (3.6 if _charge_ratio > 0.2 else 2.2)
		_cat_tail.set_point_position(1, Vector2(-10.5, 1.0 + wag * 0.45))
		_cat_tail.set_point_position(2, Vector2(-13.5, -4.5 + wag))

	# Dash thruster flame cone & afterimage ghosts
	if is_instance_valid(_thruster_flame):
		_thruster_flame.visible = dashing
		if dashing:
			var flicker: float = randf_range(0.85, 1.25)
			_thruster_flame.scale = Vector2(flicker, randf_range(0.85, 1.15))

	if dashing:
		_ghost_cooldown -= delta
		if _ghost_cooldown <= 0.0:
			_ghost_cooldown = 0.045
			_spawn_dash_ghost()
	else:
		_ghost_cooldown = 0.0

	# Turret core breathing / charge pulse
	if is_instance_valid(_turret_core):
		var core_pulse: float = 1.0 + (0.22 if _charge_ratio > 0.1 else 0.08) * sin(Time.get_ticks_msec() * (0.022 if _charge_ratio > 0.1 else 0.006))
		_turret_core.scale = Vector2(core_pulse, core_pulse)
		if _soul_empowered or _charge_ratio >= 0.99:
			_turret_core.modulate = Color(1.35, 1.05, 0.35, 1.0)
		else:
			_turret_core.modulate = Color(0.7, 1.15, 1.35, 1.0)


func transform_cat_color(target_color: Color = Color(1.0, 0.86, 0.28, 1.0)) -> void:
	_soul_empowered = true
	_soul_color = target_color
	_squash_x = 0.88
	_squash_y = 1.18
	_spring_vy = -75.0
	_ear_vel = 6.5

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	if is_instance_valid(_cat_body):
		tween.tween_property(_cat_body, "color", target_color, 0.55)
	if is_instance_valid(_cat_head_shape):
		tween.tween_property(_cat_head_shape, "color", target_color, 0.55)
	if is_instance_valid(_ear_left_outer):
		tween.tween_property(_ear_left_outer, "color", target_color, 0.55)
	if is_instance_valid(_ear_right_outer):
		tween.tween_property(_ear_right_outer, "color", target_color, 0.55)
	if is_instance_valid(_cat_tail):
		tween.tween_property(_cat_tail, "default_color", target_color, 0.55)
	if is_instance_valid(_porthole):
		tween.tween_property(_porthole, "color", target_color, 0.55)
	if is_instance_valid(_barrel_band):
		tween.tween_property(_barrel_band, "color", target_color, 0.55)
	if is_instance_valid(_mecha_light):
		tween.tween_property(_mecha_light, "color", Color(1.0, 0.9, 0.42, 1.0), 0.55)
		tween.tween_property(_mecha_light, "energy", 1.35, 0.55)


func _spawn_dash_ghost() -> void:
	var parent_scene: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if parent_scene == null:
		return
	var ghost: Polygon2D = Polygon2D.new()
	ghost.polygon = _ghost_shell_points
	ghost.color = Color(0.32, 0.92, 1.0, 0.44)
	ghost.global_position = global_position
	ghost.scale = Vector2(_facing, 1.0)
	ghost.z_index = 1
	parent_scene.add_child(ghost)

	var tween: Tween = ghost.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "scale", Vector2(_facing * 1.08, 0.94), 0.22)
	tween.chain().tween_callback(ghost.queue_free)


func _update_tread_lugs() -> void:
	if not is_instance_valid(_tread_lugs):
		return
	var count: int = _tread_lugs.get_child_count()
	if count <= 0:
		return
	# Orbit lugs smoothly around a rounded pill loop (half-width 20, radius 6.5, center y = 15.5)
	var half_w: float = 18.0
	var r: float = 6.5
	var cy: float = 15.5
	for i in count:
		var lug: Node2D = _tread_lugs.get_child(i) as Node2D
		if lug == null:
			continue
		var t: float = fposmod((float(i) / float(count)) + _tread_offset, 1.0)
		var pos: Vector2 = _pill_point(t, half_w, r)
		lug.position = Vector2(pos.x, cy + pos.y)


func _pill_point(t: float, half_w: float, r: float) -> Vector2:
	# 0.0..0.35 top straight, 0.35..0.5 right arc, 0.5..0.85 bottom straight, 0.85..1.0 left arc
	if t < 0.35:
		var u: float = t / 0.35
		return Vector2(lerpf(-half_w, half_w, u), -r)
	elif t < 0.5:
		var u: float = (t - 0.35) / 0.15
		var a: float = lerpf(-PI * 0.5, PI * 0.5, u)
		return Vector2(half_w + cos(a) * r, sin(a) * r)
	elif t < 0.85:
		var u: float = (t - 0.5) / 0.35
		return Vector2(lerpf(half_w, -half_w, u), r)
	else:
		var u: float = (t - 0.85) / 0.15
		var a: float = lerpf(PI * 0.5, PI * 1.5, u)
		return Vector2(-half_w + cos(a) * r, sin(a) * r)


func trigger_jump(charge_ratio: float = 0.0) -> void:
	var ratio: float = clampf(charge_ratio, 0.0, 1.0)
	_squash_x = lerpf(0.86, 0.72, ratio)
	_squash_y = lerpf(1.18, 1.36, ratio)
	_spring_vy = lerpf(-55.0, -110.0, ratio)
	_ear_vel = lerpf(-4.5, -8.5, ratio)
	if ratio > 0.15:
		_jump_tremble_remaining = 0.16
		_jump_tremble_strength = lerpf(1.2, 2.8, ratio)


func trigger_land(impact_speed: float) -> void:
	var strength: float = clampf(impact_speed / 450.0, 0.35, 1.2)
	_squash_x = 1.0 + 0.18 * strength
	_squash_y = 1.0 - 0.18 * strength
	_spring_vy = 85.0 * strength
	_ear_vel = 5.0 * strength


func trigger_fire(charged: bool) -> void:
	var power: float = 1.5 if charged else 0.85
	_squash_x = 1.0 + 0.08 * power
	_squash_y = 1.0 - 0.07 * power
	_spring_vy += 32.0 * power
	_ear_vel -= 3.0 * power


func trigger_dash() -> void:
	_squash_x = 1.22
	_squash_y = 0.82
	_ear_vel = -6.5
	_ghost_cooldown = 0.0
	_spawn_dash_ghost()


func trigger_hurt() -> void:
	_hurt_react_remaining = 0.55
	_squash_x = 0.84
	_squash_y = 1.22
	_spring_vy = -70.0
	_ear_vel = -9.5


func _on_blink_timer_timeout() -> void:
	_blink_remaining = 0.11
	_blink_timer.wait_time = randf_range(2.4, 5.0)
	_blink_timer.start()
