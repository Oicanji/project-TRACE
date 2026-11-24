class_name HudBoss
extends CanvasLayer

@export var boss: Node

@onready var _root_panel: PanelContainer = $MarginContainer/BossPanel
@onready var _trail_bar: ProgressBar = $MarginContainer/BossPanel/VBox/BarStack/TrailBar
@onready var _health_bar: ProgressBar = $MarginContainer/BossPanel/VBox/BarStack/HealthBar
@onready var _stagger_bar: ProgressBar = get_node_or_null("MarginContainer/BossPanel/VBox/StaggerBar") as ProgressBar

var _trail_tween: Tween


func _ready() -> void:
	if not boss and get_parent():
		boss = get_parent().get_node_or_null("ColossalBoss")

	if boss:
		if boss.has_signal("vida_alterada") and not boss.vida_alterada.is_connected(_on_vida_alterada):
			boss.vida_alterada.connect(_on_vida_alterada)
		if boss.has_signal("fase_alterada") and not boss.fase_alterada.is_connected(_on_fase_alterada):
			boss.fase_alterada.connect(_on_fase_alterada)
		if boss.has_signal("stagger_alterado") and not boss.stagger_alterado.is_connected(_on_stagger_alterado):
			boss.stagger_alterado.connect(_on_stagger_alterado)
		if boss.has_signal("morreu") and not boss.morreu.is_connected(_on_boss_morreu):
			boss.morreu.connect(_on_boss_morreu)
		if "vida" in boss and "vida_maxima" in boss:
			atualizar_vida(int(boss.vida), int(boss.vida_maxima), true)
		if is_instance_valid(_stagger_bar):
			_stagger_bar.max_value = 12.0
			_stagger_bar.value = 0.0


func _on_vida_alterada(vida_atual: int, vida_maxima: int) -> void:
	atualizar_vida(vida_atual, vida_maxima, false)


func _on_stagger_alterado(atual: float, maximo: float) -> void:
	if not is_instance_valid(_stagger_bar):
		return
	_stagger_bar.max_value = maxf(1.0, maximo)
	_stagger_bar.value = clampf(atual, 0.0, maximo)


func _on_fase_alterada(fase: int) -> void:
	# Pure visual phase cue: shift bar tint intensity without text
	if fase == 2:
		_health_bar.modulate = Color(1.15, 0.88, 0.65, 1.0)
	elif fase >= 3:
		_health_bar.modulate = Color(1.3, 0.65, 0.5, 1.0)


func _on_boss_morreu() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_root_panel, "modulate:a", 0.0, 0.45)


func atualizar_vida(vida_atual: int, vida_maxima: int, instant: bool = false) -> void:
	_health_bar.max_value = vida_maxima
	_trail_bar.max_value = vida_maxima
	_health_bar.value = vida_atual

	if instant:
		_trail_bar.value = vida_atual
		return

	if _trail_tween and _trail_tween.is_valid():
		_trail_tween.kill()
	_trail_tween = create_tween()
	_trail_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_trail_tween.tween_property(_trail_bar, "value", float(vida_atual), 0.35)
