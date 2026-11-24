class_name ColossalBoss
extends CharacterBody2D

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://components/damage_number.tscn")
const HIT_BURST_SCENE: PackedScene = preload("res://components/hit_burst.tscn")

signal vida_alterada(vida_atual: int, vida_maxima: int)
signal stagger_alterado(atual: float, maximo: float)
signal fase_alterada(fase: int)
signal morreu

enum State {
	INTRO,
	STALK,
	STOMP_TELEGRAPH,
	VOLLEY_TELEGRAPH,
	VOLLEY_FIRING,
	CLAW_TELEGRAPH,
	CLAW_SMASH,
	LEAP_TELEGRAPH,
	LEAP_AIR,
	BEAM_TELEGRAPH,
	BEAM_SWEEP,
	TANTRUM,
	RECOVER,
	STAGGERED,
	DYING,
}

@export_group("Identity & Health")
@export var boss_name: String = "CARCAÇA EVOLUÍDA — PROTÓTIPO ÔMEGA"
@export_range(20, 400, 5) var vida_maxima: int = 120
@export_range(0.4, 0.9, 0.05) var phase2_threshold: float = 0.70
@export_range(0.1, 0.6, 0.05) var phase3_threshold: float = 0.35
@export_range(4.0, 40.0, 1.0) var stagger_threshold_p1: float = 12.0
@export_range(4.0, 40.0, 1.0) var stagger_threshold_p2: float = 15.0
@export_range(1, 10, 1) var stagger_wake_hits: int = 4

@export_group("Movement")
@export_range(0.0, 200.0, 5.0) var stalk_speed_p1: float = 38.0
@export_range(0.0, 250.0, 5.0) var stalk_speed_p2: float = 54.0
@export_range(0.0, 280.0, 5.0) var stalk_speed_p3: float = 68.0
@export_range(120.0, 600.0, 10.0) var preferred_distance: float = 300.0
@export var arena_min_x: float = 470.0
@export var arena_max_x: float = 1230.0
@export var arena_floor_y: float = 520.0

@export_group("Attacks")
@export var shockwave_scene: PackedScene = preload("res://components/boss_shockwave.tscn")
@export var projectile_scene: PackedScene = preload("res://components/boss_projectile.tscn")
@export var debris_scene: PackedScene = preload("res://components/boss_debris.tscn")
@export_range(0.4, 3.5, 0.05) var attack_cooldown_p1: float = 1.55
@export_range(0.3, 3.0, 0.05) var attack_cooldown_p2: float = 1.1
@export_range(0.25, 2.5, 0.05) var attack_cooldown_p3: float = 0.85
@export_range(120.0, 700.0, 10.0) var shockwave_speed_p1: float = 285.0
@export_range(150.0, 800.0, 10.0) var shockwave_speed_p2: float = 365.0
@export_range(150.0, 800.0, 10.0) var orb_speed_p1: float = 340.0
@export_range(200.0, 900.0, 10.0) var orb_speed_p2: float = 430.0
@export_range(300.0, 1400.0, 20.0) var beam_length: float = 950.0

@export_group("Hit Feedback")
@export_range(0.0, 30.0, 0.5) var hit_shake_strength: float = 6.5
@export_range(0.0, 35.0, 0.5) var crit_shake_strength: float = 13.5
@export_range(5.0, 80.0, 1.0) var hit_shake_decay: float = 36.0
@export_range(0.0, 40.0, 1.0) var stomp_camera_shake: float = 10.5
@export_range(0.0, 40.0, 1.0) var death_camera_shake: float = 20.0

