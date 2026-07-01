extends Sprite2D
class_name MarcadorExclamacao
# ─────────────────────────────────────────────────────────────────────────────
# "!" DE MISSÃO
# Mostra um ponto de exclamação que SOME quando a missão correspondente é
# concluída (quando o jogador acerta o exercício).
#
# COMO USAR:
#   1. Coloque o "!" (este nó) em cima do objeto/NPC da missão.
#   2. No Inspetor, preencha o campo "Node Id" com o id da missão
#      (o mesmo node_id que vai para SaveManager.complete_mission).
#
# Ele some sozinho de dois jeitos:
#   • Se a missão JÁ estava concluída, ele nem aparece (some no _ready).
#   • Se você concluir a missão durante o jogo, ele some na hora — desde que o
#     SaveManager avise por um "sinal" (veja as instruções; são 2 linhas).
#
# E você também pode esconder manualmente de qualquer lugar chamando:
#     o_no.concluir()
# ─────────────────────────────────────────────────────────────────────────────

## Id da missão ligada a este "!" (igual ao usado no SaveManager).
@export var node_id: String = ""
## Se ligado, remove o nó de vez ao concluir. Se desligado, só fica invisível.
@export var remover_de_vez: bool = false


func _ready() -> void:
	# 1) Some logo se a missão já foi concluída em outra sessão.
	if _ja_concluida():
		_sumir()
		return
	# 2) Some na hora, se o SaveManager tiver o sinal "mission_completed".
	var sm := _save_manager()
	if sm != null and sm.has_signal("mission_completed"):
		sm.mission_completed.connect(_on_mission_completed)


func _on_mission_completed(id_concluida: String, _estrelas: int = 0) -> void:
	if id_concluida == node_id:
		concluir()


## Esconde o "!" — pode ser chamado de qualquer lugar do seu código.
func concluir() -> void:
	_sumir()


func _sumir() -> void:
	if remover_de_vez:
		queue_free()
	else:
		visible = false


func _ja_concluida() -> bool:
	var sm := _save_manager()
	if sm == null or node_id == "":
		return false
	if not sm.has_method("get_progress"):
		return false
	var p: Dictionary = sm.get_progress(node_id)
	return int(p.get("completado", 0)) == 1


# Pega o autoload SaveManager pelo caminho, SEM depender do nome global no
# momento da compilação. Assim o script compila mesmo que o SaveManager ainda
# não esteja registrado (ex.: addon SQLite não carregado). Se não existir,
# retorna null e o "!" simplesmente continua visível.
func _save_manager() -> Node:
	return get_node_or_null("/root/SaveManager")
