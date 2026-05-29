extends Node

# salva e carrega dados do jogo

const DB_PATH = "user://codelearn.db"

var db: SQLite = null
var current_player_id: int = -1

func _ready():
	db = SQLite.new()
	db.path = DB_PATH
	db.verbosity_level = SQLite.QUIET
	if db.open_db():
		_create_tables()
	else:
		push_error("erro ao abrir banco")

func _create_tables():
	db.create_table("player", {
		"id_player": {"data_type": "int", "primary_key": true, "auto_increment": true},
		"nome":      {"data_type": "text", "not_null": true},
		"avatar":    {"data_type": "int", "default": 0},
		"xp":        {"data_type": "int", "default": 0},
		"level":     {"data_type": "int", "default": 1},
		"moedas":    {"data_type": "int", "default": 0}
	})
	db.create_table("progress", {
		"id_progress": {"data_type": "int", "primary_key": true, "auto_increment": true},
		"id_player":   {"data_type": "int", "not_null": true},
		"node_id":     {"data_type": "text", "not_null": true},
		"estrelas":    {"data_type": "int", "default": 0},
		"completado":  {"data_type": "int", "default": 0},
		"timestamp":   {"data_type": "text", "default": ""}
	})
	db.create_table("inventory", {
		"id_inventory": {"data_type": "int", "primary_key": true, "auto_increment": true},
		"id_player":    {"data_type": "int", "not_null": true},
		"item_id":      {"data_type": "text", "not_null": true},
		"equipado":     {"data_type": "int", "default": 0}
	})
	db.create_table("badges_earned", {
		"id_badge":  {"data_type": "int", "primary_key": true, "auto_increment": true},
		"id_player": {"data_type": "int", "not_null": true},
		"badge_id":  {"data_type": "text", "not_null": true},
		"timestamp": {"data_type": "text", "default": ""}
	})
	db.query("CREATE UNIQUE INDEX IF NOT EXISTS idx_progress ON progress(id_player, node_id)")
	db.query("CREATE UNIQUE INDEX IF NOT EXISTS idx_inventory ON inventory(id_player, item_id)")
	db.query("CREATE UNIQUE INDEX IF NOT EXISTS idx_badge ON badges_earned(id_player, badge_id)")

# jogador

func create_player(nome: String, avatar: int) -> int:
	db.insert_row("player", {"nome": _esc(nome), "avatar": avatar})
	db.query("SELECT last_insert_rowid() as id")
	current_player_id = db.query_result[0]["id"]
	return current_player_id

func login(nome: String) -> Dictionary:
	db.query("SELECT * FROM player WHERE nome = '%s'" % _esc(nome))
	if db.query_result.size() > 0:
		current_player_id = db.query_result[0]["id_player"]
		return db.query_result[0]
	return {}

func get_player(id_player: int = -1) -> Dictionary:
	var pid = _pid(id_player)
	db.query("SELECT * FROM player WHERE id_player = %d" % pid)
	if db.query_result.size() > 0:
		return db.query_result[0]
	return {}

# missoes

func complete_mission(node_id: String, estrelas: int, id_player: int = -1) -> Dictionary:
	var pid = _pid(id_player)
	var xp_ganho = 0
	var moedas_ganhas = 0
	match estrelas:
		1: xp_ganho = 50;  moedas_ganhas = 5
		2: xp_ganho = 100; moedas_ganhas = 10
		3: xp_ganho = 150; moedas_ganhas = 15

	db.query("SELECT xp, level, moedas FROM player WHERE id_player = %d" % pid)
	if db.query_result.is_empty():
		push_error("jogador nao encontrado")
		return {}

	var dados = db.query_result[0]
	var xp_novo = dados["xp"] + xp_ganho
	var level_novo = dados["level"]
	var level_up = false

	while xp_novo >= level_novo * 200:
		xp_novo -= level_novo * 200
		level_novo += 1
		level_up = true

	db.update_rows("player", "id_player = %d" % pid, {
		"xp": xp_novo,
		"level": level_novo,
		"moedas": dados["moedas"] + moedas_ganhas
	})
	save_progress(node_id, estrelas, pid)
	var badges_novos = _check_badges(pid)

	return {
		"xp_ganho": xp_ganho,
		"moedas_ganhas": moedas_ganhas,
		"level_novo": level_novo,
		"level_up": level_up,
		"badges_novos": badges_novos
	}

func save_progress(node_id: String, estrelas: int, id_player: int = -1) -> bool:
	var pid = _pid(id_player)
	db.query("SELECT estrelas FROM progress WHERE id_player = %d AND node_id = '%s'" % [pid, node_id])
	if db.query_result.size() > 0:
		if estrelas <= db.query_result[0]["estrelas"]:
			return false
		db.update_rows("progress", "id_player = %d AND node_id = '%s'" % [pid, node_id], {
			"estrelas": estrelas, "completado": 1, "timestamp": _timestamp()
		})
	else:
		db.insert_row("progress", {
			"id_player": pid, "node_id": node_id,
			"estrelas": estrelas, "completado": 1, "timestamp": _timestamp()
		})
	return true

