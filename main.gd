# ══════════════════════════════════════════════════════════
#  main.gd — TOWER DEFENSE — state holder + lifecycle
# ══════════════════════════════════════════════════════════
extends Node2D

const Data = preload("res://scripts/data.gd")
const Logic = preload("res://scripts/logic.gd")
const Drawer = preload("res://scripts/drawer.gd")
const Save = preload("res://scripts/save_manager.gd")
const InputHandler = preload("res://scripts/input_handler.gd")
const ShopHandler = preload("res://scripts/shop_handler.gd")

# ─── Grid & Level ────────────────────────────────────────
var current_level_index := 0
var path_cells := []
var path_set := {}
var path_points := []

# ─── Game state ──────────────────────────────────────────
var towers := []
var enemies := []
var projectiles := []
var gold := 150
var lives := 20
var wave := 0
var wave_active := false
var spawn_timer := 0.0
var spawn_remaining := 0
var hover_cell := Vector2i(-1, -1)
var selected_tower_cell := Vector2i(-1, -1)
var hover_tower_cell := Vector2i(-1, -1)
var active_tower_cell := Vector2i(-1, -1)
var selected_tower_type := "arrow"
var hint_text := ""
var awaiting_continue_choice := false
var level_select_open := false

# ─── Double-click tracking ───────────────────────────────
var last_click_cell := Vector2i(-1, -1)
var last_click_time := 0.0

# ─── Speed & auto-waves ──────────────────────────────────
var game_speed := 1
var auto_waves := false
var auto_wave_delay := 0.0
var speed_dial_rect := Rect2()
var auto_wave_rect := Rect2()

# ─── Token economy ───────────────────────────────────────
var tokens := 0
var token_floaters := []

# ─── Prestige ────────────────────────────────────────────
var prestige_cores := 0
var prestige_shop_open := false
var prestige_upgrades := {
	"multi_shot":       {"name":"Multi Shot",        "desc":"+1 projectile per volley",  "level":0,"max_level":4,"cost_base":3,"effect":"extra_projectiles"},
	"fortified":        {"name":"Fortified",          "desc":"+2 extra lives",              "level":0,"max_level":5,"cost_base":2,"effect":"bonus_lives"},
	"compound_interest":{"name":"Compound Interest",   "desc":"+12% gold from waves",        "level":0,"max_level":5,"cost_base":3,"effect":"wave_gold_bonus"},
	"critical_mass":    {"name":"Critical Mass",      "desc":"12% chance x2.5 damage",         "level":0,"max_level":4,"cost_base":4,"effect":"critical_chance"},
	"recycling":        {"name":"Efficient Recycling",  "desc":"+6% sell refund",            "level":0,"max_level":4,"cost_base":2,"effect":"sell_refund_bonus"},
	"quick_enemies":    {"name":"Temporal Rift",       "desc":"Enemies 6% slower",                 "level":0,"max_level":5,"cost_base":3,"effect":"enemy_speed_reduction"},
}

# ─── Permanent upgrades ──────────────────────────────────
var perm_upgrades := {
	"tower_damage":   {"name":"Sharper Cores",    "desc":"+10% tower damage",        "level":0,"max_level":5,"cost_base":3,"value_per_level":0.10},
	"tower_range":    {"name":"Extended Reach",   "desc":"+8% tower range",          "level":0,"max_level":5,"cost_base":3,"value_per_level":0.08},
	"starting_gold":  {"name":"War Chest",        "desc":"+25 starting gold",      "level":0,"max_level":4,"cost_base":4,"value_per_level":25},
	"tower_discount": {"name":"Efficient Design",  "desc":"Towers cost 8% less",       "level":0,"max_level":4,"cost_base":5,"value_per_level":0.08},
	"token_gain":     {"name":"Overflow",          "desc":"+5% token drop rate",          "level":0,"max_level":3,"cost_base":6,"value_per_level":0.05},
}

# ─── Shop state ──────────────────────────────────────────
var shop_open := false
var shop_buttons := []
var shop_hover_key := ""

# ─── UI hit rects ────────────────────────────────────────
var info_panel_rect := Rect2()
var shop_tab_token_rect := Rect2()
var shop_tab_prestige_rect := Rect2()
var shop_prestige_button_rect := Rect2()
var tower_picker_rects := {}
var level_select_rects := []


# ══════════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════════

func _ready() -> void:
	$Camera2D.position = Vector2(Data.GRID_COLS * Data.CELL * 0.5, Data.GRID_ROWS * Data.CELL * 0.5)
	_apply_level()
	Save.load_persistent(self)
	if Save.has_saved_run():
		awaiting_continue_choice = true
		hint_text = "Saved game found.  Press C to Continue or N for New Game"
	else:
		level_select_open = true
		_update_hint()


