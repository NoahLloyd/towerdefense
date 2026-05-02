extends Node2D

# ─── Grid ────────────────────────────────────────────────
const GRID_COLS := 16
const GRID_ROWS := 10
const CELL := 64

# ─── Palette ─────────────────────────────────────────────
const COLOR_BG       := Color("#1a1d23")
const COLOR_GRID     := Color("#262a32")
const COLOR_PATH     := Color("#2f3540")
const COLOR_HOVER_OK := Color("#7a8a9a")
const COLOR_HOVER_BAD:= Color("#e85d4a")
const COLOR_TOWER    := Color("#9aa8b8")
const COLOR_TOWER_2  := Color("#aebfcf")   # level 2 brightens
const COLOR_TOWER_3  := Color("#c2d4e3")   # level 3
const COLOR_TOWER_4  := Color("#d6e6f3")   # level 4
const COLOR_TOWER_CORE := Color("#cfd6df")
const COLOR_RANGE    := Color(0.6, 0.7, 0.8, 0.06)
const COLOR_RANGE_SEL:= Color(0.6, 0.7, 0.8, 0.15)
const COLOR_ENEMY    := Color("#e85d4a")
const COLOR_PROJECTILE:= Color("#ffd87a")
const COLOR_HP       := Color("#9adfa0")
const COLOR_TEXT     := Color("#8a97a8")
const COLOR_PANEL_BG := Color("#1e222a")
const COLOR_PANEL_BORDER := Color("#3a404d")
const COLOR_BUTTON   := Color("#4a5568")
const COLOR_BUTTON_HOVER := Color("#5a6b82")
const COLOR_GOLD     := Color("#ffd87a")
const COLOR_TOKEN    := Color("#b8a0ff")   # purple for tokens
const COLOR_UPGRADE_FILL := Color("#6eb5ff")
const COLOR_SELL     := Color("#e85d4a")

# ─── Path (cell coords) ──────────────────────────────────
var path_cells := [
	Vector2i(-1, 5),
	Vector2i(5, 5),
	Vector2i(5, 2),
	Vector2i(10, 2),
	Vector2i(10, 7),
	Vector2i(16, 7),
]
var path_set := {}
var path_points := []

# ─── Tower stats ─────────────────────────────────────────
const TOWER_COST := 50
const TOWER_BASE_DAMAGE := 12.0
const TOWER_BASE_RANGE := 3.0 * CELL
const TOWER_BASE_FIRE_RATE := 1.4
const PROJECTILE_SPEED := 700.0
const TOWER_MAX_LEVEL := 4
const UPGRADE_BASE_COST := 45
const SELL_REFUND := 0.6

func _level_damage_mult(level: int) -> float:
	return 1.0 + (level - 1) * 0.45

func _level_range_mult(level: int) -> float:
	return 1.0 + (level - 1) * 0.18

func _level_fire_rate_mult(level: int) -> float:
	return 1.0 + (level - 1) * 0.12

func _tower_damage(level: int) -> float:
	var v := TOWER_BASE_DAMAGE * _level_damage_mult(level)
	v *= 1.0 + perm_upgrades["tower_damage"]["level"] * perm_upgrades["tower_damage"]["value_per_level"]
	return v

func _tower_range(level: int) -> float:
	var v := TOWER_BASE_RANGE * _level_range_mult(level)
	v *= 1.0 + perm_upgrades["tower_range"]["level"] * perm_upgrades["tower_range"]["value_per_level"]
	return v

func _tower_fire_rate(level: int) -> float:
	var v := TOWER_BASE_FIRE_RATE * _level_fire_rate_mult(level)
	return v

func _tower_cost() -> int:
	return int(TOWER_COST * (1.0 - perm_upgrades["tower_discount"]["level"] * perm_upgrades["tower_discount"]["value_per_level"]))

func _upgrade_cost(level: int) -> int:
	return UPGRADE_BASE_COST + (level - 1) * 30

func _sell_value(tower: Dictionary) -> int:
	var invested := _tower_cost()
	for i in range(1, tower.level):
		invested += _upgrade_cost(i)
	return int(invested * SELL_REFUND)

