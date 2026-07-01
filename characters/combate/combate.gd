extends Node2D
class_name Combate
# COMBATE EM CENA — a luta acontece DENTRO do level, ATRÁS do quiz.
# Usa os nós que já estão na tela (personagem + robô inimigo posicionado no
# level). O GerenciadorJogo passa as referências antes do add_child.
#   • Acertou       -> o aliado avança e ataca; o inimigo perde vida.
#   • Errou         -> o inimigo ataca; a barra do aliado baixa.
#   • Acertou TUDO  -> o inimigo MORRE (Death) e a luta acaba.
# Barras: robôs usam a original (3x4=12); o boss usa a clássica (5x2=10).

signal concluido(venceu: bool)

var aliado_node: Node2D = null
var inimigo_node: Node2D = null
var personagem_node: Node2D = null   # humano: fica atrás em pose de luta
var usar_barra_boss: bool = false
var perguntas: Array = [2, 0, 1]
var caminho_quiz: String = "res://interface_quiz.tscn"

const TEX_BARRA_ROBO := "res://characters/skins/ui/barra_vida_robo.png"
const TEX_BARRA_BOSS := "res://characters/skins/ui/barra_vida_boss.png"

var _ui: CanvasLayer
var _barra_aliado: BarraVida
var _barra_inimigo: BarraVida
var _aliado_hp: int = 5
var _aliado_hp_max: int = 5
var _ocupado: bool = false
var _aliado_x0: float = 0.0
var _pers_x0: float = 0.0
var _inimigo_x0: float = 0.0


func _ready() -> void:
	if aliado_node == null or inimigo_node == null:
		push_warning("Combate: faltam os nós de aliado/inimigo na cena.")
		concluido.emit(false)
		queue_free()
		return
	_montar_barras()
	_lutar()


func _montar_barras() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_ui = CanvasLayer.new()
	_ui.layer = 65
	add_child(_ui)
	var tex_robo: Texture2D = load(TEX_BARRA_ROBO)
	_barra_aliado = BarraVida.new()
	_ui.add_child(_barra_aliado)
	_barra_aliado.configurar(tex_robo, 3, 4, 12)
	_barra_aliado.position = Vector2(24, 18)
	_barra_inimigo = BarraVida.new()
	_ui.add_child(_barra_inimigo)
	if usar_barra_boss:
		_barra_inimigo.configurar(load(TEX_BARRA_BOSS), 5, 2, 10)
	else:
		_barra_inimigo.configurar(tex_robo, 3, 4, 12)
	_barra_inimigo.position = Vector2(vp.x - _barra_inimigo.tamanho_quadro().x - 24, 18)


func _lutar() -> void:
	var dir: float = signf(inimigo_node.position.x - aliado_node.position.x)
	if dir == 0.0:
		dir = 1.0
	# O ROBÔ aliado vai à FRENTE (perto do inimigo) e é quem luta.
	aliado_node.position.x = inimigo_node.position.x - dir * 30.0
	_aliado_x0 = aliado_node.position.x
	_inimigo_x0 = inimigo_node.position.x
	if aliado_node is AnimatedSprite2D:
		var al := aliado_node as AnimatedSprite2D
		al.flip_h = dir < 0.0
		for nm in ["Idle_Side", "Idle"]:
			if al.sprite_frames != null and al.sprite_frames.has_animation(nm):
				al.play(nm)
				break
	# O PERSONAGEM (humano) fica ATRÁS do robô, em pose de luta.
	if personagem_node != null:
		_pers_x0 = personagem_node.position.x
		personagem_node.position.x = aliado_node.position.x - dir * 36.0
		if personagem_node is AnimatedSprite2D:
			var pn := personagem_node as AnimatedSprite2D
			pn.flip_h = dir < 0.0
			if pn.sprite_frames != null and pn.sprite_frames.has_animation("Punch_Side"):
				pn.play("Punch_Side")
	# O inimigo encara o robô.
	if inimigo_node is AnimatedSprite2D:
		var ini := inimigo_node as AnimatedSprite2D
		ini.flip_h = aliado_node.position.x < inimigo_node.position.x
		if ini.sprite_frames != null and ini.sprite_frames.has_animation("Idle"):
			ini.play("Idle")
	var total: int = maxi(1, perguntas.size())
	var inimigo_hp: int = total
	for p in perguntas:
		var q = (load(caminho_quiz) as PackedScene).instantiate()
		if q is CanvasLayer:
			q.layer = 60
		if "modo_combate" in q:
			q.set("modo_combate", true)
		add_child(q)
		if q.has_signal("respondeu"):
			q.connect("respondeu", _resolver_tentativa)
		if q.has_method("abrir"):
			q.call("abrir", int(p))
		if q.has_signal("concluido"):
			await q.concluido
		else:
			await get_tree().create_timer(2.0).timeout
		if is_instance_valid(q):
			q.queue_free()
		inimigo_hp -= 1
		if _barra_inimigo != null:
			_barra_inimigo.definir(float(inimigo_hp) / float(total))
		if inimigo_hp <= 0:
			break
	if inimigo_node is AnimatedSprite2D:
		var ini2 := inimigo_node as AnimatedSprite2D
		if ini2.sprite_frames != null and ini2.sprite_frames.has_animation("Death"):
			ini2.play("Death")
	await get_tree().create_timer(1.6).timeout
	if personagem_node != null:
		personagem_node.position.x = _pers_x0
	concluido.emit(true)
	visible = false
	queue_free()


func _deixar_quiz_transparente(q: Node) -> void:
	var fe = q.get_node_or_null("fundoEscuro")
	if fe is ColorRect:
		var c: Color = fe.color
		c.a = 0.4
		fe.color = c


func _resolver_tentativa(acertou: bool) -> void:
	if acertou:
		_atacar(aliado_node, inimigo_node, _aliado_x0)
	else:
		_atacar(inimigo_node, aliado_node, _inimigo_x0)
		_aliado_hp = maxi(1, _aliado_hp - 1)
		if _barra_aliado != null:
			_barra_aliado.definir(float(_aliado_hp) / float(_aliado_hp_max))


func _atacar(atacante: Node2D, alvo: Node2D, base_x: float) -> void:
	if atacante == null or alvo == null or _ocupado:
		return
	_ocupado = true
	if atacante is AnimatedSprite2D:
		var asp := atacante as AnimatedSprite2D
		if asp.sprite_frames != null:
			for nome in ["Attack", "Punch_Side", "Walk", "Walk_Side"]:
				if asp.sprite_frames.has_animation(nome):
					asp.play(nome)
					break
	var rumo: float = signf(alvo.position.x - atacante.position.x)
	if rumo == 0.0:
		rumo = 1.0
	var tw := create_tween()
	tw.tween_property(atacante, "position:x", base_x + rumo * 18.0, 0.14)
	tw.tween_callback(func(): _piscar(alvo))
	tw.tween_property(atacante, "position:x", base_x, 0.14)
	await tw.finished
	if atacante is AnimatedSprite2D:
		var asp2 := atacante as AnimatedSprite2D
		if asp2.sprite_frames != null:
			for nome in ["Idle", "Idle_Side"]:
				if asp2.sprite_frames.has_animation(nome):
					asp2.play(nome)
					break
	_ocupado = false


func _piscar(alvo: Node2D) -> void:
	if alvo == null or not (alvo is CanvasItem):
		return
	alvo.modulate = Color(1, 0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(alvo, "modulate", Color.WHITE, 0.25)
