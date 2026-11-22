class_name TutorialExit
extends Area2D

signal dica_ativada(origem: Node, teclas: String, texto: String)
signal dica_desativada(origem: Node)

@export_file("*.tscn") var proxima_cena: String = "res://scenes/level_cidade.tscn"
@export var acao_interagir: StringName = &"interagir"
@export var teclas: String = "E"
@export var texto: String = "Avançar"

var _jogador_dentro: bool = false
var _trocando: bool = false


func _ready() -> void:
	set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _jogador_dentro or _trocando:
		return

	if event.is_action_pressed(acao_interagir):
		_avancar_fase()


func _avancar_fase() -> void:
	if proxima_cena.is_empty() or not ResourceLoader.exists(proxima_cena):
		push_warning("TutorialExit: proxima_cena inválida: %s" % proxima_cena)
		return

	_trocando = true
	dica_desativada.emit(self)
	get_tree().call_deferred("change_scene_to_file", proxima_cena)


func _eh_jogador(body: Node) -> bool:
	return body.is_in_group("player") or body.name == "Player"


func _on_body_entered(body: Node2D) -> void:
	if not _eh_jogador(body):
		return

	_jogador_dentro = true
	set_process_unhandled_input(true)
	var anim: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim and anim.has_animation(&"mostrar"):
		anim.play(&"mostrar")
	dica_ativada.emit(self, teclas, texto)


func _on_body_exited(body: Node2D) -> void:
	if not _eh_jogador(body):
		return

	_jogador_dentro = false
	set_process_unhandled_input(false)
	var anim: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim and anim.has_animation(&"esconder"):
		anim.play(&"esconder")
	dica_desativada.emit(self)
