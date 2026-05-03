# ══════════════════════════════════════════════════════════
#  logic.gd — Tower Defense game logic
# ══════════════════════════════════════════════════════════

const Data = preload("res://scripts/data.gd")

# ─── Tower calculations ──────────────────────────────────

static func level_damage_mult(level: int) -> float:
	return 1.0 + (level - 1) * 0.45

static func level_range_mult(level: int) -> float:
	return 1.0 + (level - 1) * 0.18

static func level_fire_rate_mult(level: int) -> float:
	return 1.0 + (level - 1) * 0.12

static func tower_damage(tower: Dictionary, perm_upgrades: Dictionary) -> float:
	var t: Dictionary = Data.TOWER_TYPES[tower.type]
	var v: float = t.damage * level_damage_mult(tower.level)
	v *= 1.0 + perm_upgrades["tower_damage"]["level"] * perm_upgrades["tower_damage"]["value_per_level"]
	return v

static func tower_range(tower: Dictionary, perm_upgrades: Dictionary) -> float:
	var t: Dictionary = Data.TOWER_TYPES[tower.type]
	var v: float = t.range_cells * Data.CELL * level_range_mult(tower.level)
	v *= 1.0 + perm_upgrades["tower_range"]["level"] * perm_upgrades["tower_range"]["value_per_level"]
	return v

static func tower_fire_rate(tower: Dictionary) -> float:
	var t: Dictionary = Data.TOWER_TYPES[tower.type]
	return t.fire_rate * level_fire_rate_mult(tower.level)

static func tower_cost(type_key: String, perm_upgrades: Dictionary) -> int:
	var base: int = Data.TOWER_TYPES[type_key].cost
	return int(base * (1.0 - perm_upgrades["tower_discount"]["level"] * perm_upgrades["tower_discount"]["value_per_level"]))

static func upgrade_cost(tower: Dictionary) -> int:
	var base_cost: int = Data.TOWER_TYPES[tower.type].cost
	return int(Data.UPGRADE_BASE_COST * (base_cost / 50.0) + (tower.level - 1) * 30)

static func sell_value(tower: Dictionary, perm_upgrades: Dictionary, prestige_upgrades: Dictionary) -> int:
	var invested: int = tower_cost(tower.type, perm_upgrades)
	for i in range(1, tower.level):
		var base_cost: int = Data.TOWER_TYPES[tower.type].cost
		invested += int(Data.UPGRADE_BASE_COST * (base_cost / 50.0) + (i - 1) * 30)
	var refund := Data.SELL_REFUND + prestige_sell_refund_bonus(prestige_upgrades)
	return int(invested * refund)

# ─── Enemy spawning ──────────────────────────────────────

static func enemy_type_for_wave(wave: int) -> String:
	var pool := ["grunt", "grunt"]
	if wave >= 2: pool.append("runner")
	if wave >= 3: pool.append("armored")
	if wave >= 4:
		pool.append("runner")
		pool.append("grunt")
	if wave >= 5: pool.append("tank")
	if wave >= 6: pool.append("tank")
	if wave >= 7: pool.append("armored")
	if wave >= 8:
		pool.append("swarm")
		pool.append("tank")
	if wave >= 10:
		pool.append("swarm")
		pool.append("armored")
		pool.append("tank")
	if wave >= 12:
		pool.append("tank")
		pool.append("armored")
	return pool[randi() % pool.size()]

static func spawn_enemy(wave: int, path_points: Array) -> Dictionary:
	var type_key := enemy_type_for_wave(wave)
	var et: Dictionary = Data.ENEMY_TYPES[type_key]
	var base_hp := 220.0 + wave * 160.0  # Brutal HP scaling
	var hp: float = base_hp * et.hp_mult
	return {
		"pos": path_points[0],
		"hp": hp,
		"max_hp": hp,
		"segment": 0,
		"type": type_key,
		"speed_mult": et.speed_mult,
		"color": et.color,
		"size": et.size,
		"armor": et.armor,
		"gold": et.gold,
		"slow_until": 0.0,
		"slow_factor": 1.0,
	}