# ─── Game state ──────────────────────────────────────────
var towers := []          # {cell: Vector2i, cooldown: float, level: int}
var enemies := []         # {pos, hp, max_hp, segment}
var projectiles := []     # {pos, target, life}
var gold := 150
var lives := 20
var wave := 0
var wave_active := false
var spawn_timer := 0.0
var spawn_remaining := 0
const ENEMY_SPEED := 95.0
const ENEMIES_PER_WAVE_BASE := 8
var hover_cell := Vector2i(-1, -1)
var selected_tower_cell := Vector2i(-1, -1)  # -1,-1 = none selected

# ─── Token economy ───────────────────────────────────────
var tokens := 0
const TOKENS_PER_WAVE := 2
const TOKEN_KILL_CHANCE := 0.08
var token_floaters := []   # {pos, life, text}

func _token_kill_chance() -> float:
	return TOKEN_KILL_CHANCE + perm_upgrades["token_gain"]["level"] * perm_upgrades["token_gain"]["value_per_level"]

func _starting_gold() -> int:
	return 150 + perm_upgrades["starting_gold"]["level"] * perm_upgrades["starting_gold"]["value_per_level"]

# ─── Permanent upgrades ──────────────────────────────────
var perm_upgrades := {
	"tower_damage":   {"name": "Sharper Cores",    "desc": "All towers deal +10% damage",        "level": 0, "max_level": 5, "cost_base": 3, "value_per_level": 0.10},
	"tower_range":    {"name": "Extended Reach",   "desc": "All towers gain +8% range",          "level": 0, "max_level": 5, "cost_base": 3, "value_per_level": 0.08},
	"starting_gold":  {"name": "War Chest",        "desc": "Start each game with +25 gold",      "level": 0, "max_level": 4, "cost_base": 4, "value_per_level": 25},
	"tower_discount": {"name": "Efficient Design", "desc": "Towers cost 8% less to build",       "level": 0, "max_level": 4, "cost_base": 5, "value_per_level": 0.08},
	"token_gain":     {"name": "Overflow",         "desc": "Earn tokens 5% more often",          "level": 0, "max_level": 3, "cost_base": 6, "value_per_level": 0.05},
}
var shop_open := false
var shop_buttons := []   # [{rect: Rect2, key: String}]
var shop_hover_key := ""

# ─── Tower info panel hit areas ──────────────────────────
var info_panel_rect := Rect2()
var info_upgrade_rect := Rect2()
var info_sell_rect := Rect2()

# ─── Nodes ───────────────────────────────────────────────
@onready var hud: Label = $CanvasLayer/HUD
@onready var token_label: Label = $CanvasLayer/TokenLabel
@onready var hint: Label = $CanvasLayer/Hint

# ══════════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════════

func _ready() -> void:
	_build_path()
	_load_tokens()
	_update_hud()

func _build_path() -> void:
	path_points.clear()
	for c in path_cells:
		path_points.append(Vector2((c.x + 0.5) * CELL, (c.y + 0.5) * CELL))
	for i in range(path_cells.size() - 1):
		var a: Vector2i = path_cells[i]
		var b: Vector2i = path_cells[i + 1]
		var step := Vector2i(sign(b.x - a.x), sign(b.y - a.y))
		var c: Vector2i = a
		while c != b:
			if c.x >= 0 and c.x < GRID_COLS and c.y >= 0 and c.y < GRID_ROWS:
				path_set[c] = true
			c += step
		if c.x >= 0 and c.x < GRID_COLS and c.y >= 0 and c.y < GRID_ROWS:
			path_set[c] = true

