extends CharacterBody2D

@onready var olhar_esquerdo: RayCast2D = $olhar_esquerdo
@onready var olhar_direito: RayCast2D = $olhar_direito
@onready var tem_chao_esquerdo: RayCast2D = $tem_chao_esquerdo
@onready var tem_chao_direita: RayCast2D = $tem_chao_direita

const SPEED = 3000.0
const STEPS = 150
var acc_steps = STEPS
var maximo_passos: int
var last_step 
var direction_change_chance = 0.95

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	inteligencia(delta)
	
	move_and_slide()

func inteligencia(delta: float):
	var direcao_aleatoria = 0
	if acc_steps == maximo_passos:
		direcao_aleatoria = randi_range(-1, 1)
		if direcao_aleatoria == 0:
			direcao_aleatoria = 1
			
		maximo_passos = randi_range(0, STEPS)
		
		last_step = direcao_aleatoria
		acc_steps = 0
	else:
		direcao_aleatoria=last_step
		acc_steps+=1
	
	# -1 SE TEM CHÃO A ESQUERDA
	if direcao_aleatoria == -1 and tem_chao_esquerdo.is_colliding():
		velocity.x = (SPEED*direcao_aleatoria) * delta
	elif direcao_aleatoria == 1 and tem_chao_direita.is_colliding():
		velocity.x = (SPEED*direcao_aleatoria) * delta
	else:
		velocity.x = 0
		acc_steps = maximo_passos



func bateu_na_hitbox(body: Area2D) -> void:
	if body.is_in_group("player"):
		print("O jogador entrou na área!")
	
