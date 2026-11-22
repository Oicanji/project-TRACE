class_name ForestZoneManager
extends CityZoneManager

@export var hud_dica_path: NodePath = NodePath("../HudDica")
@export var fireflies_path: NodePath = NodePath("../Vagalumes")

var _completed_hints: Dictionary = {}

@onready var _hud_dica: HudDica = get_node_or_null(hud_dica_path) as HudDica
@onready var _fireflies: CPUParticles2D = get_node_or_null(fireflies_path) as CPUParticles2D


func _swap_zone(zone_id: StringName, spawn_id: StringName, with_fade: bool) -> void:
	if is_instance_valid(_hud_dica):
		_hud_dica.esconder_dica(null)
	await super._swap_zone(zone_id, spawn_id, with_fade)


func _apply_zone_settings(zone: CityZone, spawn_id: StringName) -> void:
	super._apply_zone_settings(zone, spawn_id)

	if is_instance_valid(_fireflies):
		var bounds: Rect2i = zone.camera_bounds
		_fireflies.global_position = Vector2(
			bounds.position.x + bounds.size.x * 0.5,
			bounds.position.y + bounds.size.y * 0.5
		)
		_fireflies.emission_rect_extents = Vector2(
			maxf(380.0, bounds.size.x * 0.48),
			maxf(240.0, bounds.size.y * 0.45)
		)

	if is_instance_valid(_hud_dica):
		_hud_dica.esconder_dica(null)
		_connect_zone_hints(zone, zone.zone_id)


func _connect_zone_hints(root: Node, zone_id: StringName) -> void:
	for child: Node in root.get_children():
		if child is TutorialHint:
			var hint: TutorialHint = child as TutorialHint
			var hint_key: String = "%s:%s" % [zone_id, hint.name]
			if _completed_hints.has(hint_key):
				hint.set("_concluida", true)
				hint.iniciar_visivel = false
			else:
				hint.dica_ativada.connect(_hud_dica.mostrar_dica)
				hint.dica_desativada.connect(_hud_dica.esconder_dica)
				hint.dica_concluida.connect(_on_hint_completed.bind(hint_key))
		elif child is TutorialExit:
			var exit_node: TutorialExit = child as TutorialExit
			exit_node.dica_ativada.connect(_hud_dica.mostrar_dica)
			exit_node.dica_desativada.connect(_hud_dica.esconder_dica)

		_connect_zone_hints(child, zone_id)


func _on_hint_completed(origem: Node, hint_key: String) -> void:
	_completed_hints[hint_key] = true
	if is_instance_valid(_hud_dica):
		_hud_dica.concluir_dica(origem)