static func spawn_count(wave: int) -> int:
	return int(Data.ENEMIES_PER_WAVE_BASE + wave * 5.0)  # Horde scaling

# ─── Enemy movement ──────────────────────────────────────

static func move_enemies(enemies: Array, path_points: Array, delta: float, prestige_upgrades: Dictionary) -> int:
	var lives_lost := 0
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[i]
		if e.segment >= path_points.size() - 1:
			enemies.remove_at(i)
			lives_lost += 1
			continue
		var spd: float = Data.ENEMY_BASE_SPEED * e.speed_mult * _prestige_enemy_speed(prestige_upgrades)
		if e.slow_until > now:
			spd *= e.slow_factor
		var target: Vector2 = path_points[e.segment + 1]
		var diff: Vector2 = target - e.pos
		var dist: float = diff.length()
		var step: float = spd * delta
		if step >= dist:
			e.pos = target
			e.segment += 1
		else:
			e.pos += diff / dist * step
	return lives_lost

# ─── Tower firing ────────────────────────────────────────

static func process_towers(towers: Array, enemies: Array, projectiles: Array, token_floaters: Array, delta: float, perm_upgrades: Dictionary, prestige_upgrades: Dictionary) -> void:
	var multi_shot: int = prestige_upgrades["multi_shot"]["level"]
	for t in towers:
		t.cooldown -= delta
		if t.cooldown <= 0.0:
			var ttype: Dictionary = Data.TOWER_TYPES[t.type]
			var center := Vector2((t.cell.x + 0.5) * Data.CELL, (t.cell.y + 0.5) * Data.CELL)
			var rng := tower_range(t, perm_upgrades)
			var targets := _find_targets(enemies, center, rng, 1 + multi_shot)
			if not targets.is_empty():
				for tgt in targets:
					var dmg := tower_damage(t, perm_upgrades)
					if randf() < _prestige_crit(prestige_upgrades):
						dmg *= 2.5
					projectiles.append({
						"pos": center,
						"target": tgt,
						"life": 1.6,
						"damage": dmg,
						"type": t.type,
					})
				t.cooldown = 1.0 / tower_fire_rate(t)

static func _find_targets(enemies: Array, center: Vector2, rng: float, count: int) -> Array:
	var candidates := []
	for e in enemies:
		if e.pos.distance_to(center) <= rng:
			candidates.append(e)
	candidates.sort_custom(func(a, b): return a.segment > b.segment)
	return candidates.slice(0, count)

# ─── Projectile movement ─────────────────────────────────

static func process_projectiles(projectiles: Array, enemies: Array, token_floaters: Array, gold_ref, delta: float, perm_upgrades: Dictionary, prestige_upgrades: Dictionary) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		p.life -= delta
		if p.life <= 0.0 or not enemies.has(p.target):
			projectiles.remove_at(i)
			continue
		var ttype: Dictionary = Data.TOWER_TYPES[p.type]
		var pspeed: float = ttype.projectile_speed
		var diff: Vector2 = p.target.pos - p.pos
		var d: float = diff.length()
		var step: float = pspeed * delta
		if step >= d:
			_resolve_hit(p, enemies, token_floaters, gold_ref, perm_upgrades, prestige_upgrades)
			projectiles.remove_at(i)
		else:
			p.pos += diff / d * step

static func _resolve_hit(p: Dictionary, enemies: Array, token_floaters: Array, gold_ref: Array, perm_upgrades: Dictionary, prestige_upgrades: Dictionary) -> void:
	var ttype: Dictionary = Data.TOWER_TYPES[p.type]
	match ttype.kind:
		"single":
			_apply_damage(p.target, p.damage, enemies, gold_ref, token_floaters, perm_upgrades)
		"slow":
			_apply_damage(p.target, p.damage, enemies, gold_ref, token_floaters, perm_upgrades)
			if enemies.has(p.target):
				var now := Time.get_ticks_msec() / 1000.0
				p.target.slow_until = now + ttype.slow_duration
				p.target.slow_factor = ttype.slow_factor
		"splash":
			var r: float = ttype.splash_radius
			var center: Vector2 = p.target.pos
			var hit_list := []
			for e in enemies:
				if e.pos.distance_to(center) <= r:
					hit_list.append(e)
			for e in hit_list:
				_apply_damage(e, p.damage, enemies, gold_ref, token_floaters, perm_upgrades)
			token_floaters.append({"pos": center, "life": 0.35, "text": "", "splash": true, "radius": r, "color": ttype.projectile_color})

