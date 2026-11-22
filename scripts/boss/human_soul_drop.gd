class_name HumanSoulDrop
extends Area2D

signal coletada

const HIT_BURST_SCENE: PackedScene = preload("res://components/hit_burst.tscn")

@export var hover_height_above_floor: float = 46.0
@export var magnet_radius: float = 135.0
@export var magnet_speed: float = 260.0

@onready var _visual: Node2D = $Visual
@onready var _halo: Sprite2D = $Visual/Halo
@onready var _light: PointLight2D = $Visual/SoulLight

var _target_y: float = 474.0
var _hover_ready: bool = false
var _collected: bool = false
var _bob_phase: float = 0.0
var _velocity_y: float = -210.0


func configure_drop(floor_y: float) -> void:
	_target_y = floor_y - hover_height_above_floor


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if _collected:
		return

	_bob_phase += delta * 3.8

	if not _hover_ready:
		_velocity_y += 420.0 * delta
		global_position.y += _velocity_y * delta
		if _velocity_y > 0.0 and global_position.y >= _target_y:
			global_position.y = _target_y
			_hover_ready = true
	else:
		var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		if is_instance_valid(player):
			var to_player: Vector2 = player.global_position - global_position
			var dist: float = to_player.length()
			if dist < magnet_radius and dist > 2.0:
				global_position += to_player.normalized() * magnet_speed * delta
			else:
				global_position.y = lerpf(global_position.y, _target_y + sin(_bob_phase) * 9.0, 5.0 * delta)
		else:
			global_position.y = _target_y + sin(_bob_phase) * 9.0

	if is_instance_valid(_visual):
		var pulse: float = 1.0 + 0.08 * sin(_bob_phase * 1.4)
		_visual.scale = Vector2(pulse, 1.0 / pulse)
	if is_instance_valid(_halo):
		var hp: float = 0.85 + 0.18 * sin(_bob_phase * 2.0)
		_halo.scale = Vector2(hp, hp)
	if is_instance_valid(_light):
		_light.energy = 1.35 + 0.3 * sin(_bob_phase * 2.0)


func _collect() -> void:
	if _collected:
		return
	_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	var burst: Node2D = HIT_BURST_SCENE.instantiate() as Node2D
	if burst:
		burst.global_position = global_position
		var parent_scene: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
		if parent_scene:
			parent_scene.add_child(burst)
		if burst.has_method("configure"):
			burst.call("configure", Color(1.0, 0.88, 0.28, 1.0), 1.85, 32)

	coletada.emit()
	call_deferred("queue_free")


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if body.is_in_group("player"):
		_collect()


func _on_area_entered(area: Area2D) -> void:
	if _collected:
		return
	if area.is_in_group("player"):
		_collect()
