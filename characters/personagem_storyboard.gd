extends AnimatedSprite2D
class_name PersonagemStoryboard

# ─────────────────────────────────────────────────────────────────────────────
# NOVIDADES (compatível 100% com o que já estava na TELA 1):
#   • signal "chegou"        -> dispara quando o personagem PARA no destino
#                               (modo UMA_VEZ). É o GANCHO para suas questões /
#                               minigames aparecerem. NADA acontece sozinho se
#                               você não conectar nesse sinal.
#   • @export comecar_parado -> se ligado, ele NÃO anda até alguém chamar
#                               iniciar(). Útil pra ele só começar a andar quando
#                               a câmera chegar na tela dele. (Padrão: false ->
#                               a Tela 1 continua funcionando igualzinho.)
#   • func iniciar()         -> destrava o personagem que começou parado.
# ─────────────────────────────────────────────────────────────────────────────

signal chegou  # emitido ao parar no fim (Repeticao.UMA_VEZ)

enum Repeticao { IDA_E_VOLTA, LOOP, UMA_VEZ }
enum Direcao { DIREITA, ESQUERDA, CIMA, BAIXO }

@export_group("Trajeto simples (o jeito fácil)")
## Anda a partir de ONDE você colocou o personagem, sem digitar coordenadas.
@export var modo_simples: bool = true
## Para que lado ele caminha.
@export var direcao: Direcao = Direcao.DIREITA
## Quantos pixels ele anda antes de voltar / repetir.
@export var distancia: float = 240.0

@export_group("Movimento")
## Velocidade em pixels por segundo.
@export var velocidade: float = 40.0
## IDA_E_VOLTA = vai e volta (mais natural). LOOP = mesmo efeito com 2 pontos.
## UMA_VEZ = anda até o fim e PARA (use para parar num local).
@export var repeticao: Repeticao = Repeticao.IDA_E_VOLTA
## SÓ vale quando Repeticao = UMA_VEZ: ao chegar no fim, PARA e toca esta
## animação. Ex.: Idle_Down, Idle_Side, Idle_Up, Interact_Down, Punch_Side...
## Deixe vazio para apenas congelar no último quadro.
@export var animacao_ao_parar: String = "Interact_Side"
## Se ligado, ele só começa a andar quando alguém chamar iniciar()
## (ex.: o StoryboardDirector quando a câmera chega na tela dele).
@export var comecar_parado: bool = false

@export_group("Aparência")
## Marque conforme o lado em que o seu desenho do LADO (Walk_Side) está virado.
## Se o personagem anda "de costas"/virado errado, TROQUE esta opção.
## (true = o desenho já olha para a DIREITA; false = olha para a esquerda)
@export var lado_olha_para_direita: bool = true

@export_group("Trajeto avançado (opcional)")
## SÓ use isto para um caminho com vários pontos. Se tiver algo aqui, ele IGNORA
## o modo simples. Deixe vazio para usar o jeito fácil acima.
@export var waypoints: Array[Vector2] = []

@export_group("Fallback sem Aseprite Wizard")
## Sprite-sheet de caminhada (5 linhas x 4 colunas, frames de 32x32).
@export var spritesheet_walk: Texture2D
@export var tamanho_frame: Vector2i = Vector2i(32, 32)
@export var fps: float = 10.0

const LINHAS_WALK := ["Walk_Down","Walk_Down_Side","Walk_Side","Walk_Side_Up","Walk_Up"]
const TOLERANCIA := 1.0

var _pontos: Array[Vector2] = []
var _alvo: int = 0
var _sentido: int = 1
var _parado: bool = false
var _aguardando_inicio: bool = false

# ----- MODO DIRIGIDO (usado pelo StoryboardDirector) --------------------------
# Quando ligado, o personagem IGNORA o trajeto simples/waypoints e obedece a
# ir_para_x(): anda na horizontal até o X (mundo) pedido e, ao chegar, emite
# "chegou". Serve para o diretor levá-lo de uma tela para outra como um ator.
var _dirigido: bool = false
var _alvo_x: float = 0.0
var _anim_fim: String = ""