func get_progress(node_id: String, id_player: int = -1) -> Dictionary:
	var pid = _pid(id_player)
	db.query("SELECT * FROM progress WHERE id_player = %d AND node_id = '%s'" % [pid, node_id])
	if db.query_result.size() > 0:
		return db.query_result[0]
	return {}

func get_all_progress(id_player: int = -1) -> Dictionary:
	var pid = _pid(id_player)
	db.query("SELECT node_id, estrelas, completado FROM progress WHERE id_player = %d" % pid)
	var result: Dictionary = {}
	for row in db.query_result:
		result[row["node_id"]] = {"estrelas": row["estrelas"], "completado": row["completado"]}
	return result

# itens

func buy_item(item_id: String, custo: int, id_player: int = -1) -> Dictionary:
	var pid = _pid(id_player)
	db.query("SELECT item_id FROM inventory WHERE id_player = %d AND item_id = '%s'" % [pid, item_id])
	if db.query_result.size() > 0:
		return {"sucesso": false, "motivo": "duplicata", "moedas_restantes": -1}

	db.query("SELECT moedas FROM player WHERE id_player = %d" % pid)
	if db.query_result.is_empty():
		return {"sucesso": false, "motivo": "jogador_nao_encontrado", "moedas_restantes": -1}

	var moedas = db.query_result[0]["moedas"]
	if moedas < custo:
		return {"sucesso": false, "motivo": "moedas_insuficientes", "moedas_restantes": moedas}

	db.update_rows("player", "id_player = %d" % pid, {"moedas": moedas - custo})
	db.insert_row("inventory", {"id_player": pid, "item_id": item_id, "equipado": 0})
	return {"sucesso": true, "motivo": "", "moedas_restantes": moedas - custo}

func get_inventory(id_player: int = -1) -> Array:
	var pid = _pid(id_player)
	db.query("SELECT item_id, equipado FROM inventory WHERE id_player = %d" % pid)
	return db.query_result

func equip_item(item_id: String, categoria: String, id_player: int = -1) -> bool:
	var pid = _pid(id_player)
	db.query("SELECT item_id FROM inventory WHERE id_player = %d AND item_id = '%s'" % [pid, item_id])
	if db.query_result.is_empty():
		return false
	db.query("SELECT item_id FROM inventory WHERE id_player = %d AND equipado = 1 AND item_id LIKE '%s_%%'" % [pid, categoria])
	for row in db.query_result:
		db.update_rows("inventory", "id_player = %d AND item_id = '%s'" % [pid, row["item_id"]], {"equipado": 0})
	db.update_rows("inventory", "id_player = %d AND item_id = '%s'" % [pid, item_id], {"equipado": 1})
	return true

func unequip_item(item_id: String, id_player: int = -1) -> void:
	var pid = _pid(id_player)
	db.update_rows("inventory", "id_player = %d AND item_id = '%s'" % [pid, item_id], {"equipado": 0})

func get_equipped_items(id_player: int = -1) -> Dictionary:
	var pid = _pid(id_player)
	db.query("SELECT item_id FROM inventory WHERE id_player = %d AND equipado = 1" % pid)
	var result: Dictionary = {}
	for row in db.query_result:
		var parts = row["item_id"].split("_", false, 1)
		if parts.size() > 0:
			result[parts[0]] = row["item_id"]
	return result

# conquistas

func get_badges(id_player: int = -1) -> Array:
	var pid = _pid(id_player)
	db.query("SELECT badge_id FROM badges_earned WHERE id_player = %d" % pid)
	var result: Array = []
	for row in db.query_result:
		result.append(row["badge_id"])
	return result

func _check_badges(pid: int) -> Array:
	db.query("SELECT COUNT(*) as total FROM progress WHERE id_player = %d AND completado = 1" % pid)
	var total_missoes = db.query_result[0]["total"]

	db.query("SELECT COUNT(*) as total FROM progress WHERE id_player = %d AND estrelas = 3" % pid)
	var total_perfeitas = db.query_result[0]["total"]

	db.query("SELECT level FROM player WHERE id_player = %d" % pid)
	var level_atual = db.query_result[0]["level"]

	var condicoes = {
		"primeira_missao": total_missoes >= 1,
		"dez_missoes":     total_missoes >= 10,
		"vinte_missoes":   total_missoes >= 20,
		"perfeccionista":  total_perfeitas >= 5,
		"mestre_perfeito": total_perfeitas >= 20,
		"level_5":         level_atual >= 5,
		"level_10":        level_atual >= 10,
		"level_max":       level_atual >= 20,
	}

	var badges_atuais = get_badges(pid)
	var novos: Array = []
	for badge_id in condicoes:
		if condicoes[badge_id] and not badges_atuais.has(badge_id):
			db.insert_row("badges_earned", {
				"id_player": pid, "badge_id": badge_id, "timestamp": _timestamp()
			})
			novos.append(badge_id)
	return novos

# util

func _pid(id: int = -1) -> int:
	return id if id != -1 else current_player_id

func _esc(s: String) -> String:
	return s.replace("'", "''")

func _timestamp() -> String:
	return Time.get_datetime_string_from_system()