# ══════════════════════════════════════════════════════════
#  MAIN LOOP
# ══════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if shop_open:
		_process_token_floaters(delta)
		queue_redraw()
		return

	# ── Wave spawning ──
	if wave_active:
		spawn_timer -= delta
		if spawn_timer <= 0.0 and spawn_remaining > 0:
			_spawn_enemy()
			spawn_remaining -= 1
			spawn_timer = 0.55
		if spawn_remaining == 0 and enemies.is_empty():
			wave_active = false
			gold += 30
			_add_tokens(TOKENS_PER_WAVE)
			_update_hud()

	# ── Enemies advance ──
	for i in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[i]
		if e.segment >= path_points.size() - 1:
			enemies.remove_at(i)
			lives = max(0, lives - 1)
			_update_hud()
			continue
		var target: Vector2 = path_points[e.segment + 1]
		var diff: Vector2 = target - e.pos
		var dist: float = diff.length()
		var step := ENEMY_SPEED * delta
		if step >= dist:
			e.pos = target
			e.segment += 1
		else:
			e.pos += diff / dist * step

	# ── Tower targeting & firing ──
	for t in towers:
		t.cooldown -= delta
		if t.cooldown <= 0.0:
			var lv: int = t.level
			var center := Vector2((t.cell.x + 0.5) * CELL, (t.cell.y + 0.5) * CELL)
			var rng := _tower_range(lv)
			var best_seg := -1
			var best: Dictionary = {}
			for e in enemies:
				if e.pos.distance_to(center) <= rng and e.segment > best_seg:
					best_seg = e.segment
					best = e
			if not best.is_empty():
				projectiles.append({"pos": center, "target": best, "life": 1.6, "damage": _tower_damage(lv)})
				t.cooldown = 1.0 / _tower_fire_rate(lv)

	# ── Projectiles ──
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		p.life -= delta
		if p.life <= 0.0 or not enemies.has(p.target):
			projectiles.remove_at(i)
			continue
		var diff: Vector2 = p.target.pos - p.pos
		var d: float = diff.length()
		var step := PROJECTILE_SPEED * delta
		if step >= d:
			p.target.hp -= p.damage
			if p.target.hp <= 0.0:
				enemies.erase(p.target)
				gold += 8
				# Token drop chance
				if randf() < _token_kill_chance():
					_add_tokens(1)
					_spawn_token_floater(p.target.pos)
				_update_hud()
			projectiles.remove_at(i)
		else:
			p.pos += diff / d * step

	_process_token_floaters(delta)
	queue_redraw()

# ══════════════════════════════════════════════════════════
#  ENEMIES & WAVES
# ══════════════════════════════════════════════════════════

func _spawn_enemy() -> void:
	var hp := 28.0 + wave * 12.0
	enemies.append({
		"pos": path_points[0],
		"hp": hp,
		"max_hp": hp,
		"segment": 0,
	})

func _start_wave() -> void:
	if wave_active or lives <= 0:
		return
	wave += 1
	wave_active = true
	spawn_remaining = ENEMIES_PER_WAVE_BASE + wave
	spawn_timer = 0.0
	selected_tower_cell = Vector2i(-1, -1)
	_update_hud()

func _reset() -> void:
	towers.clear()
	enemies.clear()
	projectiles.clear()
	token_floaters.clear()
	gold = _starting_gold()
	lives = 20
	wave = 0
	wave_active = false
	spawn_remaining = 0
	selected_tower_cell = Vector2i(-1, -1)
	shop_open = false
	_update_hud()

# ══════════════════════════════════════════════════════════
#  TOWER ACTIONS
# ══════════════════════════════════════════════════════════

func _try_place_tower(c: Vector2i) -> void:
	if lives <= 0: return
	if c.x < 0 or c.x >= GRID_COLS or c.y < 0 or c.y >= GRID_ROWS: return
	if path_set.has(c): return
	for t in towers:
		if t.cell == c: return
	var cost := _tower_cost()
	if gold < cost: return
	gold -= cost
	towers.append({"cell": c, "cooldown": 0.0, "level": 1})
	selected_tower_cell = c
	_update_hud()

func _select_tower(c: Vector2i) -> void:
	selected_tower_cell = c

func _deselect_tower() -> void:
	selected_tower_cell = Vector2i(-1, -1)

func _get_selected_tower() -> Dictionary:
	if selected_tower_cell == Vector2i(-1, -1):
		return {}
	for t in towers:
		if t.cell == selected_tower_cell:
			return t
	return {}

func _upgrade_tower(tower: Dictionary) -> void:
	if tower.level >= TOWER_MAX_LEVEL: return
	var cost := _upgrade_cost(tower.level)
	if gold < cost: return
	gold -= cost
	tower.level += 1
	tower.cooldown = 0.0
	_update_hud()

