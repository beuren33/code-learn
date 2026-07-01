extends CanvasLayer

# ACRÉSCIMOS (em relação ao seu original):
#  - signal "concluido(acertou)": avisa o gerenciador quando a pergunta acabou.
#  - func abrir(indice): o gerenciador chama isso para mostrar a pergunta certa.
#  - ao ACERTAR, fecha sozinho depois de um instante (e emite "concluido").
# O resto é igual ao que você já tinha.

signal concluido(acertou: bool)
signal respondeu(acertou: bool)   # emitido em CADA tentativa (para o combate)

var imagem_normal = preload("res://sistema_quiz/artes/alternativaNeutro.png")
var imagem_verde = preload("res://sistema_quiz/artes/alternativaCorreta.png")
var imagem_vermelha = preload("res://sistema_quiz/artes/alternativaErrada.png")

@onready var label_pergunta = $fundoEscuro/painelFundo/fundoPergunta/textoPergunta
@onready var grid_opcoes = $fundoEscuro/painelFundo/opcoesContainer
@onready var botao_fechar = $fundoEscuro/painelFundo/fundoPergunta/botaoFechar

var banco_perguntas: Array = []
var pergunta_atual: Dictionary = {}
var botoes_alternativas: Array = []
var _indice_para_abrir: int = -1     # se >= 0, abre essa pergunta no _ready
var modo_combate: bool = false       # painel menor + fundo transparente (deixa ver a luta)


# O quiz foi desenhado numa tela grande (~1920x1080). Isto encaixa o painel no
# tamanho real da tela, então a pergunta nunca fica gigante nem estourada.
const DESIGN := Vector2(1080.0, 1920.0)

func _ready():
	botoes_alternativas = grid_opcoes.get_children()
	botao_fechar.pressed.connect(_on_botao_fechar_pressed)
	carregar_json()
	_ajustar_escala()


func _ajustar_escala() -> void:
	await get_tree().process_frame
	var painel: Control = $fundoEscuro/painelFundo
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var s: float = minf(vp.x / DESIGN.x, vp.y / DESIGN.y)
	if modo_combate:
		s *= 0.58
	painel.pivot_offset = painel.size / 2.0
	painel.scale = Vector2(s, s)
	if modo_combate:
		var fe := $fundoEscuro
		if fe is ColorRect:
			fe.color.a = 0.2
		painel.position.y -= vp.y * 0.12
	_anim_entrada(painel, s)


# Entrada suave: escurece o fundo e o painel surge crescendo um pouco.
func _anim_entrada(painel: Control, s: float) -> void:
	var fundo := $fundoEscuro
	if fundo is CanvasItem:
		fundo.modulate.a = 0.0
	painel.scale = Vector2(s * 0.9, s * 0.9)
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if fundo is CanvasItem:
		tw.tween_property(fundo, "modulate:a", 1.0, 0.28)
	tw.tween_property(painel, "scale", Vector2(s, s), 0.28)
	# Mostra a pergunta pedida pelo gerenciador (ou a 0, se aberta solta).
	if _indice_para_abrir >= 0:
		montar_pergunta(_indice_para_abrir)
	elif banco_perguntas.size() > 0:
		montar_pergunta(0)


## Chamado pelo gerenciador: mostra a pergunta de um índice e exibe o quiz.
func abrir(indice: int) -> void:
	_indice_para_abrir = indice
	if banco_perguntas.is_empty():
		carregar_json()
	montar_pergunta(indice)
	visible = true


func carregar_json():
	var caminho = "res://sistema_quiz/dados/perguntas.json"
	if FileAccess.file_exists(caminho):
		var arquivo = FileAccess.open(caminho, FileAccess.READ)
		var texto = arquivo.get_as_text()
		arquivo.close()
		var dados = JSON.parse_string(texto)
		if dados is Array:
			banco_perguntas = dados
		else:
			print("Erro: O formato do JSON deveria ser uma Lista []")
	else:
		print("Erro: Arquivo perguntas.json não foi encontrado em: ", caminho)


func montar_pergunta(indice: int):
	if indice >= banco_perguntas.size():
		print("Erro: Esse índice de pergunta não existe no JSON!")
		return
	pergunta_atual = banco_perguntas[indice]
	label_pergunta.text = pergunta_atual["pergunta"]
	for i in range(botoes_alternativas.size()):
		var botao = botoes_alternativas[i]
		var label_botao = botao.get_node("Label")
		label_botao.text = pergunta_atual["alternativas"][i]
		botao.texture_normal = imagem_normal
		if botao.pressed.is_connected(_ao_clicar_na_resposta):
			botao.pressed.disconnect(_ao_clicar_na_resposta)
		botao.pressed.connect(_ao_clicar_na_resposta.bind(i))


func _ao_clicar_na_resposta(indice_clicado: int):
	var resposta_correta = int(pergunta_atual["correta"])
	respondeu.emit(indice_clicado == resposta_correta)
	if indice_clicado == resposta_correta:
		botoes_alternativas[indice_clicado].texture_normal = imagem_verde
		print("Aluno acertou! Liberando o caminho.")
		_finalizar(true)
	else:
		var btn = botoes_alternativas[indice_clicado]
		btn.texture_normal = imagem_vermelha
		print("Aluno errou! Tente novamente.")
		await get_tree().create_timer(0.6).timeout
		if is_instance_valid(btn):
			btn.texture_normal = imagem_normal


# Ao acertar: espera um instante (para o jogador ver o verde) e fecha.
func _finalizar(acertou: bool) -> void:
	await get_tree().create_timer(0.6).timeout
	var fundo := $fundoEscuro
	if fundo is CanvasItem:
		var tw := create_tween()
		tw.tween_property(fundo, "modulate:a", 0.0, 0.22)
		await tw.finished
	visible = false
	concluido.emit(acertou)


func _on_botao_fechar_pressed():
	visible = false
	concluido.emit(false)
