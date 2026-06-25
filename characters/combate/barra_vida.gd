extends Sprite2D
class_name BarraVida
# ─────────────────────────────────────────────────────────────────────────────
# BARRA DE VIDA por folha de quadros (cheia -> vazia).
#   • Robô (original): 576x256, grade 3x4 = 12 quadros (192x64).
#   • Boss (clássica): 320x384, grade 5x2 = 10 quadros (64x192).
# Use configurar(textura, colunas, linhas, total) e depois definir(fracao 0..1).
# ─────────────────────────────────────────────────────────────────────────────

var _colunas: int = 3
var _linhas: int = 4
var _total: int = 12
var _fw: float = 0.0
var _fh: float = 0.0


func configurar(tex: Texture2D, colunas: int, linhas: int, total: int) -> void:
	if tex == null:
		return
	texture = tex
	centered = false
	region_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_colunas = colunas
	_linhas = linhas
	_total = total
	_fw = float(tex.get_width()) / float(colunas)
	_fh = float(tex.get_height()) / float(linhas)
	definir(1.0)


## fracao: 1.0 = cheia, 0.0 = vazia.
func definir(fracao: float) -> void:
	fracao = clampf(fracao, 0.0, 1.0)
	var idx: int = int(round((1.0 - fracao) * float(_total - 1)))
	idx = clampi(idx, 0, _total - 1)
	var cx: int = idx % _colunas
	var cy: int = idx / _colunas
	region_rect = Rect2(cx * _fw, cy * _fh, _fw, _fh)


## Tamanho de UM quadro (para posicionar/escalar a barra).
func tamanho_quadro() -> Vector2:
	return Vector2(_fw, _fh)
