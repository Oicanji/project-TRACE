class_name MechaController
extends CharacterBody2D

signal vida_alterada(vida_atual: int, vida_maxima: int)
signal morreu

@export_group("Movement")
@export_range(50.0, 500.0, 5.0) var max_speed: float = 120.0
@export_range(100.0, 2000.0, 10.0) var acceleration: float = 420.0
@export_range(100.0, 2000.0, 10.0) var friction: float = 520.0
@export_range(50.0, 1500.0, 10.0) var air_acceleration: float = 200.0
@export_range(-900.0, -100.0, 10.0) var jump_velocity: float = -420.0
@export_range(0.5, 2.5, 0.05) var gravity_scale: float = 1.2
@export_range(0.0, 30.0, 0.5) var hull_tilt_speed: float = 8.0

@export_group("Dash")
@export_range(200.0, 1000.0, 10.0) var dash_speed: float = 460.0
@export_range(0.05, 0.6, 0.01) var dash_duration: float = 0.18
@export_range(0.2, 4.0, 0.05) var dash_cooldown: float = 1.15
@export var dash_invulnerable: bool = true

@export_group("Combat")
@export var projectile_scene: PackedScene = preload("res://components/mecha_projectile.tscn")
@export_range(0.05, 2.0, 0.05) var fire_cooldown: float = 0.48
@export_range(1.0, 40.0, 0.5) var turret_turn_speed: float = 10.0
@export_range(0.0, 20.0, 0.5) var recoil_distance: float = 7.0
@export_range(0.0, 200.0, 5.0) var recoil_kick_velocity: float = 55.0
@export_range(0.0, 35.0, 1.0) var max_downward_aim_deg: float = 12.0
@export_range(0.2, 2.5, 0.05) var charge_time: float = 0.70
@export_range(1, 10, 1) var normal_damage: int = 1
@export_range(1, 20, 1) var charged_damage: int = 3
@export_range(200.0, 1600.0, 10.0) var normal_projectile_speed: float = 720.0
@export_range(200.0, 1800.0, 10.0) var charged_projectile_speed: float = 860.0
@export_range(1.0, 3.0, 0.05) var charged_projectile_scale: float = 1.65

@export_group("Camera Shake")
@export_range(0.0, 30.0, 0.5) var fire_shake_strength: float = 4.5
@export_range(0.0, 35.0, 0.5) var charged_shake_strength: float = 8.5
@export_range(0.0, 30.0, 0.5) var dash_shake_strength: float = 3.0
@export_range(0.0, 40.0, 0.5) var damage_shake_strength: float = 11.0
@export_range(0.0, 20.0, 0.5) var landing_shake_strength: float = 3.5
@export_range(50.0, 800.0, 10.0) var landing_shake_min_speed: float = 260.0
@export_range(5.0, 80.0, 1.0) var shake_decay: float = 28.0

@export_group("Health")
@export_range(1, 20, 1) var vida_maxima: int = 5
@export_range(0.1, 5.0, 0.1) var tempo_invencibilidade: float = 1.0
@export var auto_reload_on_death: bool = true

@onready var _visuals: Node2D = $Visuals
@onready var _rig: MechaProceduralRig = $Visuals as MechaProceduralRig
@onready var _hull: Node2D = $Visuals/Hull
@onready var _turret_pivot: Node2D = $Visuals/TurretPivot
@onready var _barrel: Node2D = $Visuals/TurretPivot/Barrel
@onready var _muzzle: Marker2D = $Visuals/TurretPivot/Muzzle
@onready var _muzzle_flash: CPUParticles2D = $Visuals/TurretPivot/Muzzle/MuzzleFlash
@onready var _charge_aura: CanvasItem = $Visuals/TurretPivot/Muzzle/ChargeAura
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _tread_dust: CPUParticles2D = $TreadDust
@onready var _dash_thruster: CPUParticles2D = $DashThruster
@onready var _fire_cooldown_timer: Timer = $FireCooldownTimer
@onready var _invincibility_timer: Timer = $InvincibilityTimer
@onready var _dash_timer: Timer = $DashTimer
@onready var _dash_cooldown_timer: Timer = $DashCooldownTimer
@onready var _camera: Camera2D = $Camera2D
@onready var _crosshair: Node2D = $Crosshair
@onready var _crosshair_top: Polygon2D = $Crosshair/TickTop
@onready var _crosshair_bottom: Polygon2D = $Crosshair/TickBottom
@onready var _crosshair_left: Polygon2D = $Crosshair/TickLeft
@onready var _crosshair_right: Polygon2D = $Crosshair/TickRight
@onready var _crosshair_center: Polygon2D = $Crosshair/CenterDot