func _ready() -> void:
	_garantir_spriteframes()
	# Decide o trajeto: avançado (se preenchido) tem prioridade; senão, modo simples.
	if not waypoints.is_empty():
		_pontos = waypoints.duplicate()
	elif modo_simples:
		var origem: Vector2 = position
		_pontos = [origem, origem + _vetor_direcao(direcao) * distancia]
	else:
		_pontos = []
	if _pontos.size() >= 1:
		position = _pontos[0]
		_alvo = 1 if _pontos.size() > 1 else 0
	# Se foi pedido pra começar parado, congela numa pose e espera iniciar().
	if comecar_parado:
		_aguardando_inicio = true
		_congelar_em_pose_inicial()


func _physics_process(delta: float) -> void:
	# Modo dirigido tem prioridade total sobre o trajeto normal.
	if _dirigido:
		_processar_dirigido(delta)
		return
	if _aguardando_inicio:
		return
	if _parado:
		return
	if _pontos.size() < 2:
		return
	var destino: Vector2 = _pontos[_alvo]
	var para_destino: Vector2 = destino - position
	var dist: float = para_destino.length()
	if dist <= TOLERANCIA:
		position = destino
		_avancar()
		return
	var dir: Vector2 = para_destino / dist
	position += dir * min(velocidade * delta, dist)
	_atualizar_animacao(dir)


## Destrava o personagem que começou parado (comecar_parado = true).
func iniciar() -> void:
	if _aguardando_inicio:
		_aguardando_inicio = false


# ===== MODO DIRIGIDO (API para o StoryboardDirector) =========================

## O diretor "assume" o personagem: cancela o trajeto automático e o deixa
## parado numa pose, esperando ordens (ir_para_x). Use uma vez, no começo.
func assumir_controle() -> void:
	_dirigido = true
	_aguardando_inicio = false
	_parado = true
	_pontos = []
	if sprite_frames != null and sprite_frames.has_animation("Idle_Side"):
		play("Idle_Side")
		stop()

## Anda na horizontal até o X (em coordenadas de MUNDO). Ao chegar, PARA e
## emite "chegou". Se "anim_ao_chegar" for preenchida, toca essa animação ao
## parar (ex.: "Interact_Side" no carro/drone); vazio = só congela em pé.
func ir_para_x(x_mundo: float, anim_ao_chegar: String = "") -> void:
	_dirigido = true
	_alvo_x = x_mundo
	_anim_fim = anim_ao_chegar
	# Se já está praticamente no destino, resolve no próximo frame.
	_parado = false


func _processar_dirigido(delta: float) -> void:
	if _parado:
		return
	var dx: float = _alvo_x - position.x
	if absf(dx) <= TOLERANCIA:
		position.x = _alvo_x
		_parado = true
		if _anim_fim != "" and sprite_frames != null and sprite_frames.has_animation(_anim_fim):
			play(_anim_fim)
		else:
			# Mantém o sprite virado para o último lado e congela em Idle.
			if sprite_frames != null and sprite_frames.has_animation("Idle_Side"):
				play("Idle_Side")
				stop()
		chegou.emit()
		return
	var passo: float = min(velocidade * delta, absf(dx))
	var sinal: float = signf(dx)
	position.x += sinal * passo
	_atualizar_animacao(Vector2(sinal, 0.0))


## Mostra a ANIMAÇÃO de caminhada virada para um lado, MAS sem o personagem se
## mover sozinho — quem move a posição é o diretor (usado na caminhada conjunta
## com a câmera seguindo). para_direita = olhando/andando para a direita.
func andar_no_lugar_visual(para_direita: bool) -> void:
	_dirigido = true
	_parado = true
	_aguardando_inicio = false
	flip_h = (para_direita != lado_olha_para_direita)
	if sprite_frames != null and sprite_frames.has_animation("Walk_Side"):
		play("Walk_Side")


func _vetor_direcao(d: int) -> Vector2:
	match d:
		Direcao.DIREITA: return Vector2.RIGHT
		Direcao.ESQUERDA: return Vector2.LEFT
		Direcao.CIMA: return Vector2.UP
		Direcao.BAIXO: return Vector2.DOWN
	return Vector2.RIGHT


