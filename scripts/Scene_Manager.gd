extends Node

# troca de cenas com fade

var params: Dictionary = {}

const SCENES = {
	"login":          "res://scenes/ui/login.tscn",
	"home":           "res://scenes/ui/home.tscn",
	"tabuleiro":      "res://scenes/game/tabuleiro.tscn",
	"missao":         "res://scenes/game/missao.tscn",
	"quiz":           "res://scenes/game/quiz.tscn",
	"boss_fight":     "res://scenes/game/boss_fight.tscn",
	"resultado":      "res://scenes/ui/resultado.tscn",
	"perfil":         "res://scenes/ui/perfil.tscn",
	"loja":           "res://scenes/ui/loja.tscn",
	"material_apoio": "res://scenes/game/material_apoio.tscn",
}

var _transitioning: bool = false
var _fade: ColorRect = null

func _ready():
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.z_index = 100
	var canvas = CanvasLayer.new()
	canvas.layer = 99
	canvas.add_child(_fade)
	add_child(canvas)

func go_to(scene_key: String, data: Dictionary = {}) -> void:
	if _transitioning:
		return
	params = data
	var path = SCENES.get(scene_key, scene_key)
	if not ResourceLoader.exists(path):
		push_error("cena nao encontrada: " + path)
		return
	_transitioning = true
	await _fade_out()
	get_tree().change_scene_to_file(path)
	await _fade_in()
	_transitioning = false

func go_back() -> void:
	go_to("tabuleiro")

func reload() -> void:
	if _transitioning:
		return
	_transitioning = true
	await _fade_out()
	get_tree().reload_current_scene()
	await _fade_in()
	_transitioning = false

func _fade_out(duration: float = 0.3) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, duration)
	await tween.finished

func _fade_in(duration: float = 0.3) -> void:
	var tween = create_tween()
	tween.tween_property(_fade, "color:a", 0.0, duration)
	await tween.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
