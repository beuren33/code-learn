extends Control

@onready var _slider_musica: HSlider = $MarginContainer/VBoxContainer/LinhaMusica/SliderMusica
@onready var _slider_sfx: HSlider = $MarginContainer/VBoxContainer/LinhaSfx/SliderSfx
@onready var _mudo_musica: CheckButton = $MarginContainer/VBoxContainer/LinhaMusica/MudoMusica
@onready var _mudo_sfx: CheckButton = $MarginContainer/VBoxContainer/LinhaSfx/MudoSfx


func _ready() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am == null:
		return
	_slider_musica.value = am.get("_music_volume")
	_slider_sfx.value = am.get("_sfx_volume")
	_mudo_musica.button_pressed = am.get("_music_muted")
	_mudo_sfx.button_pressed = am.get("_sfx_muted")


func _on_slider_musica_value_changed(value: float) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("set_music_volume", value)


func _on_slider_sfx_value_changed(value: float) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("set_sfx_volume", value)


func _on_mudo_musica_toggled(_pressed: bool) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("toggle_music_mute")


func _on_mudo_sfx_toggled(_pressed: bool) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("toggle_sfx_mute")


func _on_voltar_pressed() -> void:
	MenuFade.trocar_cena("res://scenes/ui/Menu/MainMenu.tscn")
