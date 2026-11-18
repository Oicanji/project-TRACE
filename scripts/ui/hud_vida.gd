extends CanvasLayer

@export var player: Node
@export var textura_cheia: Texture2D = preload("res://assets/ui/coracao_cheio.svg")
@export var textura_vazia: Texture2D = preload("res://assets/ui/coracao_vazio.svg")
@export var tamanho_coracao: Vector2 = Vector2(22, 22)

@onready var container_coracoes: HBoxContainer = $MarginContainer/Coracoes


func _ready() -> void:
	if not player and get_parent():
		player = get_parent().get_node_or_null("Player")

	if player and player.has_signal("vida_alterada"):
		if not player.vida_alterada.is_connected(_on_vida_alterada):
			player.vida_alterada.connect(_on_vida_alterada)
		atualizar_vida(player.vida, player.vida_maxima)
	else:
		atualizar_vida(3, 3)


func _on_vida_alterada(vida_atual: int, vida_maxima: int) -> void:
	atualizar_vida(vida_atual, vida_maxima)


func atualizar_vida(vida_atual: int, vida_maxima: int) -> void:
	if container_coracoes == null:
		return
	_garantir_quantidade_coracoes(vida_maxima)
	for i in container_coracoes.get_child_count():
		var coracao := container_coracoes.get_child(i) as TextureRect
		if coracao:
			coracao.texture = textura_cheia if i < vida_atual else textura_vazia


func _garantir_quantidade_coracoes(vida_maxima: int) -> void:
	while container_coracoes.get_child_count() < vida_maxima:
		var coracao := TextureRect.new()
		coracao.custom_minimum_size = tamanho_coracao
		coracao.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coracao.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		container_coracoes.add_child(coracao)

	while container_coracoes.get_child_count() > vida_maxima:
		var ultimo := container_coracoes.get_child(container_coracoes.get_child_count() - 1)
		container_coracoes.remove_child(ultimo)
		ultimo.queue_free()
