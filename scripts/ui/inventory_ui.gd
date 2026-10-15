class_name InventoryUI
extends CanvasLayer
## 그리드 배낭 + 상자 내용물 패널.
## 좌클릭: 상자→가져오기 / 배낭 아이템 끌어서 이동(R 회전) · 상자 쪽으로 끌면 되돌려 놓기 · 바깥에 놓으면 버리기
## 우클릭: 먹기·사용 / F: 모두 가져가기

const CELL := 62.0
var raid: Raid
var canvas: Control
var container: LootContainer = null
var drag_index := -1
var drag_rot := false
var drag_grab := Vector2.ZERO
var hover_text := ""
var font: Font
var font_b: Font
var bag_rect := Rect2()
var cont_rect := Rect2()
var take_all_rect := Rect2()
var close_rect := Rect2()

func _ready() -> void:
	layer = 20
	visible = false
	font = UITheme.black()
	font_b = UITheme.bold()
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_ui)
	canvas.gui_input.connect(_on_input)
	add_child(canvas)

func open(c: LootContainer) -> void:
	container = c
	visible = true
	drag_index = -1
	Sfx.play("bag_open", -8.0)
	canvas.queue_redraw()

func close() -> void:
	if not visible:
		return
	visible = false
	container = null
	drag_index = -1
	Sfx.play("bag_close", -10.0)

func _process(_d: float) -> void:
	if visible:
		if container and raid.player.global_position.distance_to(container.global_position) > 120.0:
			container = null
		canvas.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R and drag_index >= 0:
			drag_rot = not drag_rot
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_F and container:
			take_all()
			get_viewport().set_input_as_handled()

# ── 배치 ─────────────────────────────────────────────
func _layout(vs: Vector2) -> void:
	var bag: Backpack = raid.bag
	var bw := bag.w * CELL
	var bh := bag.h * CELL
	var has_c := container != null
	var total_w := bw + (CELL * 4 + 60 if has_c else 0.0)
	var x0 := vs.x * 0.5 - total_w * 0.5
	bag_rect = Rect2(Vector2(x0, vs.y * 0.5 - bh * 0.5 - 20), Vector2(bw, bh))
	if has_c:
		var rows := maxi(4, ceili(container.items.size() / 4.0))
		cont_rect = Rect2(Vector2(bag_rect.end.x + 60, bag_rect.position.y), Vector2(CELL * 4, rows * CELL))
		take_all_rect = Rect2(Vector2(cont_rect.position.x, cont_rect.end.y + 18), Vector2(cont_rect.size.x, 44))
	else:
		cont_rect = Rect2()
		take_all_rect = Rect2()
	close_rect = Rect2(Vector2(vs.x * 0.5 - 90, vs.y - 74), Vector2(180, 44))

func _cell_at(p: Vector2) -> Vector2i:
	var lp := (p - bag_rect.position) / CELL
	return Vector2i(floori(lp.x), floori(lp.y))

func _cont_index_at(p: Vector2) -> int:
	if container == null or not cont_rect.has_point(p):
		return -1
	var lp := (p - cont_rect.position) / CELL
	var i := floori(lp.y) * 4 + floori(lp.x)
	return i if i >= 0 and i < container.items.size() else -1

# ── 입력 ─────────────────────────────────────────────
func _on_input(event: InputEvent) -> void:
	var bag: Backpack = raid.bag
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var p := mb.position
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if close_rect.has_point(p):
				raid.toggle_inventory(false)
				return
			if take_all_rect.has_point(p) and container:
				take_all()
				return
			var ci := _cont_index_at(p)
			if ci >= 0:
				_take(ci)
				return
			if bag_rect.has_point(p):
				var cell := _cell_at(p)
				var idx := bag.index_at_cell(cell.x, cell.y)
				if idx >= 0:
					drag_index = idx
					var e: Dictionary = bag.entries[idx]
					drag_rot = e.rot
					drag_grab = p - (bag_rect.position + Vector2(e.x, e.y) * CELL)
					Sfx.play("pick", -10.0)
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and drag_index >= 0:
			_drop_drag(p)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if bag_rect.has_point(p):
				var cell2 := _cell_at(p)
				var idx2 := bag.index_at_cell(cell2.x, cell2.y)
				if idx2 >= 0:
					var id: String = bag.entries[idx2].id
					if DB.ITEMS[id].cat == "weapon":
						raid.player.equip_from_bag(idx2)
					elif DB.ITEMS[id].has("use"):
						if raid.player.use_item(id):
							raid.notify("%s 사용 중..." % DB.ITEMS[id].name, DB.C_TEXT)
					else:
						raid.notify("우클릭: 먹거나 사용할 수 있는 아이템만 가능", DB.C_MUTED)
			else:
				var ci2 := _cont_index_at(p)
				if ci2 >= 0:
					_take(ci2)

