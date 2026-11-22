class_name EndingSlideshow
extends Control

@export_file("*.tscn") var boss_scene_path: String = "res://scenes/level_boss.tscn"
@export_file("*.tscn") var start_scene_path: String = "res://scenes/level_1_floresta.tscn"

const SLIDES: Array[Dictionary] = [
	{
		"texture": "res://assets/ending/slide_01_meet_soul.png",
		"duration": 4.8,
		"light_theme": true,
		"zoom_from": 1.0,
		"zoom_to": 1.06,
		"pan": Vector2(14.0, -6.0),
	},
	{
		"texture": "res://assets/ending/slide_02_consume_soul.png",
		"duration": 5.0,
		"light_theme": true,
		"zoom_from": 1.04,
		"zoom_to": 1.11,
		"pan": Vector2(0.0, -8.0),
	},
	{
		"texture": "res://assets/ending/slide_03_yellow_cat.png",
		"duration": 5.0,
		"light_theme": true,
		"zoom_from": 1.08,
		"zoom_to": 1.01,
		"pan": Vector2(-10.0, 4.0),
	},
	{
		"texture": "res://assets/ending/slide_04_campfire.png",
		"duration": 6.5,
		"light_theme": false,
		"zoom_from": 1.08,
		"zoom_to": 1.0,
		"pan": Vector2(12.0, -8.0),
	},
]

@onready var _bg_rect: ColorRect = $BgRect
@onready var _slide_a: TextureRect = $SlideViewport/SlideA
@onready var _slide_b: TextureRect = $SlideViewport/SlideB
@onready var _warm_vignette: TextureRect = $WarmVignette
@onready var _embers: CPUParticles2D = $EmbersLayer/Embers
@onready var _dots_row: HBoxContainer = $HudLayer/BottomMargin/DotsRow
@onready var _finale_box: HBoxContainer = $HudLayer/FinaleCenter/FinaleBox
@onready var _boss_button: Button = $HudLayer/FinaleCenter/FinaleBox/ReplayBossButton
@onready var _slide_timer: Timer = $SlideTimer
@onready var _entry_fade: ColorRect = $FadeLayer/EntryFade

var current_index: int = -1
var _using_a: bool = true
var _ken_burns_tween: Tween
var _crossfade_tween: Tween


func _ready() -> void:
	_finale_box.visible = false
	_finale_box.modulate.a = 0.0
	_slide_a.modulate.a = 0.0
	_slide_b.modulate.a = 0.0
	_build_progress_dots()

	_entry_fade.color = Color(1.0, 0.99, 0.95, 1.0)
	_show_slide(0, true)

	var fade_in: Tween = create_tween()
	fade_in.tween_property(_entry_fade, "color:a", 0.0, 0.9).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	var advance_pressed: bool = false
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		advance_pressed = true
	elif event.is_action_pressed(&"pulo") or event.is_action_pressed(&"interagir") or event.is_action_pressed(&"ui_accept"):
		advance_pressed = true

	if advance_pressed and current_index < SLIDES.size() - 1:
		advance_slide()


func advance_slide() -> void:
	if current_index + 1 < SLIDES.size():
		_show_slide(current_index + 1, false)
	else:
		_reveal_finale_buttons()


