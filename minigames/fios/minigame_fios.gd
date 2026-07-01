extends Node2D

@onready var botao_start = $BotaoStart
@onready var botao_fechar = $BotaoFechar  # Referência ao botão X

var pino_selecionado: Area2D = null
var fio_atual: Line2D = null
var arrastando: bool = false
var completado: bool = false

# Dicionário atualizado com as 4 cores
var conexoes_feitas = {
	"PinoOrigem_Vermelho": false,
	"PinoOrigem_Azul": false,
	"PinoOrigem_Verde": false,
	"PinoOrigem_Rosa": false
}

func _ready():
	_ajustar_escala()
	botao_start.pressed.connect(_on_botao_start_pressed)
	botao_fechar.pressed.connect(_on_botao_fechar_pressed) # Conecta o botão X
	
	# Conecta o clique em todos os pinos da esquerda automaticamente
	for pino in $TerminaisOrigem.get_children():
		pino.input_event.connect(_on_pino_input_event.bind(pino))

func _ajustar_escala() -> void:
	await get_tree().process_frame
	var vp = get_viewport().get_visible_rect().size
	# pega o tamanho original da cena (ajusta esses valores para cada minigame)
	var design = Vector2(1920.0, 1080.0)
	var s = minf(vp.x / design.x, vp.y / design.y)
	scale = Vector2(s, s)
	# centraliza
	position = (vp - design * s) / 2.0

func _process(_delta):
	if arrastando and fio_atual:
		# Corrigido: Converte a posição do mouse para o espaço local da linha
		var mouse_pos = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()
		fio_atual.set_point_position(1, fio_atual.to_local(get_global_mouse_position()))

func _on_pino_input_event(_viewport, event, _shape_idx, pino_clicado):
	if event is InputEventMouseButton and event.pressed and not completado:
		pino_selecionado = pino_clicado
		
		var nome_cor = pino_clicado.name.split("_")[1]
		fio_atual = get_node("FiosDesenho/Fio_" + nome_cor)
		
		fio_atual.clear_points()
		# Corrigido: O ponto inicial (0) e o móvel (1) começam na posição local correta
		fio_atual.add_point(fio_atual.to_local(pino_clicado.global_position))
		fio_atual.add_point(fio_atual.to_local(pino_clicado.global_position))
		
		arrastando = true

func _input(event):
	if event is InputEventMouseButton and not event.pressed:
		if arrastando:
			arrastando = false
			verificar_conexao_destino()

func verificar_conexao_destino():
	var acertou_pino = false
	var nome_cor_origem = pino_selecionado.name.split("_")[1]
	var mouse_pos = get_global_mouse_position()
	
	for pino_destino in $TerminaisDestino.get_children():
		var distancia = mouse_pos.distance_to(pino_destino.global_position)
		if distancia < 40.0:
			var nome_cor_destino = pino_destino.name.split("_")[1]
			if nome_cor_origem == nome_cor_destino:
				fio_atual.set_point_position(1, fio_atual.to_local(pino_destino.global_position))
				conexoes_feitas[pino_selecionado.name] = true
				acertou_pino = true
				print("Fio ", nome_cor_origem, " conectado corretamente!")
				break
	
	if not acertou_pino:
		fio_atual.clear_points()
		conexoes_feitas[pino_selecionado.name] = false
		print("Conexão inválida! O fio desconectou.")
	
	pino_selecionado = null
	fio_atual = null
# VALIDAÇÃO DO BOTÃO START
func _on_botao_start_pressed():
	if completado:
		return
		
	var tudo_conectado = true
	for status in conexoes_feitas.values():
		if status == false:
			tudo_conectado = false
			break
			
	if tudo_conectado:
		completado = true
		print("INCRÍVEL! Circuito elétrico restaurado com sucesso!")
		_passar_de_fase()
	else:
		print("ERRO! O circuito está incompleto. Refaça as conexões!")
		resetar_todos_os_fios()

# BOTÃO FECHAR (X)
func _on_botao_fechar_pressed():
	print("Minigame fechado pelo jogador.")
	self.visible = false # Esconde a tela do minigame imediatamente

func resetar_todos_os_fios():
	for fio in $FiosDesenho.get_children():
		fio.clear_points()
	for chave in conexoes_feitas.keys():
		conexoes_feitas[chave] = false
		
func _passar_de_fase():
	await get_tree().create_timer(1.5).timeout
	self.visible = false
