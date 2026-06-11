extends Node

# carrega os jsons do jogo

var missions: Array = []
var items: Array = []
var badges: Array = []

var _missions_map: Dictionary = {}
var _items_map: Dictionary = {}
var _badges_map: Dictionary = {}

func _ready():
	missions = _load_json("res://data/missions.json").get("missions", [])
	items    = _load_json("res://data/items.json").get("items", [])
	badges   = _load_json("res://data/badges.json").get("badges", [])
	for m in missions: _missions_map[m["id"]] = m
	for i in items:    _items_map[i["id"]]    = i
	for b in badges:   _badges_map[b["id"]]   = b

func _load_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("arquivo nao encontrado: " + path)
		return {}
	var json = JSON.new()
	var erro = json.parse(file.get_as_text())
	file.close()
	if erro != OK:
		push_error("erro ao parsear: " + path)
		return {}
	return json.data

# missoes

func get_mission(id: String) -> Dictionary:
	return _missions_map.get(id, {})

func get_missions_by_bioma(bioma: int) -> Array:
	return missions.filter(func(m): return m.get("bioma", 0) == bioma)

func get_next_mission(node_id: String) -> String:
	for i in missions.size():
		if missions[i]["id"] == node_id and i + 1 < missions.size():
			return missions[i + 1]["id"]
	return ""

func get_questions(node_id: String) -> Array:
	return get_mission(node_id).get("perguntas", [])

func is_boss(node_id: String) -> bool:
	return get_mission(node_id).get("tipo", "") in ["mini_boss", "boss_final"]

# itens

func get_item(id: String) -> Dictionary:
	return _items_map.get(id, {})

func get_items_by_raridade(raridade: String) -> Array:
	return items.filter(func(i): return i.get("raridade", "") == raridade)

func get_items_by_categoria(categoria: String) -> Array:
	return items.filter(func(i): return i.get("categoria", "") == categoria)

# conquistas

func get_badge(id: String) -> Dictionary:
	return _badges_map.get(id, {})

func get_badge_name(id: String) -> String:
	return get_badge(id).get("nome", id)

func get_badge_icon_path(id: String) -> String:
	return get_badge(id).get("icone", "")
