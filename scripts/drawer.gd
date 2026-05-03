class_name Drawer
extends RefCounted

const Data = preload("res://scripts/data.gd")

# All drawing functions. Pass the main node (CanvasItem) + it acts as state holder.

static func draw_all(node: Node2D) -> void:
	var C = Data
	var w: float = C.GRID_COLS * C.CELL
	var h: float = C.GRID_ROWS * C.CELL
	node.draw_rect(Rect2(C.HUD_LEFT, -C.HUD_TOP_HEIGHT - 40, C.HUD_WIDTH, h + C.HUD_TOP_HEIGHT + C.HUD_BOTTOM_HEIGHT + 80), C.COLOR_BG_OUTER, true)
	node.draw_rect(Rect2(0, 0, w, h), C.COLOR_BG, true)
	for c: Vector2i in node.path_set.keys():
		node.draw_rect(Rect2(c.x * C.CELL, c.y * C.CELL, C.CELL, C.CELL), C.COLOR_PATH, true)
	for x: int in range(C.GRID_COLS + 1):
		node.draw_line(Vector2(x * C.CELL, 0), Vector2(x * C.CELL, h), C.COLOR_GRID, 1.0)
	for y: int in range(C.GRID_ROWS + 1):
		node.draw_line(Vector2(0, y * C.CELL), Vector2(w, y * C.CELL), C.COLOR_GRID, 1.0)
	for i: int in range(node.path_points.size() - 1):
		node.draw_line(node.path_points[i], node.path_points[i + 1], Color(1, 1, 1, 0.06), 2.0)

	if not node.shop_open and not node.level_select_open and node.hover_cell.x >= 0 and node.hover_cell.x < C.GRID_COLS and node.hover_cell.y >= 0 and node.hover_cell.y < C.GRID_ROWS:
		var occupied: bool = false
		for t: Dictionary in node.towers:
			if t.cell == node.hover_cell:
				occupied = true
				break
		var blocked: bool = node.path_set.has(node.hover_cell) or occupied
		var col: Color = C.COLOR_HOVER_BAD if blocked else C.COLOR_HOVER_OK
		node.draw_rect(Rect2(node.hover_cell.x * C.CELL, node.hover_cell.y * C.CELL, C.CELL, C.CELL), col, false, 2.0)
		if not blocked and node.selected_tower_type != "":
			var preview_center: Vector2 = Vector2((node.hover_cell.x + 0.5) * C.CELL, (node.hover_cell.y + 0.5) * C.CELL)
			var preview_t: Dictionary = C.TOWER_TYPES[node.selected_tower_type]
			var preview_range: float = preview_t.range_cells * C.CELL
			preview_range *= 1.0 + node.perm_upgrades["tower_range"]["level"] * node.perm_upgrades["tower_range"]["value_per_level"]
			node.draw_circle(preview_center, preview_range, C.COLOR_RANGE)

	for t: Dictionary in node.towers:
		draw_tower(node, t)
	for e: Dictionary in node.enemies:
		draw_enemy(node, e)
	for p: Dictionary in node.projectiles:
		draw_projectile(node, p)
	for f: Dictionary in node.token_floaters:
		if f.get("splash", false):
			var ft: float = clamp(1.0 - (f.life / 0.35), 0.0, 1.0)
			var r: float = f.radius * (0.4 + ft * 0.7)
			var alpha: float = 0.55 * (1.0 - ft)
			var col: Color = f.color
			col.a = alpha
			node.draw_arc(f.pos, r, 0, TAU, 32, col, 3.0, true)
		else:
			draw_outlined_text(node, f.pos, f.text, 16, C.COLOR_TOKEN, HORIZONTAL_ALIGNMENT_CENTER)

	if node.active_tower_cell != Vector2i(-1, -1) and not node.shop_open and not node.level_select_open and node.lives > 0:
		draw_tower_info_panel(node)

	draw_top_hud(node)
	draw_bottom_bar(node)

	if node.shop_open:
		draw_shop(node)
	if node.level_select_open:
		draw_level_select(node)
	if node.awaiting_continue_choice:
		draw_continue_prompt(node)
	if node.lives <= 0 and not node.shop_open and not node.level_select_open and not node.awaiting_continue_choice:
		draw_game_over(node)

# ── Top HUD ──