static func _apply_damage(target: Dictionary, dmg: float, enemies: Array, gold_ref: Array, token_floaters: Array, perm_upgrades: Dictionary) -> void:
	if not enemies.has(target):
		return
	var armor: float = target.get("armor", 0.0)
	var actual := dmg * (1.0 - armor)
	target.hp -= actual
	if target.hp <= 0.0:
		enemies.erase(target)
		gold_ref[0] += int(target.gold)
		if randf() < _token_kill_chance(perm_upgrades):
			token_floaters.append({"pos": target.pos + Vector2(0, -16), "life": 2.0, "text": "+1 token", "splash": false})

# ─── Token floaters ──────────────────────────────────────

static func process_token_floaters(token_floaters: Array, delta: float) -> void:
	for i in range(token_floaters.size() - 1, -1, -1):
		var f: Dictionary = token_floaters[i]
		f.life -= delta
		if not f.get("splash", false):
			f.pos.y -= 30.0 * delta
		if f.life <= 0.0:
			token_floaters.remove_at(i)

# ─── Economy helpers ─────────────────────────────────────

static func shop_upgrade_cost(key: String, perm_upgrades: Dictionary) -> int:
	var u: Dictionary = perm_upgrades[key]
	return u["cost_base"] * (1 + u["level"])

static func prestige_core_cost(key: String, prestige_upgrades: Dictionary) -> int:
	var u: Dictionary = prestige_upgrades[key]
	return u["cost_base"] * (1 + u["level"])

static func token_kill_chance(perm_upgrades: Dictionary) -> float:
	return Data.TOKEN_KILL_CHANCE + perm_upgrades["token_gain"]["level"] * perm_upgrades["token_gain"]["value_per_level"]

static func _token_kill_chance(perm_upgrades: Dictionary) -> float:
	return Data.TOKEN_KILL_CHANCE + perm_upgrades["token_gain"]["level"] * perm_upgrades["token_gain"]["value_per_level"]

static func starting_gold(perm_upgrades: Dictionary) -> int:
	return 150 + perm_upgrades["starting_gold"]["level"] * perm_upgrades["starting_gold"]["value_per_level"]

# ─── Prestige helpers ────────────────────────────────────

static func prestige_bonus_lives(prestige_upgrades: Dictionary) -> int:
	return prestige_upgrades["fortified"]["level"] * 2

static func prestige_wave_gold_mult(prestige_upgrades: Dictionary) -> float:
	return 1.0 + prestige_upgrades["compound_interest"]["level"] * 0.12

static func _prestige_crit(prestige_upgrades: Dictionary) -> float:
	return prestige_upgrades["critical_mass"]["level"] * 0.12

static func prestige_sell_refund_bonus(prestige_upgrades: Dictionary) -> float:
	return prestige_upgrades["recycling"]["level"] * 0.06

static func _prestige_enemy_speed(prestige_upgrades: Dictionary) -> float:
	return 1.0 - prestige_upgrades["quick_enemies"]["level"] * 0.06

static func can_prestige(wave: int, wave_active: bool, lives: int) -> bool:
	return wave >= Data.PRESTIGE_WAVE_THRESHOLD and not wave_active and lives > 0

static func prestige_cores_earned(wave: int, tokens: int, perm_upgrades: Dictionary) -> int:
	var base: int = int(floor(float(wave) / 5.0))
	if base < 1:
		base = 1
	var upgrade_bonus: int = 0
	for key in perm_upgrades:
		upgrade_bonus += int(perm_upgrades[key]["level"])
	upgrade_bonus = int(floor(float(upgrade_bonus) / 3.0))
	var token_bonus: int = int(floor(float(tokens) / 100.0))
	return base + upgrade_bonus + token_bonus