@onready var _visuals: Node2D = $Visuals
@onready var _rig: ColossalBossRig = $Visuals as ColossalBossRig
@onready var _core_glow: Node2D = $Visuals/Torso/CoreGlow
@onready var _visor_eye: Node2D = $Visuals/Torso/Head/VisorEye
@onready var _core_light: PointLight2D = get_node_or_null("Visuals/Torso/CoreGlow/CoreLight") as PointLight2D
@onready var _visor_origin: Marker2D = $VisorOrigin
@onready var _core_weakpoint: Area2D = $CoreWeakpoint
@onready var _claw_area: Area2D = $ClawArea
@onready var _claw_collision: CollisionShape2D = $ClawArea/CollisionShape2D
@onready var _beam_pivot: Node2D = $BeamPivot
@onready var _telegraph_line: Line2D = $BeamPivot/TelegraphLine
@onready var _beam_line: Line2D = $BeamPivot/BeamLine
@onready var _beam_area: Area2D = $BeamPivot/BeamArea
@onready var _beam_collision: CollisionShape2D = $BeamPivot/BeamArea/CollisionShape2D
@onready var _hit_sparks: CPUParticles2D = $HitSparks
@onready var _crit_sparks: CPUParticles2D = $CritSparks
@onready var _state_timer: Timer = $StateTimer
@onready var _sub_action_timer: Timer = $SubActionTimer

var vida: int = 120
var fase: int = 1
var esta_morto: bool = false
var current_state: State = State.INTRO
var stagger_points: float = 0.0

var _facing: float = -1.0
var _last_attack: int = -1
var _shake_strength: float = 0.0
var _visuals_rest_pos: Vector2 = Vector2.ZERO
var _flash_tween: Tween
var _beam_start_angle: float = PI * 0.75
var _beam_end_angle: float = PI * 0.55
var _beam_elapsed: float = 0.0
var _beam_duration: float = 1.2

var _volley_remaining: int = 0
var _stagger_hits_taken: int = 0
var _tantrum_waves_remaining: int = 0
var _death_blasts_remaining: int = 0


func _ready() -> void:
	vida = vida_maxima
	_visuals_rest_pos = _visuals.position
	_set_beam_active(false)
	_set_claw_active(false)
	_telegraph_line.visible = false
	if is_instance_valid(_rig) and not _rig.footstep_planted.is_connected(_on_footstep_planted):
		_rig.footstep_planted.connect(_on_footstep_planted)
	vida_alterada.emit(vida, vida_maxima)
	stagger_alterado.emit(stagger_points, _get_stagger_threshold())
	_enter_state(State.INTRO)


func _physics_process(delta: float) -> void:
	if esta_morto:
		return

	if not is_on_floor():
		velocity.y += get_gravity().y * (1.25 if current_state == State.LEAP_AIR else 1.0) * delta

	match current_state:
		State.INTRO:
			velocity.x = 0.0
			_face_player()
		State.STALK:
			_process_stalk()
		State.VOLLEY_TELEGRAPH:
			velocity.x = 0.0
			_update_volley_telegraph()
		State.LEAP_AIR:
			if global_position.x <= arena_min_x and velocity.x < 0.0:
				velocity.x = 0.0
			elif global_position.x >= arena_max_x and velocity.x > 0.0:
				velocity.x = 0.0
		State.BEAM_TELEGRAPH:
			velocity.x = 0.0
			_update_beam_telegraph()
		State.BEAM_SWEEP:
			velocity.x = 0.0
			_process_beam_sweep(delta)
		_:
			velocity.x = 0.0

	var was_air_leap: bool = current_state == State.LEAP_AIR and not is_on_floor()
	move_and_slide()

	if was_air_leap and is_on_floor():
		execute_stomp_attack()
		_enter_state(State.RECOVER)

	if is_instance_valid(_rig):
		_rig.update_rig(delta, int(current_state), velocity, fase, _beam_pivot.rotation, _facing)
	_update_visual_effects(delta)


func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _get_stagger_threshold() -> float:
	return stagger_threshold_p2 if fase >= 2 else stagger_threshold_p1


func is_core_exposed() -> bool:
	return current_state == State.STAGGERED or current_state == State.RECOVER


func _face_player() -> void:
	var player: Node2D = _get_player()
	if not is_instance_valid(player):
		return
	var dx: float = player.global_position.x - global_position.x
	if absf(dx) > 12.0:
		_facing = -1.0 if dx < 0.0 else 1.0
		_visuals.scale.x = _facing
		_visor_origin.position.x = 30.0 * _facing
		_beam_pivot.position = _visor_origin.position
		_claw_area.position.x = 128.0 * _facing