static func draw_top_hud(node: Node2D) -> void:
	var C = Data
	var bar_y: float = -C.HUD_TOP_HEIGHT
	var bar: Rect2 = Rect2(C.HUD_LEFT, bar_y, C.HUD_WIDTH, C.HUD_TOP_HEIGHT)
	node.draw_rect(bar, C.COLOR_PANEL_BG, true)
	node.draw_rect(Rect2(C.HUD_LEFT, bar_y + C.HUD_TOP_HEIGHT - 2, C.HUD_WIDTH, 2), C.COLOR_PANEL_BORDER, true)

	draw_text(node, Vector2(C.HUD_LEFT + 24, bar_y + 28), "TOWER DEFENSE", 22, C.COLOR_TEXT)
	draw_text(node, Vector2(C.HUD_LEFT + 24, bar_y + 50), "MAP: %s" % C.LEVELS[node.current_level_index].name.to_upper(), 11, C.COLOR_TEXT_DIM)

	var badge_w: float = 130.0
	var gap: float = 14.0
	var badges_total: float = badge_w * 4 + gap * 3
	var bx: float = C.HUD_LEFT + (C.HUD_WIDTH - badges_total) * 0.5 + 60
	var by: float = bar_y + 12

	draw_stat_badge(node, Vector2(bx + (badge_w + gap) * 0, by), badge_w, "LIVES", str(node.lives), C.COLOR_HEART, C.COLOR_HEART_DARK, "heart")
	draw_stat_badge(node, Vector2(bx + (badge_w + gap) * 1, by), badge_w, "GOLD",  str(node.gold),  C.COLOR_GOLD,  C.COLOR_GOLD_DARK,  "coin")
	draw_stat_badge(node, Vector2(bx + (badge_w + gap) * 2, by), badge_w, "WAVE",  str(node.wave),  C.COLOR_WAVE,  C.COLOR_WAVE.darkened(0.35), "wave")
	draw_stat_badge(node, Vector2(bx + (badge_w + gap) * 3, by), badge_w, "TOKENS", str(node.tokens), C.COLOR_TOKEN, C.COLOR_TOKEN_DARK, "gem")

	draw_text(node, Vector2(C.HUD_RIGHT - 24, bar_y + 40), "TAB  >  SHOP", 14, C.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)

	# ── Prestige-ready badge (prominent pulsing banner) ──
	if not node.shop_open and node._can_prestige():
		var pbadge_w: float = 340.0
		var pbadge_h: float = 50.0
		var pbadge_x: float = C.HUD_LEFT + (C.HUD_WIDTH - pbadge_w) * 0.5
		var earned: int = node._prestige_cores_earned()
		var pulse: float = abs(sin(Time.get_ticks_msec() / 1000.0 * 2.0))
		# Outer glow ring
		node.draw_rect(Rect2(pbadge_x - 6, bar_y - 3, pbadge_w + 12, pbadge_h + 10), Color(C.COLOR_CORE.r, C.COLOR_CORE.g, C.COLOR_CORE.b, 0.3 + pulse * 0.25), false, 3.0)
		node.draw_rect(Rect2(pbadge_x - 4, bar_y - 1, pbadge_w + 8, pbadge_h + 6), Color(C.COLOR_CORE.r, C.COLOR_CORE.g, C.COLOR_CORE.b, 0.15), true)
		# Dark inner
		node.draw_rect(Rect2(pbadge_x, bar_y + 2, pbadge_w, pbadge_h), C.COLOR_CORE.darkened(0.55), true)
		# Left star icon
		draw_core(node, Vector2(pbadge_x + 26, bar_y + pbadge_h * 0.5 + 2), 14, C.COLOR_CORE, C.COLOR_CORE_DARK)
		draw_core(node, Vector2(pbadge_x + 26, bar_y + pbadge_h * 0.5 + 2), 9, C.COLOR_CORE.lightened(0.3), C.COLOR_CORE)
		# Right star icon
		draw_core(node, Vector2(pbadge_x + pbadge_w - 26, bar_y + pbadge_h * 0.5 + 2), 14, C.COLOR_CORE, C.COLOR_CORE_DARK)
		draw_core(node, Vector2(pbadge_x + pbadge_w - 26, bar_y + pbadge_h * 0.5 + 2), 9, C.COLOR_CORE.lightened(0.3), C.COLOR_CORE)
		# Main text
		draw_text(node, Vector2(pbadge_x + pbadge_w * 0.5, bar_y + 19), "PRESTIGE READY", 16, C.COLOR_CORE.lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER)
		draw_text(node, Vector2(pbadge_x + pbadge_w * 0.5, bar_y + 42), "+%d CORE%s   >  TAB to prestige shop" % [earned, "S" if earned != 1 else ""], 12, C.COLOR_CORE, HORIZONTAL_ALIGNMENT_CENTER)


static func draw_stat_badge(canvas: CanvasItem, pos: Vector2, width: float, label: String, value: String, fill: Color, dark: Color, icon_kind: String) -> void:
	var C = Data
	var h: float = 40.0
	var rect: Rect2 = Rect2(pos.x, pos.y, width, h)
	draw_rounded_rect(canvas, rect, 8.0, C.COLOR_PANEL_BG_2, true)
	draw_rounded_rect(canvas, rect, 8.0, dark, false, 1.5)
	var icon_size: float = h - 10.0
	draw_icon(canvas, icon_kind, Vector2(pos.x + 6 + icon_size * 0.5, pos.y + h * 0.5), icon_size * 0.5, fill, dark)
	var text_x: float = pos.x + icon_size + 16
	draw_text(canvas, Vector2(text_x, pos.y + 14), label, 10, C.COLOR_TEXT_DIM)
	draw_text(canvas, Vector2(text_x, pos.y + 32), value, 18, fill)

static func draw_icon(canvas: CanvasItem, kind: String, center: Vector2, radius: float, fill: Color, dark: Color) -> void:
	match kind:
		"heart": draw_heart(canvas, center, radius, fill, dark)
		"coin": draw_coin(canvas, center, radius, fill, dark)
		"gem": draw_gem(canvas, center, radius, fill, dark)
		"wave": draw_wave_arrow(canvas, center, radius, fill, dark)
		"core": draw_core(canvas, center, radius, fill, dark)

static func draw_heart(canvas: CanvasItem, center: Vector2, r: float, fill: Color, _dark: Color) -> void:
	var lobe_r: float = r * 0.55
	var left: Vector2 = center + Vector2(-lobe_r * 0.7, -r * 0.15)
	var right: Vector2 = center + Vector2(lobe_r * 0.7, -r * 0.15)
	canvas.draw_circle(left, lobe_r, fill)
	canvas.draw_circle(right, lobe_r, fill)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(center.x - r * 0.95, center.y - r * 0.05),
		Vector2(center.x + r * 0.95, center.y - r * 0.05),
		Vector2(center.x, center.y + r * 0.85),
	]), fill)
	canvas.draw_circle(left + Vector2(-lobe_r * 0.3, -lobe_r * 0.3), lobe_r * 0.25, fill.lightened(0.35))

static func draw_coin(canvas: CanvasItem, center: Vector2, r: float, fill: Color, dark: Color) -> void:
	canvas.draw_circle(center, r, dark)
	canvas.draw_circle(center, r * 0.82, fill)
	var ring_pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(29):
		var a: float = TAU * i / 28.0
		ring_pts.append(center + Vector2(cos(a), sin(a)) * r * 0.62)
	canvas.draw_polyline(ring_pts, dark, 1.5, true)
	var mark_w: float = r * 0.18; var mark_h: float = r * 0.7
	canvas.draw_rect(Rect2(center.x - mark_w * 0.5, center.y - mark_h * 0.5, mark_w, mark_h), dark, true)
	canvas.draw_arc(center, r * 0.82, PI * 1.15, PI * 1.55, 12, fill.lightened(0.4), 2.5, true)

static func draw_gem(canvas: CanvasItem, center: Vector2, r: float, fill: Color, dark: Color) -> void:
	var top: Vector2 = center + Vector2(0, -r); var bot: Vector2 = center + Vector2(0, r)
	var ul: Vector2 = center + Vector2(-r * 0.8, -r * 0.35); var ur: Vector2 = center + Vector2(r * 0.8, -r * 0.35)
	var ll: Vector2 = center + Vector2(-r * 0.55, r * 0.45); var lr: Vector2 = center + Vector2(r * 0.55, r * 0.45)
	canvas.draw_colored_polygon(PackedVector2Array([top, ur, lr, bot, ll, ul]), fill)
	canvas.draw_colored_polygon(PackedVector2Array([top, ul, center]), fill.lightened(0.18))
	canvas.draw_colored_polygon(PackedVector2Array([top, ur, center]), fill.lightened(0.32))
	canvas.draw_colored_polygon(PackedVector2Array([center, lr, bot, ll]), dark)
	canvas.draw_polyline(PackedVector2Array([top, ur, lr, bot, ll, ul, top]), dark.darkened(0.2), 1.5, true)