func _drop_drag(p: Vector2) -> void:
	var bag: Backpack = raid.bag
	var idx := drag_index
	drag_index = -1
	if idx < 0 or idx >= bag.entries.size():
		return
	var id: String = bag.entries[idx].id
	if bag_rect.grow(CELL * 0.5).has_point(p):
		var tl := p - drag_grab - bag_rect.position + Vector2(CELL * 0.5, CELL * 0.5)
		var cx := floori(tl.x / CELL)
		var cy := floori(tl.y / CELL)
		if bag.move(idx, cx, cy, drag_rot):
			Sfx.play("place", -8.0)
		else:
			Sfx.play("deny", -8.0)
		return
	if container and cont_rect.grow(20).has_point(p):
		bag.remove_at(idx)
		container.items.append(id)
		container.queue_redraw()
		Sfx.play("place", -8.0)
		return
	# 바깥: 바닥에 버리기
	bag.remove_at(idx)
	raid.drop_item_on_ground(id)
	raid.notify("%s 버림" % DB.ITEMS[id].name, DB.C_MUTED)

func _take(ci: int) -> bool:
	var id: String = container.items[ci]
	var it: Dictionary = DB.ITEMS[id]
	if it.cat == "ammo":
		container.take(ci)
		raid.player.add_ammo(it.ammo, int(it.amount))
		raid.notify("%s +%d" % [it.name, int(it.amount)], DB.C_LEGEND)
		Sfx.play("ammo", -6.0)
		return true
	if raid.bag.try_add(id):
		container.take(ci)
		raid.on_loot_taken(id)
		return true
	raid.notify("배낭이 가득 찼다! 덜 비싼 걸 상자에 두고 오자", DB.C_DANGER)
	Sfx.play("deny", -6.0)
	return false

func take_all() -> void:
	if container == null:
		return
	# 가치 높은 것부터
	var order := []
	for i in container.items.size():
		order.append(i)
	order.sort_custom(func(a, b): return int(DB.ITEMS[container.items[a]].v) > int(DB.ITEMS[container.items[b]].v))
	var ids := []
	for i in order:
		ids.append(container.items[i])
	var full := false
	for id in ids:
		var ci: int = container.items.find(id)
		if ci < 0:
			continue
		var it: Dictionary = DB.ITEMS[id]
		if it.cat != "ammo" and raid.bag.find_spot(id).is_empty():
			full = true
			continue
		_take(ci)
	if full:
		raid.notify("배낭이 가득 차서 일부를 두고 왔다", DB.C_DANGER)

# ── 그리기 ───────────────────────────────────────────
func _txt(pos: Vector2, s: String, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1, f: Font = null) -> void:
	canvas.draw_string(f if f else font_b, pos, s, align, width, size, col)