func _process_stalk() -> void:
	_face_player()
	var player: Node2D = _get_player()
	if not is_instance_valid(player):
		velocity.x = 0.0
		return

	var dx: float = player.global_position.x - global_position.x
	var abs_dx: float = absf(dx)
	var speed: float = stalk_speed_p3 if fase >= 3 else (stalk_speed_p2 if fase >= 2 else stalk_speed_p1)

	if abs_dx > preferred_distance + 40.0:
		velocity.x = signf(dx) * speed
	elif abs_dx < preferred_distance - 100.0:
		velocity.x = -signf(dx) * speed * 0.65
	else:
		velocity.x = 0.0

	if global_position.x <= arena_min_x and velocity.x < 0.0:
		velocity.x = 0.0
	elif global_position.x >= arena_max_x and velocity.x > 0.0:
		velocity.x = 0.0


func _enter_state(next_state: State) -> void:
	current_state = next_state
	_telegraph_line.visible = false
	_set_beam_active(false)
	_set_claw_active(false)
	_sub_action_timer.stop()

	match next_state:
		State.INTRO:
			_face_player()
			_state_timer.start(1.35)
		State.STALK:
			var wait: float = attack_cooldown_p3 if fase >= 3 else (attack_cooldown_p2 if fase >= 2 else attack_cooldown_p1)
			_state_timer.start(wait)
		State.STOMP_TELEGRAPH:
			_face_player()
			# Delayed False Knight-style wind-up
			_state_timer.start(0.62 if fase >= 2 else 0.82)
		State.VOLLEY_TELEGRAPH:
			_face_player()
			_telegraph_line.visible = true
			_state_timer.start(0.45 if fase >= 2 else 0.6)
		State.VOLLEY_FIRING:
			_volley_remaining = 4 if fase >= 3 else (3 if fase >= 2 else 2)
			_fire_single_volley_orb()
			_sub_action_timer.start(0.18 if fase >= 2 else 0.24)
			_state_timer.start(2.0)
		State.CLAW_TELEGRAPH:
			_face_player()
			_state_timer.start(0.48 if fase >= 2 else 0.62)
		State.CLAW_SMASH:
			execute_claw_smash()
			_state_timer.start(0.24)
		State.LEAP_TELEGRAPH:
			_face_player()
			_state_timer.start(0.50)
		State.LEAP_AIR:
			execute_leap()
			_state_timer.start(2.2)
		State.BEAM_TELEGRAPH:
			_face_player()
			_prepare_beam_angles()
			_telegraph_line.visible = true
			_state_timer.start(0.68 if fase >= 3 else 0.82)
		State.BEAM_SWEEP:
			_beam_elapsed = 0.0
			_beam_duration = 1.0 if fase >= 3 else 1.2
			_beam_pivot.rotation = _beam_start_angle
			_set_beam_active(true)
			_state_timer.start(_beam_duration)
		State.TANTRUM:
			_tantrum_waves_remaining = 6
			spawn_tantrum_debris()
			_sub_action_timer.start(0.42)
			_state_timer.start(2.9)
		State.RECOVER:
			_state_timer.start(0.68 if fase >= 3 else (0.78 if fase >= 2 else 1.0))
		State.STAGGERED:
			_stagger_hits_taken = 0
			_state_timer.start(3.5)
		State.DYING:
			_death_blasts_remaining = 6
			_spawn_death_explosion()
			_sub_action_timer.start(0.28)
			_state_timer.start(2.2)
		_:
			_state_timer.start(1.0)


func _choose_next_attack() -> void:
	var player: Node2D = _get_player()
	var dist: float = absf(player.global_position.x - global_position.x) if is_instance_valid(player) else 350.0

	# Context-aware Hollow Knight spatial respect: punish close camping with Claw Smash or Leap!
	if dist < 225.0 and _last_attack != 2:
		_last_attack = 2
		_enter_state(State.CLAW_TELEGRAPH)
		return

	var candidates: Array[int] = [0, 1] # 0=Stomp, 1=Volley
	if fase >= 2:
		candidates.append(3) # 3=Leap Slam
		candidates.append(4) # 4=Beam Sweep
	if fase >= 3:
		candidates.append(5) # 5=Collapse Tantrum

	if _last_attack in candidates and candidates.size() > 1:
		candidates.erase(_last_attack)

	var pick: int = candidates[randi() % candidates.size()]
	_last_attack = pick

	match pick:
		0:
			_enter_state(State.STOMP_TELEGRAPH)
		1:
			_enter_state(State.VOLLEY_TELEGRAPH)
		2:
			_enter_state(State.CLAW_TELEGRAPH)
		3:
			_enter_state(State.LEAP_TELEGRAPH)
		4:
			_enter_state(State.BEAM_TELEGRAPH)
		5:
			_enter_state(State.TANTRUM)
		_:
			_enter_state(State.STOMP_TELEGRAPH)