func _process(delta: float) -> void:
	Engine.time_scale = float(game_speed)

	if awaiting_continue_choice or level_select_open:
		queue_redraw()
		return

	if shop_open:
		Logic.process_token_floaters(token_floaters, delta)
		queue_redraw()
		return

	if wave_active:
		spawn_timer -= delta
		if spawn_timer <= 0.0 and spawn_remaining > 0:
			_spawn_enemy()
			spawn_remaining -= 1
			spawn_timer = 0.55
		if spawn_remaining == 0 and enemies.is_empty():
			wave_active = false
			gold += int(30 * Logic.prestige_wave_gold_mult(prestige_upgrades))
			_add_tokens(Data.TOKENS_PER_WAVE)
			Save.save_persistent(self)
			_update_hint()
			if auto_waves and lives > 0:
				auto_wave_delay = 0.6

	if auto_wave_delay > 0.0:
		auto_wave_delay -= delta
		if auto_wave_delay <= 0.0:
			InputHandler._start_wave(self)

	var lives_lost := Logic.move_enemies(enemies, path_points, delta, prestige_upgrades)
	lives = max(0, lives - lives_lost)
	if lives_lost > 0:
		_update_hint()

	Logic.process_towers(towers, enemies, projectiles, token_floaters, delta, perm_upgrades, prestige_upgrades)

	var gold_ref := [gold]
	Logic.process_projectiles(projectiles, enemies, token_floaters, gold_ref, delta, perm_upgrades, prestige_upgrades)
	gold = gold_ref[0]

	Logic.process_token_floaters(token_floaters, delta)
	queue_redraw()


func _draw() -> void:
	Drawer.draw_all(self)


# ══════════════════════════════════════════════════════════
#  INPUT — delegates to InputHandler
# ══════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	InputHandler.handle_input(self, event)


# ══════════════════════════════════════════════════════════
#  TOWER STAT WRAPPERS (for Drawer)
# ══════════════════════════════════════════════════════════

func _tower_damage(t: Dictionary) -> float:
	return Logic.tower_damage(t, perm_upgrades)

func _tower_range(t: Dictionary) -> float:
	return Logic.tower_range(t, perm_upgrades)

func _tower_fire_rate(t: Dictionary) -> float:
	return Logic.tower_fire_rate(t)

func _tower_cost(type_key: String) -> int:
	return Logic.tower_cost(type_key, perm_upgrades)

func _upgrade_cost(t: Dictionary) -> int:
	return Logic.upgrade_cost(t)

func _sell_value(t: Dictionary) -> int:
	return Logic.sell_value(t, perm_upgrades, prestige_upgrades)

func _get_active_tower() -> Dictionary:
	if active_tower_cell == Vector2i(-1, -1):
		return {}
	for t in towers:
		if t.cell == active_tower_cell:
			return t
	return {}

func _info_panel_has_point(mp: Vector2) -> bool:
	return info_panel_rect.has_point(mp)


# ══════════════════════════════════════════════════════════
#  ENEMIES
# ══════════════════════════════════════════════════════════

func _spawn_enemy() -> void:
	enemies.append(Logic.spawn_enemy(wave, path_points))


# ══════════════════════════════════════════════════════════
#  TOKEN SYSTEM
# ══════════════════════════════════════════════════════════

func _add_tokens(n: int) -> void:
	tokens += n
	Save.save_persistent(self)


# ══════════════════════════════════════════════════════════
#  PRESTIGE WRAPPERS (for Drawer)
# ══════════════════════════════════════════════════════════

func _can_prestige() -> bool:
	return ShopHandler._can_prestige(self)

func _prestige_cores_earned() -> int:
	return Logic.prestige_cores_earned(wave, tokens, perm_upgrades)

func _prestige_core_cost(key: String) -> int:
	return Logic.prestige_core_cost(key, prestige_upgrades)


# ══════════════════════════════════════════════════════════
#  ECONOMY HELPERS
# ══════════════════════════════════════════════════════════

func _starting_gold() -> int:
	return Logic.starting_gold(perm_upgrades)

func _get_shop_upgrade_cost(key: String) -> int:
	return Logic.shop_upgrade_cost(key, perm_upgrades)


# ══════════════════════════════════════════════════════════
#  LEVEL
# ══════════════════════════════════════════════════════════

func _apply_level() -> void:
	var lvl: Dictionary = Data.LEVELS[current_level_index]
	path_cells = lvl.path_cells.duplicate()
	var result := Logic.build_path(path_cells)
	path_set = result["set"]
	path_points = result["points"]


# ══════════════════════════════════════════════════════════
#  SPEED + HINT
# ══════════════════════════════════════════════════════════

func _update_hint() -> void:
	if level_select_open:
		hint_text = "Select a map: click a card or press 1-%d" % Data.LEVELS.size()
	elif shop_open:
		hint_text = "TAB / ESC: close shop    Earn tokens from waves and kills"
	elif lives <= 0:
		hint_text = "BREACHED.  Press R to restart"
	elif active_tower_cell != Vector2i(-1, -1):
		hint_text = "Double-click: upgrade  |  Right-click: sell"
	elif wave_active:
		hint_text = "1/2/3/4: pick tower    A: auto-waves    []: speed (1-8x)    M: change map"
	else:
		hint_text = "1/2/3/4: pick tower    SPACE: start wave    A: auto    []: speed    R: restart    TAB: shop"
