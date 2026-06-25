extends AnimatedSprite2D
class_name DroneStoryboard
# ─────────────────────────────────────────────────────────────────────────────
# STORYBOARD DO DRONE — 3 ESTADOS
#
#   1) ESPERANDO    → fica PARADO tocando a animação "DEATH" (drone desligado).
#   2) SUBINDO      → quando o "!" SOME, decola e sobe até uma altura.
#   3) PATRULHANDO  → ao chegar na altura, fica indo da DIREITA para a ESQUERDA
#                     da plantação (vai e volta, pra sempre).
#
# JEITO DE USAR:
#   • Coloque o drone acima do CENTRO da plantação.
#   • O "!" (nó "Exclamacao") já é filho do drone, então não precisa ligar nada:
#     quando ele sumir (missão concluída), o drone decola sozinho.
#   • No Inspetor ajuste: Altura Subida e Largura Patrulha.
# ─────────────────────────────────────────────────────────────────────────────

enum Estado { ESPERANDO, SUBINDO, PATRULHANDO }

@export_group("Gatilho (o \"!\")")
## Nó do ponto de exclamação que o drone vigia. Por padrão pega o filho "Exclamacao".
@export var marcador_exclamacao: NodePath = ^"Exclamacao"

@export_group("Parado (antes de decolar)")
## Animação enquanto espera (drone desligado). No seu projeto: "DEATH".
@export var animacao_parado: String = "DEATH"

@export_group("Decolagem")
## Animação de voo. No seu projeto: "IDLE".
@export var animacao_voo: String = "IDLE"
## Quantos pixels o drone SOBE ao decolar.
@export var altura_subida: float = 120.0
## Velocidade da subida (pixels por segundo).
@export var velocidade_subida: float = 80.0

@export_group("Patrulha (direita ↔ esquerda)")
## Largura total da varredura, centrada em onde o drone decolou.
@export var largura_patrulha: float = 300.0
## Velocidade da patrulha (pixels por segundo).
@export var velocidade_patrulha: float = 60.0
## Espelhar o sprite conforme o lado (ligue só se o desenho do drone for de perfil).
@export var virar_para_o_movimento: bool = false

@export_group("Balanço (opcional)")
## Sobe e desce de leve enquanto voa, dando vida.
@export var balancar: bool = true
@export var altura_balanco: float = 4.0
@export var velocidade_balanco: float = 3.0

var _estado: Estado = Estado.ESPERANDO
var _start: Vector2 = Vector2.ZERO
var _alvo_y: float = 0.0
var _x_esq: float = 0.0
var _x_dir: float = 0.0
var _destino_x: float = 0.0
var _t: float = 0.0
var _excl: Node = null
var _pode_vigiar: bool = false


func _ready() -> void:
	_start = position
	_tocar(animacao_parado)            # começa parado, no estilo "death"
	_excl = get_node_or_null(marcador_exclamacao)
	if _excl == null:
		push_warning("DroneStoryboard: não achei o \"!\" em \"%s\". "
			% [marcador_exclamacao]
			+ "Confira o campo 'Marcador Exclamacao' no Inspetor "
			+ "(ou chame decolar() na mão).")
	else:
		_pode_vigiar = true
		# Se a missão JÁ estava concluída (o "!" nasce sumido), decola direto.
		if _exclamacao_sumiu():
			_decolar()


func _process(delta: float) -> void:
	# Balanço só enquanto está no ar (não enquanto está parado em DEATH).
	if balancar and _estado != Estado.ESPERANDO:
		_t += delta * velocidade_balanco
		offset.y = sin(_t) * altura_balanco


func _physics_process(delta: float) -> void:
	match _estado:
		Estado.ESPERANDO:
			if _pode_vigiar and _exclamacao_sumiu():
				_decolar()

		Estado.SUBINDO:
			position.y = move_toward(position.y, _alvo_y, velocidade_subida * delta)
			if absf(position.y - _alvo_y) <= 0.5:
				position.y = _alvo_y
				_comecar_patrulha()

		Estado.PATRULHANDO:
			if virar_para_o_movimento and absf(_destino_x - position.x) > 0.1:
				flip_h = _destino_x > position.x
			position.x = move_toward(position.x, _destino_x, velocidade_patrulha * delta)
			if absf(position.x - _destino_x) <= 0.5:
				# Chegou numa ponta: troca o destino para a outra ponta.
				_destino_x = _x_esq if is_equal_approx(_destino_x, _x_dir) else _x_dir


# Começa a decolagem (também pode ser chamada de fora, ex.: por um sinal).
func decolar() -> void:
	if _estado == Estado.ESPERANDO:
		_decolar()


func _decolar() -> void:
	_estado = Estado.SUBINDO
	_alvo_y = _start.y - altura_subida   # subir = diminuir o Y
	_tocar(animacao_voo)


func _comecar_patrulha() -> void:
	_estado = Estado.PATRULHANDO
	_x_esq = _start.x - largura_patrulha * 0.5
	_x_dir = _start.x + largura_patrulha * 0.5
	_destino_x = _x_dir                  # vai primeiro para a direita


# O "!" sumiu? (foi removido com queue_free OU ficou invisível)
func _exclamacao_sumiu() -> bool:
	if _excl == null or not is_instance_valid(_excl):
		return true
	if _excl is CanvasItem and not (_excl as CanvasItem).visible:
		return true
	return false


func _tocar(nome: String) -> void:
	if sprite_frames != null and sprite_frames.has_animation(nome):
		play(nome)
