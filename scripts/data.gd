# ══════════════════════════════════════════════════════════
#  data.gd — All constants for Tower Defense
# ══════════════════════════════════════════════════════════

# ─── Grid ────────────────────────────────────────────────
const GRID_COLS := 16
const GRID_ROWS := 10
const CELL := 64

# ─── HUD layout ──────────────────────────────────────────
const HUD_TOP_HEIGHT := 64.0
const HUD_BOTTOM_HEIGHT := 124.0
const HUD_LEFT := -128.0
const HUD_RIGHT := 1152.0
const HUD_WIDTH := HUD_RIGHT - HUD_LEFT

# ─── Palette ─────────────────────────────────────────────
const COLOR_BG        := Color("#1a1d23")
const COLOR_BG_OUTER  := Color("#11141a")
const COLOR_GRID      := Color("#262a32")
const COLOR_PATH      := Color("#2f3540")
const COLOR_HOVER_OK  := Color("#7a8a9a")
const COLOR_HOVER_BAD := Color("#e85d4a")
const COLOR_TOWER_CORE:= Color("#cfd6df")
const COLOR_RANGE     := Color(0.6, 0.7, 0.8, 0.06)
const COLOR_RANGE_SEL := Color(0.6, 0.7, 0.8, 0.15)
const COLOR_PROJECTILE:= Color("#ffd87a")
const COLOR_HP        := Color("#9adfa0")
const COLOR_TEXT      := Color("#c5cdda")
const COLOR_TEXT_DIM  := Color("#8a97a8")
const COLOR_PANEL_BG  := Color("#1e222a")
const COLOR_PANEL_BG_2:= Color("#252a35")
const COLOR_PANEL_BORDER:= Color("#3a404d")
const COLOR_BUTTON    := Color("#4a5568")
const COLOR_BUTTON_HOVER:= Color("#5a6b82")
const COLOR_GOLD      := Color("#ffd87a")
const COLOR_GOLD_DARK := Color("#c99a3a")
const COLOR_TOKEN     := Color("#b8a0ff")
const COLOR_TOKEN_DARK:= Color("#8a6bd8")
const COLOR_HEART     := Color("#ff6b6b")
const COLOR_HEART_DARK:= Color("#c44a4a")
const COLOR_WAVE      := Color("#6eb5ff")
const COLOR_UPGRADE_FILL:= Color("#6eb5ff")
const COLOR_SELL      := Color("#e85d4a")
const COLOR_CORE      := Color("#ffaf4d")
const COLOR_CORE_DARK := Color("#c9772a")
const COLOR_FROST_TINT:= Color("#9be0ff")

# ─── Tower types ─────────────────────────────────────────
const TOWER_TYPES := {
	"arrow": {
		"name": "Arrow",
		"desc": "Cheap balanced single target",
		"cost": 50,
		"damage": 12.0,
		"range_cells": 3.0,
		"fire_rate": 1.4,
		"color": Color("#9aa8b8"),
		"core_color": Color("#cfd6df"),
		"kind": "single",
		"projectile_speed": 700.0,
		"projectile_color": Color("#ffd87a"),
		"projectile_size": 4.0,
		"shape": "square",
	},
	"cannon": {
		"name": "Cannon",
		"desc": "Heavy splash. Slow fire",
		"cost": 110,
		"damage": 28.0,
		"range_cells": 2.6,
		"fire_rate": 0.55,
		"color": Color("#a87d52"),
		"core_color": Color("#e5c197"),
		"kind": "splash",
		"splash_radius": 60.0,
		"projectile_speed": 520.0,
		"projectile_color": Color("#ff9a5a"),
		"projectile_size": 6.0,
		"shape": "octagon",
	},
	"frost": {
		"name": "Frost",
		"desc": "Slows targets. Light dmg",
		"cost": 80,
		"damage": 6.0,
		"range_cells": 2.8,
		"fire_rate": 1.7,
		"color": Color("#7ab5d8"),
		"core_color": Color("#cfeaf7"),
		"kind": "slow",
		"slow_factor": 0.55,
		"slow_duration": 1.4,
		"projectile_speed": 750.0,
		"projectile_color": Color("#9be0ff"),
		"projectile_size": 4.0,
		"shape": "diamond",
	},
	"sniper": {
		"name": "Sniper",
		"desc": "Massive damage. Huge range",
		"cost": 140,
		"damage": 70.0,
		"range_cells": 6.5,
		"fire_rate": 0.45,
		"color": Color("#a08fb0"),
		"core_color": Color("#e2d6ec"),
		"kind": "single",
		"projectile_speed": 1400.0,
		"projectile_color": Color("#d4b8ff"),
		"projectile_size": 3.0,
		"shape": "triangle",
	},
}
const TOWER_TYPE_KEYS := ["arrow", "cannon", "frost", "sniper"]