func execute_stomp_attack() -> void:
	if is_instance_valid(_rig):
		_rig.trigger_stomp_slam()
	_notify_player_camera_shake(stomp_camera_shake)
	if shockwave_scene == null:
		return

	var wave_speed: float = shockwave_speed_p2 if fase >= 2 else shockwave_speed_p1
	var parent_scene: Node = get_tree().current_scene if get_tree().current_scene else get_parent()

	for dir: float in [-1.0, 1.0]:
		var wave: Node2D = shockwave_scene.instantiate() as Node2D
		if wave == null:
			continue
		wave.global_position = Vector2(global_position.x + dir * 68.0, arena_floor_y)
		if wave.has_method("configure"):
			wave.call("configure", dir, wave_speed)
		parent_scene.add_child(wave)


func execute_claw_smash() -> void:
	_set_claw_active(true)
	_notify_player_camera_shake(9.0)
	var impact_pos: Vector2 = _claw_area.global_position + Vector2(0.0, 48.0)
	_spawn_burst(impact_pos, Color(1.0, 0.35, 0.25, 1.0), 1.35, 20)


func execute_leap() -> void:
	var player: Node2D = _get_player()
	var target_x: float = (arena_min_x + arena_max_x) * 0.5
	if is_instance_valid(player):
		# Aim toward the player's side, clamped comfortably inside the arena
		var desired_x: float = player.global_position.x - _facing * 90.0
		target_x = clampf(desired_x, arena_min_x + 40.0, arena_max_x - 40.0)
	var flight_time: float = 0.85
	velocity.y = -580.0
	velocity.x = clampf((target_x - global_position.x) / flight_time, -460.0, 460.0)
	if is_instance_valid(_rig):
		_rig.emit_footstep_dust()
	_notify_player_camera_shake(5.0)


func execute_volley_attack() -> void:
	_fire_single_volley_orb()


func _fire_single_volley_orb() -> void:
	if projectile_scene == null:
		return
	var player: Node2D = _get_player()
	var origin: Vector2 = _visor_origin.global_position
	var base_angle: float = PI if _facing < 0.0 else 0.0
	if is_instance_valid(player):
		base_angle = (player.global_position - origin).angle()

	# Slight rhythmic vertical fan like Grimm's Fire Bats
	var fan_offset: float = deg_to_rad(randf_range(-5.5, 5.5))
	var orb: Node2D = projectile_scene.instantiate() as Node2D
	if orb == null:
		return
	orb.global_position = origin
	orb.global_rotation = base_angle + fan_offset
	if orb.has_method("configure"):
		orb.call("configure", orb_speed_p2 if fase >= 2 else orb_speed_p1)
	var parent_scene: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	parent_scene.add_child(orb)
	_notify_player_camera_shake(3.0)


func spawn_tantrum_debris() -> void:
	if is_instance_valid(_rig):
		_rig.trigger_stomp_slam()
	_notify_player_camera_shake(6.5)
	if debris_scene == null:
		return

	var parent_scene: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	var player: Node2D = _get_player()
	var drop_x: float = randf_range(120.0, 1580.0)
	if is_instance_valid(player) and randf() < 0.55:
		drop_x = clampf(player.global_position.x + randf_range(-90.0, 90.0), 90.0, 1610.0)

	var debris: Node2D = debris_scene.instantiate() as Node2D
	if debris:
		debris.global_position = Vector2(drop_x, -90.0)
		parent_scene.add_child(debris)
		if debris.has_method("configure_drop"):
			debris.call("configure_drop", arena_floor_y, 0.72)


