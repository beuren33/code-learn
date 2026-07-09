extends Node2D

signal concluido(sucesso: bool)

@onready var botao_start = $BotaoStart
@onready var botao_fechar = $BotaoFechar
@onready var led_aceso = $LedAcesoEfeito

# Controle de Arrastar Peças (LED / Resistor)
var peca_atual: Area2D = null
var arrastando_peca: bool = false
var pecas_no_lugar: Dictionary = {"Item_LED": false, "Item_Resistor": false}
var posicoes_iniciais_pecas: Dictionary = {}

# Controle dos Fios (Vermelho e Preto)
var fio_atual: Line2D = null
var pino_origem_atual: Area2D = null
var pino_alvo_atual: Area2D = null
var arrastando_fio: bool = false

var fio_positivo_ok: bool = false
var fio_negativo_ok: bool = false
var completado: bool = false

func _ready():
	botao_start.pressed.connect(_on_botao_start_pressed)
	botao_fechar.pressed.connect(_on_botao_fechar_pressed)
	led_aceso.visible = false
	
	# Configura LED e Resistor
	for peca in $PecasArrastaveis.get_children():
		posicoes_iniciais_pecas[peca] = peca.global_position
		peca.input_event.connect(_on_peca_input_event.bind(peca))
		
	# Configura os cliques nos dois polos da bateria (Positivo e Negativo)
	$PinosBateria/PoloPositivo.input_event.connect(_on_polo_bateria_input_event.bind($FioPositivo, $PinosBateria/PoloPositivo, $PinosBateria/EntradaPlacaPositivo))
	$PinosBateria/PoloNegativo.input_event.connect(_on_polo_bateria_input_event.bind($FioNegativo, $PinosBateria/PoloNegativo, $PinosBateria/EntradaPlacaNegativo))

func _process(_delta):
	# Movimento das Peças (LED / Resistor)
	if arrastando_peca and peca_atual and not completado:
		peca_atual.global_position = get_global_mouse_position()
		
	# Movimento dos Fios (A ponta móvel do fio)
	if arrastando_fio and fio_atual and not completado:
		# Corrigido: Usa a posição global diretamente no espaço da linha para evitar pulos
		fio_atual.set_point_position(1, fio_atual.to_local(get_global_mouse_position()))


func _on_polo_bateria_input_event(_viewport, event, _shape_idx, linha, origem, destino):
	if event is InputEventMouseButton and event.pressed and not completado:
		arrastando_fio = true
		fio_atual = linha
		pino_origem_atual = origem
		pino_alvo_atual = destino
		
		if linha == $FioPositivo: fio_positivo_ok = false
		else: fio_negativo_ok = false
		
		fio_atual.clear_points()
		# Corrigido: Garante que o início e o fim começam exatamente onde o polo da bateria está
		fio_atual.add_point(fio_atual.to_local(origem.global_position))
		fio_atual.add_point(fio_atual.to_local(origem.global_position))

func _input(event):
	if event is InputEventMouseButton and not event.pressed:
		if arrastando_peca:
			arrastando_peca = false
			verificar_encaixe_peca(peca_atual)
			peca_atual = null
			
		if arrastando_fio:
			arrastando_fio = false
			verificar_conexao_fio()

# --- ARRASTAR PEÇAS ---
func _on_peca_input_event(_viewport, event, _shape_idx, peca_clicada):
	if event is InputEventMouseButton and event.pressed and not completado:
		arrastando_peca = true
		peca_atual = peca_clicada

func verificar_encaixe_peca(peca: Area2D):
	var nome_vaga = peca.name.replace("Item_", "Vaga_")
	var vaga = get_node_or_null("VagasEncaixe/" + nome_vaga)
	
	if vaga and peca.overlaps_area(vaga):
		peca.global_position = vaga.global_position
		pecas_no_lugar[peca.name] = true
		print(peca.name, " no lugar certo!")
	else:
		pecas_no_lugar[peca.name] = false

# --- SISTEMA DOS DOIS FIOS ---

func verificar_conexao_fio():
	var mouse_pos = get_global_mouse_position()
	var conectou_certo = false
	
	var distancia = mouse_pos.distance_to(pino_alvo_atual.global_position)
	if distancia < 40.0:
		fio_atual.set_point_position(1, fio_atual.to_local(pino_alvo_atual.global_position))
		conectou_certo = true
		
		if fio_atual == $FioPositivo: fio_positivo_ok = true
		else: fio_negativo_ok = true
		
		print("Fio ", fio_atual.name, " conectado com sucesso!")
	
	if not conectou_certo:
		fio_atual.clear_points()
		if fio_atual == $FioPositivo: fio_positivo_ok = false
		else: fio_negativo_ok = false
		print("Fio solto fora do lugar.")
	
	fio_atual = null
	pino_origem_atual = null
	pino_alvo_atual = null

# --- BOTÃO START ---
func _on_botao_start_pressed():
	if completado:
		return
		
	# Só liga se: LED ok + Resistor ok + Fio Positivo ok + Fio Negativo ok
	if pecas_no_lugar["Item_LED"] and pecas_no_lugar["Item_Resistor"] and fio_positivo_ok and fio_negativo_ok:
		completado = true
		print("CIRCUTIO PERFEITO! Energia restaurada.")
		led_aceso.visible = true # Acende o LED
		_passar_de_fase()
	else:
		print("ERRO! O circuito continua sem energia. Verifique os componentes e a polaridade dos cabos.")
		resetar_tudo()

func resetar_tudo():
	var tween = create_tween().set_parallel(true)
	for peca in posicoes_iniciais_pecas.keys():
		tween.tween_property(peca, "global_position", posicoes_iniciais_pecas[peca], 0.4)
		pecas_no_lugar[peca.name] = false
		
	$FioPositivo.clear_points()
	$FioNegativo.clear_points()
	fio_positivo_ok = false
	fio_negativo_ok = false
	led_aceso.visible = false

func _on_botao_fechar_pressed():
	self.visible = false
	concluido.emit(false)

func _passar_de_fase():
	await get_tree().create_timer(2.0).timeout
	self.visible = false
	concluido.emit(true)