func _avancar() -> void:
	match repeticao:
		Repeticao.LOOP:
			_alvo = (_alvo + 1) % _pontos.size()
		Repeticao.UMA_VEZ:
			if _alvo < _pontos.size() - 1:
				_alvo += 1
			else:
				_parar_no_local()
		Repeticao.IDA_E_VOLTA:
			_alvo += _sentido
			if _alvo > _pontos.size() - 1:
				_alvo = _pontos.size() - 2
				_sentido = -1
			elif _alvo < 0:
				_alvo = 1
				_sentido = 1


# Para no lugar e toca a animação escolhida (modo UMA_VEZ).
func _parar_no_local() -> void:
	_parado = true
	if animacao_ao_parar != "" and sprite_frames != null and sprite_frames.has_animation(animacao_ao_parar):
		play(animacao_ao_parar)
	else:
		stop()
	# GANCHO: avisa que chegou no destino (suas questões/minigames entram aqui).
	chegou.emit()


# Congela numa pose virada para o lado certo, antes de começar a andar.
func _congelar_em_pose_inicial() -> void:
	var quer_direita := direcao == Direcao.DIREITA
	if direcao == Direcao.DIREITA or direcao == Direcao.ESQUERDA:
		flip_h = (quer_direita != lado_olha_para_direita)
	var pose := "Idle_Side"
	if sprite_frames != null and sprite_frames.has_animation(pose):
		play(pose)
		stop()


# Escolhe a animação a partir da direção do movimento.
func _atualizar_animacao(dir: Vector2) -> void:
	var ang: float = rad_to_deg(atan2(dir.y, dir.x))
	var nome: String
	var lado: int = 0  # -1 = esquerda, 0 = cima/baixo puro (sem lado), +1 = direita
	if ang >= -22.5 and ang < 22.5: nome = "Walk_Side"; lado = 1
	elif ang >= 22.5 and ang < 67.5: nome = "Walk_Down_Side"; lado = 1
	elif ang >= 67.5 and ang < 112.5: nome = "Walk_Down"; lado = 0
	elif ang >= 112.5 and ang < 157.5: nome = "Walk_Down_Side"; lado = -1
	elif ang >= 157.5 or ang < -157.5: nome = "Walk_Side"; lado = -1
	elif ang >= -157.5 and ang < -112.5: nome = "Walk_Side_Up"; lado = -1
	elif ang >= -112.5 and ang < -67.5: nome = "Walk_Up"; lado = 0
	else: nome = "Walk_Side_Up"; lado = 1
	# Espelha SÓ quando há um lado horizontal. Vira o sprite para o lado certo
	# levando em conta para onde o seu desenho já está virado.
	if lado != 0:
		var quer_direita: bool = lado > 0
		flip_h = (quer_direita != lado_olha_para_direita)
	if sprite_frames != null and sprite_frames.has_animation(nome):
		if animation != nome or not is_playing():
			play(nome)


# Garante um SpriteFrames usável (do Aseprite Wizard / .tres, ou monta do PNG).
func _garantir_spriteframes() -> void:
	if sprite_frames != null and sprite_frames.has_animation("Walk_Side"):
		return
	if spritesheet_walk == null:
		push_warning("PersonagemStoryboard: arraste um SpriteFrames (ex.: personagem_completo.tres) "
			+ "no campo Sprite Frames, ou a sheet de Walk no Fallback.")
		return
	sprite_frames = _construir_frames(spritesheet_walk)
	play("Walk_Side")


func _construir_frames(tex: Texture2D) -> SpriteFrames:
	var sf := SpriteFrames.new()
	var fw: int = tamanho_frame.x
	var fh: int = tamanho_frame.y
	var cols: int = int(tex.get_width() / fw)
	for linha in LINHAS_WALK.size():
		var nome: String = LINHAS_WALK[linha]
		if not sf.has_animation(nome):
			sf.add_animation(nome)
		sf.set_animation_speed(nome, fps)
		sf.set_animation_loop(nome, true)
		for col in cols:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(col * fw, linha * fh, fw, fh)
			sf.add_frame(nome, at)
	return sf
