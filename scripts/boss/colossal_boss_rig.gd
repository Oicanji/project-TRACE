class_name ColossalBossRig
extends Node2D

signal footstep_planted

@onready var _left_leg: Node2D = $LeftLeg
@onready var _left_knee: Node2D = $LeftLeg/Knee
@onready var _right_leg: Node2D = $RightLeg
@onready var _right_knee: Node2D = $RightLeg/Knee
@onready var _back_arm: Node2D = $BackArm
@onready var _back_elbow: Node2D = $BackArm/Elbow
@onready var _torso: Node2D = $Torso
@onready var _head: Node2D = $Torso/Head
@onready var _shutter_left: Node2D = $Torso/CoreShutterLeft
@onready var _shutter_right: Node2D = $Torso/CoreShutterRight
@onready var _cable_left: Line2D = $Torso/CableLeft
@onready var _cable_right: Line2D = $Torso/CableRight
@onready var _front_arm: Node2D = $FrontArm
@onready var _front_elbow: Node2D = $FrontArm/Elbow

# Hydraulic piston rods that dynamically extend/compress with joints
@onready var _piston_l_leg: Line2D = get_node_or_null("PistonLeftLeg") as Line2D
@onready var _piston_r_leg: Line2D = get_node_or_null("PistonRightLeg") as Line2D
@onready var _piston_f_arm: Line2D = get_node_or_null("PistonFrontArm") as Line2D
@onready var _steam_left: CPUParticles2D = get_node_or_null("Torso/SteamVentLeft") as CPUParticles2D
@onready var _steam_right: CPUParticles2D = get_node_or_null("Torso/SteamVentRight") as CPUParticles2D
@onready var _footstep_dust: CPUParticles2D = get_node_or_null("FootstepDust") as CPUParticles2D

var _torso_rest_pos: Vector2 = Vector2.ZERO
var _front_arm_rest_pos: Vector2 = Vector2.ZERO
var _back_arm_rest_pos: Vector2 = Vector2.ZERO

var _walk_phase: float = 0.0
var _last_step_half: int = 0
var _idle_phase: float = 0.0
var _tantrum_phase: float = 0.0
var _recoil_rot: float = 0.0
var _recoil_vel: float = 0.0
var _slam_drop: float = 0.0
var _cable_sway: float = 0.0
var _cable_sway_vel: float = 0.0


func _ready() -> void:
	_torso_rest_pos = _torso.position
	_front_arm_rest_pos = _front_arm.position
	_back_arm_rest_pos = _back_arm.position


