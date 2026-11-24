class_name DamageNumber
extends Node2D

@onready var _label: Label = $Label

var _pending_text: String = ""
var _pending_color: Color = Color.WHITE
var _pending_size: int = 18
var _rise_distance: float = 44.0


func setup(text_value: String, color: Color, font_size: int = 18, rise_distance: float = 44.0) -> void:
	_pending_text = text_value
	_pending_color = color
	_pending_size = font_size
	_rise_distance = rise_distance
	if is_node_ready():
		_apply_and_animate()


func _ready() -> void:
	if not _pending_text.is_empty():
		_apply_and_animate()


func _apply_and_animate() -> void:
	_label.text = _pending_text
	_label.add_theme_color_override("font_color", _pending_color)
	_label.add_theme_font_size_override("font_size", _pending_size)

	var drift_x: float = randf_range(-18.0, 18.0)
	scale = Vector2(0.45, 0.45)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.18, 1.18), 0.11).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "global_position", global_position + Vector2(drift_x, -_rise_distance), 0.65).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

	var fade_tween: Tween = create_tween()
	fade_tween.tween_interval(0.32)
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.34).set_ease(Tween.EASE_IN)
	fade_tween.tween_callback(queue_free)
