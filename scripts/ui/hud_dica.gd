class_name HudDica
extends CanvasLayer

@onready var _anchor: Control = $Anchor
@onready var _key_badge: PanelContainer = $Anchor/Margin/Center/Card/Padding/Row/KeyBadge
@onready var _key_label: Label = $Anchor/Margin/Center/Card/Padding/Row/KeyBadge/KeyMargin/KeyLabel
@onready var _action_label: Label = $Anchor/Margin/Center/Card/Padding/Row/ActionLabel
@onready var _firefly_dot: TextureRect = $Anchor/Margin/Center/Card/Padding/Row/FireflyDot
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _hide_timer: Timer = $HideTimer

var _origem_atual: Node = null
var _visivel: bool = false


func _ready() -> void:
	_anchor.modulate.a = 0.0
	_anchor.visible = false
	_anim.animation_finished.connect(_on_animation_finished)
	_hide_timer.timeout.connect(_on_hide_timer_timeout)


func mostrar_dica(origem: Node, teclas: String, texto: String) -> void:
	_hide_timer.stop()
	var mudou_origem: bool = _origem_atual != origem
	_origem_atual = origem

	_key_label.text = teclas
	_key_badge.visible = not teclas.is_empty()
	_action_label.text = texto
	_resetar_destaque()

	_anchor.visible = true
	if not _visivel or mudou_origem:
		_visivel = true
		_anim.stop()
		_anim.play(&"mostrar")


func esconder_dica(origem: Node) -> void:
	if origem != null and _origem_atual != origem:
		return

	_hide_timer.stop()
	_origem_atual = null
	if _visivel:
		_visivel = false
		_anim.play(&"esconder")


func concluir_dica(origem: Node) -> void:
	if _origem_atual != origem or not _visivel:
		return

	_anim.play(&"concluir")
	_hide_timer.start()


func _resetar_destaque() -> void:
	_key_badge.modulate = Color.WHITE
	_firefly_dot.modulate = Color.WHITE


func _on_hide_timer_timeout() -> void:
	if _origem_atual != null:
		esconder_dica(_origem_atual)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"esconder" and not _visivel:
		_anchor.visible = false
		_resetar_destaque()
