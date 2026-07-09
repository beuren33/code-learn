extends Sprite2D
class_name MarcadorExclamacao
# ─────────────────────────────────────────────────────────────────────────────
# "!" DE MISSÃO
# Mostra um ponto de exclamação que SOME quando a missão correspondente é
# concluída (quando o jogador acerta o exercício).
#
# COMO USAR:
#   1. Coloque o "!" (este nó) em cima do objeto/NPC da missão.
#   2. Quando a missão for concluída, chame de qualquer lugar do código:
#        o_no.concluir()
# ─────────────────────────────────────────────────────────────────────────────

## Id da missão ligada a este "!" (usado por quem chamar concluir() de fora).
@export var node_id: String = ""
## Se ligado, remove o nó de vez ao concluir. Se desligado, só fica invisível.
@export var remover_de_vez: bool = false


## Esconde o "!" — pode ser chamado de qualquer lugar do seu código.
func concluir() -> void:
	if remover_de_vez:
		queue_free()
	else:
		visible = false