func _sell_tower(tower: Dictionary) -> void:
	var val := _sell_value(tower)
	gold += val
	towers.erase(tower)
	if selected_tower_cell == tower.cell:
		_deselect_tower()
	_update_hud()

# ══════════════════════════════════════════════════════════
#  TOKEN SYSTEM
# ══════════════════════════════════════════════════════════

func _add_tokens(n: int) -> void:
	tokens += n
	_save_tokens()

func _spend_tokens(n: int) -> bool:
	if tokens < n: return false
	tokens -= n
	_save_tokens()
	return true

func _spawn_token_floater(pos: Vector2) -> void:
	token_floaters.append({"pos": pos + Vector2(0, -16), "life": 2.0, "text": "+1 token"})

func _process_token_floaters(delta: float) -> void:
	for i in range(token_floaters.size() - 1, -1, -1):
		var f: Dictionary = token_floaters[i]
		f.life -= delta
		f.pos.y -= 30.0 * delta
		if f.life <= 0.0:
			token_floaters.remove_at(i)

func _save_tokens() -> void:
	var f := FileAccess.open("res://token_save.json", FileAccess.WRITE)
	if f:
		var data := {"tokens": tokens, "upgrades": {}}
		for key in perm_upgrades:
			data["upgrades"][key] = perm_upgrades[key]["level"]
		f.store_string(JSON.stringify(data))
		f.close()

func _load_tokens() -> void:
	if not FileAccess.file_exists("res://token_save.json"):
		return
	var f := FileAccess.open("res://token_save.json", FileAccess.READ)
	if not f: return
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) == OK:
		var data = json.get_data()
		if data is Dictionary:
			if data.has("tokens"):
				tokens = data["tokens"]
			if data.has("upgrades") and data["upgrades"] is Dictionary:
				for key in data["upgrades"]:
					if perm_upgrades.has(key):
						perm_upgrades[key]["level"] = data["upgrades"][key]

# ══════════════════════════════════════════════════════════
#  SHOP SYSTEM
# ══════════════════════════════════════════════════════════

func _get_shop_upgrade_cost(key: String) -> int:
	var u: Dictionary = perm_upgrades[key]
	return u["cost_base"] * (1 + u["level"])

func _buy_upgrade(key: String) -> void:
	var u : Dictionary = perm_upgrades[key]
	if u["level"] >= u["max_level"]: return
	var cost := _get_shop_upgrade_cost(key)
	if not _spend_tokens(cost): return
	u["level"] += 1
	_update_hud()

# ══════════════════════════════════════════════════════════
#  INPUT
# ══════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mp := get_global_mouse_position()
		hover_cell = Vector2i(int(floor(mp.x / CELL)), int(floor(mp.y / CELL)))
		if shop_open:
			_shop_mouse_move(mp)

	elif event is InputEventMouseButton and event.pressed:
		var mp := get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if shop_open:
				_shop_click(mp)
			elif selected_tower_cell != Vector2i(-1, -1):
				_handle_info_panel_click(mp)
			else:
				var c := Vector2i(int(floor(mp.x / CELL)), int(floor(mp.y / CELL)))
				# Click on existing tower -> select it
				for t in towers:
					if t.cell == c:
						_select_tower(c)
						return
				# Click on empty cell -> place tower
				_try_place_tower(c)
		elif event.button_index == MOUSE_BUTTON_RIGHT and not shop_open:
			var c := Vector2i(int(floor(mp.x / CELL)), int(floor(mp.y / CELL)))
			for t in towers:
				if t.cell == c:
					_sell_tower(t)
					return
			_deselect_tower()

	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			shop_open = not shop_open
			if shop_open:
				selected_tower_cell = Vector2i(-1, -1)
			_update_hud()
		elif event.keycode == KEY_SPACE and not shop_open:
			_start_wave()
		elif event.keycode == KEY_R and not shop_open:
			_reset()
		elif event.keycode == KEY_ESCAPE:
			if shop_open:
				shop_open = false
				_update_hud()
			elif selected_tower_cell != Vector2i(-1, -1):
				_deselect_tower()

# ── Info panel click handling ──