static func draw_wave_arrow(canvas: CanvasItem, center: Vector2, r: float, fill: Color, _dark: Color) -> void:
	for i: int in range(3):
		var off: float = -r * 0.6 + i * r * 0.55
		var c: Color = Color(fill.r, fill.g, fill.b, 0.4 + i * 0.3)
		var a: Vector2 = center + Vector2(off, -r * 0.6); var b: Vector2 = center + Vector2(off + r * 0.45, 0); var d: Vector2 = center + Vector2(off, r * 0.6)
		canvas.draw_line(a, b, c, 3.0); canvas.draw_line(b, d, c, 3.0)

static func draw_core(canvas: CanvasItem, center: Vector2, r: float, fill: Color, dark: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(6):
		pts.append(center + Vector2(cos(TAU * i / 6.0 - PI / 2.0), sin(TAU * i / 6.0 - PI / 2.0)) * r)
	canvas.draw_colored_polygon(pts, fill)
	var inner: PackedVector2Array = PackedVector2Array()
	for i: int in range(6):
		inner.append(center + Vector2(cos(TAU * i / 6.0 - PI / 2.0), sin(TAU * i / 6.0 - PI / 2.0)) * r * 0.55)
	canvas.draw_colored_polygon(inner, fill.lightened(0.25))
	pts.append(pts[0])
	canvas.draw_polyline(pts, dark, 1.5, true)

# ── Bottom bar ──

static func draw_bottom_bar(node: Node2D) -> void:
	var C = Data
	var bar_y: float = float(C.GRID_ROWS * C.CELL)
	var bar: Rect2 = Rect2(C.HUD_LEFT, bar_y, C.HUD_WIDTH, C.HUD_BOTTOM_HEIGHT)
	node.draw_rect(bar, C.COLOR_PANEL_BG, true)
	node.draw_rect(Rect2(C.HUD_LEFT, bar_y, C.HUD_WIDTH, 2), C.COLOR_PANEL_BORDER, true)

	var card_w: float = 168.0; var card_h: float = 80.0; var gap: float = 12.0
	var total: float = card_w * C.TOWER_TYPE_KEYS.size() + gap * (C.TOWER_TYPE_KEYS.size() - 1)
	var start_x: float = C.HUD_LEFT + (C.HUD_WIDTH - total) * 0.5
	var card_y: float = bar_y + 8
	node.tower_picker_rects.clear()
	var mp: Vector2 = node.get_global_mouse_position()

	for i: int in range(C.TOWER_TYPE_KEYS.size()):
		var key: String = C.TOWER_TYPE_KEYS[i]
		var info: Dictionary = C.TOWER_TYPES[key]
		var rect: Rect2 = Rect2(start_x + i * (card_w + gap), card_y, card_w, card_h)
		node.tower_picker_rects[key] = rect
		var is_selected: bool = key == node.selected_tower_type
		var is_hover: bool = rect.has_point(mp)
		var cost: int = node._tower_cost(key)
		var can_afford: bool = node.gold >= cost
		var bg_col: Color = C.COLOR_PANEL_BG_2
		if is_selected: bg_col = info.color.darkened(0.55)
		elif is_hover: bg_col = C.COLOR_BUTTON_HOVER
		draw_rounded_rect(node, rect, 7, bg_col, true)
		var border_col: Color = info.color if is_selected else C.COLOR_PANEL_BORDER
		draw_rounded_rect(node, rect, 7, border_col, false, 2.0 if is_selected else 1.0)

		draw_tower_glyph(node, Vector2(rect.position.x + 28, rect.position.y + card_h * 0.5), 16, info)
		draw_text(node, Vector2(rect.position.x + card_w - 10, rect.position.y + 16), "%d" % (i + 1), 12, C.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		draw_text(node, Vector2(rect.position.x + 56, rect.position.y + 22), info.name, 14, C.COLOR_TEXT)
		# Truncated description for card
		var desc_text: String = info.desc
		if desc_text.length() > 22:
			desc_text = desc_text.substr(0, 20) + ".."
		draw_text(node, Vector2(rect.position.x + 56, rect.position.y + 40), desc_text, 10, C.COLOR_TEXT_DIM)
		var cost_col: Color = C.COLOR_GOLD if can_afford else Color("#7a6a4a")
		draw_coin(node, Vector2(rect.position.x + 64, rect.position.y + card_h - 14), 7, cost_col, C.COLOR_GOLD_DARK)
		draw_text(node, Vector2(rect.position.x + 76, rect.position.y + card_h - 10), "%d" % cost, 12, cost_col)

	var dial_x: float = C.HUD_RIGHT - 90.0; var dial_y: float = bar_y + 8; var dial_w: float = 66.0
	node.speed_dial_rect = Rect2(dial_x, dial_y, dial_w, 80)
	var dial_hov: bool = node.speed_dial_rect.has_point(mp)
	draw_rounded_rect(node, node.speed_dial_rect, 7, C.COLOR_BUTTON if not dial_hov else C.COLOR_BUTTON_HOVER, true)
	draw_rounded_rect(node, node.speed_dial_rect, 7, C.COLOR_PANEL_BORDER, false, 1.0)
	draw_text(node, Vector2(dial_x + dial_w * 0.5, dial_y + 22), "SPEED", 10, C.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	draw_text(node, Vector2(dial_x + dial_w * 0.5, dial_y + 52), "%dx" % node.game_speed, 20, C.COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	draw_text(node, Vector2(dial_x + dial_w * 0.5, dial_y + 72), "[] click", 9, C.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)

	var auto_x: float = dial_x - 78.0
	node.auto_wave_rect = Rect2(auto_x, dial_y, 66.0, 80)
	var auto_hov: bool = node.auto_wave_rect.has_point(mp)
	var auto_col: Color = C.COLOR_BUTTON if not auto_hov else C.COLOR_BUTTON_HOVER
	if node.auto_waves:
		auto_col = C.COLOR_GOLD.darkened(0.45)
		if auto_hov: auto_col = C.COLOR_GOLD
	draw_rounded_rect(node, node.auto_wave_rect, 7, auto_col, true)
	draw_rounded_rect(node, node.auto_wave_rect, 7, C.COLOR_PANEL_BORDER, false, 1.0)
	draw_text(node, Vector2(auto_x + 33, node.auto_wave_rect.position.y + 22), "AUTO", 10, C.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	draw_text(node, Vector2(auto_x + 33, node.auto_wave_rect.position.y + 52), "ON" if node.auto_waves else "OFF", 20, C.COLOR_GOLD if node.auto_waves else C.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	draw_text(node, Vector2(auto_x + 33, node.auto_wave_rect.position.y + 72), "A key", 9, C.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)

	draw_text(node, Vector2(C.HUD_LEFT + C.HUD_WIDTH * 0.5, bar_y + C.HUD_BOTTOM_HEIGHT - 10), node.hint_text, 13, C.COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)

# ── Tower glyphs ──

static func draw_tower_glyph(canvas: CanvasItem, center: Vector2, size: float, info: Dictionary) -> void:
	var s: float = size; var col: Color = info.color; var core: Color = info.core_color
	match info.shape:
		"square":
			canvas.draw_rect(Rect2(center.x - s, center.y - s, s * 2, s * 2), col, true)
			canvas.draw_rect(Rect2(center.x - s * 0.45, center.y - s * 0.45, s * 0.9, s * 0.9), core, true)
		"octagon":
			var pts: PackedVector2Array = PackedVector2Array()
			for i: int in range(8):
				pts.append(center + Vector2(cos(TAU * i / 8.0 + PI / 8.0), sin(TAU * i / 8.0 + PI / 8.0)) * s)
			canvas.draw_colored_polygon(pts, col)
			canvas.draw_circle(center, s * 0.45, core)
		"diamond":
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -s), center + Vector2(s, 0), center + Vector2(0, s), center + Vector2(-s, 0)
			]), col)
			canvas.draw_circle(center, s * 0.4, core)
		"triangle":
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -s), center + Vector2(s * 0.9, s * 0.7), center + Vector2(-s * 0.9, s * 0.7)
			]), col)
			canvas.draw_circle(center + Vector2(0, s * 0.15), s * 0.35, core)
		_:
			canvas.draw_circle(center, s, col)