# ─── Enemy types ─────────────────────────────────────────
const ENEMY_TYPES := {
	"grunt":   {"name": "Grunt",   "hp_mult": 1.0,  "speed_mult": 1.0,  "color": Color("#e85d4a"), "gold": 8,  "armor": 0.0, "size": 13.0},
	"runner":  {"name": "Runner",  "hp_mult": 0.55, "speed_mult": 1.75, "color": Color("#ffe17a"), "gold": 6,  "armor": 0.0, "size": 11.0},
	"tank":    {"name": "Tank",    "hp_mult": 3.4,  "speed_mult": 0.55, "color": Color("#8a3a3a"), "gold": 22, "armor": 0.0, "size": 18.0},
	"armored": {"name": "Armored", "hp_mult": 1.7,  "speed_mult": 0.85, "color": Color("#9aa8b9"), "gold": 14, "armor": 0.4, "size": 14.0},
	"swarm":   {"name": "Swarm",   "hp_mult": 0.28, "speed_mult": 1.3,  "color": Color("#d8b0ff"), "gold": 3,  "armor": 0.0, "size": 9.0},
}

# ─── Levels ──────────────────────────────────────────────
const LEVELS := [
	{"name": "Lattice Bend", "desc": "Two corners. Classic intro",    "path_cells": [Vector2i(-1,5), Vector2i(5,5), Vector2i(5,2), Vector2i(10,2), Vector2i(10,7), Vector2i(16,7)]},
	{"name": "Serpent",      "desc": "Tight S curve. Long corridors", "path_cells": [Vector2i(-1,1), Vector2i(13,1), Vector2i(13,4), Vector2i(2,4), Vector2i(2,7), Vector2i(16,7)]},
	{"name": "Spiral",       "desc": "Winding switchbacks",           "path_cells": [Vector2i(-1,5), Vector2i(2,5), Vector2i(2,2), Vector2i(8,2), Vector2i(8,7), Vector2i(13,7), Vector2i(13,4), Vector2i(16,4)]},
	{"name": "Crossroads",   "desc": "Wide open. Vertical sweep",     "path_cells": [Vector2i(-1,8), Vector2i(4,8), Vector2i(4,1), Vector2i(11,1), Vector2i(11,8), Vector2i(16,8)]},
]

# ─── Constants ───────────────────────────────────────────
const TOWER_MAX_LEVEL := 4
const UPGRADE_BASE_COST := 45
const SELL_REFUND := 0.6
const ENEMY_BASE_SPEED := 95.0
const ENEMIES_PER_WAVE_BASE := 8
const TOKENS_PER_WAVE := 2
const TOKEN_KILL_CHANCE := 0.08
const PRESTIGE_WAVE_THRESHOLD := 10
const SAVE_PATH := "user://save_data.json"

# ─── Prestige upgrades ───────────────────────────────────
const PRESTIGE_UPGRADES_DEF := {
	"multi_shot":       {"name": "Multi Shot",        "desc": "+1 projectile per volley",            "level": 0, "max_level": 4, "cost_base": 3, "effect": "extra_projectiles"},
	"fortified":        {"name": "Fortified",         "desc": "+2 extra lives per level",             "level": 0, "max_level": 5, "cost_base": 2, "effect": "bonus_lives"},
	"compound_interest": {"name": "Compound Interest","desc": "+12% gold from waves per level",       "level": 0, "max_level": 5, "cost_base": 3, "effect": "wave_gold_bonus"},
	"critical_mass":    {"name": "Critical Mass",     "desc": "12% chance x2.5 damage per level",     "level": 0, "max_level": 4, "cost_base": 4, "effect": "critical_chance"},
	"recycling":        {"name": "Efficient Recycling","desc": "+6% sell refund per level",           "level": 0, "max_level": 4, "cost_base": 2, "effect": "sell_refund_bonus"},
	"quick_enemies":    {"name": "Temporal Rift",     "desc": "Enemies move 6% slower per level",     "level": 0, "max_level": 5, "cost_base": 3, "effect": "enemy_speed_reduction"},
}

# ─── Permanent upgrades (token shop) ─────────────────────
const PERM_UPGRADES_DEF := {
	"tower_damage":   {"name": "Sharper Cores",    "desc": "+10% tower damage",              "level": 0, "max_level": 5, "cost_base": 3, "value_per_level": 0.10},
	"tower_range":    {"name": "Extended Reach",   "desc": "+8% tower range",                "level": 0, "max_level": 5, "cost_base": 3, "value_per_level": 0.08},
	"starting_gold":  {"name": "War Chest",        "desc": "+25 starting gold",              "level": 0, "max_level": 4, "cost_base": 4, "value_per_level": 25},
	"tower_discount": {"name": "Efficient Design", "desc": "Towers cost 8% less",             "level": 0, "max_level": 4, "cost_base": 5, "value_per_level": 0.08},
	"token_gain":     {"name": "Overflow",         "desc": "+5% token drop rate",            "level": 0, "max_level": 3, "cost_base": 6, "value_per_level": 0.05},
}
