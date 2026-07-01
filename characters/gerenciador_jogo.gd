extends Node
class_name GerenciadorJogo
# ─────────────────────────────────────────────────────────────────────────────
# GERENCIADOR — liga o storyboard aos QUIZZES e MINIGAMES, na ordem do PDF.
#
# Como funciona: o StoryboardDirector avisa "personagem_chegou(cena)" em cada
# missão. Aqui, para cada cena, rodamos a lista de passos (quiz por índice e/ou
# minigame), um de cada vez. Quando o passo termina (a tela do quiz/minigame
# fica invisível ou é fechada), vamos para o próximo; no fim, mandamos o
# personagem seguir (director.continuar()).
#
# COMO USAR:
#   1) Na cena do storyboard (node_2d), crie um Node novo e coloque este script.
#   2) No Inspetor, aponte "Caminho Diretor" para o StoryboardDirector.
#   3) Preencha os caminhos das cenas (quiz e os 3 minigames) depois de copiá-las
#      para o projeto (veja o README).
#
# Detecção de fim (sem precisar mexer nos minigames): o passo termina quando a
# tela do minigame/quiz fica INVISÍVEL (self.visible = false) OU é liberada.
# Os minigames que você mandou já fazem isso ao vencer. Para precisão, dá para
# emitir um sinal "concluido" neles (opcional — veja o README).
# ─────────────────────────────────────────────────────────────────────────────

@export var caminho_diretor: NodePath

@export_group("Cenas (preencher depois de copiar para o projeto)")
@export_file("*.tscn") var cena_quiz: String = "res://sistema_quiz/interface_quiz.tscn"
@export_file("*.tscn") var mg_drone: String = ""   # mini_drone.tscn
@export_file("*.tscn") var mg_fios: String = ""    # minigame_fios.tscn
@export_file("*.tscn") var mg_led: String = ""     # minigame_circuito.tscn (LED)

@export_group("Combate")
@export_file("*.tscn") var cena_combate: String = "res://characters/combate/combate.tscn"
@export_file("*.tres") var inimigo_robo_a: String = "res://characters/skins/inimigos/robo_a.tres"
@export_file("*.tres") var inimigo_robo_c: String = "res://characters/skins/inimigos/robo_c.tres"
@export_file("*.tres") var inimigo_boss: String = "res://characters/skins/inimigos/boss_inimigo.tres"

var _dir: Node = null
var _camada: CanvasLayer = null


func _ready() -> void:
	await get_tree().process_frame
	_dir = get_node_or_null(caminho_diretor)
	if _dir == null:
		push_warning("GerenciadorJogo: aponte 'Caminho Diretor' para o StoryboardDirector.")
		return
	# Camada por cima de tudo, onde abrimos quiz/minigames.
	_camada = CanvasLayer.new()
	_camada.name = "CamadaMinigames"
	_camada.layer = 50
	add_child(_camada)
	# Assume o controle do ritmo: o diretor espera a gente em cada missão.
	_dir.set("modo_automatico", false)
	_dir.connect("personagem_chegou", _na_missao)


# Para cada cena, roda os passos (quiz/minigame) na ordem do PDF e depois libera
# o personagem para continuar.
func _na_missao(cena: int) -> void:
	for passo in _passos_da_cena(cena):
		await _rodar_passo(passo)
	if _dir != null:
		_dir.call("continuar")


# ─── MAPA: cena do storyboard -> passos (na ordem do PDF) ────────────────────
# quiz(i) = mostra a pergunta de índice i do perguntas.json
# mini(x) = abre o minigame x
# Os índices abaixo batem com o perguntas.json que você mandou (18 perguntas).
# Como você só tem 3 minigames, eles se repetem nos slots que ainda não têm
# minigame próprio — troque à vontade.
func _passos_da_cena(cena: int) -> Array:
	match cena:
		1:  return [_quiz(2), _mini(mg_drone)]                 # Drone: N1 + Mg1
		2:  return [_quiz(0), _quiz(1)]                        # Camionete: N2, N3
		3:  return []                                          # Rodovia (só dirigindo)
		4:  return [_quiz(3), _mini(mg_fios), _mini(mg_led)]   # Robô aliado: N4 + Mg2, Mg3
		5:  return [_quiz(7)]                                  # Entrar na loja: N5
		6:  return [_mini(mg_fios), _mini(mg_led), _quiz(6), _quiz(4)]  # Armário Mg4/Mg5 + sair N6/N7
		7:  return [_luta("RoboInimigoFora", [14, 13], false)]  # Fora da fábrica: luta robô
		8:  return [_luta("RoboInimigo", [9, 8], false)]        # Dentro da fábrica: luta vilão
		9:  return []                                        # Level_8: chegada (sem luta extra)
		10: return [_luta("SuperBoss", [10, 17, 13], true)]     # Boss final: barra clássica
		11: return [_quiz(11), _mini(mg_led)]                  # Final esteira: N16 + Mg8
		_:  return []