# ── Tower drawing ──

static func draw_tower(node: Node2D, t: Dictionary) -> void:
	var C = Data
	var center: Vector2 = Vector2((t.cell.x + 0.5) * C.CELL, (t.cell.y + 0.5) * C.CELL)
	var lv: int = t.level
	var info: Dictionary = C.TOWER_TYPES[t.type]
	var is_hovered: bool = t.cell == node.hover_tower_cell
	if is_hovered:
		node.draw_circle(center, node._tower_range(t), C.COLOR_RANGE_SEL)

	var s: float = C.CELL * (0.42 + lv * 0.06)
	var tc: Color = info.color.lightened(min(lv * 0.06, 0.4))
	var cc: Color = info.core_color
	match info.shape:
		"square":
			node.draw_rect(Rect2(center.x - s * 0.5, center.y - s * 0.5, s, s), tc, true)
			var inner: float = s * 0.45
			node.draw_rect(Rect2(center.x - inner * 0.5, center.y - inner * 0.5, inner, inner), cc, true)
		"octagon":
			var pts: PackedVector2Array = PackedVector2Array()
			for i: int in range(8):
				pts.append(center + Vector2(cos(TAU * i / 8.0 + PI / 8.0), sin(TAU * i / 8.0 + PI / 8.0)) * s * 0.6)
			node.draw_colored_polygon(pts, tc)
			node.draw_circle(center, s * 0.28, cc)
		"diamond":
			node.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -s * 0.6), center + Vector2(s * 0.6, 0), center + Vector2(0, s * 0.6), center + Vector2(-s * 0.6, 0)
			]), tc)
			node.draw_circle(center, s * 0.25, cc)
		"triangle":
			node.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -s * 0.6), center + Vector2(s * 0.55, s * 0.45), center + Vector2(-s * 0.55, s * 0.45)
			]), tc)
			node.draw_circle(center + Vector2(0, s * 0.1), s * 0.22, cc)

	if is_hovered:
		var dot_r: float = 3.0; var dot_spacing: float = 8.0
		var dot_start: Vector2 = center + Vector2(-(lv - 1) * dot_spacing * 0.5, -s * 0.55 - 10)
		for i: int in range(lv):
			node.draw_circle(dot_start + Vector2(i * dot_spacing, 0), dot_r, C.COLOR_TOWER_CORE)
		node.draw_rect(Rect2(center.x - s * 0.5 - 3, center.y - s * 0.5 - 3, s + 6, s + 6), C.COLOR_HOVER_OK, false, 2.0)

# ── Enemy ──

static func draw_enemy(canvas: CanvasItem, e: Dictionary) -> void:
	var C = Data
	var size: float = e.size; var col: Color = e.color
	var now: float = Time.get_ticks_msec() / 1000.0
	if e.slow_until > now:
		canvas.draw_circle(e.pos, size + 3.0, Color(C.COLOR_FROST_TINT.r, C.COLOR_FROST_TINT.g, C.COLOR_FROST_TINT.b, 0.25))
	canvas.draw_circle(e.pos, size, col)
	if e.armor > 0.0:
		canvas.draw_arc(e.pos, size + 1.5, 0, TAU, 24, Color("#cfd6df"), 1.5, true)
	var hp_frac: float = clampf(float(e.hp) / float(e.max_hp), 0.0, 1.0)
	var bw: float = max(28.0, size * 2.2)
	canvas.draw_rect(Rect2(e.pos.x - bw * 0.5, e.pos.y - size - 10, bw, 4), Color(0, 0, 0, 0.55), true)
	canvas.draw_rect(Rect2(e.pos.x - bw * 0.5, e.pos.y - size - 10, bw * hp_frac, 4), C.COLOR_HP, true)

# ── Projectile ──

static func draw_projectile(canvas: CanvasItem, p: Dictionary) -> void:
	var info: Dictionary = Data.TOWER_TYPES[p.type]
	var col: Color = info.projectile_color; var size: float = info.projectile_size
	if info.shape == "diamond":
		canvas.draw_colored_polygon(PackedVector2Array([
			p.pos + Vector2(0, -size), p.pos + Vector2(size, 0), p.pos + Vector2(0, size), p.pos + Vector2(-size, 0)
		]), col)
	else:
		canvas.draw_circle(p.pos, size, col)

# ── Tower info panel (hover - no buttons, fixed text overflow) ──

