extends Node2D
class_name StoryboardDirector
# ─────────────────────────────────────────────────────────────────────────────
# DIRETOR DO STORYBOARD — protagonista (+ robô ALIADO a partir da cidade) viajando
# por TODAS as 9 telas do roteiro (o PDF "documentoCodeLearn").
#
# MAPA DAS TELAS (já batendo com o seu LDtk):
#   Level_0  Fazenda / drone           Level_5  Loja por dentro (armário)
#   Level_1  Fazenda / camionete       Level_6  Fábrica por fora (portão)
#   Level_2  Rodovia (carro andando)   Level_7  Fábrica por dentro (braço -> sobe)
#   Level_3  Cidade (robô vira aliado) Level_8  Sala de produção (inimigo+boss+final)
#   Level_4  Loja por fora (entrada)
#
# O roteiro é uma LISTA de cenas (veja _construir_roteiro): para mudar/acrescentar
# uma tela é só editar uma linha. Telas cujo Level ainda não exista são PULADAS
# com aviso, sem quebrar o jogo.
#
# LIGAR SEUS MINIGAMES/PERGUNTAS:
#   dir.modo_automatico = false
#   dir.personagem_chegou.connect(func(cena): ...)   # abra o quiz dessa cena
#   # quando o jogador terminar: dir.continuar()
# ─────────────────────────────────────────────────────────────────────────────

signal personagem_chegou(cena: int)
signal mudou_de_tela(cena: int)

enum Transicao { DESLIZAR, CORTE, ESCURECER }
enum Lado { ESQUERDA, CENTRO, DIREITA }

# ===== CÂMERA =================================================================
@export_group("Câmera")
@export var usar_camera: bool = true
@export var tamanho_tela: Vector2 = Vector2(320, 160)
@export var enquadrar_level_inteiro: bool = true
@export var levels_largos: Array[String] = ["Level_4", "Level_5", "Level_6", "Level_8"]  # telas de 640px (câmera segue)
@export var zoom_manual: Vector2 = Vector2(3, 3)

# ===== TRANSIÇÃO =============================================================
@export_group("Transição entre telas")
@export var tipo_transicao: Transicao = Transicao.ESCURECER
@export var duracao_transicao: float = 1.0
@export var cor_escurecer: Color = Color.BLACK

# ===== PROTAGONISTA ==========================================================
@export_group("Protagonista")
@export var nome_personagem: String = "PersonagemStoryboard"
@export var velocidade: float = 45.0
@export var margem: float = 12.0
@export var parada_antes: float = 22.0
@export var animacao_ao_parar: String = "Interact_Side"

# ===== ROBÔ ALIADO ===========================================================
@export_group("Robô aliado (vira aliado na cidade e segue até o fim)")
## É o mesmo nó que começa como o robô danificado da cidade (PersonagemTela4).
@export var nome_aliado: String = "PersonagemTela4"
## Distância (px) que o aliado fica ATRÁS do protagonista nas caminhadas juntos.
@export var distancia_aliado: float = 24.0

# ===== ALTURA DO CHÃO (Y) POR TELA (conserta "personagem voando") ============
@export_group("Altura do chão (Y) por tela")
@export var y_fazenda_drone: float = 135.0
@export var y_fazenda_carro: float = 155.0
@export var y_rodovia: float = 150.0
@export var y_cidade: float = 154.0
@export var y_loja_fora: float = 150.0
@export var y_loja_dentro: float = 150.0
@export var y_fabrica_fora: float = 150.0
@export var y_fabrica_dentro: float = 150.0
@export var y_segundo_andar: float = 95.0    # depois de subir pelo braço robótico
@export var y_producao: float = 150.0

# ===== TELAS (Levels do LDtk) ================================================
@export_group("Telas — Levels do LDtk")
@export var level_fazenda_drone: String = "Level_0"
@export var level_fazenda_carro: String = "Level_1"
@export var level_rodovia: String = "Level_2"
@export var level_cidade: String = "Level_3"
@export var level_loja_fora: String = "Level_4"
@export var level_loja_dentro: String = "Level_5"
@export var level_fabrica_fora: String = "Level_6"
@export var level_fabrica_dentro: String = "Level_7"
@export var level_producao: String = "Level_8"