var vida: int = 5
var invencivel: bool = false
var esta_morto: bool = false

# Turret angle stored as offset from straight up (-PI / 2) so clamping and
# interpolation always arc cleanly over the top instead of swinging through treads.
var _turret_offset_from_up: float = PI * 0.5
var _barrel_rest_pos: Vector2 = Vector2.ZERO
var _recoil_tween: Tween
var _blink_tween: Tween
var _shake_strength: float = 0.0
var _was_on_floor: bool = true
var _last_air_vy: float = 0.0

var _is_dashing: bool = false
var _dash_dir: float = 1.0
var _is_charging: bool = false
var _charge_elapsed: float = 0.0
var _hitstop_active: bool = false


func _exit_tree() -> void:
	if _hitstop_active:
		Engine.time_scale = 1.0
		_hitstop_active = false


func _ready() -> void:
	vida = vida_maxima
	vida_alterada.emit(vida, vida_maxima)

	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(46.0)

	_barrel_rest_pos = _barrel.position
	_turret_pivot.rotation = -PI * 0.5 + _turret_offset_from_up
	_fire_cooldown_timer.wait_time = fire_cooldown
	_invincibility_timer.wait_time = tempo_invencibilidade
	_dash_timer.wait_time = dash_duration
	_dash_cooldown_timer.wait_time = dash_cooldown
	_update_charge_visuals()


func _process(delta: float) -> void:
	_update_camera_shake(delta)
	_update_crosshair()


func _physics_process(delta: float) -> void:
	if esta_morto:
		return

	_handle_dash_input()
	_apply_gravity(delta)
	_handle_movement(delta)
	_handle_turret_aim(delta)
	_handle_fire_input(delta)

	if not is_on_floor():
		_last_air_vy = velocity.y

	move_and_slide()

	if not _was_on_floor and is_on_floor():
		if is_instance_valid(_rig):
			_rig.trigger_land(_last_air_vy)
		if _last_air_vy >= landing_shake_min_speed:
			apply_camera_shake(landing_shake_strength)
		_last_air_vy = 0.0
	_was_on_floor = is_on_floor()

	_update_visual_feedback(delta)


func _handle_dash_input() -> void:
	if _is_dashing or not _dash_cooldown_timer.is_stopped():
		return
	if Input.is_action_just_pressed("dash"):
		var move_dir: float = Input.get_axis("esquerda", "direita")
		var chosen_dir: float = move_dir if not is_zero_approx(move_dir) else _hull.scale.x
		start_dash(chosen_dir)


func start_dash(direction: float = 1.0) -> void:
	if _is_dashing or esta_morto or not _dash_cooldown_timer.is_stopped():
		return

	_is_dashing = true
	_dash_dir = -1.0 if direction < 0.0 else 1.0
	_dash_timer.start(dash_duration)
	_dash_cooldown_timer.start(dash_cooldown)

	velocity.x = _dash_dir * dash_speed
	velocity.y = minf(velocity.y, 0.0) * 0.2
	apply_camera_shake(dash_shake_strength)
	if is_instance_valid(_rig):
		_rig.trigger_dash()

	if is_instance_valid(_dash_thruster):
		_dash_thruster.position = Vector2(-24.0 * _dash_dir, 4.0)
		_dash_thruster.direction = Vector2(-_dash_dir, -0.15)
		_dash_thruster.emitting = true

	_visuals.modulate = Color(0.65, 1.35, 1.5, _visuals.modulate.a)


func _apply_gravity(delta: float) -> void:
	if _is_dashing:
		velocity.y += get_gravity().y * 0.12 * delta
		return
	if not is_on_floor():
		velocity.y += get_gravity().y * gravity_scale * delta


