extends Node2D

@onready var botao_start = $BotaoStart

var helice_atual: Area2D = null
var arrastando: bool = false
var completado: bool = false

# Guardar a posição inicial de início de cada hélice
var posicoes_iniciais: Dictionary = {}

func _ready():
	botao_start.pressed.connect(_on_botao_start_pressed)
	
	# Mapeia as hélices e suas posições de partida
	for filho in get_children():
		if "HeliceArrastavel" in filho.name:
			posicoes_iniciais[filho] = filho.global_position
			filho.input_event.connect(_on_helice_input_event.bind(filho))

func _process(_delta):
	if arrastando and helice_atual and not completado:
		helice_atual.global_position = get_global_mouse_position()

func _input(event):
	if event is InputEventMouseButton and not event.pressed:
		if arrastando:
			arrastando = false
			verificar_encaixe_temporario(helice_atual)
			helice_atual = null

func _on_helice_input_event(_viewport, event, _shape_idx, helice_clicada):
	if event is InputEventMouseButton and event.pressed and not completado:
		arrastando = true
		helice_atual = helice_clicada

# Quando solta, apenas "imanta" se estiver perto do motor
func verificar_encaixe_temporario(helice: Area2D):
	var vagas = get_tree().get_nodes_in_group("vagas_drone")
	for vaga in vagas:
		if helice.overlaps_area(vaga):
			helice.global_position = vaga.global_position
			print(helice.name, " encostou na vaga!")
			return

# VALIDAÇÃO DO BOTÃO START (Sem falhas)
func _on_botao_start_pressed():
	if completado:
		return
		
	var motor_esquerdo_ok = false
	var motor_direito_ok = false
	
	# Pegamos as duas vagas pelos nomes exatos que você deu na árvore de nós
	var vaga1 = $AreaEncaixe1
	var vaga2 = $AreaEncaixe2
	
	# O motor 1 está preenchido por alguma hélice?
	if vaga1.get_overlapping_areas().size() > 0:
		motor_esquerdo_ok = true
		
	# O motor 2 está preenchido por alguma hélice?
	if vaga2.get_overlapping_areas().size() > 0:
		motor_direito_ok = true
		
	# SÓ GANHA SE OS DOIS MOTORES TIVEREM ALGO EM CIMA
	if motor_esquerdo_ok and motor_direito_ok:
		completado = true
		print("INCRÍVEL! As duas hélices estão certas. Drone decolando!")
		_passar_de_fase()
	else:
		print("ERRO! O drone falhou. Alguma hélice está faltando ou fora do lugar!")
		resetar_helices()

func resetar_helices():
	var tween = create_tween().set_parallel(true)
	for helice in posicoes_iniciais.keys():
		tween.tween_property(helice, "global_position", posicoes_iniciais[helice], 0.4)

func _passar_de_fase():
	await get_tree().create_timer(1.5).timeout
	self.visible = false