func _update_volley_telegraph() -> void:
	var player: Node2D = _get_player()
	if not is_instance_valid(player):
		return
	var origin: Vector2 = _beam_pivot.global_position
	var angle: float = (player.global_position - origin).angle()
	_beam_pivot.rotation = angle
	var pulse: float = 0.45 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.02))
	_telegraph_line.default_color = Color(1.0, 0.25, 0.25, pulse)


func _prepare_beam_angles() -> void:
	if _facing < 0.0:
		_beam_start_angle = deg_to_rad(168.0)
		_beam_end_angle = deg_to_rad(118.0)
	else:
		_beam_start_angle = deg_to_rad(12.0)
		_beam_end_angle = deg_to_rad(62.0)
	_beam_pivot.rotation = _beam_start_angle


func _update_beam_telegraph() -> void:
	_beam_pivot.rotation = _beam_start_angle
	var pulse: float = 0.4 + 0.55 * absf(sin(Time.get_ticks_msec() * 0.028))
	_telegraph_line.default_color = Color(1.0, 0.35, 0.18, pulse)


func _process_beam_sweep(delta: float) -> void:
	_beam_elapsed += delta
	var t: float = clampf(_beam_elapsed / maxf(_beam_duration, 0.01), 0.0, 1.0)
	_beam_pivot.rotation = lerpf(_beam_start_angle, _beam_end_angle, t)
	_notify_player_camera_shake(2.5)


func _set_beam_active(active: bool) -> void:
	if is_instance_valid(_beam_line):
		_beam_line.visible = active
	if is_instance_valid(_beam_area):
		_beam_area.set_deferred("monitoring", active)
		_beam_area.set_deferred("monitorable", active)
	if is_instance_valid(_beam_collision):
		_beam_collision.set_deferred("disabled", not active)


func _set_claw_active(active: bool) -> void:
	if is_instance_valid(_claw_area):
		_claw_area.set_deferred("monitoring", active)
		_claw_area.set_deferred("monitorable", active)
	if is_instance_valid(_claw_collision):
		_claw_collision.set_deferred("disabled", not active)


func _update_visual_effects(delta: float) -> void:
	if _shake_strength > 0.01:
		_visuals.position = _visuals_rest_pos + Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength * 0.6, _shake_strength * 0.6)
		)
		_shake_strength = move_toward(_shake_strength, 0.0, hit_shake_decay * delta)
	elif _visuals.position != _visuals_rest_pos:
		_visuals.position = _visuals_rest_pos

	if is_instance_valid(_core_glow):
		var exposed: bool = is_core_exposed()
		var pulse_speed: float = 0.024 if exposed else (0.014 if fase >= 2 else 0.006)
		var amp: float = 0.28 if exposed else 0.14
		var pulse: float = 1.0 + amp * sin(Time.get_ticks_msec() * pulse_speed)
		_core_glow.scale = Vector2(pulse, pulse)


func is_weakpoint_hit(hit_pos: Vector2) -> bool:
	if not is_instance_valid(_core_weakpoint):
		return false
	return absf(hit_pos.y - _core_weakpoint.global_position.y) <= 36.0


func tomar_dano(quantidade: int = 1) -> void:
	tomar_dano_detalhado(quantidade, false, global_position + Vector2(0.0, -40.0), false)


func tomar_dano_critico(quantidade: int = 1, critico: bool = false) -> void:
	if esta_morto or current_state == State.INTRO or current_state == State.DYING or quantidade <= 0:
		return
	_apply_damage_internal(quantidade, critico, false, global_position + Vector2(0.0, -58.0))


func tomar_dano_detalhado(base_damage: int, is_charged: bool, hit_pos: Vector2, weakpoint_overlap: bool = false) -> bool:
	if esta_morto or current_state == State.INTRO or current_state == State.DYING or base_damage <= 0:
		return false

	var exposed: bool = is_core_exposed()
	var is_crit: bool = exposed and (weakpoint_overlap or is_weakpoint_hit(hit_pos))
	var final_damage: int = base_damage * 3 if is_crit else base_damage

	_apply_damage_internal(final_damage, is_crit, is_charged, hit_pos)
	return is_crit