func _draw_ui() -> void:
	var vs := canvas.size
	_layout(vs)
	var bag: Backpack = raid.bag
	var mouse := canvas.get_local_mouse_position()
	hover_text = ""
	canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.04, 0.05, 0.08, 0.72))
	# 배낭 패널
	var panel := bag_rect.grow(18)
	panel.position.y -= 50
	panel.size.y += 50 + 150
	UITheme.box(Color(DB.C_UI_SOLID, 0.95), 16, Color(1, 1, 1, 0.08), 2).draw(canvas.get_canvas_item(), panel)
	_txt(panel.position + Vector2(18, 38), "배낭", 24, DB.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font)
	_txt(panel.position + Vector2(18, 38), "%d / %d칸 · %s 냥" % [bag.used_cells(), bag.w * bag.h, HUD._fmt(bag.total_value())], 16, DB.C_LEGEND, HORIZONTAL_ALIGNMENT_RIGHT, panel.size.x - 36)
	for y in bag.h:
		for x in bag.w:
			var cr := Rect2(bag_rect.position + Vector2(x, y) * CELL, Vector2(CELL, CELL)).grow(-2)
			var cheek := x < DB.CHEEK_W and y < DB.CHEEK_H
			UITheme.box(Color("#F5A3A8", 0.16) if cheek else Color(1, 1, 1, 0.05), 6, Color("#F5A3A8", 0.7) if cheek else Color(0, 0, 0, 0), 2 if cheek else 0).draw(canvas.get_canvas_item(), cr)
	# 뺨주머니 안내
	_txt(bag_rect.position + Vector2(0, -8), "♥ 뺨주머니 — 여기 넣은 건 쓰러져도 지켜진다", 13, Color("#F5A3A8"))
	# 무게 상태
	var lr := bag.load_ratio()
	if lr > 0.5:
		_txt(bag_rect.position + Vector2(0, -8), "무거움: 이동 -%d%%%s" % [int((lr - 0.5) * 50.0), " · 발소리 커짐" if lr > 0.75 else ""], 13, DB.C_DANGER if lr > 0.75 else DB.C_LEGEND, HORIZONTAL_ALIGNMENT_RIGHT, bag_rect.size.x)
	# 드래그 미리보기 칸
	if drag_index >= 0 and drag_index < bag.entries.size():
		var did: String = bag.entries[drag_index].id
		var tl := mouse - drag_grab - bag_rect.position + Vector2(CELL * 0.5, CELL * 0.5)
		var cx := floori(tl.x / CELL)
		var cy := floori(tl.y / CELL)
		if bag_rect.grow(CELL * 0.5).has_point(mouse):
			var ok := bag.can_place(did, cx, cy, drag_rot, drag_index)
			var s := Backpack.size_of(did, drag_rot)
			canvas.draw_rect(Rect2(bag_rect.position + Vector2(cx, cy) * CELL, Vector2(s) * CELL), Color(0.4, 0.9, 0.5, 0.25) if ok else Color(0.9, 0.3, 0.3, 0.3))
	for i in bag.entries.size():
		if i == drag_index:
			continue
		var e: Dictionary = bag.entries[i]
		var s2 := Backpack.size_of(e.id, e.rot)
		var r := Rect2(bag_rect.position + Vector2(e.x, e.y) * CELL, Vector2(s2) * CELL).grow(-3)
		_item_card(e.id, r, e.rot)
		if r.has_point(mouse) and drag_index < 0:
			hover_text = e.id
	# 휴대 장비 (사망 시 잃음)
	var gy := bag_rect.end.y + 26
	_txt(Vector2(bag_rect.position.x, gy + 4), "휴대 장비", 15, DB.C_MUTED)
	_txt(Vector2(bag_rect.position.x, gy + 4), "사망 시 잃음", 13, DB.C_DANGER, HORIZONTAL_ALIGNMENT_RIGHT, bag_rect.size.x)
	var p: Player = raid.player
	var wx := bag_rect.position.x
	for wid in p.weapons:
		var wr := Rect2(Vector2(wx, gy + 14), Vector2(120, 62))
		UITheme.box(Color(1, 1, 1, 0.05), 8, Color(DB.C_DANGER, 0.8), 2).draw(canvas.get_canvas_item(), wr)
		Art.draw_weapon_icon(canvas, wid, wr.position + Vector2(56, 28), 1.2)
		_txt(wr.position + Vector2(8, 56), DB.WEAPONS[wid].name, 12, DB.C_TEXT)
		wx += 130
	var ar := Rect2(Vector2(wx, gy + 14), Vector2(bag_rect.end.x - wx, 62))
	UITheme.box(Color(1, 1, 1, 0.05), 8, Color(DB.C_DANGER, 0.5), 2).draw(canvas.get_canvas_item(), ar)
	_txt(ar.position + Vector2(10, 22), "권총탄 %d" % int(p.reserve.pistol), 13, DB.C_TEXT)
	_txt(ar.position + Vector2(10, 40), "산탄 %d" % int(p.reserve.shell), 13, DB.C_TEXT)
	_txt(ar.position + Vector2(10, 58), "석궁 화살 %d" % int(p.reserve.bolt), 13, DB.C_TEXT)
	_txt(Vector2(bag_rect.position.x, gy + 104), "끌어서 이동 · R 회전 · 우클릭 사용 · 바깥에 놓으면 버리기", 13, Color(1, 1, 1, 0.45))
	# 상자 패널
	if container:
		var cp := cont_rect.grow(18)
		cp.position.y -= 50
		cp.size.y += 50 + 70
		UITheme.box(Color(DB.C_UI_SOLID, 0.95), 16, Color(1, 1, 1, 0.08), 2).draw(canvas.get_canvas_item(), cp)
		_txt(cp.position + Vector2(18, 38), container.display_name(), 22, DB.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font)
		var rows := int(cont_rect.size.y / CELL)
		for y in rows:
			for x in 4:
				UITheme.box(Color(1, 1, 1, 0.04), 6).draw(canvas.get_canvas_item(), Rect2(cont_rect.position + Vector2(x, y) * CELL, Vector2(CELL, CELL)).grow(-2))
		if container.items.is_empty():
			_txt(cont_rect.position + Vector2(0, CELL * 1.6), "비어 있다", 18, DB.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER, cont_rect.size.x)
		for i in container.items.size():
			var id: String = container.items[i]
			var r2 := Rect2(cont_rect.position + Vector2(i % 4, i / 4) * CELL, Vector2(CELL, CELL)).grow(-3)
			_item_card(id, r2, false, true)
			if r2.has_point(mouse):
				hover_text = id
				canvas.draw_rect(r2, Color(1, 1, 1, 0.08))
		var hov := take_all_rect.has_point(mouse)
		UITheme.box(DB.C_HERO if hov else DB.C_HERO.darkened(0.2), 10).draw(canvas.get_canvas_item(), take_all_rect)
		_txt(take_all_rect.position + Vector2(0, 29), "F  모두 가져가기", 17, Color("#1B1A22"), HORIZONTAL_ALIGNMENT_CENTER, take_all_rect.size.x, font)
		_txt(Vector2(cp.position.x + 18, cp.position.y + 58), "클릭: 가져오기 · 배낭 아이템을 여기로 끌면 놓고 감", 12, Color(1, 1, 1, 0.45))
	# 닫기
	var hc := close_rect.has_point(mouse)
	UITheme.box(Color("#38415A") if hc else Color("#2A3142"), 10, Color(1, 1, 1, 0.1), 2).draw(canvas.get_canvas_item(), close_rect)
	_txt(close_rect.position + Vector2(0, 29), "닫기 (Tab)", 17, DB.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, close_rect.size.x)
	# 드래그 중인 아이템
	if drag_index >= 0 and drag_index < bag.entries.size():
		var did2: String = bag.entries[drag_index].id
		var s3 := Backpack.size_of(did2, drag_rot)
		_item_card(did2, Rect2(mouse - drag_grab, Vector2(s3) * CELL).grow(-3), drag_rot)
	elif hover_text != "":
		_tooltip(hover_text, mouse, vs)