func update_rig(
	delta: float,
	state: int,
	velocity: Vector2,
	fase: int,
	beam_angle: float,
	facing: float
) -> void:
	var speed_mult: float = 1.0 + 0.25 * float(maxi(0, fase - 1))
	_idle_phase += delta * 2.6 * speed_mult

	# Steam vents active in Phase 2+
	var venting: bool = fase >= 2 and state != 0 and state != 14
	if is_instance_valid(_steam_left):
		_steam_left.emitting = venting
		_steam_left.amount = 18 if fase >= 3 else 10
	if is_instance_valid(_steam_right):
		_steam_right.emitting = venting
		_steam_right.amount = 18 if fase >= 3 else 10

	# Hit recoil spring recovery
	var recoil_acc: float = -150.0 * _recoil_rot - 14.0 * _recoil_vel
	_recoil_vel += recoil_acc * delta
	_recoil_rot = clampf(_recoil_rot + _recoil_vel * delta, -0.38, 0.38)

	# Slam impact compression recovery
	_slam_drop = lerpf(_slam_drop, 0.0, 1.0 - exp(-10.0 * delta))

	var target_torso_y: float = sin(_idle_phase) * 3.5 + _slam_drop
	var target_torso_rot: float = 0.0
	var target_head_rot: float = sin(_idle_phase * 0.7) * 0.04
	var target_l_hip: float = 0.0
	var target_l_knee: float = 0.0
	var target_r_hip: float = 0.0
	var target_r_knee: float = 0.0
	var target_f_arm: float = 0.08 + sin(_idle_phase) * 0.06
	var target_f_elbow: float = -0.18
	var target_b_arm: float = -0.1 - sin(_idle_phase) * 0.06
	var target_b_elbow: float = -0.15
	var target_shutter_open: float = 2.0

	# ColossalBoss.State mapping:
	# 0=INTRO, 1=STALK, 2=STOMP_TELEGRAPH, 3=VOLLEY_TELEGRAPH, 4=VOLLEY_FIRING,
	# 5=CLAW_TELEGRAPH, 6=CLAW_SMASH, 7=LEAP_TELEGRAPH, 8=LEAP_AIR,
	# 9=BEAM_TELEGRAPH, 10=BEAM_SWEEP, 11=TANTRUM, 12=RECOVER, 13=STAGGERED, 14=DYING
	match state:
		0: # INTRO — coiled dormant crouch slowly rising
			target_torso_y = 22.0
			target_torso_rot = 0.14
			target_head_rot = 0.22
			target_l_hip = -0.22
			target_l_knee = 0.42
			target_r_hip = 0.22
			target_r_knee = 0.35
			target_f_arm = 0.35
			target_b_arm = 0.25

		1: # STALK — heavy alternating mechanical stomp walk
			var moving: float = clampf(absf(velocity.x) / 36.0, 0.0, 1.8)
			if moving > 0.08:
				_walk_phase += delta * 4.5 * moving
				var half_cycle: int = int(floor(_walk_phase / PI))
				if half_cycle != _last_step_half:
					_last_step_half = half_cycle
					_slam_drop = 6.5
					emit_footstep_dust()
					footstep_planted.emit()

				var s_l: float = sin(_walk_phase)
				var s_r: float = sin(_walk_phase + PI)
				target_l_hip = s_l * 0.36
				target_l_knee = maxf(0.0, -cos(_walk_phase)) * 0.44
				target_r_hip = s_r * 0.36
				target_r_knee = maxf(0.0, -cos(_walk_phase + PI)) * 0.44
				target_torso_y += absf(cos(_walk_phase)) * 8.5
				target_torso_rot = cos(_walk_phase) * 0.055
				target_f_arm = -s_l * 0.34
				target_b_arm = -s_r * 0.34
				target_f_elbow = -0.25 + maxf(0.0, s_l) * 0.2
				target_b_elbow = -0.25 + maxf(0.0, s_r) * 0.2

		2: # STOMP_TELEGRAPH — delayed menacing overhead wind-up
			target_torso_y = -15.0
			target_torso_rot = -0.15
			target_head_rot = -0.12
			target_f_arm = -2.25
			target_f_elbow = 0.48
			target_b_arm = -2.05
			target_b_elbow = 0.38
			target_r_hip = -0.72
			target_r_knee = 0.78
			target_l_hip = 0.14
			target_l_knee = 0.16

		3, 4: # VOLLEY_TELEGRAPH & VOLLEY_FIRING — braced wide, visor locked
			target_torso_y = 6.0
			target_torso_rot = -0.09
			target_head_rot = 0.1
			target_f_arm = 0.58
			target_f_elbow = -0.68
			target_b_arm = -0.48
			target_b_elbow = -0.42

		5: # CLAW_TELEGRAPH — huge back-swing of front spiked arm
			target_torso_y = -6.0
			target_torso_rot = -0.22
			target_head_rot = 0.14
			target_f_arm = -2.45
			target_f_elbow = -0.45
			target_b_arm = 0.42
			target_b_elbow = -0.35

		6: # CLAW_SMASH — violent forward downward swipe
			target_torso_y = 18.0
			target_torso_rot = 0.26
			target_head_rot = 0.18
			target_f_arm = 1.15
			target_f_elbow = 0.2
			target_b_arm = -0.55
			target_b_elbow = -0.3

		7: # LEAP_TELEGRAPH — deep coil crouch before jump
			target_torso_y = 32.0
			target_torso_rot = 0.22
			target_head_rot = -0.1
			target_l_hip = -0.48
			target_l_knee = 0.85
			target_r_hip = 0.42
			target_r_knee = 0.78
			target_f_arm = 0.65
			target_b_arm = 0.55

		8: # LEAP_AIR — dramatic tucked airborne boss slam
			target_torso_y = -12.0
			target_torso_rot = clampf(velocity.y * 0.00035, -0.22, 0.24)
			target_l_hip = -0.55
			target_l_knee = 0.95
			target_r_hip = 0.28
			target_r_knee = 0.65
			target_f_arm = -1.95
			target_b_arm = -1.75

		9: # BEAM_TELEGRAPH — lean forward menacingly
			target_torso_y = 4.0
			target_torso_rot = 0.12
			target_head_rot = 0.18
			target_f_arm = 0.52
			target_f_elbow = -0.35
			target_b_arm = 0.35
			target_b_elbow = -0.25

		10: # BEAM_SWEEP — lean hard, track beam with head
			target_torso_y = 10.0
			target_torso_rot = 0.18
			var local_beam: float = beam_angle if facing >= 0.0 else (PI - beam_angle)
			target_head_rot = clampf(wrapf(local_beam, -PI, PI) * 0.45, -0.35, 0.45)
			target_f_arm = 0.78
			target_f_elbow = -0.55
			target_b_arm = 0.55
			target_b_elbow = -0.45

		11: # TANTRUM — rapid alternating fist-pounds (False Knight rage!)
			_tantrum_phase += delta * 15.0
			var pound: float = sin(_tantrum_phase)
			target_torso_y = 12.0 + absf(pound) * 14.0
			target_torso_rot = pound * 0.14
			target_head_rot = -pound * 0.12
			target_f_arm = -1.7 + pound * 1.4
			target_b_arm = -1.7 - pound * 1.4
			target_f_elbow = -0.25
			target_b_elbow = -0.25

		12: # RECOVER — brief post-attack opening, chest shutters slide open
			target_torso_y = 16.0 + sin(_idle_phase * 1.8) * 3.0
			target_torso_rot = 0.14
			target_head_rot = 0.24
			target_f_arm = 0.28
			target_f_elbow = -0.08
			target_b_arm = 0.18
			target_b_elbow = -0.05
			target_l_hip = -0.14
			target_l_knee = 0.26
			target_r_hip = 0.14
			target_r_knee = 0.22
			target_shutter_open = 24.0

		13: # STAGGERED — False Knight kneel! Shutters thrown WIDE open!
			target_torso_y = 42.0 + sin(_idle_phase * 2.5) * 2.5
			target_torso_rot = 0.26
			target_head_rot = 0.42
			target_f_arm = 0.48
			target_f_elbow = 0.12
			target_b_arm = 0.36
			target_b_elbow = 0.1
			target_l_hip = -0.55
			target_l_knee = 1.05
			target_r_hip = 0.42
			target_r_knee = 0.88
			target_shutter_open = 32.0

		14: # DYING — violent trembling collapse
			target_torso_y = 48.0 + randf_range(-4.0, 4.0)
			target_torso_rot = 0.32 + randf_range(-0.08, 0.08)
			target_head_rot = 0.5 + randf_range(-0.1, 0.1)
			target_f_arm = 0.62
			target_b_arm = 0.55
			target_l_hip = -0.62
			target_l_knee = 1.15
			target_r_hip = 0.48
			target_r_knee = 0.96
			target_shutter_open = 34.0

	var interp_speed: float = 18.0 if state == 6 else 11.0
	var w: float = 1.0 - exp(-interp_speed * delta)
	_torso.position.y = lerpf(_torso.position.y, _torso_rest_pos.y + target_torso_y, w)
	_torso.rotation = lerpf(_torso.rotation, target_torso_rot + _recoil_rot, w)
	_head.rotation = lerpf(_head.rotation, target_head_rot + _recoil_rot * 1.35, w)

	_left_leg.rotation = lerpf(_left_leg.rotation, target_l_hip, w)
	_left_knee.rotation = lerpf(_left_knee.rotation, target_l_knee, w)
	_right_leg.rotation = lerpf(_right_leg.rotation, target_r_hip, w)
	_right_knee.rotation = lerpf(_right_knee.rotation, target_r_knee, w)

	var arm_offset_y: float = _torso.position.y - _torso_rest_pos.y
	_front_arm.position.y = _front_arm_rest_pos.y + arm_offset_y
	_back_arm.position.y = _back_arm_rest_pos.y + arm_offset_y
	_front_arm.rotation = lerpf(_front_arm.rotation, target_f_arm + _recoil_rot * 0.7, w)
	_front_elbow.rotation = lerpf(_front_elbow.rotation, target_f_elbow, w)
	_back_arm.rotation = lerpf(_back_arm.rotation, target_b_arm + _recoil_rot * 0.5, w)
	_back_elbow.rotation = lerpf(_back_elbow.rotation, target_b_elbow, w)

	# Mechanically slide chest armor shutters open/closed around the weak-point core
	_shutter_left.position.x = lerpf(_shutter_left.position.x, -target_shutter_open, 1.0 - exp(-10.0 * delta))
	_shutter_right.position.x = lerpf(_shutter_right.position.x, target_shutter_open, 1.0 - exp(-10.0 * delta))

	# Pendulum sway on dangling power cables
	var sway_target: float = clampf(-velocity.x * 0.25 + _recoil_vel * 4.0, -26.0, 26.0)
	var sway_acc: float = 48.0 * (sway_target - _cable_sway) - 5.5 * _cable_sway_vel
	_cable_sway_vel += sway_acc * delta
	_cable_sway = clampf(_cable_sway + _cable_sway_vel * delta, -32.0, 32.0)
	_update_cable_points()
	_update_hydraulic_pistons()