func _apply_damage_internal(final_damage: int, critico: bool, is_charged: bool, hit_pos: Vector2) -> void:
	vida = clampi(vida - final_damage, 0, vida_maxima)
	vida_alterada.emit(vida, vida_maxima)
	_play_hit_feedback(critico, is_charged)

	# Handle False Knight-style stagger buildup vs. stagger wake-up
	if vida > 0:
		if current_state == State.STAGGERED:
			_stagger_hits_taken += 1
			if _stagger_hits_taken >= stagger_wake_hits:
				execute_stomp_attack()
				_enter_state(State.STALK)
		else:
			stagger_points += 3.0 if is_charged else 1.0
			var threshold: float = _get_stagger_threshold()
			stagger_alterado.emit(stagger_points, threshold)
			if stagger_points >= threshold and current_state != State.LEAP_AIR:
				_trigger_stagger_break()

	# Check Phase 2 (70%) and Phase 3 (35%) escalations
	if vida > 0:
		var hp_ratio: float = float(vida) / float(vida_maxima)
		if fase == 1 and hp_ratio <= phase2_threshold:
			_enter_phase(2)
		elif fase == 2 and hp_ratio <= phase3_threshold:
			_enter_phase(3)

	if vida <= 0:
		_enter_state(State.DYING)


func _trigger_stagger_break() -> void:
	stagger_points = 0.0
	stagger_alterado.emit(stagger_points, _get_stagger_threshold())
	_notify_player_camera_shake(11.0)
	_notify_player_hitstop(0.06)
	_spawn_burst(global_position + Vector2(0.0, -58.0), Color(0.45, 0.95, 1.0, 1.0), 1.85, 30)
	_enter_state(State.STAGGERED)


func _enter_phase(new_fase: int) -> void:
	fase = new_fase
	fase_alterada.emit(fase)
	_notify_player_camera_shake(13.0)
	_notify_player_hitstop(0.065)
	_shake_strength = maxf(_shake_strength, 15.0)

	if fase == 2:
		_spawn_burst(global_position + Vector2(0.0, -58.0), Color(1.0, 0.78, 0.24, 1.0), 2.0, 32)
		if is_instance_valid(_core_glow):
			_core_glow.modulate = Color(1.45, 0.88, 0.25, 1.0)
		if is_instance_valid(_visor_eye):
			_visor_eye.modulate = Color(1.45, 0.92, 0.28, 1.0)
		if is_instance_valid(_core_light):
			_core_light.color = Color(1.0, 0.65, 0.2, 1.0)
			_core_light.energy = 1.8
	elif fase >= 3:
		_spawn_burst(global_position + Vector2(0.0, -58.0), Color(1.0, 0.35, 0.2, 1.0), 2.3, 38)
		if is_instance_valid(_core_glow):
			_core_glow.modulate = Color(1.8, 0.52, 0.22, 1.0)
		if is_instance_valid(_visor_eye):
			_visor_eye.modulate = Color(1.8, 0.45, 0.2, 1.0)
		if is_instance_valid(_core_light):
			_core_light.color = Color(1.0, 0.35, 0.15, 1.0)
			_core_light.energy = 2.35

	if is_instance_valid(_crit_sparks):
		_crit_sparks.restart()


func _play_hit_feedback(critico: bool, is_charged: bool) -> void:
	_shake_strength = maxf(_shake_strength, crit_shake_strength if critico else hit_shake_strength)
	if is_instance_valid(_rig):
		_rig.trigger_hit_recoil(critico)

	if critico:
		_notify_player_camera_shake(5.5 if is_charged else 3.5)
		_notify_player_hitstop(0.05 if is_charged else 0.035)
		if is_instance_valid(_crit_sparks):
			_crit_sparks.restart()
	else:
		if is_charged:
			_notify_player_hitstop(0.025)
		if is_instance_valid(_hit_sparks):
			_hit_sparks.restart()

	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	_visuals.modulate = Color(2.8, 2.2, 1.1, 1.0) if critico else Color(2.1, 2.1, 2.1, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_visuals, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.14)


func _spawn_damage_popup(text_val: String, color: Color, font_size: int, rise: float, pos: Vector2) -> void:
	var popup: Node2D = DAMAGE_NUMBER_SCENE.instantiate() as Node2D
	if popup == null:
		return
	popup.global_position = pos
	var parent_scene: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if parent_scene:
		parent_scene.add_child(popup)
	if popup.has_method("setup"):
		popup.call("setup", text_val, color, font_size, rise)