static func draw_tower_info_panel(node: Node2D) -> void:
	var C = Data
	var t: Dictionary = node._get_active_tower()
	if t.is_empty(): return
	var lv: int = t.level; var info: Dictionary = C.TOWER_TYPES[t.type]
	var center: Vector2 = Vector2((t.cell.x + 0.5) * C.CELL, (t.cell.y + 0.5) * C.CELL)

	var pw: float = 250.0; var ph: float = 200.0
	var px: float = center.x + C.CELL * 0.7; var py: float = center.y - ph * 0.5
	if px + pw > C.GRID_COLS * C.CELL: px = center.x - pw - C.CELL * 0.7
	if py < 0: py = 0
	if py + ph > C.GRID_ROWS * C.CELL: py = C.GRID_ROWS * C.CELL - ph
	node.info_panel_rect = Rect2(px, py, pw, ph)

	draw_rounded_rect(node, Rect2(px - 2, py - 2, pw + 4, ph + 4), 8, C.COLOR_PANEL_BORDER, true)
	draw_rounded_rect(node, Rect2(px, py, pw, ph), 7, C.COLOR_PANEL_BG, true)

	var x: float = px + 12; var y: float = py + 12; var lh: float = 20.0
	draw_tower_glyph(node, Vector2(x + 12, y + 12), 10, info)
	draw_text(node, Vector2(x + 30, y + 16), "%s  Lv.%d" % [info.name, lv], 14, C.COLOR_TEXT)
	y += lh + 6

	var dmg: float = node._tower_damage(t); var rng: float = node._tower_range(t); var fr: float = node._tower_fire_rate(t)
	draw_text(node, Vector2(x, y + 12), "Damage", 11, C.COLOR_TEXT_DIM)
	draw_text(node, Vector2(px + pw - 12, y + 12), "%.0f" % dmg, 12, C.COLOR_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	y += lh
	draw_text(node, Vector2(x, y + 12), "Range", 11, C.COLOR_TEXT_DIM)
	draw_text(node, Vector2(px + pw - 12, y + 12), "%.0f" % rng, 12, C.COLOR_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	y += lh
	draw_text(node, Vector2(x, y + 12), "Fire Rate", 11, C.COLOR_TEXT_DIM)
	draw_text(node, Vector2(px + pw - 12, y + 12), "%.1f/s" % fr, 12, C.COLOR_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	y += lh

	var special_text: String = ""; var sp_col: Color = info.color.lightened(0.2)
	match info.kind:
		"splash": special_text = "Splash %.0f" % info.splash_radius
		"slow": special_text = "Slows %.0f%%" % ((1.0 - info.slow_factor) * 100.0)
		_: special_text = "Single target"
	draw_text(node, Vector2(x, y + 12), "Special", 11, C.COLOR_TEXT_DIM)
	draw_text(node, Vector2(px + pw - 12, y + 12), special_text, 11, sp_col, HORIZONTAL_ALIGNMENT_RIGHT)
	y += lh + 4

	# Action hints - no buttons, just text instructions
	var up_cost: int = node._upgrade_cost(t) if lv < C.TOWER_MAX_LEVEL else 0
	var sell_val: int = node._sell_value(t)
	if lv < C.TOWER_MAX_LEVEL:
		draw_text(node, Vector2(px + pw * 0.5, y + 12), "Double-click: Upgrade %dg" % up_cost, 10, C.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		y += lh
	draw_text(node, Vector2(px + pw * 0.5, y + 12), "Right-click: Sell +%dg" % sell_val, 10, C.COLOR_SELL, HORIZONTAL_ALIGNMENT_CENTER)

# ── Continue prompt ──

static func draw_continue_prompt(node: Node2D) -> void:
	var C = Data
	var sw: float = C.GRID_COLS * C.CELL; var sh: float = C.GRID_ROWS * C.CELL
	node.draw_rect(Rect2(C.HUD_LEFT, -C.HUD_TOP_HEIGHT - 40, C.HUD_WIDTH, sh + C.HUD_TOP_HEIGHT + C.HUD_BOTTOM_HEIGHT + 80), Color(0, 0, 0, 0.7), true)
	var pw: float = 460.0; var ph: float = 180.0; var px: float = (sw - pw) * 0.5; var py: float = (sh - ph) * 0.5
	draw_rounded_rect(node, Rect2(px - 3, py - 3, pw + 6, ph + 6), 10, C.COLOR_PANEL_BORDER, true)
	draw_rounded_rect(node, Rect2(px, py, pw, ph), 9, C.COLOR_PANEL_BG, true)
	draw_text(node, Vector2(px + pw * 0.5, py + 50), "SAVED RUN FOUND", 22, C.COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	draw_text(node, Vector2(px + pw * 0.5, py + 90), "C > Continue", 16, C.COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	draw_text(node, Vector2(px + pw * 0.5, py + 120), "N > New Game", 16, C.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)

# ── Level select ──

static func draw_level_select(node: Node2D) -> void:
	var C = Data
	var sw: float = C.GRID_COLS * C.CELL; var sh: float = C.GRID_ROWS * C.CELL
	node.draw_rect(Rect2(C.HUD_LEFT, -C.HUD_TOP_HEIGHT - 40, C.HUD_WIDTH, sh + C.HUD_TOP_HEIGHT + C.HUD_BOTTOM_HEIGHT + 80), Color(0, 0, 0, 0.75), true)
	var pw: float = 880.0; var ph: float = 540.0; var px: float = (sw - pw) * 0.5; var py: float = (sh - ph) * 0.5
	draw_rounded_rect(node, Rect2(px - 3, py - 3, pw + 6, ph + 6), 10, C.COLOR_PANEL_BORDER, true)
	draw_rounded_rect(node, Rect2(px, py, pw, ph), 9, C.COLOR_PANEL_BG, true)
	draw_text(node, Vector2(px + pw * 0.5, py + 38), "SELECT MAP", 24, C.COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	draw_text(node, Vector2(px + pw * 0.5, py + 60), "Click a card or press 1-%d" % C.LEVELS.size(), 12, C.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)

	var card_w: float = (pw - 60) / 2.0; var card_h: float = 200.0; var col_gap: float = 16.0; var row_gap: float = 14.0
	var grid_x: float = px + 20; var grid_y: float = py + 80
	node.level_select_rects.clear()
	var mp: Vector2 = node.get_global_mouse_position()

	for i: int in range(C.LEVELS.size()):
		var col_i: int = i % 2; var row_i: int = i / 2
		var rx: float = grid_x + col_i * (card_w + col_gap); var ry: float = grid_y + row_i * (card_h + row_gap)
		var rect: Rect2 = Rect2(rx, ry, card_w, card_h)
		node.level_select_rects.append(rect)
		var hov: bool = rect.has_point(mp); var sel: bool = i == node.current_level_index
		var bg: Color = C.COLOR_PANEL_BG_2
		if sel: bg = C.COLOR_BUTTON
		elif hov: bg = C.COLOR_BUTTON_HOVER
		draw_rounded_rect(node, rect, 8, bg, true)
		draw_rounded_rect(node, rect, 8, C.COLOR_GOLD if sel else C.COLOR_PANEL_BORDER, false, 2.0 if sel else 1.0)

		var thumb_pad: float = 14.0; var thumb_x: float = rx + thumb_pad; var thumb_y: float = ry + 36
		var thumb_w: float = card_w - thumb_pad * 2; var thumb_h: float = card_h - 60.0
		var lvl: Dictionary = C.LEVELS[i]
		draw_level_preview(node, Rect2(thumb_x, thumb_y, thumb_w, thumb_h), lvl)
		draw_text(node, Vector2(rx + 16, ry + 22), "%d. %s" % [i + 1, lvl.name], 16, C.COLOR_TEXT)
		draw_text(node, Vector2(rx + card_w - 16, ry + 22), lvl.desc, 11, C.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)

static func draw_level_preview(canvas: CanvasItem, rect: Rect2, lvl: Dictionary) -> void:
	var C = Data
	canvas.draw_rect(rect, C.COLOR_BG, true)
	var sx: float = rect.size.x / float(C.GRID_COLS); var sy: float = rect.size.y / float(C.GRID_ROWS)
	var cells: Array = lvl.path_cells
	var preview_set: Dictionary = {}
	for i: int in range(cells.size() - 1):
		var a: Vector2i = cells[i]; var b: Vector2i = cells[i + 1]
		var step: Vector2i = Vector2i(sign(b.x - a.x), sign(b.y - a.y))
		var c: Vector2i = a
		while c != b:
			if c.x >= 0 and c.x < C.GRID_COLS and c.y >= 0 and c.y < C.GRID_ROWS: preview_set[c] = true
			c += step
		if c.x >= 0 and c.x < C.GRID_COLS and c.y >= 0 and c.y < C.GRID_ROWS: preview_set[c] = true
	for cell: Vector2i in preview_set.keys():
		canvas.draw_rect(Rect2(rect.position.x + cell.x * sx, rect.position.y + cell.y * sy, sx, sy), C.COLOR_PATH, true)
	for i: int in range(cells.size() - 1):
		var p1: Vector2i = cells[i]; var p2: Vector2i = cells[i + 1]
		canvas.draw_line(rect.position + Vector2((p1.x + 0.5) * sx, (p1.y + 0.5) * sy), rect.position + Vector2((p2.x + 0.5) * sx, (p2.y + 0.5) * sy), Color(1, 1, 1, 0.18), 1.5)
	canvas.draw_rect(rect, C.COLOR_PANEL_BORDER, false, 1.0)

# ── Shop ──

static func draw_shop(node: Node2D) -> void:
	var C = Data
	var sw: float = C.GRID_COLS * C.CELL; var sh: float = C.GRID_ROWS * C.CELL
	node.draw_rect(Rect2(C.HUD_LEFT, -C.HUD_TOP_HEIGHT - 40, C.HUD_WIDTH, sh + C.HUD_TOP_HEIGHT + C.HUD_BOTTOM_HEIGHT + 80), Color(0, 0, 0, 0.65), true)
	var pw: float = 640.0; var ph: float = 600.0; var px: float = (sw - pw) * 0.5; var py: float = (sh - ph) * 0.5
	draw_rounded_rect(node, Rect2(px - 3, py - 3, pw + 6, ph + 6), 10, C.COLOR_PANEL_BORDER, true)
	draw_rounded_rect(node, Rect2(px, py, pw, ph), 9, C.COLOR_PANEL_BG, true)

	var x: float = px + 24; var y: float = py + 18
	var tab_w: float = 170.0; var tab_h: float = 34.0; var tab_gap: float = 8.0
	node.shop_tab_token_rect = Rect2(x, y, tab_w, tab_h)
	node.shop_tab_prestige_rect = Rect2(x + tab_w + tab_gap, y, tab_w, tab_h)

	var token_tab_col: Color = C.COLOR_PANEL_BG_2 if node.prestige_shop_open else C.COLOR_BUTTON_HOVER
	var prestige_tab_col: Color = C.COLOR_BUTTON_HOVER if node.prestige_shop_open else C.COLOR_PANEL_BG_2
	draw_rounded_rect(node, node.shop_tab_token_rect, 6, token_tab_col, true)
	draw_rounded_rect(node, node.shop_tab_prestige_rect, 6, prestige_tab_col, true)

	draw_gem(node, Vector2(x + 16, y + tab_h * 0.5), 9, C.COLOR_TOKEN, C.COLOR_TOKEN_DARK)
	draw_text(node, Vector2(x + 32, y + 22), "Token Shop", 14, C.COLOR_TEXT if not node.prestige_shop_open else C.COLOR_TEXT_DIM)

	var pt_x: float = node.shop_tab_prestige_rect.position.x
	draw_core(node, Vector2(pt_x + 16, y + tab_h * 0.5), 9, C.COLOR_CORE, C.COLOR_CORE_DARK)
	draw_text(node, Vector2(pt_x + 32, y + 22), "Prestige Shop", 14, C.COLOR_TEXT if node.prestige_shop_open else C.COLOR_TEXT_DIM)

	var cur_x: float = px + pw - 24
	if node.prestige_shop_open:
		draw_core(node, Vector2(cur_x - 100, y + tab_h * 0.5 - 4), 12, C.COLOR_CORE, C.COLOR_CORE_DARK)
		draw_text(node, Vector2(cur_x, y + 26), "%d" % node.prestige_cores, 22, C.COLOR_CORE, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		draw_gem(node, Vector2(cur_x - 100, y + tab_h * 0.5 - 4), 12, C.COLOR_TOKEN, C.COLOR_TOKEN_DARK)
		draw_text(node, Vector2(cur_x, y + 26), "%d" % node.tokens, 22, C.COLOR_TOKEN, HORIZONTAL_ALIGNMENT_RIGHT)

	y += tab_h + 14
	node.draw_rect(Rect2(px + 18, y - 4, pw - 36, 1), C.COLOR_PANEL_BORDER, true)
	draw_text(node, Vector2(px + pw * 0.5, py + ph - 16), "TAB: switch tabs    ESC: close", 13, Color(0.55, 0.6, 0.7), HORIZONTAL_ALIGNMENT_CENTER)

	node.shop_buttons.clear()
	node.shop_prestige_button_rect = Rect2()

	if node.prestige_shop_open:
		draw_prestige_tab(node, px, py, pw, ph, x, y)
	else:
		draw_token_tab(node, px, py, pw, ph, x, y)

static func draw_token_tab(node: Node2D, px: float, _py: float, pw: float, _ph: float, x: float, y: float) -> void:
	var C = Data
	var card_h: float = 72.0; var card_spacing: float = 10.0
	var keys: Array[String] = ["tower_damage", "tower_range", "starting_gold", "tower_discount", "token_gain"]
	var cy: float = y
	for key: String in keys:
		var u: Dictionary = node.perm_upgrades[key]
		var is_max: bool = u["level"] >= u["max_level"]
		var cost: int = node._get_shop_upgrade_cost(key) if not is_max else 0
		var can_afford: bool = node.tokens >= cost and not is_max
		var card_rect: Rect2 = Rect2(x, cy, pw - 48, card_h)
		node.shop_buttons.append({"rect": card_rect, "key": key})
		var card_col: Color = C.COLOR_BUTTON
		if key == node.shop_hover_key and not is_max and can_afford: card_col = C.COLOR_BUTTON_HOVER
		if is_max: card_col = Color(0.18, 0.20, 0.25, 1)
		draw_rounded_rect(node, card_rect, 6, card_col, true)
		# Shorten names/descs to avoid overflow
		var name_text: String = u["name"]
		if name_text.length() > 20:
			name_text = name_text.substr(0, 18) + ".."
		var desc_text: String = u["desc"]
		if desc_text.length() > 32:
			desc_text = desc_text.substr(0, 30) + ".."
		draw_text(node, Vector2(x + 14, cy + 22), name_text, 14, C.COLOR_TEXT)
		draw_text(node, Vector2(x + 14, cy + 44), desc_text, 11, Color(0.7, 0.75, 0.85))

		var dot_x: float = x + pw - 240
		for i: int in range(u["max_level"]):
			var filled: bool = i < u["level"]
			node.draw_circle(Vector2(dot_x + i * 20, cy + 22), 6, C.COLOR_UPGRADE_FILL if filled else Color(0.25, 0.28, 0.35))
		draw_text(node, Vector2(dot_x + u["max_level"] * 20 + 10, cy + 26), "%d/%d" % [u["level"], u["max_level"]], 12, Color(0.6, 0.7, 0.8))

		if is_max:
			draw_text(node, Vector2(x + pw - 60, cy + 38), "MAX", 14, Color(0.5, 0.55, 0.65), HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			draw_gem(node, Vector2(x + pw - 100, cy + 38), 8, C.COLOR_TOKEN if can_afford else C.COLOR_TOKEN.darkened(0.4), C.COLOR_TOKEN_DARK)
			var cost_col: Color = C.COLOR_TOKEN if can_afford else Color(0.5, 0.4, 0.6, 1)
			draw_text(node, Vector2(x + pw - 60, cy + 42), "%d" % cost, 16, cost_col, HORIZONTAL_ALIGNMENT_RIGHT)
		cy += card_h + card_spacing

static func draw_prestige_tab(node: Node2D, px: float, py: float, pw: float, ph: float, x: float, y: float) -> void:
	var C = Data
	var card_h: float = 58.0; var card_spacing: float = 5.0
	var keys: Array[String] = ["multi_shot", "fortified", "compound_interest", "critical_mass", "recycling", "quick_enemies"]
	var cy: float = y
	for key: String in keys:
		var u: Dictionary = node.prestige_upgrades[key]
		var is_max: bool = u["level"] >= u["max_level"]
		var cost: int = node._prestige_core_cost(key) if not is_max else 0
		var can_afford: bool = node.prestige_cores >= cost and not is_max
		var card_rect: Rect2 = Rect2(x, cy, pw - 48, card_h)
		node.shop_buttons.append({"rect": card_rect, "key": key})
		var card_col: Color = C.COLOR_BUTTON
		if key == node.shop_hover_key and not is_max and can_afford: card_col = C.COLOR_BUTTON_HOVER
		if is_max: card_col = Color(0.18, 0.20, 0.25, 1)
		draw_rounded_rect(node, card_rect, 6, card_col, true)
		var name_text: String = u["name"]
		if name_text.length() > 20:
			name_text = name_text.substr(0, 18) + ".."
		var desc_text: String = u["desc"]
		if desc_text.length() > 35:
			desc_text = desc_text.substr(0, 33) + ".."
		draw_text(node, Vector2(x + 14, cy + 19), name_text, 13, C.COLOR_CORE)
		draw_text(node, Vector2(x + 14, cy + 38), desc_text, 11, Color(0.7, 0.75, 0.85))
		var dot_x: float = x + pw - 240
		for i: int in range(u["max_level"]):
			var filled: bool = i < u["level"]
			node.draw_circle(Vector2(dot_x + i * 18, cy + 20), 5, C.COLOR_CORE if filled else Color(0.25, 0.28, 0.35))
		draw_text(node, Vector2(dot_x + u["max_level"] * 18 + 10, cy + 24), "%d/%d" % [u["level"], u["max_level"]], 12, Color(0.6, 0.7, 0.8))
		if is_max:
			draw_text(node, Vector2(x + pw - 60, cy + 32), "MAX", 14, Color(0.5, 0.55, 0.65), HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			draw_core(node, Vector2(x + pw - 100, cy + 32), 8, C.COLOR_CORE if can_afford else C.COLOR_CORE.darkened(0.4), C.COLOR_CORE_DARK)
			var cost_col: Color = C.COLOR_CORE if can_afford else Color(0.55, 0.4, 0.25, 1)
			draw_text(node, Vector2(x + pw - 60, cy + 36), "%d" % cost, 16, cost_col, HORIZONTAL_ALIGNMENT_RIGHT)
		cy += card_h + card_spacing

	var btn_w: float = pw - 48; var btn_h: float = 42.0; var btn_y: float = py + ph - btn_h - 36
	node.shop_prestige_button_rect = Rect2(x, btn_y, btn_w, btn_h)
	var can_prst: bool = node._can_prestige()
	var btn_label: String; var btn_col: Color
	if can_prst:
		btn_label = "PRESTIGE  >  +%d cores  (resets tokens & upgrades)" % node._prestige_cores_earned()
		btn_col = C.COLOR_CORE.darkened(0.15)
		if node.shop_prestige_button_rect.has_point(node.get_global_mouse_position()): btn_col = C.COLOR_CORE
	else:
		btn_label = "Reach wave %d to prestige" % C.PRESTIGE_WAVE_THRESHOLD
		btn_col = Color(0.22, 0.22, 0.27, 1)
	draw_rounded_rect(node, node.shop_prestige_button_rect, 7, btn_col, true)
	var label_col: Color = Color("#1a1208") if can_prst else Color(0.5, 0.5, 0.55)
	draw_text(node, Vector2(x + btn_w * 0.5, btn_y + 27), btn_label, 13, label_col, HORIZONTAL_ALIGNMENT_CENTER)

# ── Game over ──

static func draw_game_over(node: Node2D) -> void:
	var C = Data
	var sw: float = C.GRID_COLS * C.CELL; var sh: float = C.GRID_ROWS * C.CELL
	node.draw_rect(Rect2(C.HUD_LEFT, -C.HUD_TOP_HEIGHT - 40, C.HUD_WIDTH, sh + C.HUD_TOP_HEIGHT + C.HUD_BOTTOM_HEIGHT + 80), Color(0, 0, 0, 0.72), true)
	var pw: float = 480.0; var ph: float = 370.0; var px: float = (sw - pw) * 0.5; var py: float = (sh - ph) * 0.5
	draw_rounded_rect(node, Rect2(px - 3, py - 3, pw + 6, ph + 6), 12, C.COLOR_PANEL_BORDER, true)
	draw_rounded_rect(node, Rect2(px, py, pw, ph), 10, C.COLOR_PANEL_BG, true)

	draw_text(node, Vector2(px + pw * 0.5, py + 50), "BREACHED", 32, C.COLOR_HEART, HORIZONTAL_ALIGNMENT_CENTER)
	draw_text(node, Vector2(px + pw * 0.5, py + 80), "The path was overrun", 14, C.COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	node.draw_rect(Rect2(px + 40, py + 105, pw - 80, 1), C.COLOR_PANEL_BORDER, true)

	var stat_y: float = py + 130
	_draw_stat_row(node, px, stat_y, pw, "Wave Reached", str(node.wave), C.COLOR_WAVE); stat_y += 40
	_draw_stat_row(node, px, stat_y, pw, "Gold Held", str(node.gold), C.COLOR_GOLD); stat_y += 40
	_draw_stat_row(node, px, stat_y, pw, "Tokens", str(node.tokens), C.COLOR_TOKEN); stat_y += 40
	_draw_stat_row(node, px, stat_y, pw, "Towers Placed", str(node.towers.size()), C.COLOR_TOWER_CORE)
	node.draw_rect(Rect2(px + 40, stat_y + 22, pw - 80, 1), C.COLOR_PANEL_BORDER, true)

	var btn_w: float = 140.0; var btn_h: float = 42.0; var btn_y: float = py + ph - 64
	var mp: Vector2 = node.get_global_mouse_position()
	var restart_rect: Rect2 = Rect2(px + pw * 0.5 - btn_w - 12, btn_y, btn_w, btn_h)
	var r_hov: bool = restart_rect.has_point(mp)
	draw_rounded_rect(node, restart_rect, 6, C.COLOR_HEART.darkened(0.1) if r_hov else C.COLOR_HEART.darkened(0.3), true)
	draw_text(node, Vector2(restart_rect.position.x + btn_w * 0.5, restart_rect.position.y + 28), "R  Restart", 15, Color("#ffffff"), HORIZONTAL_ALIGNMENT_CENTER)

	var map_rect: Rect2 = Rect2(px + pw * 0.5 + 12, btn_y, btn_w, btn_h)
	var m_hov: bool = map_rect.has_point(mp)
	draw_rounded_rect(node, map_rect, 6, C.COLOR_BUTTON_HOVER if m_hov else C.COLOR_BUTTON, true)
	draw_text(node, Vector2(map_rect.position.x + btn_w * 0.5, map_rect.position.y + 28), "M  Maps", 15, C.COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)

static func _draw_stat_row(canvas: CanvasItem, px: float, y: float, pw: float, label: String, value: String, color: Color) -> void:
	draw_text(canvas, Vector2(px + 50, y + 18), label, 14, Data.COLOR_TEXT_DIM)
	draw_text(canvas, Vector2(px + pw - 50, y + 18), value, 18, color, HORIZONTAL_ALIGNMENT_RIGHT)

# ── Generic helpers ──

static func draw_text(canvas: CanvasItem, pos: Vector2, text: String, size: int, color: Color, halign: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	canvas.draw_string(ThemeDB.fallback_font, pos, text, halign, -1, size, color)

static func draw_outlined_text(canvas: CanvasItem, pos: Vector2, text: String, size: int, color: Color, halign: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font: Font = ThemeDB.fallback_font
	for dx: int in [-1, 1]:
		for dy: int in [-1, 1]:
			canvas.draw_string(font, pos + Vector2(dx, dy), text, halign, -1, size, Color(0, 0, 0, 0.85))
	canvas.draw_string(font, pos, text, halign, -1, size, color)

static func draw_rounded_rect(canvas: CanvasItem, rect: Rect2, radius: float, color: Color, filled: bool, line_width: float = 1.0) -> void:
	if filled:
		var rp: Vector2 = rect.position; var rs: Vector2 = rect.size
		canvas.draw_rect(Rect2(rp.x + radius, rp.y, rs.x - radius * 2, rs.y), color, true)
		canvas.draw_rect(Rect2(rp.x, rp.y + radius, rs.x, rs.y - radius * 2), color, true)
		canvas.draw_circle(rp + Vector2(radius, radius), radius, color)
		canvas.draw_circle(rp + Vector2(rs.x - radius, radius), radius, color)
		canvas.draw_circle(rp + Vector2(radius, rs.y - radius), radius, color)
		canvas.draw_circle(rp + Vector2(rs.x - radius, rs.y - radius), radius, color)
	else:
		var pts: PackedVector2Array = PackedVector2Array(); var seg: int = 6; var rp: Vector2 = rect.position; var rad: float = radius
		for i: int in range(seg + 1):
			var a: float = PI + i * PI * 0.5 / seg
			pts.append(rp + Vector2(rad, rad) + Vector2(cos(a), sin(a)) * rad)
		for i: int in range(seg + 1):
			var a: float = PI * 1.5 + i * PI * 0.5 / seg
			pts.append(rp + Vector2(rect.size.x - rad, rad) + Vector2(cos(a), sin(a)) * rad)
		for i: int in range(seg + 1):
			var a: float = i * PI * 0.5 / seg
			pts.append(rp + Vector2(rect.size.x - rad, rect.size.y - rad) + Vector2(cos(a), sin(a)) * rad)
		for i: int in range(seg + 1):
			var a: float = PI * 0.5 + i * PI * 0.5 / seg
			pts.append(rp + Vector2(rad, rect.size.y - rad) + Vector2(cos(a), sin(a)) * rad)
		pts.append(pts[0])
		canvas.draw_polyline(pts, color, line_width, true)
