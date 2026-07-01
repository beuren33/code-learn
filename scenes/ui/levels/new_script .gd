extends Node2D
# ─────────────────────────────────────────────────────────────────────────────
# Controlador de conteúdo dos levels (importados do LDtk).
#
# Faz DUAS coisas, ambas em runtime (achando cada level pelo NOME), o que é
# seguro mesmo se você reimportar o .ldtk (nada se perde):
#
#   1) FUNDOS  -> recria um único fundo correto por level (já existia).
#   2) STORYBOARD -> coloca o DRONE animado + "!" no Level_0 e um "!" em cima
#                    do carro no Level_1 (parte nova).
#
# Tudo é configurável no Inspetor (selecione o nó raiz Node2D em node_2d.tscn).
# ─────────────────────────────────────────────────────────────────────────────

# ===== CONFIG: STORYBOARD (parte nova) =======================================

@export_group("Storyboard — Drone + \"!\" (Level_0)")
## Liga/desliga o spawn do drone animado no Level_0.
@export var spawnar_drone_level0: bool = true
## Cena do drone (que já traz o "!" como filho). Se ficar vazio, carrega
## res://characters/drone_storyboard.tscn automaticamente.
@export var cena_drone: PackedScene
## Posição (em coordenadas do Level_0) onde o drone começa.
## (176, 96) é exatamente onde está o marcador "Drone" do LDtk no Level_0.
@export var pos_drone_level0: Vector2 = Vector2(176, 96)
## Esconde o marcador "Drone" original do LDtk para não ficar drone duplicado.
@export var esconder_drone_ldtk: bool = true

@export_group("Storyboard — \"!\" em cima do carro (Level_1)")
## Liga/desliga o spawn do "!" no Level_1.
@export var spawnar_exclamacao_level1: bool = true
## Textura do "!". Se ficar vazio, carrega res://characters/exclamacao.png.
@export var textura_exclamacao: Texture2D
## Posição (em coordenadas do Level_1) do "!". Ajuste para ficar em cima do
## carro: o carro está desenhado nos tiles, então mire na posição dele.
@export var pos_exclamacao_level1: Vector2 = Vector2(96, 78)
## Escala do "!".
@export var escala_exclamacao: Vector2 = Vector2(0.7, 0.659)
## (Opcional) id de missão para o "!" sumir quando o exercício for concluído.
## Deixe vazio para o "!" ficar sempre visível (modo storyboard).
@export var node_id_exclamacao_level1: String = ""

const CAMINHO_CENA_DRONE := "res://characters/drone_storyboard.tscn"
const CAMINHO_CENA_DRONE_ESPACO := "res://characters/drone_storyboard .tscn"
const CAMINHO_TEX_EXCLAMACAO := "res://characters/exclamacao.png"
const CAMINHO_SCRIPT_EXCLAMACAO := "res://characters/exclamacao.gd"

# ===== CONFIG: FUNDOS (já existia — inalterado) ==============================

const BG_NODE_NAME := "BG Image"
const BG_Z_INDEX := -4096  # mínimo permitido pelo Godot (CANVAS_ITEM_Z_MIN); fica atras de tudo

# Configuracao de fundo por level.
#   path      -> textura do fundo
#   top_left  -> posicao (canto superior esquerdo) em pixels
#   scale     -> escala uniforme (float; NAO pode ser truncada para int)
#   crop_rect -> recorte da textura (x, y, largura, altura)
const BACKGROUNDS := {
	"Level_0": {
		"path": "res://scenes/ui/levels/tilesets/background_sky_windmill.png",
		"top_left": Vector2(0, 0),
		"scale": Vector2(0.11904762, 0.11904762),
		"crop_rect": Rect2i(240, 0, 2688, 1344),
	},
	"Level_1": {
		"path": "res://scenes/ui/levels/tilesets/Back_2.png",
		"top_left": Vector2(0, 0),
		"scale": Vector2(0.11904762, 0.11904762),
		"crop_rect": Rect2i(240, 0, 2688, 1344),
	},
	"Level_2": {
		"path": "res://scenes/ui/levels/tilesets/highway-sky.png",
		"top_left": Vector2(0, 0),
		"scale": Vector2(0.8, 0.8),
		"crop_rect": Rect2i(0, 20, 400, 200),
	},
	"Level_3": {
		"path": "res://scenes/ui/levels/tilesets/ceu_entardecer_cidade_1.png",
		"top_left": Vector2(0, 0),
		"scale": Vector2(0.25, 0.25),
		"crop_rect": Rect2i(0, 0, 1280, 640),
	},
	"Level_4": {
		"path": "res://scenes/ui/levels/tilesets_cidade/cidade_casas_up49.png",
		"top_left": Vector2(0, 0),
		"scale": Vector2(0.125, 0.125),
		"crop_rect": Rect2i(0, 80, 2560, 1280),
	},
	"Level_5": {
		"path": "res://scenes/ui/levels/tilesets_cidade/mercado_background_v2.png",
		"top_left": Vector2(0, 0),
		"scale": Vector2(0.125, 0.125),
		"crop_rect": Rect2i(0, 80, 2560, 1280),
	},
	# Level_6 nao tem fundo definido no LDtk.
}