# ===== ALVOS DAS MISSÕES (os "!") ============================================
# Os que ainda não existem fazem o personagem parar no CENTRO da tela (e a
# pergunta dispara igual). Crie cada um como um Sprite2D com o exclamacao.png.
@export_group("Alvos das missões (nós com o \"!\")")
@export var nome_drone: String = "DroneStoryboard"
@export var nome_excl_carro: String = "ExclamacaoCarro"
@export var nome_excl_npc_aliado: String = "PersonagemTela4/ExclamacaoNpc"
@export var nome_porta_loja: String = "PortaLoja"
@export var nome_armario_loja: String = "ArmarioLoja"
@export var nome_portao_fabrica: String = "PortaoFabrica"
@export var nome_braco_robotico: String = "BracoRobotico"
@export var nome_robo_inimigo: String = "RoboInimigo"
@export var nome_inimigo_fora: String = "RoboInimigoFora"
@export var nome_super_boss: String = "SuperBoss"
@export var nome_painel_esteira: String = "PainelEsteira"

# ===== PRÉ-VISUALIZAÇÃO ======================================================
@export_group("Pré-visualização (sem minigames)")
@export var modo_automatico: bool = true
@export var espera_questoes: float = 2.0
@export var duracao_rodovia: float = 3.0     # tempo do trecho dirigindo (cena 3)

# ===== EFEITO DE CARRO/CENÁRIO ANDANDO =======================================
@export_group("Efeito de carro/cenário andando")
@export var efeito_carro_andando: bool = true
@export var velocidade_scroll: float = 45.0
@export var scroll_para_esquerda: bool = true
@export var mover_cena_toda: bool = true
@export var camada_carro_rodovia: String = "Tiles4"
@export var parallax_rodovia: bool = true

const CAMINHO_SCROLL := "res://characters/cenario_carro_andando.gd"

var _cam: Camera2D = null
var _pers: PersonagemStoryboard = null
var _aliado: PersonagemStoryboard = null
var _fade: ColorRect = null
var _scroller: Node = null
var _continuar_pedido: bool = false
var _roteiro: Array = []
var _seguir_level: String = ""   # qual Level a câmera deve seguir (vazio = parada)


func _ready() -> void:
	await get_tree().process_frame
	if usar_camera:
		_criar_camera()
	_criar_fade()
	_pers = _achar(nome_personagem) as PersonagemStoryboard
	if _pers == null:
		push_warning("StoryboardDirector: protagonista '%s' não encontrado." % nome_personagem)
		return
	_pers.assumir_controle()
	_pers.velocidade = velocidade
	_aliado = _achar(nome_aliado) as PersonagemStoryboard
	if _aliado != null:
		_aliado.assumir_controle()
		_aliado.velocidade = velocidade
	_roteiro = _construir_roteiro()
	_rodar_roteiro()


# ===== API PÚBLICA ============================================================

# Câmera segue o personagem dentro da tela (em telas largas tipo 640).
func _process(_delta: float) -> void:
	if _seguir_level == "" or _cam == null or _pers == null or not _pers.visible:
		return
	var n := _achar_level(_seguir_level)
	if n == null:
		return
	var left: float = n.global_position.x
	var larg: float = _largura_level(n)
	var half: float = tamanho_tela.x * 0.5
	var alvo_x: float
	if larg <= tamanho_tela.x:
		alvo_x = left + larg * 0.5
	else:
		alvo_x = clampf(_pers.position.x, left + half, left + larg - half)
	_cam.position.x = lerpf(_cam.position.x, alvo_x, 0.15)


func continuar() -> void:
	_continuar_pedido = true

func avancar() -> void:
	continuar()


