extends Node2D
class_name CenarioCarroAndando
# ─────────────────────────────────────────────────────────────────────────────
# EFEITO "CARRO ANDANDO" (rodovia / cidade).
#
# O carro fica PARADO e o cenário desliza, dando a sensação de movimento.
#
# DOIS MODOS (campo "mover_cena_toda"):
#   • DESLIGADO (mais seguro): move só o FUNDO (céu). Nunca buga.
#   • LIGADO: move TODAS as camadas (céu, árvores, estrada, prédios) menos a do
#     CARRO. O carro é detectado sozinho pelo tileset ("Cars..."), então funciona
#     tanto na rodovia (camada Tiles4) quanto na cidade (camada Tiles2).
#
# IMPORTANTE: este efeito NÃO mexe na ordem (z) das camadas — só desliza. Por
# isso não causa aquele "terremoto"/sobreposição que aparecia antes.
# ─────────────────────────────────────────────────────────────────────────────

## Velocidade base do cenário (px/s).
@export var velocidade: float = 45.0
## Para a esquerda = sensação de carro indo para a DIREITA.
@export var para_esquerda: bool = true
## Tamanho do quadro da tela (Level do LDtk = 320x160).
@export var tamanho_tela: Vector2 = Vector2(320, 160)
## LIGADO = move a cena toda (menos o carro). DESLIGADO = só o céu (seguro).
@export var mover_cena_toda: bool = true
## Nome de uma camada do carro para manter parada (além da detecção automática).
@export var camada_carro: String = "Tiles4"
## Fundo anda mais devagar que a frente (profundidade).
@export var parallax: bool = true
## Fator de velocidade da camada mais ao fundo (1.0 = igual à frente).
@export var fator_fundo: float = 0.4
## Nome do sprite de fundo (céu) criado pelo controlador de fundos.
@export var nome_bg: String = "BG Image"

var _ativo: bool = false
var _itens: Array = []   # cada item: { "no": Node2D, "fator": float, "base": float }


func iniciar() -> void:
	if _ativo:
		return
	if not _montar():
		push_warning("CenarioCarroAndando: não achei nada para mover.")
		return
	_ativo = true


func parar() -> void:
	_ativo = false


func _process(delta: float) -> void:
	if not _ativo or _itens.is_empty():
		return
	var w: float = tamanho_tela.x
	var dir: float = -1.0 if para_esquerda else 1.0
	for item in _itens:
		var no: Node2D = item["no"]
		if not is_instance_valid(no):
			continue
		no.position.x += velocidade * delta * dir * item["fator"]
		if dir < 0.0 and no.position.x <= item["base"] - w:
			no.position.x += 2.0 * w
		elif dir > 0.0 and no.position.x >= item["base"] + w:
			no.position.x -= 2.0 * w


func _montar() -> bool:
	var pai := get_parent()
	if pai == null:
		return false

	var camadas: Array[Node2D] = []
	if mover_cena_toda:
		# Todas as camadas visuais (tiles + céu), menos a(s) do carro.
		for c in pai.get_children():
			if c == self or not (c is Node2D):
				continue
			if _eh_carro(c):
				continue
			var eh_tile: bool = c.get_class() == "TileMapLayer" or c.get_class() == "TileMap"
			if eh_tile or c is Sprite2D:
				camadas.append(c as Node2D)
	else:
		# Modo seguro: só o fundo (céu).
		var bg := pai.get_node_or_null(nome_bg)
		if bg is Node2D:
			camadas.append(bg as Node2D)

	if camadas.is_empty():
		return false

	var w: float = tamanho_tela.x
	var n: int = camadas.size()
	for i in n:
		var L: Node2D = camadas[i]
		var fator: float = 1.0
		if parallax and n > 1:
			fator = lerpf(fator_fundo, 1.0, float(i) / float(n - 1))
		var bx: float = L.position.x
		_itens.append({ "no": L, "fator": fator, "base": bx })
		var dup: Node2D = L.duplicate()
		pai.add_child(dup)
		# Mantém a MESMA ordem/profundidade da original (não mexe em z_index).
		pai.move_child(dup, L.get_index() + 1)
		dup.position = L.position + Vector2(w, 0.0)
		_itens.append({ "no": dup, "fator": fator, "base": bx + w })

	return true


# A camada é do CARRO? (pelo nome OU pelo tileset "Cars...")
func _eh_carro(no: Node) -> bool:
	if no.name == camada_carro:
		return true
	if no.get_class() != "TileMapLayer":
		return false
	var ts = no.get("tile_set")
	if ts == null or not (ts is TileSet):
		return false
	var tset: TileSet = ts
	for k in tset.get_source_count():
		var src := tset.get_source(tset.get_source_id(k))
		if src is TileSetAtlasSource:
			var tex: Texture2D = (src as TileSetAtlasSource).texture
			if tex != null and "car" in tex.resource_path.to_lower():
				return true
	return false