func _handle_info_panel_click(mp: Vector2) -> void:
	if info_sell_rect.has_point(mp):
		var t := _get_selected_tower()
		if not t.is_empty():
			_sell_tower(t)
		return
	if info_upgrade_rect.has_point(mp):
		var t := _get_selected_tower()
		if not t.is_empty():
			_upgrade_tower(t)
		return
	# Click outside panel -> deselect, or select another tower
	var c := Vector2i(int(floor(mp.x / CELL)), int(floor(mp.y / CELL)))
	for t in towers:
		if t.cell == c:
			_select_tower(c)
			return
	_deselect_tower()

# ── Shop click handling ──

func _shop_mouse_move(mp: Vector2) -> void:
	shop_hover_key = ""
	for sb in shop_buttons:
		if sb.rect.has_point(mp):
			shop_hover_key = sb.key
			return

func _shop_click(mp: Vector2) -> void:
	for sb in shop_buttons:
		if sb.rect.has_point(mp):
			_buy_upgrade(sb.key)
			return

# ══════════════════════════════════════════════════════════
#  HUD
# ══════════════════════════════════════════════════════════

func _update_hud() -> void:
	hud.text = "LIVES  %d     GOLD  %d     WAVE  %d" % [lives, gold, wave]
	token_label.text = "TOKENS  %d  (Tab = Shop)" % tokens
	if shop_open:
		hint.text = "TAB / ESC: close shop.   Earn tokens from waves and kills."
	elif lives <= 0:
		hint.text = "Breached. Press R to restart."
	elif selected_tower_cell != Vector2i(-1, -1):
		hint.text = "Tower selected. Click upgrade/sell, or click elsewhere to deselect."
	elif wave_active:
		hint.text = "Wave in progress."
	else:
		hint.text = "Click empty cell to place tower (%d gold).   SPACE: start wave.   R: restart.   TAB: shop." % _tower_cost()

# ══════════════════════════════════════════════════════════
#  DRAWING
# ══════════════════════════════════════════════════════════

func _draw() -> void:
	var w := GRID_COLS * CELL
	var h := GRID_ROWS * CELL
	var total_w: int = maxi(w, 1024)

	# Background
	draw_rect(Rect2(0, 0, w, h), COLOR_BG, true)

	# Path corridor
	for c in path_set.keys():
		draw_rect(Rect2(c.x * CELL, c.y * CELL, CELL, CELL), COLOR_PATH, true)

	# Grid lines
	for x in range(GRID_COLS + 1):
		draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, h), COLOR_GRID, 1.0)
	for y in range(GRID_ROWS + 1):
		draw_line(Vector2(0, y * CELL), Vector2(w, y * CELL), COLOR_GRID, 1.0)

	# Path centerline
	for i in range(path_points.size() - 1):
		draw_line(path_points[i], path_points[i + 1], Color(1, 1, 1, 0.06), 2.0)

	# Hover preview (not when shop open)
	if not shop_open and hover_cell.x >= 0 and hover_cell.x < GRID_COLS and hover_cell.y >= 0 and hover_cell.y < GRID_ROWS:
		var occupied := false
		for t in towers:
			if t.cell == hover_cell:
				occupied = true
				break
		var blocked := path_set.has(hover_cell) or occupied
		var col := COLOR_HOVER_BAD if blocked else COLOR_HOVER_OK
		draw_rect(Rect2(hover_cell.x * CELL, hover_cell.y * CELL, CELL, CELL), col, false, 2.0)

	# ── Towers ──
	for t in towers:
		_draw_tower(t)

	# ── Enemies ──
	for e in enemies:
		draw_circle(e.pos, 13, COLOR_ENEMY)
		var hp_frac: float = clampf(float(e.hp) / float(e.max_hp), 0.0, 1.0)
		var bw := 28.0
		draw_rect(Rect2(e.pos.x - bw * 0.5, e.pos.y - 22, bw, 4), Color(0, 0, 0, 0.55), true)
		draw_rect(Rect2(e.pos.x - bw * 0.5, e.pos.y - 22, bw * hp_frac, 4), COLOR_HP, true)

	# ── Projectiles ──
	for p in projectiles:
		draw_circle(p.pos, 4, COLOR_PROJECTILE)

	# ── Token floaters ──
	for f in token_floaters:
		draw_string(ThemeDB.fallback_font, f.pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, COLOR_TOKEN)

	# ── Tower info panel ──
	if selected_tower_cell != Vector2i(-1, -1) and not shop_open:
		_draw_tower_info_panel()

	# ── Shop overlay ──
	if shop_open:
		_draw_shop()