# ===== ROTEIRO (dados) ========================================================
func _construir_roteiro() -> Array:
	return [
		# 1) FAZENDA / DRONE: sai de casa (esquerda), vai até o drone, conserta. (N1, Mg1)
		_cena({
			"cena": 1, "level": level_fazenda_drone, "y": y_fazenda_drone,
			"entra": Lado.ESQUERDA, "anda_ate": nome_drone,
			"esconder": nome_drone + "/Exclamacao", "questao": true, "primeira": true,
			"voltar_para": Lado.ESQUERDA,
		}),
		# 2) FAZENDA / CAMIONETE: vai até o carro, liga e entra. (N2, N3)
		_cena({
			"cena": 2, "level": level_fazenda_carro, "y": y_fazenda_carro,
			"entra": Lado.DIREITA, "anda_ate": nome_excl_carro,
			"esconder": nome_excl_carro, "questao": true, "some_fim": true,
		}),
		# 3) RODOVIA: dirigindo (cenário desliza); a camionete falha no caminho.
		_cena({
			"cena": 3, "level": level_rodovia, "y": y_rodovia,
			"scroll": true,
		}),
		# 4) CIDADE: sai do carro, acha o robô danificado e o conserta -> ALIADO. (N4, Mg2, Mg3)
		_cena({
			"cena": 4, "level": level_cidade, "y": y_cidade,
			"entra": Lado.ESQUERDA, "anda_ate": nome_aliado, "x_inicial": 1200.0,
			"esconder": nome_excl_npc_aliado, "questao": true,
		}),
		# 5) LOJA POR FORA: os DOIS vão até a porta (Mercado do Tomás) e entram. (N5)
		_cena({
			"cena": 5, "level": level_loja_fora, "y": y_loja_fora,
			"entra": Lado.ESQUERDA, "anda_ate": nome_porta_loja, "ally": true,
			"esconder": nome_porta_loja, "questao": true, "some_fim": true,
		}),
		# 6) LOJA POR DENTRO: vai até o super armário, resolve, pega itens e tranca. (Mg4, Mg5)
		_cena({
			"cena": 6, "level": level_loja_dentro, "y": y_loja_dentro,
			"entra": Lado.ESQUERDA, "anda_ate": nome_armario_loja, "ally": true,
			"esconder": nome_armario_loja, "questao": true,
			"voltar_para": Lado.ESQUERDA,
		}),
		# 6.5) SAÍDA DA LOJA: reaparece na frente do mercado e segue reto até a fábrica.
		_cena({
			"cena": 50, "level": level_loja_fora, "y": y_loja_fora,
			"entra": Lado.ESQUERDA, "ally": true, "x_inicial": 1950.0,
			"sai_para": Lado.DIREITA, "questao": false,
		}),
		# 7) FÁBRICA POR FORA: vai até o portão e resolve para entrar. (N8)
		_cena({
			"cena": 7, "level": level_fabrica_fora, "y": y_fabrica_fora,
			"entra": Lado.ESQUERDA, "anda_ate": nome_inimigo_fora, "ally": true,
			"anim_parar": "Punch_Side",
			"esconder": nome_portao_fabrica, "questao": true,
		}),
		# 8) FÁBRICA POR DENTRO: conserta o braço robótico e SOBE ao 2º andar. (N9, N10, Mg6)
		_cena({
			"cena": 8, "level": level_fabrica_dentro, "y": y_fabrica_dentro,
			"entra": Lado.ESQUERDA, "anda_ate": nome_robo_inimigo, "ally": true,
			"anim_parar": "Punch_Side",
			"esconder": nome_robo_inimigo, "questao": true,
			"voltar_para": Lado.DIREITA,
		}),
		# 9) SALA DE PRODUÇÃO — robô inimigo: enfrentar. (N11, N12)
		_cena({
			"cena": 9, "level": level_producao, "y": y_producao,
			"entra": Lado.ESQUERDA, "anda_ate": nome_robo_inimigo, "ally": true,
			"anim_parar": "Punch_Side", "esconder": nome_robo_inimigo, "questao": true,
		}),
		# 10) BATALHA FINAL — o BOSS (mesma tela; não troca de Level). (Mg7, N13, N14, N15)
		_cena({
			"cena": 10, "level": level_producao, "y": y_producao, "continua": true,
			"anda_ate": nome_super_boss, "ally": true,
			"pose_fim": "Punch_Side", "esconder": nome_super_boss, "questao": true,
		}),
		# 11) FINAL — conserta o painel da esteira; a cidade é salva. (N16, Mg8)
		_cena({
			"cena": 11, "level": level_producao, "y": y_producao, "continua": true,
			"anda_ate": nome_painel_esteira, "ally": true,
			"esconder": nome_painel_esteira, "questao": true,
		}),
	]


