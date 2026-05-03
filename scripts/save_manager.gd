# ══════════════════════════════════════════════════════════
#  save_manager.gd — Save/Load for Tower Defense
# ══════════════════════════════════════════════════════════
extends RefCounted

const Data = preload("res://scripts/data.gd")


static func save_persistent(game: Node2D) -> void:
	var data := {
		"tokens": game.tokens,
		"upgrades": {},
		"prestige_upgrades": {},
		"prestige_cores": game.prestige_cores,
		"current_level_index": game.current_level_index,
		"selected_tower_type": game.selected_tower_type,
		"has_run": false,
		"run": {}
	}
	for key in game.perm_upgrades:
		data["upgrades"][key] = game.perm_upgrades[key]["level"]
	for key in game.prestige_upgrades:
		data["prestige_upgrades"][key] = game.prestige_upgrades[key]["level"]

	if game.wave > 0 and game.lives > 0:
		data["has_run"] = true
		data["run"] = {
			"gold": game.gold,
			"lives": game.lives,
			"wave": game.wave,
			"wave_active": game.wave_active,
			"spawn_remaining": game.spawn_remaining,
			"level_index": game.current_level_index,
			"towers": []
		}
		for t in game.towers:
			data["run"]["towers"].append({"cell": [t.cell.x, t.cell.y], "level": t.level, "type": t.type})

	var f := FileAccess.open(Data.SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


static func load_persistent(game: Node2D) -> void:
	if not FileAccess.file_exists(Data.SAVE_PATH):
		return
	var f := FileAccess.open(Data.SAVE_PATH, FileAccess.READ)
	if not f: return
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) == OK:
		var data = json.get_data()
		if data is Dictionary:
			if data.has("tokens"): game.tokens = data["tokens"]
			if data.has("prestige_cores"): game.prestige_cores = data["prestige_cores"]
			if data.has("current_level_index"): game.current_level_index = clamp(int(data["current_level_index"]), 0, Data.LEVELS.size() - 1)
			if data.has("selected_tower_type"):
				var st: String = data["selected_tower_type"]
				if Data.TOWER_TYPES.has(st): game.selected_tower_type = st
			if data.has("upgrades") and data["upgrades"] is Dictionary:
				for key in data["upgrades"]:
					if game.perm_upgrades.has(key):
						game.perm_upgrades[key]["level"] = data["upgrades"][key]
			if data.has("prestige_upgrades") and data["prestige_upgrades"] is Dictionary:
				for key in data["prestige_upgrades"]:
					if game.prestige_upgrades.has(key):
						game.prestige_upgrades[key]["level"] = data["prestige_upgrades"][key]


static func has_saved_run() -> bool:
	if not FileAccess.file_exists(Data.SAVE_PATH):
		return false
	var f := FileAccess.open(Data.SAVE_PATH, FileAccess.READ)
	if not f: return false
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) == OK:
		var data = json.get_data()
		if data is Dictionary and data.has("has_run"):
			return data["has_run"]
	return false


static func load_saved_run(game: Node2D) -> void:
	if not FileAccess.file_exists(Data.SAVE_PATH):
		return
	var f := FileAccess.open(Data.SAVE_PATH, FileAccess.READ)
	if not f: return
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) == OK:
		var data = json.get_data()
		if data is Dictionary and data.has("run"):
			var run = data["run"]
			if run is Dictionary:
				game.gold = run.get("gold", 150)
				game.lives = run.get("lives", 20)
				game.wave = run.get("wave", 0)
				game.wave_active = run.get("wave_active", false)
				game.spawn_remaining = run.get("spawn_remaining", 0)
				if run.has("level_index"):
					game.current_level_index = clamp(int(run["level_index"]), 0, Data.LEVELS.size() - 1)
				var saved_towers = run.get("towers", [])
				for st in saved_towers:
					var t_type: String = st.get("type", "arrow")
					if not Data.TOWER_TYPES.has(t_type):
						t_type = "arrow"
					game.towers.append({
						"cell": Vector2i(st["cell"][0], st["cell"][1]),
						"cooldown": 0.0,
						"level": st["level"],
						"type": t_type,
					})


static func clear_saved_run() -> void:
	if not FileAccess.file_exists(Data.SAVE_PATH):
		return
	var f := FileAccess.open(Data.SAVE_PATH, FileAccess.READ)
	if not f: return
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) == OK:
		var data = json.get_data()
		if data is Dictionary:
			data["has_run"] = false
			data["run"] = {}
			var fw := FileAccess.open(Data.SAVE_PATH, FileAccess.WRITE)
			if fw:
				fw.store_string(JSON.stringify(data))
				fw.close()
