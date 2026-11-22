class_name CityZoneManager
extends Node

@export var initial_zone_id: StringName = &"zone_01"
@export var initial_spawn_id: StringName = &"from_start"
@export var zone_scenes: Dictionary = {}

@export_group("Scene Nodes")
@export var player_path: NodePath = NodePath("../Player")
@export var camera_path: NodePath = NodePath("../Player/Camera2D")
@export var zone_container_path: NodePath = NodePath("../ZoneContainer")
@export var canvas_modulate_path: NodePath = NodePath("../AtmosferaCidade")
@export var rain_particles_path: NodePath = NodePath("../ChuvaFrente")
@export var rain_back_particles_path: NodePath = NodePath("../ChuvaFundo")
@export var fog_front_path: NodePath = NodePath("../NevoaFrente/FogRect")
@export var fog_mid_path: NodePath = NodePath("../NevoaMeio/FogRect")
@export var transition_anim_path: NodePath = NodePath("../TransicaoZona/AnimationPlayer")

const PORTAL_COOLDOWN_SEC: float = 0.55

var _current_zone: CityZone = null
var _transitioning: bool = false
var _portal_cooldown: float = 0.0

@onready var _player: CharacterBody2D = get_node(player_path) as CharacterBody2D
@onready var _camera: Camera2D = get_node(camera_path) as Camera2D
@onready var _zone_container: Node2D = get_node(zone_container_path) as Node2D
@onready var _canvas_modulate: CanvasModulate = get_node_or_null(canvas_modulate_path) as CanvasModulate
@onready var _rain_front: CPUParticles2D = get_node_or_null(rain_particles_path) as CPUParticles2D
@onready var _rain_back: CPUParticles2D = get_node_or_null(rain_back_particles_path) as CPUParticles2D
@onready var _fog_front: ColorRect = get_node_or_null(fog_front_path) as ColorRect
@onready var _fog_mid: ColorRect = get_node_or_null(fog_mid_path) as ColorRect
@onready var _transition_anim: AnimationPlayer = get_node_or_null(transition_anim_path) as AnimationPlayer


func _ready() -> void:
	call_deferred("_load_initial_zone")


func _process(delta: float) -> void:
	if _portal_cooldown > 0.0:
		_portal_cooldown = maxf(0.0, _portal_cooldown - delta)


func _load_initial_zone() -> void:
	await _swap_zone(initial_zone_id, initial_spawn_id, false)


func _on_zone_portal_entered(portal: ZonePortal) -> void:
	if _transitioning or _portal_cooldown > 0.0:
		return
	if portal.target_zone_id == &"":
		return
	_swap_zone(portal.target_zone_id, portal.target_spawn_id, true)


func _swap_zone(zone_id: StringName, spawn_id: StringName, with_fade: bool) -> void:
	var scene_path: String = str(zone_scenes.get(String(zone_id), ""))
	if scene_path.is_empty():
		scene_path = str(zone_scenes.get(zone_id, ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_warning("CityZoneManager: zona inválida '%s' (%s)" % [zone_id, scene_path])
		return

	_transitioning = true
	if _player:
		_player.set_physics_process(false)
		_player.velocity = Vector2.ZERO

	if with_fade and _transition_anim and _transition_anim.has_animation(&"escurecer"):
		_transition_anim.play(&"escurecer")
		await _transition_anim.animation_finished

	if is_instance_valid(_current_zone):
		_current_zone.queue_free()
		_current_zone = null
		await get_tree().process_frame

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("CityZoneManager: falha ao carregar %s" % scene_path)
		_transitioning = false
		if is_instance_valid(_player):
			_player.set_physics_process(true)
		return

	var instance: CityZone = packed.instantiate() as CityZone
	if instance == null:
		push_error("CityZoneManager: raiz de %s não é CityZone" % scene_path)
		_transitioning = false
		if is_instance_valid(_player):
			_player.set_physics_process(true)
		return

	_zone_container.add_child(instance)
	_current_zone = instance
	_current_zone.portal_entered.connect(_on_zone_portal_entered)

	_apply_zone_settings(_current_zone, spawn_id)

	if with_fade and _transition_anim and _transition_anim.has_animation(&"clarear"):
		_transition_anim.play(&"clarear")
		await _transition_anim.animation_finished

	if is_instance_valid(_player):
		_player.set_physics_process(true)

	_portal_cooldown = PORTAL_COOLDOWN_SEC
	_transitioning = false


func _apply_zone_settings(zone: CityZone, spawn_id: StringName) -> void:
	var spawn_pos: Vector2 = zone.get_spawn_position(spawn_id)
	if is_instance_valid(_player):
		_player.global_position = spawn_pos
		_player.velocity = Vector2.ZERO
		if "ON_WALL" in _player:
			_player.set("ON_WALL", false)
		if "GRAPPLE" in _player:
			_player.set("GRAPPLE", false)
		if "objs_batendo" in _player:
			_player.set("objs_batendo", 0)

	if is_instance_valid(_camera):
		var bounds: Rect2i = zone.camera_bounds
		_camera.limit_left = bounds.position.x
		_camera.limit_top = bounds.position.y
		_camera.limit_right = bounds.end.x
		_camera.limit_bottom = bounds.end.y
		_camera.reset_smoothing()

	if is_instance_valid(_canvas_modulate):
		_canvas_modulate.color = zone.ambient_color

	var center: Vector2 = Vector2(
		zone.camera_bounds.position.x + zone.camera_bounds.size.x * 0.5,
		zone.camera_bounds.position.y - 40.0
	)
	var half_w: float = maxf(800.0, zone.camera_bounds.size.x * 0.55)

	if is_instance_valid(_rain_front):
		_rain_front.global_position = center
		_rain_front.emission_rect_extents = Vector2(half_w, 60.0)
		_rain_front.emitting = zone.rain_intensity > 0.05
		_rain_front.modulate.a = clampf(zone.rain_intensity, 0.0, 1.0)

	if is_instance_valid(_rain_back):
		_rain_back.global_position = center
		_rain_back.emission_rect_extents = Vector2(half_w, 60.0)
		_rain_back.emitting = zone.is_outdoor and zone.rain_intensity > 0.15
		_rain_back.modulate.a = clampf(zone.rain_intensity * 0.65, 0.0, 0.8)

	# Heavy white fog outdoors, thick eerie cold mist indoors
	if is_instance_valid(_fog_mid):
		var mat_mid: ShaderMaterial = _fog_mid.material as ShaderMaterial
		if mat_mid:
			mat_mid.set_shader_parameter("opacity", 0.58 if zone.is_outdoor else 0.28)
	if is_instance_valid(_fog_front):
		var mat_front: ShaderMaterial = _fog_front.material as ShaderMaterial
		if mat_front:
			mat_front.set_shader_parameter("opacity", 0.34 if zone.is_outdoor else 0.18)