# Preenche os padrões de uma cena (você só escreve o que muda).
func _cena(d: Dictionary) -> Dictionary:
	var base := {
		"cena": 0, "level": "", "y": 150.0,
		"entra": Lado.ESQUERDA, "anda_ate": "", "sai_para": Lado.CENTRO,
		"anim_parar": animacao_ao_parar, "esconder": "", "questao": false,
		"voltar_para": Lado.CENTRO, "subir": 0.0, "pose_fim": "",
		"ally": false, "some_fim": false, "scroll": false,
		"primeira": false, "continua": false, "x_inicial": 0.0,
	}
	base.merge(d, true)
	return base


# ===== ROTEIRO (execução) =====================================================

func _rodar_roteiro() -> void:
	for cena in _roteiro:
		await _rodar_cena(cena)
	await _escurecer(1.0, duracao_transicao * 0.5)   # fecha no fim
	_mostrar_fim()


func _mostrar_fim() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/Credits/Credits.tscn")


func _rodar_cena(c: Dictionary) -> void:
	var level_nome: String = c["level"]
	var level := _achar_level(level_nome)
	if level == null:
		push_warning("StoryboardDirector: Level '%s' (cena %d) não existe — pulando."
			% [level_nome, int(c["cena"])])
		return

	var usa_aliado: bool = c["ally"] and _aliado != null

	# "continua" = mesma tela da cena anterior: não transiciona nem reposiciona.
	if not c["continua"]:
		if c["primeira"]:
			_enquadrar_instantaneo(level_nome)
			mudou_de_tela.emit(int(c["cena"]))
		else:
			await _transicao(level_nome, int(c["cena"]))

		# Cena de scroll (dirigindo): personagem dentro do carro -> invisível.
		if c["scroll"]:
			_seguir_level = ""
			_pers.visible = false
			if _aliado != null:
				_aliado.visible = false
			if efeito_carro_andando:
				_ligar_scroll()
			if c["questao"]:
				personagem_chegou.emit(int(c["cena"]))
				await _esperar_questoes()
			else:
				await get_tree().create_timer(duracao_rodovia).timeout
			_parar_scroll()
			return

		# Posiciona protagonista e (se for o caso) o aliado.
		_pers.visible = true
		var _xini: float = float(c.get("x_inicial", 0.0))
		var _x0: float = _xini if _xini > 0.0 else _x_entrada(level_nome, c["entra"])
		_pers.position = Vector2(_x0, c["y"])
		_cam.position.x = _centro_da_tela(level_nome).x if _cam else 0.0
		_seguir_level = level_nome
		# Se o ALVO desta cena é o robô aliado (cidade), garante que ele apareça.
		if c["anda_ate"] == nome_aliado and _aliado != null:
			_aliado.visible = true
			_aliado.position = Vector2(_centro_x(level_nome) + 40.0, c["y"])
			if _aliado.sprite_frames != null and _aliado.sprite_frames.has_animation("Idle_Side"):
				_aliado.play("Idle_Side")
		if usa_aliado:
			_aliado.visible = true
			var atras := -1.0 if c["entra"] == Lado.DIREITA else 1.0
			_aliado.position = Vector2(_pers.position.x - distancia_aliado * atras, c["y"])

	# Caminhada: até um alvo (com "!") OU até uma borda de saída.
	if c["anda_ate"] != "":
		await _andar_ate(_x_obj(c["anda_ate"], level_nome), c["anim_parar"], usa_aliado)
	elif c["sai_para"] != Lado.CENTRO:
		await _andar_ate(_x_borda_saida(level_nome, c["sai_para"]), "", usa_aliado)

	# Pose especial ao chegar (ex.: lutar com o boss).
	if c["pose_fim"] != "":
		_pers.tocar_pose(c["pose_fim"], true)

	# Gancho da pergunta/minigame.
	if c["questao"]:
		_continuar_pedido = false
		await get_tree().create_timer(2.0).timeout   # segura a pose parado 2s antes do quiz
		personagem_chegou.emit(int(c["cena"]))
		await _esperar_questoes()

	# Some o "!" depois da pergunta.
	if c["esconder"] != "":
		_esconder_marcador(c["esconder"])

	# Sobe pelo braço robótico (depois de consertado).
	if float(c["subir"]) > 0.0:
		await _subir(float(c["subir"]), usa_aliado)

	# Volta para uma borda (ex.: sair pela esquerda).
	if c["voltar_para"] != Lado.CENTRO:
		await _andar_ate(_x_borda_saida(level_nome, c["voltar_para"]), "", usa_aliado)

	# Some no fim (entra no carro / loja / fábrica).
	if c["some_fim"]:
		_pers.visible = false
		if usa_aliado:
			_aliado.visible = false