func _handle_movement(delta: float) -> void:
	if _is_dashing:
		velocity.x = _dash_dir * dash_speed
		return

	var direction: float = Input.get_axis("esquerda", "direita")

	if is_on_floor():
		if not is_zero_approx(direction):
			velocity.x = move_toward(velocity.x, direction * max_speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

		if Input.is_action_just_pressed("pulo"):
			velocity.y = jump_velocity
			if is_instance_valid(_rig):
				_rig.trigger_jump()
	else:
		if not is_zero_approx(direction):
			velocity.x = move_toward(velocity.x, direction * max_speed, air_acceleration * delta)


func _handle_turret_aim(delta: float) -> void:
	var to_mouse: Vector2 = get_global_mouse_position() - _turret_pivot.global_position
	if to_mouse.length_squared() < 1.0:
		return

	if to_mouse.x < -2.0:
		_hull.scale.x = -1.0
	elif to_mouse.x > 2.0:
		_hull.scale.x = 1.0

	_turret_pivot.position.x = -12.0 * _hull.scale.x

	var raw_angle: float = to_mouse.angle()
	var raw_offset: float = wrapf(raw_angle - (-PI * 0.5), -PI, PI)
	var max_offset: float = PI * 0.5 + deg_to_rad(max_downward_aim_deg)
	var target_offset: float = clampf(raw_offset, -max_offset, max_offset)

	var weight: float = 1.0 - exp(-turret_turn_speed * delta)
	_turret_offset_from_up = lerpf(_turret_offset_from_up, target_offset, weight)
	_turret_pivot.rotation = -PI * 0.5 + _turret_offset_from_up

	if _barrel is Sprite2D:
		(_barrel as Sprite2D).flip_v = cos(_turret_pivot.rotation) < 0.0


func _handle_fire_input(delta: float) -> void:
	if Input.is_action_pressed("ataque"):
		if not _is_charging and _fire_cooldown_timer.is_stopped():
			_is_charging = true
			_charge_elapsed = 0.0
		elif _is_charging:
			_charge_elapsed = minf(_charge_elapsed + delta, charge_time)
	elif _is_charging:
		var charged: bool = _charge_elapsed >= charge_time
		_is_charging = false
		_charge_elapsed = 0.0
		_fire_cannon(charged)

	_update_charge_visuals()


func _fire_cannon(charged: bool = false) -> void:
	if projectile_scene == null:
		return

	_fire_cooldown_timer.start(fire_cooldown)

	var projectile: Node2D = projectile_scene.instantiate() as Node2D
	if projectile == null:
		return

	projectile.global_position = _muzzle.global_position
	projectile.global_rotation = _turret_pivot.global_rotation

	if projectile.has_method("configure_shot"):
		if charged:
			projectile.call("configure_shot", charged_damage, charged_projectile_speed, charged_projectile_scale, true)
		else:
			projectile.call("configure_shot", normal_damage, normal_projectile_speed, 1.0, false)

	var parent_scene: Node = get_tree().current_scene
	if parent_scene:
		parent_scene.add_child(projectile)
	else:
		get_parent().add_child(projectile)

	var fire_dir: Vector2 = Vector2.RIGHT.rotated(_turret_pivot.global_rotation)
	var kick: float = recoil_kick_velocity * (1.75 if charged else 1.0)
	if not _is_dashing:
		velocity.x -= fire_dir.x * kick

	apply_camera_shake(charged_shake_strength if charged else fire_shake_strength)
	_play_recoil(1.45 if charged else 1.0)
	if is_instance_valid(_rig):
		_rig.trigger_fire(charged)
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.restart()


func _update_charge_visuals() -> void:
	if not is_instance_valid(_charge_aura):
		return
	var ratio: float = clampf(_charge_elapsed / maxf(charge_time, 0.01), 0.0, 1.0) if _is_charging else 0.0
	if ratio <= 0.05:
		_charge_aura.visible = false
		return
	_charge_aura.visible = true
	var pulse: float = 1.0 + 0.14 * sin(Time.get_ticks_msec() * 0.025) if ratio >= 1.0 else 1.0
	var s: float = lerpf(0.35, 1.35, ratio) * pulse
	if _charge_aura is Node2D:
		(_charge_aura as Node2D).scale = Vector2(s, s)
	_charge_aura.modulate = Color(1.4, 1.05, 0.3, 0.95) if ratio >= 1.0 else Color(0.4, 1.1, 1.4, 0.72)


func _update_crosshair() -> void:
	if not is_instance_valid(_crosshair):
		return
	_crosshair.visible = not esta_morto
	if esta_morto:
		return

	_crosshair.global_position = get_global_mouse_position()

	var ratio: float = clampf(_charge_elapsed / maxf(charge_time, 0.01), 0.0, 1.0) if _is_charging else 0.0
	var gap: float = lerpf(11.0, 5.0, ratio)
	_crosshair_top.position = Vector2(0.0, -gap)
	_crosshair_bottom.position = Vector2(0.0, gap)
	_crosshair_left.position = Vector2(-gap, 0.0)
	_crosshair_right.position = Vector2(gap, 0.0)

	var tick_color: Color = Color(1.0, 0.85, 0.25, 0.95) if ratio >= 1.0 else Color(0.4, 0.92, 1.0, 0.88)
	_crosshair_top.color = tick_color
	_crosshair_bottom.color = tick_color
	_crosshair_left.color = tick_color
	_crosshair_right.color = tick_color

	var dash_ready: bool = _dash_cooldown_timer.is_stopped() and not _is_dashing
	_crosshair_center.color = Color(0.95, 1.0, 1.0, 0.95) if dash_ready else Color(0.55, 0.62, 0.7, 0.45)


func apply_camera_shake(strength: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)


func absorver_alma_humana(nova_cor: Color = Color(1.0, 0.86, 0.28, 1.0)) -> void:
	apply_camera_shake(6.0)
	if is_instance_valid(_rig):
		_rig.transform_cat_color(nova_cor)


func trigger_hitstop(duration: float = 0.045) -> void:
	if _hitstop_active or duration <= 0.0:
		return
	_hitstop_active = true
	Engine.time_scale = 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


func _update_camera_shake(delta: float) -> void:
	if not is_instance_valid(_camera):
		return
	if _shake_strength > 0.01:
		_camera.offset = Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength)
		)
		_shake_strength = move_toward(_shake_strength, 0.0, shake_decay * delta)
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