func _ready() -> void:
	_apply_all_backgrounds()
	_aplicar_storyboard()


# ===== STORYBOARD (parte nova) ===============================================

func _aplicar_storyboard() -> void:
	if spawnar_drone_level0:
		_spawnar_drone_level0()
	if spawnar_exclamacao_level1:
		_spawnar_exclamacao_level1()


# Coloca o DRONE animado (que já traz o "!" junto) no Level_0.
func _spawnar_drone_level0() -> void:
	var level := _find_level("Level_0")
	if level == null:
		push_warning("Storyboard: Level_0 nao encontrado para o drone.")
		return

	# Esconde o marcador 'Drone' do LDtk para nao ficar duplicado.
	if esconder_drone_ldtk:
		for d in level.find_children("Drone", "", true, false):
			var ci := d as CanvasItem
			if ci != null:
				ci.visible = false

	var cena: PackedScene = cena_drone
	if cena == null:
		# Tenta o caminho normal e, como rede de segurança, a variação com
		# espaço no nome do arquivo ("drone_storyboard .tscn").
		if ResourceLoader.exists(CAMINHO_CENA_DRONE):
			cena = load(CAMINHO_CENA_DRONE)
		elif ResourceLoader.exists(CAMINHO_CENA_DRONE_ESPACO):
			cena = load(CAMINHO_CENA_DRONE_ESPACO)
	if cena == null:
		push_warning("Storyboard: cena do drone nao encontrada. Arraste-a no campo 'Cena Drone' do Inspetor.")
		return

	var drone := cena.instantiate()
	drone.name = "DroneStoryboard_L0"
	level.add_child(drone)
	(drone as Node2D).position = pos_drone_level0


# Coloca um "!" em cima do carro no Level_1 (o carro esta nos tiles, por isso
# a posicao e configuravel no Inspetor).
func _spawnar_exclamacao_level1() -> void:
	var level := _find_level("Level_1")
	if level == null:
		push_warning("Storyboard: Level_1 nao encontrado para a exclamacao.")
		return

	var tex: Texture2D = textura_exclamacao
	if tex == null:
		tex = load(CAMINHO_TEX_EXCLAMACAO)
	if tex == null:
		push_warning("Storyboard: textura do '!' nao encontrada em %s" % CAMINHO_TEX_EXCLAMACAO)
		return

	var marca := Sprite2D.new()
	marca.name = "ExclamacaoCarro_L1"
	marca.texture = tex
	marca.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marca.position = pos_exclamacao_level1
	marca.scale = escala_exclamacao

	# Anexa o script do "!" para integrar com a logica de missao (some quando
	# concluida). Com node_id vazio ele simplesmente fica sempre visivel.
	var scr := load(CAMINHO_SCRIPT_EXCLAMACAO)
	if scr != null:
		marca.set_script(scr)
		marca.set("node_id", node_id_exclamacao_level1)

	level.add_child(marca)


# ===== FUNDOS (já existia — inalterado) ======================================

# Percorre todos os levels da cena e aplica o fundo correspondente.
func _apply_all_backgrounds() -> void:
	for level_name in BACKGROUNDS:
		var level_node := _find_level(level_name)
		if level_node == null:
			push_warning("Level nao encontrado na cena: %s" % level_name)
			continue
		_apply_background(level_node, BACKGROUNDS[level_name])


# Procura um no de level pelo nome em toda a arvore (robusto a mudancas de
# hierarquia: nao importa se o level e filho direto do mundo ou esta aninhado).
func _find_level(level_name: String) -> Node2D:
	var found := find_child(level_name, true, false)
	return found as Node2D


# Cria (ou recria) o fundo de um level, garantindo que exista apenas um e que
# fique atras de tudo.
func _apply_background(level_node: Node2D, config: Dictionary) -> void:
	# 1) Remove qualquer fundo anterior (evita duplicado / fundo desatualizado).
	var existing := level_node.get_node_or_null(BG_NODE_NAME)
	if existing != null:
		existing.free()

	# 2) Carrega a textura.
	var texture: Texture2D = load(config["path"])
	if texture == null:
		push_warning("Background nao encontrado: %s" % config["path"])
		return

	# 3) Monta o sprite com o enquadramento exato do LDtk.
	var sprite := Sprite2D.new()
	sprite.name = BG_NODE_NAME
	sprite.texture = texture
	sprite.centered = false                 # ancora no canto superior esquerdo
	sprite.position = config["top_left"]    # sem centralizar (sem deslocamento)
	sprite.scale = config["scale"]          # escala float (nao trunca p/ zero)
	sprite.region_enabled = true
	sprite.region_rect = config["crop_rect"]
	sprite.z_index = BG_Z_INDEX             # sempre atras dos tiles/personagens

	# 4) Adiciona como PRIMEIRO filho -> desenhado primeiro, fica atras de tudo.
	level_node.add_child(sprite)
	level_node.move_child(sprite, 0)