func _spawn_burst(pos: Vector2, tint: Color, burst_scale: float, count: int) -> void:
	var burst: Node2D = HIT_BURST_SCENE.instantiate() as Node2D
	if burst == null:
		return
	burst.global_position = pos
	var parent_scene: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if parent_scene:
		parent_scene.add_child(burst)
	if burst.has_method("configure"):
		burst.call("configure", tint, burst_scale, count)


func _spawn_death_explosion() -> void:
	var offset: Vector2 = Vector2(randf_range(-75.0, 75.0), randf_range(-115.0, 60.0))
	_spawn_burst(global_position + offset, Color(1.0, 0.55, 0.2, 1.0), randf_range(1.3, 1.9), 24)
	_notify_player_camera_shake(9.5)
	_shake_strength = 14.0


func _finish_death() -> void:
	if esta_morto:
		return
	esta_morto = true
	_set_beam_active(false)
	_set_claw_active(false)
	_telegraph_line.visible = false
	_state_timer.stop()
	_sub_action_timer.stop()
	_spawn_burst(global_position + Vector2(0.0, -40.0), Color(1.0, 0.85, 0.35, 1.0), 2.8, 42)
	_notify_player_camera_shake(death_camera_shake)
	_notify_player_hitstop(0.08)
	morreu.emit()
	call_deferred("queue_free")


func _notify_player_camera_shake(strength: float) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.has_method("apply_camera_shake"):
		player.call("apply_camera_shake", strength)


func _notify_player_hitstop(duration: float) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.has_method("trigger_hitstop"):
		player.call("trigger_hitstop", duration)


func _on_state_timer_timeout() -> void:
	if esta_morto:
		return

	match current_state:
		State.INTRO:
			if is_instance_valid(_rig):
				_rig.trigger_stomp_slam()
			_notify_player_camera_shake(8.5)
			_enter_state(State.STALK)
		State.STALK:
			_choose_next_attack()
		State.STOMP_TELEGRAPH:
			execute_stomp_attack()
			_enter_state(State.RECOVER)
		State.VOLLEY_TELEGRAPH:
			_enter_state(State.VOLLEY_FIRING)
		State.VOLLEY_FIRING:
			_enter_state(State.RECOVER)
		State.CLAW_TELEGRAPH:
			_enter_state(State.CLAW_SMASH)
		State.CLAW_SMASH:
			_enter_state(State.RECOVER)
		State.LEAP_TELEGRAPH:
			_enter_state(State.LEAP_AIR)
		State.LEAP_AIR:
			execute_stomp_attack()
			_enter_state(State.RECOVER)
		State.BEAM_TELEGRAPH:
			_enter_state(State.BEAM_SWEEP)
		State.BEAM_SWEEP:
			_enter_state(State.RECOVER)
		State.TANTRUM:
			_enter_state(State.RECOVER)
		State.RECOVER, State.STAGGERED:
			_enter_state(State.STALK)
		State.DYING:
			_finish_death()
		_:
			_enter_state(State.STALK)


func _on_sub_action_timer_timeout() -> void:
	if esta_morto:
		return

	match current_state:
		State.VOLLEY_FIRING:
			_volley_remaining -= 1
			if _volley_remaining > 0:
				_fire_single_volley_orb()
				_sub_action_timer.start(0.18 if fase >= 2 else 0.24)
			else:
				_enter_state(State.RECOVER)
		State.TANTRUM:
			_tantrum_waves_remaining -= 1
			if _tantrum_waves_remaining > 0:
				spawn_tantrum_debris()
				if _tantrum_waves_remaining % 3 == 0:
					execute_stomp_attack()
				_sub_action_timer.start(0.42)
		State.DYING:
			_death_blasts_remaining -= 1
			if _death_blasts_remaining > 0:
				_spawn_death_explosion()
				_sub_action_timer.start(0.24)
			else:
				_finish_death()
		_:
			pass


func _on_footstep_planted() -> void:
	_notify_player_camera_shake(1.8)


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_damage") and not (area is MechaProjectile):
		tomar_dano(1)
