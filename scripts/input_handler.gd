# ══════════════════════════════════════════════════════════
#  input_handler.gd — All input for Tower Defense
# ══════════════════════════════════════════════════════════
extends RefCounted

const Data = preload("res://scripts/data.gd")
const Logic = preload("res://scripts/logic.gd")
const Save = preload("res://scripts/save_manager.gd")
const ShopHandler = preload("res://scripts/shop_handler.gd")

const DOUBLE_CLICK_WINDOW := 0.4


# ─── Main dispatcher ─────────────────────────────────────

static func handle_input(node: Node2D, event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_move(node, get_global_mouse_position(node))

	elif event is InputEventMouseButton and event.pressed:
		if node.awaiting_continue_choice:
			return
		var mp := get_global_mouse_position(node)
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(node, mp)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(node, mp)

	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(node, event)


# ─── Mouse move ──────────────────────────────────────────

static func _handle_mouse_move(node: Node2D, mp: Vector2) -> void:
	node.hover_cell = Vector2i(int(floor(mp.x / Data.CELL)), int(floor(mp.y / Data.CELL)))
	_update_active_tower(node, mp)
	if node.shop_open:
		ShopHandler.mouse_move(node, mp)


# ─── Left click ──────────────────────────────────────────

static func _handle_left_click(node: Node2D, mp: Vector2) -> void:
	if node.level_select_open:
		_level_select_click(node, mp)
		return

	# Game over screen
	if node.lives <= 0 and not node.shop_open and not node.level_select_open:
		if _handle_game_over_click(node, mp):
			return

	if node.shop_open:
		ShopHandler.click(node, mp)
		return

	# Tower picker bar
	for key in node.tower_picker_rects:
		if (node.tower_picker_rects[key] as Rect2).has_point(mp):
			node.selected_tower_type = key
			node.active_tower_cell = Vector2i(-1, -1)
			_update_hint(node)
			return

	# Speed dial
	if node.speed_dial_rect.has_point(mp):
		_cycle_speed(node)
		return

	# Auto-wave toggle
	if node.auto_wave_rect.has_point(mp):
		node.auto_waves = not node.auto_waves
		_update_hint(node)
		return

	# Info panel click (absorb, no action)
	if node.active_tower_cell != Vector2i(-1, -1) and node.has_method("_info_panel_has_point") and node._info_panel_has_point(mp):
		return

	var c := Vector2i(int(floor(mp.x / Data.CELL)), int(floor(mp.y / Data.CELL)))

	# Double-click for tower upgrade
	var now := Time.get_ticks_msec() / 1000.0
	if c == node.last_click_cell and (now - node.last_click_time) < DOUBLE_CLICK_WINDOW:
		var t := _get_tower_at(node, c)
		if not t.is_empty():
			_upgrade_tower(node, t)
			node.last_click_cell = Vector2i(-1, -1)
			return

	node.last_click_cell = c
	node.last_click_time = now

	# Single click: select tower or place
	var t := _get_tower_at(node, c)
	if not t.is_empty():
		node.active_tower_cell = c
		_update_hint(node)
		return

	_try_place_tower(node, c)


# ─── Right click ─────────────────────────────────────────

static func _handle_right_click(node: Node2D, mp: Vector2) -> void:
	if node.shop_open or node.level_select_open:
		return
	var c := Vector2i(int(floor(mp.x / Data.CELL)), int(floor(mp.y / Data.CELL)))
	var t := _get_tower_at(node, c)
	if not t.is_empty():
		_sell_tower(node, t)
	else:
		node.active_tower_cell = Vector2i(-1, -1)
		_update_hint(node)


# ─── Game over click ─────────────────────────────────────

static func _handle_game_over_click(node: Node2D, mp: Vector2) -> bool:
	var sw := Data.GRID_COLS * Data.CELL; var sh := Data.GRID_ROWS * Data.CELL
	var pw := 480.0; var ph := 370.0
	var px := (sw - pw) * 0.5; var py := (sh - ph) * 0.5
	var btn_w := 140.0; var btn_h := 42.0; var btn_y := py + ph - 64

	var restart_rect := Rect2(px + pw * 0.5 - btn_w - 12, btn_y, btn_w, btn_h)
	var map_rect := Rect2(px + pw * 0.5 + 12, btn_y, btn_w, btn_h)

	if restart_rect.has_point(mp):
		_reset(node)
		return true
	if map_rect.has_point(mp):
		node.level_select_open = true
		_update_hint(node)
		return true
	return false


# ─── Keyboard ────────────────────────────────────────────

static func _handle_key(node: Node2D, event: InputEventKey) -> void:
	if node.awaiting_continue_choice:
		if event.keycode == KEY_C:
			node.awaiting_continue_choice = false
			Save.load_saved_run(node)
		elif event.keycode == KEY_N:
			node.awaiting_continue_choice = false
			Save.clear_saved_run()
			node.level_select_open = true
			_update_hint(node)
		return

	if node.level_select_open:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var idx: int = event.keycode - KEY_1
			if idx < Data.LEVELS.size():
				_select_level(node, idx)
		return

	if event.keycode >= KEY_1 and event.keycode <= KEY_4 and not node.shop_open:
		var idx: int = event.keycode - KEY_1
		if idx < Data.TOWER_TYPE_KEYS.size():
			node.selected_tower_type = Data.TOWER_TYPE_KEYS[idx]
			node.active_tower_cell = Vector2i(-1, -1)
			_update_hint(node)
		return

	match event.keycode:
		KEY_TAB:
			ShopHandler.toggle(node)
		KEY_SPACE:
			if not node.shop_open:
				_start_wave(node)
		KEY_R:
			if not node.shop_open:
				_reset(node)
		KEY_M:
			if not node.shop_open and ((node.wave == 0 and not node.wave_active) or node.lives <= 0):
				node.level_select_open = true
				_update_hint(node)
		KEY_ESCAPE:
			if node.shop_open:
				ShopHandler.close(node)
			elif node.active_tower_cell != Vector2i(-1, -1):
				node.active_tower_cell = Vector2i(-1, -1)
				_update_hint(node)
		KEY_BRACKETRIGHT:
			if not node.shop_open:
				node.game_speed = min(node.game_speed + 1, 8)
				_update_hint(node)
		KEY_BRACKETLEFT:
			if not node.shop_open:
				node.game_speed = max(node.game_speed - 1, 1)
				_update_hint(node)
		KEY_A:
			if not node.shop_open:
				node.auto_waves = not node.auto_waves
				_update_hint(node)


# ─── Tower hover tracking ────────────────────────────────

static func _update_active_tower(node: Node2D, mp: Vector2) -> void:
	if node.shop_open or node.level_select_open or node.awaiting_continue_choice or node.lives <= 0:
		node.active_tower_cell = Vector2i(-1, -1)
		node.hover_tower_cell = Vector2i(-1, -1)
		return
	var c := Vector2i(int(floor(mp.x / Data.CELL)), int(floor(mp.y / Data.CELL)))
	node.hover_tower_cell = Vector2i(-1, -1)
	for t in node.towers:
		if t.cell == c:
			node.hover_tower_cell = c
			break
	if node.hover_tower_cell != Vector2i(-1, -1):
		node.active_tower_cell = node.hover_tower_cell
		return
	# Keep panel open if mouse is on it
	if node.active_tower_cell != Vector2i(-1, -1):
		# info_panel_rect is set by Drawer, check if mp is inside it
		if node.has_method("_info_panel_has_point") and node._info_panel_has_point(mp):
			return
	node.active_tower_cell = Vector2i(-1, -1)


# ─── Tower actions ───────────────────────────────────────

static func _try_place_tower(node: Node2D, c: Vector2i) -> void:
	if node.lives <= 0: return
	if c.x < 0 or c.x >= Data.GRID_COLS or c.y < 0 or c.y >= Data.GRID_ROWS: return
	if node.path_set.has(c): return
	for t in node.towers:
		if t.cell == c: return
	var cost := Logic.tower_cost(node.selected_tower_type, node.perm_upgrades)
	if node.gold < cost: return
	node.gold -= cost
	node.towers.append({"cell": c, "cooldown": 0.0, "level": 1, "type": node.selected_tower_type})
	node.active_tower_cell = c
	_update_hint(node)

static func _upgrade_tower(node: Node2D, t: Dictionary) -> void:
	if t.level >= Data.TOWER_MAX_LEVEL: return
	var cost := Logic.upgrade_cost(t)
	if node.gold < cost: return
	node.gold -= cost
	t.level += 1
	t.cooldown = 0.0
	_update_hint(node)

static func _sell_tower(node: Node2D, t: Dictionary) -> void:
	var val := Logic.sell_value(t, node.perm_upgrades, node.prestige_upgrades)
	node.gold += val
	node.towers.erase(t)
	if node.active_tower_cell == t.cell:
		node.active_tower_cell = Vector2i(-1, -1)
	_update_hint(node)

static func _get_tower_at(node: Node2D, c: Vector2i) -> Dictionary:
	for t in node.towers:
		if t.cell == c:
			return t
	return {}


# ─── Game flow ───────────────────────────────────────────

static func _start_wave(node: Node2D) -> void:
	if node.wave_active or node.lives <= 0: return
	node.wave += 1
	node.wave_active = true
	node.spawn_remaining = Logic.spawn_count(node.wave)
	node.spawn_timer = 0.0
	node.active_tower_cell = Vector2i(-1, -1)
	Save.save_persistent(node)
	_update_hint(node)

static func _reset(node: Node2D) -> void:
	node.towers.clear()
	node.enemies.clear()
	node.projectiles.clear()
	node.token_floaters.clear()
	node.gold = Logic.starting_gold(node.perm_upgrades)
	node.lives = 20 + Logic.prestige_bonus_lives(node.prestige_upgrades)
	node.wave = 0
	node.wave_active = false
	node.spawn_remaining = 0
	node.active_tower_cell = Vector2i(-1, -1)
	node.shop_open = false
	node.level_select_open = true
	Save.clear_saved_run()
	_update_hint(node)

static func _select_level(node: Node2D, idx: int) -> void:
	node.current_level_index = idx
	_apply_level(node)
	node.level_select_open = false
	node.towers.clear()
	node.enemies.clear()
	node.projectiles.clear()
	node.gold = Logic.starting_gold(node.perm_upgrades)
	node.lives = 20 + Logic.prestige_bonus_lives(node.prestige_upgrades)
	node.wave = 0
	node.wave_active = false
	node.spawn_remaining = 0
	node.active_tower_cell = Vector2i(-1, -1)
	Save.save_persistent(node)
	_update_hint(node)

static func _apply_level(node: Node2D) -> void:
	var lvl: Dictionary = Data.LEVELS[node.current_level_index]
	node.path_cells = lvl.path_cells.duplicate()
	var result := Logic.build_path(node.path_cells)
	node.path_set = result["set"]
	node.path_points = result["points"]


# ─── Level select click ──────────────────────────────────

static func _level_select_click(node: Node2D, mp: Vector2) -> void:
	for i in range(node.level_select_rects.size()):
		if (node.level_select_rects[i] as Rect2).has_point(mp):
			_select_level(node, i)
			return


# ─── Speed ───────────────────────────────────────────────

static func _cycle_speed(node: Node2D) -> void:
	node.game_speed = node.game_speed % 8 + 1
	_update_hint(node)


# ─── Hint ────────────────────────────────────────────────

static func _update_hint(node: Node2D) -> void:
	var C = Data
	if node.level_select_open:
		node.hint_text = "Select a map: click a card or press 1-%d" % C.LEVELS.size()
	elif node.shop_open:
		node.hint_text = "TAB / ESC: close shop    Earn tokens from waves and kills"
	elif node.lives <= 0:
		node.hint_text = "BREACHED.  Press R to restart"
	elif node.active_tower_cell != Vector2i(-1, -1):
		node.hint_text = "Double-click: upgrade  |  Right-click: sell"
	elif node.wave_active:
		node.hint_text = "1/2/3/4: pick tower    A: auto-waves    []: speed (1-8x)    M: change map"
	else:
		node.hint_text = "1/2/3/4: pick tower    SPACE: start wave    A: auto    []: speed    R: restart    TAB: shop"


# ─── Utility ─────────────────────────────────────────────

static func get_global_mouse_position(node: Node2D) -> Vector2:
	return node.get_global_mouse_position()
