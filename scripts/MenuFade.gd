extends Node

# Troca de cena com fade (preto) — evita cortes secos entre telas.

var _transitioning: bool = false
var _fade: ColorRect = null


func _ready() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.z_index = 100
	var canvas := CanvasLayer.new()
	canvas.layer = 99
	canvas.add_child(_fade)
	add_child(canvas)


func trocar_cena(caminho: String, duracao: float = 0.3) -> void:
	if _transitioning:
		return
	if not ResourceLoader.exists(caminho):
		push_error("Transicao: cena nao encontrada: " + caminho)
		return
	_transitioning = true
	await _fade_out(duracao)
	get_tree().change_scene_to_file(caminho)
	await _fade_in(duracao)
	_transitioning = false


func _fade_out(duracao: float) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, duracao)
	await tween.finished


func _fade_in(duracao: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, duracao)
	await tween.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
