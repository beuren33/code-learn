extends Node2D
class_name FundosLevels
# ─────────────────────────────────────────────────────────────────────────────
# CONTROLADOR DE FUNDOS DOS LEVELS
#
# O importador do LDtk NÃO traz a "imagem de fundo do level" (o bgRelPath). Por
# isso este script desenha um Sprite2D de fundo em cada Level, atrás de tudo.
#
# Já cobre as 9 telas. Para as telas novas (640 ou 320 de largura) ele AJUSTA
# a imagem sozinho: encaixa pela largura da tela e centraliza na vertical — sem
# você precisar calcular recorte na mão.
#
# COMO USAR: selecione o nó RAIZ da cena (Node2D do node_2d.tscn), e no Inspetor
# troque o Script por este arquivo. Ele substitui o controlador antigo embutido.
# ─────────────────────────────────────────────────────────────────────────────

const BG_NODE_NAME := "BG Image"
const BG_Z_INDEX := -4096          # mínimo do Godot: fica atrás de tudo
const ALTURA := 160.0              # altura padrão de uma tela (Level do LDtk)

# Para cada Level: a imagem de fundo e a LARGURA da tela.
# - Telas 0–3 mantêm o ajuste antigo (scale + crop) que já estava bom.
# - Telas 4–8 usam ajuste automático pela largura (só informo a imagem + largura).
const FUNDOS := {
	"Level_0": {
		"path": "res://scenes/ui/levels/tilesets/background_sky_windmill.png",
		"scale": Vector2(0.11904762, 0.11904762), "crop_rect": Rect2i(240, 0, 2688, 1344),
	},
	"Level_1": {
		"path": "res://scenes/ui/levels/tilesets/Back_2.png",
		"scale": Vector2(0.11904762, 0.11904762), "crop_rect": Rect2i(240, 0, 2688, 1344),
	},
	"Level_2": {
		"path": "res://scenes/ui/levels/tilesets/highway-sky.png",
		"scale": Vector2(0.8, 0.8), "crop_rect": Rect2i(0, 20, 400, 200),
	},
	"Level_3": {
		"path": "res://scenes/ui/levels/tilesets/ceu_entardecer_cidade_1.png",
		"scale": Vector2(0.25, 0.25), "crop_rect": Rect2i(0, 0, 1280, 640),
	},
	"Level_4": {
		"path": "res://scenes/ui/levels/tilesets_cidade/background_final_v2 (1).png",
		"scale": Vector2(0.23809524, 0.23809524), "crop_rect": Rect2i(0, 240, 2688, 672),
	},
	"Level_5": {
		"path": "res://scenes/ui/levels/tilesets_cidade/background_small_scale.png",
		"scale": Vector2(0.23809524, 0.23809524), "crop_rect": Rect2i(0, 240, 2688, 672),
	},
	"Level_6": {
		"path": "res://scenes/ui/levels/tilesets_cidade/fabrica_nexus_640x160.png",
		"scale": Vector2(0.23809524, 0.23809524), "crop_rect": Rect2i(0, 240, 2688, 672),
	},
	"Level_7": {
		"path": "res://scenes/ui/levels/tilesets_cidade/interior_fabrica_pixel_art_simples.png",
		"scale": Vector2(0.125, 0.125), "crop_rect": Rect2i(0, 80, 2560, 1280),
	},
	"Level_8": {
		"path": "res://scenes/ui/levels/tilesets_cidade/boss_arena_640x160.png",
		"scale": Vector2(0.23809524, 0.23809524), "crop_rect": Rect2i(0, 240, 2688, 672),
	},
}


func _ready() -> void:
	for nome_level in FUNDOS:
		var level_node := _find_level(nome_level)
		if level_node == null:
			push_warning("FundosLevels: Level não encontrado na cena: %s" % nome_level)
			continue
		_aplicar_fundo(level_node, FUNDOS[nome_level])


func _find_level(nome_level: String) -> Node2D:
	return find_child(nome_level, true, false) as Node2D


func _aplicar_fundo(level_node: Node2D, cfg: Dictionary) -> void:
	# Remove um fundo anterior, se houver (evita duplicar).
	var existente := level_node.get_node_or_null(BG_NODE_NAME)
	if existente != null:
		existente.free()

	var textura: Texture2D = load(cfg["path"])
	if textura == null:
		push_warning("FundosLevels: imagem de fundo não encontrada: %s" % cfg["path"])
		return

	var sprite := Sprite2D.new()
	sprite.name = BG_NODE_NAME
	sprite.texture = textura
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.z_index = BG_Z_INDEX
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art nítida

	if cfg.has("crop_rect"):
		# Modo antigo (telas 0–3): usa o recorte/escala já ajustados.
		sprite.scale = cfg["scale"]
		sprite.region_enabled = true
		sprite.region_rect = cfg["crop_rect"]
	else:
		# Modo automático (telas novas): encaixa pela largura, centraliza vertical.
		var largura: float = cfg["largura"]
		var iw: float = float(textura.get_width())
		var ih: float = float(textura.get_height())
		var escala: float = largura / iw
		var altura_fonte: float = ALTURA / escala            # px da imagem que cabem na altura
		var topo: float = maxf(0.0, (ih - altura_fonte) * 0.5)
		sprite.scale = Vector2(escala, escala)
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, topo, iw, altura_fonte)

	level_node.add_child(sprite)
	level_node.move_child(sprite, 0)