func _update_cable_points() -> void:
	if is_instance_valid(_cable_left):
		_cable_left.set_point_position(1, Vector2(-62.0 + _cable_sway * 0.5, -52.0))
		_cable_left.set_point_position(2, Vector2(-56.0 + _cable_sway, -18.0))
	if is_instance_valid(_cable_right):
		_cable_right.set_point_position(1, Vector2(62.0 + _cable_sway * 0.5, -50.0))
		_cable_right.set_point_position(2, Vector2(58.0 + _cable_sway, -14.0))


func _update_hydraulic_pistons() -> void:
	if is_instance_valid(_piston_l_leg):
		var a: Vector2 = to_local(_torso.to_global(Vector2(-38.0, 14.0)))
		var b: Vector2 = to_local(_left_knee.to_global(Vector2(-18.0, 18.0)))
		_piston_l_leg.set_point_position(0, a)
		_piston_l_leg.set_point_position(1, b)
	if is_instance_valid(_piston_r_leg):
		var a: Vector2 = to_local(_torso.to_global(Vector2(38.0, 14.0)))
		var b: Vector2 = to_local(_right_knee.to_global(Vector2(18.0, 18.0)))
		_piston_r_leg.set_point_position(0, a)
		_piston_r_leg.set_point_position(1, b)
	if is_instance_valid(_piston_f_arm):
		var a: Vector2 = to_local(_torso.to_global(Vector2(-74.0, -96.0)))
		var b: Vector2 = to_local(_front_elbow.to_global(Vector2(-10.0, 14.0)))
		_piston_f_arm.set_point_position(0, a)
		_piston_f_arm.set_point_position(1, b)


func emit_footstep_dust() -> void:
	if is_instance_valid(_footstep_dust):
		_footstep_dust.restart()


func trigger_stomp_slam() -> void:
	_slam_drop = 28.0
	_recoil_vel += 3.4
	_cable_sway_vel += 46.0
	emit_footstep_dust()


func trigger_hit_recoil(critico: bool) -> void:
	var kick: float = -4.6 if critico else -2.0
	_recoil_vel += kick
	_cable_sway_vel += -38.0 if critico else -16.0