func _quiz(indice: int) -> Dictionary:
	return {"tipo": "quiz", "indice": indice}

func _mini(caminho: String) -> Dictionary:
	return {"tipo": "mini", "cena": caminho}

func _achar_no_cena(nome: String) -> Node2D:
	var raiz := get_parent()
	if raiz != null:
		var n := raiz.get_node_or_null(NodePath(nome))
		if n is Node2D:
			return n
	var alvo := get_tree().current_scene
	if alvo != null:
		var n2 := alvo.find_child(nome, true, false)
		if n2 is Node2D:
			return n2
	return null


func _luta(inimigo: String, perguntas: Array, boss: bool) -> Dictionary:
	return {"tipo": "luta", "inimigo": inimigo, "perguntas": perguntas, "boss": boss}


func _rodar_passo(passo: Dictionary) -> void:
	if passo["tipo"] == "quiz":
		if not _existe(cena_quiz):
			push_warning("GerenciadorJogo: cena do quiz não encontrada: %s" % cena_quiz)
			return
		var q := (load(cena_quiz) as PackedScene).instantiate()
		_camada.add_child(q)
		# Mostra a pergunta certa.
		if q.has_method("abrir"):
			q.call("abrir", int(passo["indice"]))
		elif q.has_method("montar_pergunta"):
			q.call("montar_pergunta", int(passo["indice"]))
			if "visible" in q:
				q.set("visible", true)
		await _esperar_fim(q)
	elif passo["tipo"] == "luta":
		if not _existe(cena_combate):
			push_warning("GerenciadorJogo: cena de combate não encontrada.")
			return
		var inimigo := _achar_no_cena(String(passo["inimigo"]))
		var robo: Node2D = _dir.get_aliado() if _dir != null and _dir.has_method("get_aliado") else null
		var humano: Node2D = _dir.get_personagem() if _dir != null and _dir.has_method("get_personagem") else null
		# o LUTADOR é o robô aliado; se não houver, usa o humano como fallback
		var lutador: Node2D = robo if robo != null else humano
		if inimigo == null or lutador == null:
			push_warning("Combate: não achei o lutador ou o inimigo '" + String(passo["inimigo"]) + "'.")
			return
		var c = (load(cena_combate) as PackedScene).instantiate()
		c.set("aliado_node", lutador)
		c.set("personagem_node", humano if humano != lutador else null)
		c.set("inimigo_node", inimigo)
		c.set("perguntas", passo["perguntas"])
		c.set("usar_barra_boss", passo["boss"])
		c.set("caminho_quiz", cena_quiz)
		_camada.add_child(c)
		await _esperar_fim(c)
	else:
		var caminho: String = passo["cena"]
		if not _existe(caminho):
			# Slot de minigame ainda não preenchido: ignora sem travar.
			return
		var m := (load(caminho) as PackedScene).instantiate()
		_camada.add_child(m)
		await _esperar_fim(m)


# Espera o quiz/minigame terminar: quando emite "concluido", OU fica invisível,
# OU é liberado da árvore. Depois remove a instância.
func _esperar_fim(inst: Node) -> void:
	var estado := {"pronto": false}
	if inst.has_signal("concluido"):
		inst.connect("concluido", func(_a = null): estado["pronto"] = true)
	# Dá um quadro para a tela aparecer antes de começar a checar.
	await get_tree().process_frame
	await get_tree().process_frame
	while is_instance_valid(inst) and not estado["pronto"]:
		if ("visible" in inst) and inst.get("visible") == false:
			break
		await get_tree().process_frame
	if is_instance_valid(inst):
		inst.queue_free()
	await get_tree().process_frame


func _existe(caminho: String) -> bool:
	return caminho != "" and ResourceLoader.exists(caminho)
