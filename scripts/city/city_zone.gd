class_name CityZone
extends Node2D

signal portal_entered(portal: ZonePortal)

@export var zone_id: StringName = &"zone_01"
@export var zone_title: String = "ORLA DA CIDADE"
@export var zone_subtitle: String = "ZONA 01"
@export var camera_bounds: Rect2i = Rect2i(0, 0, 1792, 768)
@export var is_outdoor: bool = true
@export_range(0.0, 1.5, 0.05) var rain_intensity: float = 1.0
@export var ambient_color: Color = Color(0.76, 0.84, 0.86, 1.0)


func _ready() -> void:
	for child: Node in _collect_portals(self):
		var portal: ZonePortal = child as ZonePortal
		if portal:
			portal.portal_triggered.connect(_on_portal_triggered)


func get_spawn_position(spawn_id: StringName) -> Vector2:
	var spawns_node: Node = get_node_or_null("Spawns")
	if spawns_node:
		var marker: Marker2D = spawns_node.get_node_or_null(NodePath(String(spawn_id))) as Marker2D
		if marker:
			return marker.global_position
		for child: Node in spawns_node.get_children():
			if child is Marker2D:
				return (child as Marker2D).global_position
	return Vector2(160.0, 480.0)


func _collect_portals(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in root.get_children():
		if child is ZonePortal:
			result.append(child)
		result.append_array(_collect_portals(child))
	return result


func _on_portal_triggered(portal: ZonePortal) -> void:
	portal_entered.emit(portal)
