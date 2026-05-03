# ══════════════════════════════════════════════════════════
#  shop_handler.gd — Shop + Prestige logic for Tower Defense
# ══════════════════════════════════════════════════════════
extends RefCounted

const Data = preload("res://scripts/data.gd")
const Logic = preload("res://scripts/logic.gd")
const Save = preload("res://scripts/save_manager.gd")


# ─── Toggle / Close ──────────────────────────────────────

static func toggle(node: Node2D) -> void:
	if node.shop_open:
		node.prestige_shop_open = not node.prestige_shop_open
	else:
		node.shop_open = true
		node.prestige_shop_open = false
		node.active_tower_cell = Vector2i(-1, -1)
	_update_hint(node)

static func close(node: Node2D) -> void:
	node.shop_open = false
	_update_hint(node)


# ─── Mouse move ──────────────────────────────────────────

static func mouse_move(node: Node2D, mp: Vector2) -> void:
	node.shop_hover_key = ""
	for sb in node.shop_buttons:
		if sb.rect.has_point(mp):
			node.shop_hover_key = sb.key
			return


# ─── Click ───────────────────────────────────────────────

static func click(node: Node2D, mp: Vector2) -> void:
	if node.shop_tab_token_rect.has_point(mp):
		node.prestige_shop_open = false
		return
	if node.shop_tab_prestige_rect.has_point(mp):
		node.prestige_shop_open = true
		return
	if node.prestige_shop_open and node.shop_prestige_button_rect.has_point(mp) and _can_prestige(node):
		_do_prestige(node)
		return
	for sb in node.shop_buttons:
		if sb.rect.has_point(mp):
			if node.prestige_shop_open:
				_buy_prestige_upgrade(node, sb.key)
			else:
				_buy_upgrade(node, sb.key)
			return


# ─── Token purchases ─────────────────────────────────────

static func _buy_upgrade(node: Node2D, key: String) -> void:
	var u: Dictionary = node.perm_upgrades[key]
	if u["level"] >= u["max_level"]: return
	var cost := Logic.shop_upgrade_cost(key, node.perm_upgrades)
	if node.tokens < cost: return
	node.tokens -= cost
	u["level"] += 1
	Save.save_persistent(node)


# ─── Prestige upgrades ───────────────────────────────────

static func _buy_prestige_upgrade(node: Node2D, key: String) -> void:
	var u: Dictionary = node.prestige_upgrades[key]
	if u["level"] >= u["max_level"]: return
	var cost := Logic.prestige_core_cost(key, node.prestige_upgrades)
	if node.prestige_cores < cost: return
	node.prestige_cores -= cost
	u["level"] += 1
	Save.save_persistent(node)

static func _can_prestige(node: Node2D) -> bool:
	return Logic.can_prestige(node.wave, node.wave_active, node.lives)

static func _do_prestige(node: Node2D) -> void:
	var earned := Logic.prestige_cores_earned(node.wave, node.tokens, node.perm_upgrades)
	node.prestige_cores += earned
	node.token_floaters.append({"pos": Vector2(Data.GRID_COLS * Data.CELL * 0.5, Data.GRID_ROWS * Data.CELL * 0.5 - 40), "life": 4.0, "text": "+%d CORES" % earned, "splash": false})
	for key in node.perm_upgrades:
		node.perm_upgrades[key]["level"] = 0
	node.tokens = 0
	node.towers.clear()
	node.enemies.clear()
	node.projectiles.clear()
	node.gold = Logic.starting_gold(node.perm_upgrades)
	node.lives = 20 + Logic.prestige_bonus_lives(node.prestige_upgrades)
	node.wave = 0
	node.wave_active = false
	node.spawn_remaining = 0
	node.active_tower_cell = Vector2i(-1, -1)
	node.shop_open = false
	node.prestige_shop_open = false
	node.level_select_open = true
	Save.clear_saved_run()
	Save.save_persistent(node)
	_update_hint(node)


# ─── Helpers ─────────────────────────────────────────────

static func _update_hint(node: Node2D) -> void:
	node._update_hint()