# ===== CAMINHADA ==============================================================

func _andar_ate(x_mundo: float, anim: String, usa_aliado: bool) -> void:
	if _pers == null:
		return
	var de_esquerda := _pers.position.x < x_mundo
	var destino := x_mundo
	if anim != "":
		destino = (x_mundo - parada_antes) if de_esquerda else (x_mundo + parada_antes)
	var atras := distancia_aliado if de_esquerda else -distancia_aliado
	_pers.ir_para_x(destino, anim)
	if usa_aliado:
		_aliado.ir_para_x(destino - atras, "")
	await _pers.chegou


func _subir(px: float, usa_aliado: bool) -> void:
	var dur: float = maxf(0.5, px / maxf(10.0, velocidade))
	_pers.tocar_pose("Jump_Up", true)
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_pers, "position:y", _pers.position.y - px, dur)
	if usa_aliado:
		_aliado.tocar_pose("Jump_Up", true)
		tw.tween_property(_aliado, "position:y", _aliado.position.y - px, dur)
	if _cam != null:
		tw.tween_property(_cam, "position:y", _cam.position.y - px, dur)
	await tw.finished
	_pers.tocar_pose("Idle_Side", true)
	if usa_aliado:
		_aliado.tocar_pose("Idle_Side", true)


func _esperar_questoes() -> void:
	if modo_automatico:
		await get_tree().create_timer(espera_questoes).timeout
	else:
		while not _continuar_pedido:
			await get_tree().process_frame
		_continuar_pedido = false


# ===== CÂMERA / TRANSIÇÃO =====================================================

func _criar_camera() -> void:
	_cam = Camera2D.new()
	_cam.name = "CameraStoryboard"
	_cam.position_smoothing_enabled = false
	_cam.zoom = _zoom_para_caber_level() if enquadrar_level_inteiro else zoom_manual
	add_child(_cam)
	_cam.make_current()

func _zoom_para_caber_level() -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	if tamanho_tela.x <= 0.0 or tamanho_tela.y <= 0.0:
		return Vector2(3, 3)
	var fator: float = minf(vp.x / tamanho_tela.x, vp.y / tamanho_tela.y)
	if fator <= 0.0:
		fator = 3.0
	return Vector2(fator, fator)

func _enquadrar_instantaneo(nome_level: String) -> void:
	if not usar_camera or _cam == null:
		return
	_seguir_level = ""
	_cam.position = _centro_da_tela(nome_level)

func _transicao(nome_level: String, numero: int) -> void:
	match tipo_transicao:
		Transicao.ESCURECER:
			await _escurecer(1.0, duracao_transicao * 0.5)
			_enquadrar_instantaneo(nome_level)
			await _escurecer(0.0, duracao_transicao * 0.5)
		Transicao.CORTE:
			_enquadrar_instantaneo(nome_level)
		Transicao.DESLIZAR:
			if usar_camera and _cam != null:
				var tw := create_tween()
				tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				tw.tween_property(_cam, "position", _centro_da_tela(nome_level), duracao_transicao)
				await tw.finished
	mudou_de_tela.emit(numero)

func _centro_da_tela(nome_level: String) -> Vector2:
	var n := _achar_level(nome_level)
	return (n.global_position + tamanho_tela * 0.5) if n != null else Vector2.ZERO


# ===== FADE ===================================================================