func _draw_tower(t: Dictionary) -> void:
	var center := Vector2((t.cell.x + 0.5) * CELL, (t.cell.y + 0.5) * CELL)
	var lv: int = t.level

	# Range circle (brighter if selected)
	var rng := _tower_range(lv)
	var rcol := COLOR_RANGE_SEL if t.cell == selected_tower_cell else COLOR_RANGE
	draw_circle(center, rng, rcol)

	# Body size scales with level
	var s: float = CELL * (0.48 + lv * 0.07)
	var tower_color := COLOR_TOWER
	match lv:
		2: tower_color = COLOR_TOWER_2
		3: tower_color = COLOR_TOWER_3
		4: tower_color = COLOR_TOWER_4

	draw_rect(Rect2(center.x - s * 0.5, center.y - s * 0.5, s, s), tower_color, true)

	# Inner core
	var inner: float = s * 0.45
	draw_rect(Rect2(center.x - inner * 0.5, center.y - inner * 0.5, inner, inner), COLOR_TOWER_CORE, true)

	# Level indicator dots
	var dot_r := 3.0
	var dot_spacing := 8.0
	var dot_start := center + Vector2(-(lv - 1) * dot_spacing * 0.5, -s * 0.5 - 10)
	for i in range(lv):
		draw_circle(dot_start + Vector2(i * dot_spacing, 0), dot_r, COLOR_TOWER_CORE)

	# Selection highlight
	if t.cell == selected_tower_cell:
		draw_rect(Rect2(center.x - s * 0.5 - 3, center.y - s * 0.5 - 3, s + 6, s + 6), COLOR_HOVER_OK, false, 2.0)


func _draw_tower_info_panel() -> void:
	var t := _get_selected_tower()
	if t.is_empty(): return

	var lv: int = t.level
	var center := Vector2((t.cell.x + 0.5) * CELL, (t.cell.y + 0.5) * CELL)

	# Position panel to the right of the tower, clamp to screen
	var pw := 190.0
	var ph := 170.0
	var px := center.x + CELL * 0.7
	var py := center.y - ph * 0.5
	if px + pw > GRID_COLS * CELL:
		px = center.x - pw - CELL * 0.7
	if py < 0: py = 0
	if py + ph > GRID_ROWS * CELL:
		py = GRID_ROWS * CELL - ph

	info_panel_rect = Rect2(px, py, pw, ph)

	# Panel background
	draw_rect(Rect2(px - 2, py - 2, pw + 4, ph + 4), COLOR_PANEL_BORDER, true)
	draw_rect(Rect2(px, py, pw, ph), COLOR_PANEL_BG, true)

	var font := ThemeDB.fallback_font
	var x := px + 10
	var y := py + 8
	var lh := 18.0

	draw_string(font, Vector2(x, y), "TOWER  Lv.%d" % lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_TEXT)
	y += lh + 4

	var dmg := _tower_damage(lv)
	var rng := _tower_range(lv)
	var fr := _tower_fire_rate(lv)

	draw_string(font, Vector2(x, y), "Damage:  %.0f" % dmg, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_GOLD)
	y += lh
	draw_string(font, Vector2(x, y), "Range:  %.0f" % rng, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_TEXT)
	y += lh
	draw_string(font, Vector2(x, y), "Fire Rate:  %.1f/s" % fr, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_TEXT)
	y += lh + 6

	# Upgrade button
	var can_up: bool = lv < TOWER_MAX_LEVEL
	var up_cost: int = _upgrade_cost(lv) if can_up else 0
	var up_text := "Upgrade  (%dg)" % up_cost if can_up else "MAX LEVEL"
	var btn_h := 26.0
	info_upgrade_rect = Rect2(x, y, pw - 20, btn_h)
	var btn_col := COLOR_BUTTON if can_up else Color(0.2, 0.2, 0.25, 1)
	if info_upgrade_rect.has_point(get_global_mouse_position()) and can_up:
		btn_col = COLOR_BUTTON_HOVER
	draw_rect(info_upgrade_rect, btn_col, true)
	draw_string(font, Vector2(x + (pw - 20) * 0.5, y + 5), up_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, COLOR_TEXT if can_up else Color(0.3, 0.3, 0.4))
	y += btn_h + 6

	# Sell button
	var sell_val := _sell_value(t)
	var sell_text := "Sell  (+%dg)" % sell_val
	info_sell_rect = Rect2(x, y, pw - 20, btn_h)
	var sell_col := COLOR_SELL
	if info_sell_rect.has_point(get_global_mouse_position()):
		sell_col = Color("#f07a6a")
	draw_rect(info_sell_rect, sell_col, true)
	draw_string(font, Vector2(x + (pw - 20) * 0.5, y + 5), sell_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color("#ffffff"))


