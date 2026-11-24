class_name TransitionSlideshow
extends Control

@export var slide_textures: Array[Texture2D] = []
@export_file("*.tscn") var next_scene_path: String = ""
@export_range(2.0, 12.0, 0.2) var slide_duration: float = 4.8
@export var bg_color: Color = Color(0.04, 0.05, 0.08, 1.0)
@export var particle_color: Color = Color(0.58, 0.9, 1.0, 0.7)
@export var fade_color: Color = Color(0.03, 0.04, 0.06, 1.0)
@export var enable_ken_burns: bool = true

@onready var _bg_rect: ColorRect = $BgRect
@onready var _slide_a: TextureRect = $SlideViewport/SlideA
@onready var _slide_b: TextureRect = $SlideViewport/SlideB
@onready var _particles: CPUParticles2D = $ParticlesLayer/Particles
@onready var _dots_row: HBoxContainer = $HudLayer/BottomMargin/DotsRow
@onready var _fade_rect: ColorRect = $FadeLayer/FadeRect
@onready var _slide_timer: Timer = $SlideTimer

var current_index: int = -1
var _using_a: bool = true
var _transitioning_out: bool = false
var _ken_burns_tween: Tween
var _crossfade_tween: Tween


func _ready() -> void:
	_bg_rect.color = bg_color
	_particles.color = particle_color
	_slide_a.modulate.a = 0.0
	_slide_b.modulate.a = 0.0
	_build_progress_dots()

	_fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, 1.0)
	if slide_textures.is_empty():
		_finish_and_go_next()
		return

	_show_slide(0, true)

	var fade_in: Tween = create_tween()
	fade_in.tween_property(_fade_rect, "color:a", 0.0, 0.75).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning_out:
		return
	var advance_pressed: bool = false
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		advance_pressed = true
	elif event.is_action_pressed(&"pulo") or event.is_action_pressed(&"interagir") or event.is_action_pressed(&"ui_accept"):
		advance_pressed = true

	if advance_pressed:
		advance_slide()


func advance_slide() -> void:
	if _transitioning_out:
		return
	if current_index + 1 < slide_textures.size():
		_show_slide(current_index + 1, false)
	else:
		_finish_and_go_next()


func _show_slide(index: int, instant: bool) -> void:
	if index < 0 or index >= slide_textures.size():
		return

	current_index = index
	var tex: Texture2D = slide_textures[index]

	var incoming: TextureRect = _slide_a if _using_a else _slide_b
	var outgoing: TextureRect = _slide_b if _using_a else _slide_a
	_using_a = not _using_a

	incoming.texture = tex
	incoming.pivot_offset = incoming.size * 0.5

	if _ken_burns_tween and _ken_burns_tween.is_valid():
		_ken_burns_tween.kill()
	if enable_ken_burns:
		var zoom_in: bool = (index % 2 == 0)
		var z_from: float = 1.0 if zoom_in else 1.08
		var z_to: float = 1.08 if zoom_in else 1.01
		var pan: Vector2 = Vector2(14.0, -6.0) if zoom_in else Vector2(-14.0, 6.0)
		incoming.scale = Vector2(z_from, z_from)
		incoming.position = -pan * 0.5
		_ken_burns_tween = create_tween()
		_ken_burns_tween.set_parallel(true)
		_ken_burns_tween.tween_property(incoming, "scale", Vector2(z_to, z_to), slide_duration + 1.1).set_ease(Tween.EASE_IN_OUT)
		_ken_burns_tween.tween_property(incoming, "position", pan * 0.5, slide_duration + 1.1).set_ease(Tween.EASE_IN_OUT)
	else:
		incoming.scale = Vector2.ONE
		incoming.position = Vector2.ZERO

	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	if instant:
		incoming.modulate.a = 1.0
		outgoing.modulate.a = 0.0
	else:
		incoming.modulate.a = 0.0
		_crossfade_tween = create_tween()
		_crossfade_tween.set_parallel(true)
		_crossfade_tween.tween_property(incoming, "modulate:a", 1.0, 0.9).set_ease(Tween.EASE_IN_OUT)
		_crossfade_tween.tween_property(outgoing, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN_OUT)

	_update_progress_dots()
	_slide_timer.start(slide_duration)


func _build_progress_dots() -> void:
	for child in _dots_row.get_children():
		child.queue_free()
	for i in slide_textures.size():
		var dot: ColorRect = ColorRect.new()
		dot.custom_minimum_size = Vector2(9.0, 9.0)
		dot.color = Color(0.85, 0.92, 0.98, 0.25)
		_dots_row.add_child(dot)


func _update_progress_dots() -> void:
	for i in _dots_row.get_child_count():
		var dot: ColorRect = _dots_row.get_child(i) as ColorRect
		if dot == null:
			continue
		if i == current_index:
			dot.color = Color(particle_color.r, particle_color.g, particle_color.b, 1.0)
		elif i < current_index:
			dot.color = Color(particle_color.r, particle_color.g, particle_color.b, 0.55)
		else:
			dot.color = Color(0.75, 0.8, 0.88, 0.22)


func _finish_and_go_next() -> void:
	if _transitioning_out:
		return
	_transitioning_out = true
	_slide_timer.stop()

	if next_scene_path.is_empty() or not ResourceLoader.exists(next_scene_path):
		return

	var fade_out: Tween = create_tween()
	fade_out.tween_property(_fade_rect, "color:a", 1.0, 0.75).set_ease(Tween.EASE_IN_OUT)
	fade_out.tween_callback(_change_to_next_scene)


func _change_to_next_scene() -> void:
	get_tree().call_deferred("change_scene_to_file", next_scene_path)


func _on_slide_timer_timeout() -> void:
	advance_slide()
