extends Node2D
class_name StoryboardDirector
# ─────────────────────────────────────────────────────────────────────────────
# DIRETOR DO STORYBOARD — UM protagonista que viaja pelas telas.
#
# FLUXO (exatamente como você pediu):
#   1) TELA 2 (celeiro): o protagonista aparece e caminha para a ESQUERDA.
#   2) TELA 1 (drone): aparece na ESQUERDA, anda até o drone, faz a missão,
#      e VOLTA (sai pela esquerda).
#   3) TELA 2 (celeiro): volta, vai até o CARRO e arruma.
#   4) TELA 3 (rodovia): transição; a cena TODA se move menos o carro.
#   5) TELA 4: o protagonista chega e encontra outro personagem (2 no total).
#   6) TELA 5: idem — 2 personagens.
#
# Os "outros personagens" (NPCs) das telas 4 e 5 ficam PARADOS, posicionados na
# mão no editor (nós "PersonagemTela4" e "NpcTela5"). O diretor só conduz o
# PROTAGONISTA ("PersonagemStoryboard") e anda ele até perto do NPC.
#
# LIGAR SEUS MINIGAMES:
#   dir.modo_automatico = false
#   dir.personagem_chegou.connect(func(tela): ...)   # abra o quiz
#   # ao terminar: dir.continuar()
# ─────────────────────────────────────────────────────────────────────────────

signal personagem_chegou(tela: int)
signal mudou_de_tela(tela: int)

enum Transicao { DESLIZAR, CORTE, ESCURECER }
enum Lado { ESQUERDA, CENTRO, DIREITA }

# ===== CÂMERA =================================================================
@export_group("Câmera")
@export var usar_camera: bool = true
@export var tamanho_tela: Vector2 = Vector2(320, 160)
@export var enquadrar_level_inteiro: bool = true
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

# ----- Altura do chão (Y) por tela (conserta "personagem voando") ------------
@export_group("Altura do chão (Y) por tela")
@export var y_celeiro: float = 155.0
@export var y_drone: float = 135.0
@export var y_rodovia: float = 150.0
@export var y_tela4: float = 154.0
@export var y_tela5: float = 155.0

# ===== TELAS (Levels do LDtk) ================================================
@export_group("Telas (Levels do LDtk)")
@export var level_celeiro: String = "Level_1"   # TELA 2 (começo)
@export var level_drone: String = "Level_0"     # TELA 1
@export var level_rodovia: String = "Level_2"   # TELA 3
@export var level_tela4: String = "Level_3"     # TELA 4 (encontra o NPC)
@export var level_tela5: String = "Level_5"     # TELA 5 (o MERCADO)

# ===== OUTRO PERSONAGEM (o NPC da tela 4 que depois caminha junto) ===========
@export_group("NPC (o 2º personagem)")
## O 2º personagem: fica parado na tela 4 com um "!" e depois caminha junto até
## o mercado. É o nó "PersonagemTela4" (com o filho "ExclamacaoNpc").
@export var npc_tela4: String = "PersonagemTela4"
## Tempo (s) da caminhada conjunta da tela 4 até o mercado (câmera seguindo).
@export var duracao_caminhada_mercado: float = 3.5

# ===== ALVOS DAS MISSÕES (os "!") ============================================
@export_group("Alvos das missões")
@export var nome_excl_carro: String = "ExclamacaoCarro"
@export var nome_drone: String = "DroneStoryboard"

# ===== PRÉ-VISUALIZAÇÃO ======================================================
@export_group("Pré-visualização (sem minigames)")
@export var modo_automatico: bool = true
@export var espera_questoes: float = 2.0

# ===== TELA 3 — efeito de carro andando ======================================
@export_group("Tela 3 — carro andando")
@export var efeito_carro_andando: bool = true
@export var velocidade_scroll: float = 45.0
@export var scroll_para_esquerda: bool = true
@export var mover_cena_toda: bool = true
@export var camada_carro_rodovia: String = "Tiles4"
@export var parallax_rodovia: bool = true

const CAMINHO_SCROLL := "res://characters/cenario_carro_andando.gd"

var _cam: Camera2D = null
var _pers: PersonagemStoryboard = null
var _fade: ColorRect = null
var _scroller: Node = null
var _continuar_pedido: bool = false


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
	_rodar_roteiro()


# ===== API PÚBLICA ============================================================

func continuar() -> void:
	_continuar_pedido = true

func avancar() -> void:
	continuar()


# ===== ROTEIRO ================================================================