func _show_slide(index: int, instant: bool) -> void:
	if index < 0 or index >= SLIDES.size():
		return

	current_index = index
	var data: Dictionary = SLIDES[index]
	var tex_path: String = String(data["texture"])
	var tex: Texture2D = load(tex_path) as Texture2D if ResourceLoader.exists(tex_path) else null
	var light_theme: bool = bool(data["light_theme"])

	var incoming: TextureRect = _slide_a if _using_a else _slide_b
	var outgoing: TextureRect = _slide_b if _using_a else _slide_a
	_using_a = not _using_a

	incoming.texture = tex
	incoming.pivot_offset = incoming.size * 0.5
	var z_from: float = float(data["zoom_from"])
	var z_to: float = float(data["zoom_to"])
	var pan: Vector2 = data["pan"] as Vector2
	var dur: float = float(data["duration"])

	incoming.scale = Vector2(z_from, z_from)
	incoming.position = -pan * 0.5

	if _ken_burns_tween and _ken_burns_tween.is_valid():
		_ken_burns_tween.kill()
	_ken_burns_tween = create_tween()
	_ken_burns_tween.set_parallel(true)
	_ken_burns_tween.tween_property(incoming, "scale", Vector2(z_to, z_to), dur + 1.2).set_ease(Tween.EASE_IN_OUT)
	_ken_burns_tween.tween_property(incoming, "position", pan * 0.5, dur + 1.2).set_ease(Tween.EASE_IN_OUT)

	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	if instant:
		incoming.modulate.a = 1.0
		outgoing.modulate.a = 0.0
	else:
		incoming.modulate.a = 0.0
		_crossfade_tween = create_tween()
		_crossfade_tween.set_parallel(true)
		_crossfade_tween.tween_property(incoming, "modulate:a", 1.0, 0.95).set_ease(Tween.EASE_IN_OUT)
		_crossfade_tween.tween_property(outgoing, "modulate:a", 0.0, 0.95).set_ease(Tween.EASE_IN_OUT)

	_apply_slide_theme(light_theme, instant)
	_update_progress_dots()

	if index == SLIDES.size() - 1:
		_slide_timer.start(3.0)
	else:
		_slide_timer.start(dur)


func _apply_slide_theme(light_theme: bool, instant: bool) -> void:
	var target_bg: Color = Color(0.99, 0.99, 0.98, 1.0) if light_theme else Color(0.05, 0.04, 0.05, 1.0)
	var target_vig_a: float = 0.12 if light_theme else 0.68
	if is_instance_valid(_embers):
		_embers.emitting = true
		_embers.color = Color(1.0, 0.88, 0.3, 0.65) if light_theme else Color(1.0, 0.62, 0.22, 0.85)

	if instant:
		_bg_rect.color = target_bg
		_warm_vignette.modulate.a = target_vig_a
	else:
		var t: Tween = create_tween()
		t.set_parallel(true)
		t.tween_property(_bg_rect, "color", target_bg, 0.9)
		t.tween_property(_warm_vignette, "modulate:a", target_vig_a, 0.9)


func _build_progress_dots() -> void:
	for child in _dots_row.get_children():
		child.queue_free()
	for i in SLIDES.size():
		var dot: ColorRect = ColorRect.new()
		dot.custom_minimum_size = Vector2(9.0, 9.0)
		dot.color = Color(1.0, 0.88, 0.5, 0.3)
		_dots_row.add_child(dot)


func _update_progress_dots() -> void:
	for i in _dots_row.get_child_count():
		var dot: ColorRect = _dots_row.get_child(i) as ColorRect
		if dot == null:
			continue
		if i == current_index:
			dot.color = Color(1.0, 0.86, 0.3, 1.0)
		elif i < current_index:
			dot.color = Color(1.0, 0.86, 0.55, 0.55)
		else:
			dot.color = Color(0.75, 0.72, 0.68, 0.25)


func _reveal_finale_buttons() -> void:
	if _finale_box.visible:
		return
	_finale_box.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(_finale_box, "modulate:a", 1.0, 0.85).set_ease(Tween.EASE_OUT)
	_boss_button.grab_focus()


func _on_slide_timer_timeout() -> void:
	if current_index < SLIDES.size() - 1:
		advance_slide()
	else:
		_reveal_finale_buttons()


func _on_replay_boss_pressed() -> void:
	if not boss_scene_path.is_empty() and ResourceLoader.exists(boss_scene_path):
		get_tree().call_deferred("change_scene_to_file", boss_scene_path)


func _on_back_start_pressed() -> void:
	if not start_scene_path.is_empty() and ResourceLoader.exists(start_scene_path):
		get_tree().call_deferred("change_scene_to_file", start_scene_path)