func _draw_shop() -> void:
	var sw := GRID_COLS * CELL
	var sh := GRID_ROWS * CELL

	# Dim overlay
	draw_rect(Rect2(0, 0, sw, sh), Color(0, 0, 0, 0.6), true)

	# Shop panel
	var pw := 540.0
	var ph := 370.0
	var px := (sw - pw) * 0.5
	var py := (sh - ph) * 0.5

	draw_rect(Rect2(px - 3, py - 3, pw + 6, ph + 6), COLOR_PANEL_BORDER, true)
	draw_rect(Rect2(px, py, pw, ph), COLOR_PANEL_BG, true)

	var font := ThemeDB.fallback_font
	var x := px + 20
	var y := py + 14

	draw_string(font, Vector2(x, y), "PERMANENT UPGRADES", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_TEXT)
	y += 8
	draw_string(font, Vector2(px + pw - 20, y), "Tokens: %d" % tokens, HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, COLOR_TOKEN)
	draw_string(font, Vector2(px + pw * 0.5, py + ph - 16), "Click to purchase  |  TAB / ESC to close", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.4, 0.45, 0.55))

	y += 24
	var card_h := 52.0
	var card_spacing := 8.0

	shop_buttons.clear()

	var keys := ["tower_damage", "tower_range", "starting_gold", "tower_discount", "token_gain"]
	for key in keys:
		var u: Dictionary = perm_upgrades[key]
		var is_max: bool = u["level"] >= u["max_level"]
		var cost: int = _get_shop_upgrade_cost(key) if not is_max else 0
		var can_afford: bool = tokens >= cost and not is_max

		var card_rect := Rect2(x, y, pw - 40, card_h)
		shop_buttons.append({"rect": card_rect, "key": key})

		# Card background
		var card_col := COLOR_BUTTON
		if key == shop_hover_key and not is_max and can_afford:
			card_col = COLOR_BUTTON_HOVER
		if is_max:
			card_col = Color(0.18, 0.20, 0.25, 1)
		draw_rect(card_rect, card_col, true)

		# Name + description
		draw_string(font, Vector2(x + 10, y + 10), u["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_TEXT)
		draw_string(font, Vector2(x + 10, y + 28), u["desc"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.55, 0.65))

		# Level dots on the right
		var dot_x := x + pw - 120
		for i in range(u["max_level"]):
			var filled: bool = i < u["level"]
			var dot_col := COLOR_UPGRADE_FILL if filled else Color(0.25, 0.28, 0.35)
			draw_circle(Vector2(dot_x + i * 18, y + 18), 5, dot_col)
		draw_string(font, Vector2(dot_x + u["max_level"] * 18 + 8, y + 12), "%d/%d" % [u["level"], u["max_level"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.6, 0.7))

		# Cost button
		var cost_text := "MAX" if is_max else "%d tokens" % cost
		var cost_col := COLOR_TOKEN if can_afford else Color(0.5, 0.4, 0.6, 1) if not is_max else Color(0.3, 0.3, 0.35)
		draw_string(font, Vector2(dot_x + u["max_level"] * 18 + 8, y + 28), cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cost_col)

		y += card_h + card_spacing