func _rodar_roteiro() -> void:
	# 1) TELA 2 (celeiro): aparece na DIREITA e caminha para a ESQUERDA.
	_enquadrar_instantaneo(level_celeiro)
	mudou_de_tela.emit(2)
	_pers.visible = true
	_pers.position = Vector2(_borda_direita(level_celeiro), y_celeiro)
	await _andar(_borda_esquerda(level_celeiro) - 12.0)

	# -> TELA 1 (drone)
	await _transicao(level_drone, 1)

	# 2) TELA 1 (drone): aparece na esquerda, anda até o drone, VOLTA.
	_pers.position = Vector2(_borda_esquerda(level_drone), y_drone)
	await _andar_ate_objeto(_x_obj(nome_drone, level_drone))
	personagem_chegou.emit(1)
	await _esperar_questoes()
	_esconder_excl_drone()
	await _andar(_borda_esquerda(level_drone) - 12.0)   # volta pela esquerda

	# -> TELA 2 (celeiro)
	await _transicao(level_celeiro, 2)

	# 3) TELA 2: vai até o CARRO e arruma.
	_pers.position = Vector2(_borda_direita(level_celeiro), y_celeiro)
	await _andar_ate_objeto(_x_obj(nome_excl_carro, level_celeiro))
	personagem_chegou.emit(2)
	await _esperar_questoes()
	_esconder_excl_carro()
	_pers.visible = false   # entra no carro

	# 4) -> TELA 3 (rodovia): cena toda se move, menos o carro.
	await _transicao(level_rodovia, 3)
	if efeito_carro_andando:
		_ligar_scroll()
	await _esperar_questoes()
	_parar_scroll()

	# 5) -> TELA 4: encontra o outro personagem (com "!" vermelho na cabeça).
	await _transicao(level_tela4, 4)
	_pers.position = Vector2(_borda_esquerda(level_tela4), y_tela4)
	_pers.visible = true
	await _andar_ate_npc(npc_tela4, level_tela4)
	personagem_chegou.emit(4)
	await _esperar_questoes()
	_esconder_excl_npc(npc_tela4)              # o "!" some

	# 6) -> TELA 5 (MERCADO): os DOIS caminham juntos, a câmera segue, e entram.
	await _caminhar_juntos_ate_mercado(npc_tela4)
	personagem_chegou.emit(5)
	await _esperar_questoes()
	# Entram no mercado (somem).
	_pers.visible = false
	var npc_final := _achar(npc_tela4)
	if npc_final != null and "visible" in npc_final:
		npc_final.set("visible", false)


# ===== CAMINHADA ==============================================================

# Anda até um X (mundo). Sem animação especial ao parar (usado para sair de cena).
func _andar(x_mundo: float) -> void:
	if _pers == null:
		return
	_pers.ir_para_x(x_mundo, "")
	await _pers.chegou

# Anda até um objeto (drone/carro), parando do lado de onde VEIO (não passa direto).
func _andar_ate_objeto(obj_x: float) -> void:
	if _pers == null:
		return
	var de_esquerda := _pers.position.x < obj_x
	var destino := (obj_x - parada_antes) if de_esquerda else (obj_x + parada_antes)
	_pers.ir_para_x(destino, animacao_ao_parar)
	await _pers.chegou

# Anda até perto do NPC daquela tela (o 2º personagem).
func _andar_ate_npc(npc_nome: String, level_nome: String) -> void:
	var npc := _achar(npc_nome)
	var alvo: float = _centro_x(level_nome)
	if npc is Node2D:
		alvo = (npc as Node2D).global_position.x
	await _andar_ate_objeto(alvo)


# Os DOIS caminham juntos da tela 4 até o mercado, com a CÂMERA seguindo.
func _caminhar_juntos_ate_mercado(npc_nome: String) -> void:
	var npc := _achar(npc_nome) as PersonagemStoryboard
	var alvo_x: float = _borda_esquerda(level_tela5) + 40.0
	var dur: float = maxf(0.5, duracao_caminhada_mercado)

	# Liga a animação de andar (o diretor é quem move a posição).
	_pers.andar_no_lugar_visual(true)
	if npc != null:
		npc.andar_no_lugar_visual(true)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_pers, "position:x", alvo_x, dur)
	tw.tween_property(_pers, "position:y", y_tela5, dur)
	if npc != null:
		tw.tween_property(npc, "position:x", alvo_x - 24.0, dur)
		tw.tween_property(npc, "position:y", y_tela5, dur)
	if _cam != null:
		tw.tween_property(_cam, "position", _centro_da_tela(level_tela5), dur) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


# Esconde o "!" vermelho que fica em cima do NPC (filho "ExclamacaoNpc").
func _esconder_excl_npc(npc_nome: String) -> void:
	var npc := _achar(npc_nome)
	if npc == null:
		return
	var ex := npc.get_node_or_null("ExclamacaoNpc")
	if ex != null and "visible" in ex:
		ex.set("visible", false)


func _esperar_questoes() -> void:
	if modo_automatico:
		await get_tree().create_timer(espera_questoes).timeout
	else:
		_continuar_pedido = false
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

func _borda_esquerda(nome_level: String) -> float:
	var n := _achar_level(nome_level)
	return (n.global_position.x + margem) if n != null else 0.0

func _borda_direita(nome_level: String) -> float:
	var n := _achar_level(nome_level)
	return (n.global_position.x + tamanho_tela.x - margem) if n != null else tamanho_tela.x

func _centro_x(nome_level: String) -> float:
	var n := _achar_level(nome_level)
	return (n.global_position.x + tamanho_tela.x * 0.5) if n != null else tamanho_tela.x * 0.5

func _x_obj(nome_obj: String, level_fallback: String) -> float:
	var o := _achar(nome_obj)
	return (o as Node2D).global_position.x if o is Node2D else _centro_x(level_fallback)


# ===== "!" DAS MISSÕES ========================================================

func _esconder_excl_carro() -> void:
	var n := _achar(nome_excl_carro)
	if n == null:
		return
	if n.has_method("concluir"):
		n.call("concluir")
	elif "visible" in n:
		n.set("visible", false)

func _esconder_excl_drone() -> void:
	var d := _achar(nome_drone)
	if d == null:
		return
	var marc := d.get_node_or_null("Exclamacao")
	if marc != null:
		if marc.has_method("concluir"):
			marc.call("concluir")
		elif "visible" in marc:
			marc.set("visible", false)


# ===== TELA 3 — scroll ========================================================

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
		_scroller.queue_free()
	_scroller = null


# ===== BUSCAS =================================================================

func _achar_level(nome: String) -> Node2D:
	return get_tree().current_scene.find_child(nome, true, false) as Node2D

func _achar(nome: String) -> Node:
	return get_tree().current_scene.find_child(nome, true, false)
