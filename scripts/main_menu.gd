extends Control

func _ready() -> void:
	pass

func _on_startbtn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/levels/node_2d.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_creditos_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/Credits/Credits.tscn")