func _criar_fade() -> void:
	var camada := CanvasLayer.new()
	camada.name = "FadeLayer"
	camada.layer = 100
	add_child(camada)
	_fade = ColorRect.new()
	_fade.color = Color(cor_escurecer.r, cor_escurecer.g, cor_escurecer.b, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(_fade)

func _escurecer(alpha: float, dur: float) -> void:
	if _fade == null:
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, dur)
	await tw.finished


# ===== POSIÇÕES (mundo) ======================================================

func _x_entrada(nome_level: String, lado: int) -> float:
	match lado:
		Lado.ESQUERDA: return _borda_esquerda(nome_level) - 20.0
		Lado.DIREITA: return _borda_direita(nome_level)
		_: return _centro_x(nome_level)

func _x_borda_saida(nome_level: String, lado: int) -> float:
	match lado:
		Lado.ESQUERDA: return _borda_esquerda(nome_level) - 24.0
		Lado.DIREITA: return _borda_direita(nome_level) + 24.0
		_: return _centro_x(nome_level)

func _borda_esquerda(nome_level: String) -> float:
	var n := _achar_level(nome_level)
	return (n.global_position.x + margem) if n != null else 0.0

func _borda_direita(nome_level: String) -> float:
	var n := _achar_level(nome_level)
	# A largura real do Level pode ser 320 ou 640; usa a do nó quando der.
	var larg: float = tamanho_tela.x
	if n != null and "get_rect" in n:
		pass
	return (n.global_position.x + _largura_level(n) - margem) if n != null else larg

func _centro_x(nome_level: String) -> float:
	var n := _achar_level(nome_level)
	return (n.global_position.x + _largura_level(n) * 0.5) if n != null else tamanho_tela.x * 0.5

# Largura do Level (px). Tenta ler do nó; cai para tamanho_tela.x se não der.
func get_personagem() -> Node2D:
	return _pers


func get_aliado() -> Node2D:
	return _aliado


func _largura_level(n: Node) -> float:
	if n != null and n.name in levels_largos:
		return 640.0
	return tamanho_tela.x

func _x_obj(nome_obj: String, level_fallback: String) -> float:
	var o := _achar(nome_obj)
	return (o as Node2D).global_position.x if o is Node2D else _centro_x(level_fallback)


# ===== "!" DAS MISSÕES ========================================================

# Esconde um "!" pelo nome. Aceita "NoFilho" ou "Pai/Filho".
func _esconder_marcador(caminho: String) -> void:
	var partes := caminho.split("/")
	var no := _achar(partes[0])
	if no == null:
		return
	if partes.size() > 1:
		no = no.get_node_or_null(partes[1])
	if no == null:
		return
	if no.has_method("concluir"):
		no.call("concluir")
	elif "visible" in no:
		no.set("visible", false)


# ===== EFEITO DE CENÁRIO ANDANDO =============================================

func _ligar_scroll() -> void:
	if _scroller != null:
		return
	var level2 := _achar_level(level_rodovia)
	if level2 == null or not ResourceLoader.exists(CAMINHO_SCROLL):
		return
	var scr := load(CAMINHO_SCROLL)
	if scr == null:
		return
	var no := Node2D.new()
	no.set_script(scr)
	no.name = "CenarioCarroAndando"
	level2.add_child(no)
	no.set("velocidade", velocidade_scroll)
	no.set("para_esquerda", scroll_para_esquerda)
	no.set("tamanho_tela", tamanho_tela)
	no.set("camada_carro", camada_carro_rodovia)
	no.set("parallax", parallax_rodovia)
	no.set("mover_cena_toda", mover_cena_toda)
	_scroller = no
	if no.has_method("iniciar"):
		no.call("iniciar")

func _parar_scroll() -> void:
	if _scroller != null and is_instance_valid(_scroller):
		if _scroller.has_method("parar"):
			_scroller.call("parar")
		_scroller.queue_free()
	_scroller = null


# ===== BUSCAS =================================================================

func _achar_level(nome: String) -> Node2D:
	return get_tree().current_scene.find_child(nome, true, false) as Node2D

func _achar(nome: String) -> Node:
	return get_tree().current_scene.find_child(nome, true, false)