func _play_recoil(multiplier: float = 1.0) -> void:
	if _recoil_tween and _recoil_tween.is_valid():
		_recoil_tween.kill()

	_barrel.position = _barrel_rest_pos - Vector2(recoil_distance * multiplier, 0.0)
	_recoil_tween = create_tween()
	_recoil_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_recoil_tween.tween_property(_barrel, "position", _barrel_rest_pos, minf(0.18, fire_cooldown * 0.8))


func _update_visual_feedback(delta: float) -> void:
	var target_tilt: float = 0.0
	if is_on_floor():
		target_tilt = clampf(get_floor_normal().angle() + PI * 0.5, -0.35, 0.35)

	if is_instance_valid(_rig):
		var charge_ratio: float = clampf(_charge_elapsed / maxf(charge_time, 0.01), 0.0, 1.0) if _is_charging else 0.0
		_rig.update_rig(
			delta,
			velocity,
			is_on_floor(),
			target_tilt,
			_hull.scale.x,
			_turret_pivot.rotation,
			charge_ratio,
			_is_dashing
		)
	else:
		_hull.rotation = lerpf(_hull.rotation, target_tilt, 1.0 - exp(-hull_tilt_speed * delta))

	if is_instance_valid(_tread_dust):
		var moving_on_ground: bool = is_on_floor() and absf(velocity.x) > 25.0 and not _is_dashing
		_tread_dust.emitting = moving_on_ground


func tomar_dano(quantidade: int = 1) -> void:
	if esta_morto or invencivel or quantidade <= 0:
		return
	if _is_dashing and dash_invulnerable:
		return

	vida = clampi(vida - quantidade, 0, vida_maxima)
	vida_alterada.emit(vida, vida_maxima)
	apply_camera_shake(damage_shake_strength)
	if is_instance_valid(_rig):
		_rig.trigger_hurt()
	trigger_hitstop(0.05)

	if vida <= 0:
		morrer()
	else:
		_iniciar_invencibilidade()


func _iniciar_invencibilidade() -> void:
	invencivel = true
	_invincibility_timer.start(tempo_invencibilidade)

	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()

	_blink_tween = create_tween()
	var piscadas: int = maxi(1, int(tempo_invencibilidade / 0.2))
	for i in piscadas:
		_blink_tween.tween_property(_visuals, "modulate:a", 0.35, 0.1)
		_blink_tween.tween_property(_visuals, "modulate:a", 1.0, 0.1)


func morrer() -> void:
	if esta_morto:
		return

	esta_morto = true
	_is_dashing = false
	_is_charging = false
	_charge_elapsed = 0.0
	_update_charge_visuals()
	set_physics_process(false)
	if is_instance_valid(_tread_dust):
		_tread_dust.emitting = false
	if is_instance_valid(_dash_thruster):
		_dash_thruster.emitting = false
	morreu.emit()
	if auto_reload_on_death:
		get_tree().call_deferred("reload_current_scene")


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		tomar_dano(1)


func _on_dash_timer_timeout() -> void:
	_is_dashing = false
	velocity.x = _dash_dir * max_speed * 0.85
	if is_instance_valid(_dash_thruster):
		_dash_thruster.emitting = false
	_visuals.modulate = Color(1.0, 1.0, 1.0, _visuals.modulate.a)


func _on_invincibility_timer_timeout() -> void:
	if esta_morto:
		return

	invencivel = false
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	_visuals.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if is_instance_valid(_hurtbox):
		for area: Area2D in _hurtbox.get_overlapping_areas():
			if area.is_in_group("enemy"):
				tomar_dano(1)
				break
