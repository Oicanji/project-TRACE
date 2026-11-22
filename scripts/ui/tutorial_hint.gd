class_name TutorialHint
extends Area2D

signal dica_ativada(origem: Node, teclas: String, texto: String)
signal dica_desativada(origem: Node)
signal dica_concluida(origem: Node)

@export var teclas: String = "A / D"
@export var texto: String = "Mover"
@export var iniciar_visivel: bool = false
@export var tamanho_area: Vector2 = Vector2(360.0, 260.0)
@export var acoes_conclusao: PackedStringArray = PackedStringArray()
@export var exigir_escalada: bool = false

var _jogador: Node2D = null
var _ativa: bool = false
var _concluida: bool = false

@onready var _colisao: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_aplicar_area()
	set_process(false)
	if iniciar_visivel:
		call_deferred(&"_ativar_inicial")


func _process(_delta: float) -> void:
	if _concluida:
		set_process(false)
		return

	if exigir_escalada:
		if is_instance_valid(_jogador) and _jogador.get("GRAPPLE") == true:
			_marcar_concluida()
		return

	for acao: String in acoes_conclusao:
		if InputMap.has_action(acao) and Input.is_action_pressed(acao):
			_marcar_concluida()
			return


func _ativar_inicial() -> void:
	if _concluida or _ativa:
		return
	_ativa = true
	if not acoes_conclusao.is_empty():
		set_process(true)
	dica_ativada.emit(self, teclas, texto)


func _aplicar_area() -> void:
	if _colisao.shape is RectangleShape2D:
		var forma: RectangleShape2D = (_colisao.shape as RectangleShape2D).duplicate()
		forma.size = tamanho_area
		_colisao.shape = forma


func _marcar_concluida() -> void:
	_concluida = true
	_ativa = false
	set_process(false)
	dica_concluida.emit(self)


func _eh_jogador(body: Node) -> bool:
	return body.is_in_group("player") or body.name == "Player"


func _on_body_entered(body: Node2D) -> void:
	if not _eh_jogador(body):
		return

	_jogador = body
	if _concluida:
		return

	if exigir_escalada or not acoes_conclusao.is_empty():
		set_process(true)

	if not _ativa:
		_ativa = true
		dica_ativada.emit(self, teclas, texto)


func _on_body_exited(body: Node2D) -> void:
	if body != _jogador:
		return

	_jogador = null
	set_process(false)

	if _ativa:
		_ativa = false
		dica_desativada.emit(self)