# ─── Building paths from path_cells ──────────────────────

static func build_path(path_cells: Array) -> Dictionary:
	var path_set := {}
	var path_points := []
	for c in path_cells:
		path_points.append(Vector2((c.x + 0.5) * Data.CELL, (c.y + 0.5) * Data.CELL))
	for i in range(path_cells.size() - 1):
		var a: Vector2i = path_cells[i]
		var b: Vector2i = path_cells[i + 1]
		var step := Vector2i(sign(b.x - a.x), sign(b.y - a.y))
		var c: Vector2i = a
		while c != b:
			if c.x >= 0 and c.x < Data.GRID_COLS and c.y >= 0 and c.y < Data.GRID_ROWS:
				path_set[c] = true
			c += step
		if c.x >= 0 and c.x < Data.GRID_COLS and c.y >= 0 and c.y < Data.GRID_ROWS:
			path_set[c] = true
	return {"set": path_set, "points": path_points}

# ─── Save / Load ─────────────────────────────────────────

static func save_game(state: Dictionary) -> void:
	var data := {
		"tokens": state.tokens,
		"upgrades": {},
		"prestige_upgrades": {},
		"prestige_cores": state.prestige_cores,
		"current_level_index": state.current_level_index,
		"selected_tower_type": state.selected_tower_type,
		"has_run": false,
		"run": {}
	}
	for key in state.perm_upgrades:
		data["upgrades"][key] = state.perm_upgrades[key]["level"]
	for key in state.prestige_upgrades:
		data["prestige_upgrades"][key] = state.prestige_upgrades[key]["level"]

	if state.wave > 0 and state.lives > 0:
		data["has_run"] = true
		data["run"] = {
			"gold": state.gold,
			"lives": state.lives,
			"wave": state.wave,
			"wave_active": state.wave_active,
			"spawn_remaining": state.spawn_remaining,
			"level_index": state.current_level_index,
			"towers": []
		}
		for t in state.towers:
			data["run"]["towers"].append({"cell": [t.cell.x, t.cell.y], "level": t.level, "type": t.type})

	var f := FileAccess.open(Data.SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

static func load_game(state: Dictionary) -> void:
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
			if data.has("tokens"):
				state.tokens = data["tokens"]
			if data.has("prestige_cores"):
				state.prestige_cores = data["prestige_cores"]
			if data.has("current_level_index"):
				state.current_level_index = clamp(int(data["current_level_index"]), 0, Data.LEVELS.size() - 1)
			if data.has("selected_tower_type"):
				var st: String = data["selected_tower_type"]
				if Data.TOWER_TYPES.has(st):
					state.selected_tower_type = st
			if data.has("upgrades") and data["upgrades"] is Dictionary:
				for key in data["upgrades"]:
					if state.perm_upgrades.has(key):
						state.perm_upgrades[key]["level"] = data["upgrades"][key]
			if data.has("prestige_upgrades") and data["prestige_upgrades"] is Dictionary:
				for key in data["prestige_upgrades"]:
					if state.prestige_upgrades.has(key):
						state.prestige_upgrades[key]["level"] = data["prestige_upgrades"][key]

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

static func load_saved_run(state: Dictionary) -> void:
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
				state.gold = run.get("gold", starting_gold(state.perm_upgrades))
				state.lives = run.get("lives", 20)
				state.wave = run.get("wave", 0)
				state.wave_active = run.get("wave_active", false)
				state.spawn_remaining = run.get("spawn_remaining", 0)
				if run.has("level_index"):
					state.current_level_index = clamp(int(run["level_index"]), 0, Data.LEVELS.size() - 1)
				var saved_towers = run.get("towers", [])
				for st in saved_towers:
					var t_type: String = st.get("type", "arrow")
					if not Data.TOWER_TYPES.has(t_type):
						t_type = "arrow"
					state.towers.append({
						"cell": Vector2i(st["cell"][0], st["cell"][1]),
						"cooldown": 0.0,
						"level": st["level"],
						"type": t_type,
					})

static func clear_saved_run(state: Dictionary) -> void:
	save_game(state)
	# Re-write with has_run=false
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