func _item_card(id: String, r: Rect2, rot: bool, compact: bool = false) -> void:
	var it: Dictionary = DB.ITEMS[id]
	var rc := DB.rarity_color(int(it.r))
	UITheme.box(Color(rc.darkened(0.75), 0.95), 8, rc, 2).draw(canvas.get_canvas_item(), r)
	canvas.draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 4)), Color(rc, 0.35))
	if rot:
		canvas.draw_set_transform(r.get_center(), PI * 0.5, Vector2.ONE)
		var rr := Rect2(-Vector2(r.size.y, r.size.x) * 0.5, Vector2(r.size.y, r.size.x)).grow(-6)
		Art.draw_item_icon(canvas, id, rr)
		canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	else:
		Art.draw_item_icon(canvas, id, r.grow(-6))
	if not compact or it.cat == "ammo":
		pass
	var vtxt := str(int(it.v)) if it.cat != "ammo" else "+%d" % int(it.amount)
	canvas.draw_string_outline(font_b, r.position + Vector2(4, r.size.y - 5), vtxt, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 8, 12, 4, Color(0, 0, 0, 0.9))
	canvas.draw_string(font_b, r.position + Vector2(4, r.size.y - 5), vtxt, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 8, 12, DB.C_LEGEND if it.cat != "ammo" else DB.C_TEXT)
	if compact and (int(it.w) > 1 or int(it.h) > 1):
		canvas.draw_string_outline(font_b, r.position + Vector2(5, 16), "%d×%d" % [it.w, it.h], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color(0, 0, 0, 0.9))
		canvas.draw_string(font_b, r.position + Vector2(5, 16), "%d×%d" % [it.w, it.h], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DB.C_MUTED)

func _tooltip(id: String, m: Vector2, vs: Vector2) -> void:
	var it: Dictionary = DB.ITEMS[id]
	var rc := DB.rarity_color(int(it.r))
	var w := 280.0
	var r := Rect2(m + Vector2(18, 18), Vector2(w, 112))
	if r.end.x > vs.x - 10:
		r.position.x = m.x - w - 18
	if r.end.y > vs.y - 10:
		r.position.y = m.y - r.size.y - 18
	UITheme.box(Color(DB.C_UI_SOLID, 0.98), 10, rc, 2).draw(canvas.get_canvas_item(), r)
	_txt(r.position + Vector2(14, 28), it.name, 18, rc, HORIZONTAL_ALIGNMENT_LEFT, -1, font)
	_txt(r.position + Vector2(14, 28), DB.RARITY_NAMES[int(it.r)], 13, rc, HORIZONTAL_ALIGNMENT_RIGHT, w - 28)
	_txt(r.position + Vector2(14, 52), "판매가 %d 냥 · %d×%d칸" % [int(it.v), int(it.w), int(it.h)], 13, DB.C_LEGEND)
	canvas.draw_multiline_string(font_b, r.position + Vector2(14, 76), it.desc, HORIZONTAL_ALIGNMENT_LEFT, w - 28, 13, 2, DB.C_MUTED)
