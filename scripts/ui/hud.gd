class_name HUD
extends CanvasLayer
## 전투 HUD. 전투 중엔 체력·탄약·무기·적 위치·탈출 방향만 남긴다.

var raid: Raid
var canvas: Control
var vignette: ColorRect
var vmat: ShaderMaterial
var notes: Array = []          # [text, color, t]
var hurt_dirs: Array = []      # [angle, t]
var minimap_tex: ImageTexture
var big_map := false
var hint := ""
var hint_t := 0.0
var extract_glow := 0.0
var danger_flash := 0.0
var font: Font
var font_b: Font

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.84, 0.27, 0.27, 1.0);
uniform float strength = 0.0;
uniform vec4 warm : source_color = vec4(1.0, 0.75, 0.35, 1.0);
uniform float warm_strength = 0.0;
uniform float base_dark = 0.35;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv * vec2(1.25, 1.0));
	float edge = smoothstep(0.32, 0.78, d);
	vec3 col = vec3(0.0);
	float a = edge * base_dark;
	col = mix(col, tint.rgb, clamp(strength, 0.0, 1.0));
	a = max(a, edge * strength * 0.75);
	col = mix(col, warm.rgb, clamp(warm_strength, 0.0, 1.0));
	a = max(a, edge * warm_strength * 0.7);
	COLOR = vec4(col, a);
}
"""

func _ready() -> void:
	layer = 10
	font = UITheme.black()
	font_b = UITheme.bold()
	vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	vmat = ShaderMaterial.new()
	vmat.shader = sh
	vignette.material = vmat
	add_child(vignette)
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_hud)
	add_child(canvas)
	_build_minimap()

func notify(text: String, color: Color = DB.C_TEXT) -> void:
	for n in notes:
		if n[0] == text:
			n[2] = 3.2
			return
	notes.append([text, color, 3.2])
	if notes.size() > 4:
		notes.pop_front()

func show_hint(text: String, dur: float = 6.0) -> void:
	hint = text
	hint_t = dur

func on_hurt(from_pos: Vector2) -> void:
	var p: Player = raid.player
	hurt_dirs.append([(from_pos - p.global_position).angle(), 1.0])
	danger_flash = 1.0

func _build_minimap() -> void:
	var W := LevelData.width()
	var H := LevelData.height()
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var c := LevelData.code(x, y)
			var col := Color("#3A3F4A")
			if c == "#":
				col = Color("#1A1D25")
			elif LevelData.is_solid_code(c):
				col = Color("#596172")
			else:
				match LevelData.floor_code(x, y):
					"_": col = Color("#8A8270")
					"=": col = Color("#6B5844")
					"g": col = Color("#4E7A40")
					"m": col = Color("#4F3F2E")
					",": col = Color("#4E5562")
			img.set_pixel(x, y, col)
	minimap_tex = ImageTexture.create_from_image(img)
	# 블렌더로 렌더한 맵이 있으면 그걸 축소해서 미니맵으로 사용 (실제 화면과 같은 모습)
	var mm_path: String = Regions.cur().minimap  # 미니맵은 위에서 본 판
	if not ResourceLoader.exists(mm_path):
		mm_path = MapRender.BAKED
	if ResourceLoader.exists(mm_path):
		var bt: Texture2D = load(mm_path)
		var bi := bt.get_image()
		if bi:
			if bi.is_compressed():
				bi.decompress()
			bi.resize(W * 6, H * 6, Image.INTERPOLATE_LANCZOS)
			bi.convert(Image.FORMAT_RGBA8)
			for y in H:
				for x in W:
					var c2 := LevelData.code(x, y)
					if c2 != "#" and LevelData.is_solid_code(c2):
						bi.fill_rect(Rect2i(x * 6 + 1, y * 6 + 1, 4, 4), Color("#2A2E38"))
			minimap_tex = ImageTexture.create_from_image(bi)

func _process(delta: float) -> void:
	for n in notes:
		n[2] -= delta
	notes = notes.filter(func(n): return n[2] > 0.0)
	for h in hurt_dirs:
		h[1] -= delta * 1.4
	hurt_dirs = hurt_dirs.filter(func(h): return h[1] > 0.0)
	hint_t = maxf(0.0, hint_t - delta)
	danger_flash = maxf(0.0, danger_flash - delta * 2.0)
	var p: Player = raid.player
	if p:
		var low := clampf(1.0 - p.hp / 45.0, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		vmat.set_shader_parameter("strength", maxf(low * (0.55 + pulse * 0.3), danger_flash * 0.8))
	extract_glow = lerpf(extract_glow, 1.0 if raid.extract_active else 0.0, 1.0 - exp(-delta * 4.0))
	vmat.set_shader_parameter("warm_strength", extract_glow)
	vmat.set_shader_parameter("base_dark", 0.3 + raid.storm_k * 0.3)
	canvas.queue_redraw()

# ── 그리기 ───────────────────────────────────────────
func _txt(pos: Vector2, s: String, size: int, col: Color, outline: bool = true, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1, f: Font = null) -> void:
	var fnt := f if f else font
	if outline:
		canvas.draw_string_outline(fnt, pos, s, align, width, size, 5, Color(0.06, 0.07, 0.1, 0.85))
	canvas.draw_string(fnt, pos, s, align, width, size, col)

func _panel(r: Rect2, a: float = 0.82) -> void:
	var sb := UITheme.box(Color(DB.C_UI_SOLID, a), 12, Color(1, 1, 1, 0.07), 2)
	sb.draw(canvas.get_canvas_item(), r)

func _bar(r: Rect2, k: float, col: Color, back: Color = Color(0, 0, 0, 0.5)) -> void:
	var sb := UITheme.box(back, 5)
	sb.draw(canvas.get_canvas_item(), r)
	if k > 0.0:
		var fill := UITheme.box(col, 5)
		fill.draw(canvas.get_canvas_item(), Rect2(r.position, Vector2(maxf(r.size.x * clampf(k, 0, 1), 10), r.size.y)))
		canvas.draw_rect(Rect2(r.position + Vector2(4, 2), Vector2(maxf(r.size.x * clampf(k, 0, 1) - 8, 2), 3)), Color(1, 1, 1, 0.25))

func _draw_hud() -> void:
	var p: Player = raid.player
	if p == null:
		return
	var vs := canvas.size
	if raid.inv_open:
		_draw_notes(vs)
		return
	_draw_status(p, vs)
	_draw_weapon(p, vs)
	_draw_hotbar(p, vs)
	_draw_equipment(p, vs)
	_draw_minimap(p, vs)
	_draw_notes(vs)
	_draw_prompt(vs)
	_draw_hurt(vs)
	_draw_extract(vs)
	_draw_exit_arrows(p, vs)
	_draw_boss(p, vs)
	_draw_contracts(vs)
	if hint_t > 0.0 and hint != "":
		var a := minf(1.0, hint_t)
		var w := font_b.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 40
		var r := Rect2(Vector2(vs.x * 0.5 - w * 0.5, vs.y - 196), Vector2(w, 40))
		var sb := UITheme.box(Color(DB.C_HERO.darkened(0.55), 0.85 * a), 20, Color(DB.C_HERO, a), 2)
		sb.draw(canvas.get_canvas_item(), r)
		_txt(r.position + Vector2(20, 27), hint, 18, Color(1, 1, 1, a), false, HORIZONTAL_ALIGNMENT_LEFT, -1, font_b)
	if big_map:
		_draw_big_map(p, vs)
	if not raid.paused_menu:
		_draw_crosshair(p)

func _draw_status(p: Player, vs: Vector2) -> void:
	var r := Rect2(Vector2(18, vs.y - 104), Vector2(330, 86))
	_panel(r)
	# 초상
	var pc := r.position + Vector2(44, 46)
	canvas.draw_circle(pc, 30, Color(DB.C_HERO, 0.25))
	var hk: String = p.SPRITE
	var pf := Sprites.char_frame(hk, "portrait", 0)
	if p.mood == "hurt" or p.hp < 35:
		pf = Sprites.char_frame(hk, "portrait_hurt", 0)
	elif p.mood == "happy":
		pf = Sprites.char_frame(hk, "portrait_happy", 0)
	Sprites.draw_char(canvas, hk, pf, pc + Vector2(0, 30), 0.62)
	# 상태 칩: 웅크림 · 은신 · 버프 · 무거움
	var chips := []
	if p.crouching:
		var tl := raid.tile_at(p.global_position)
		chips.append(["풀숲 은신" if tl == "g" else "웅크림", Color("#6CCB5F") if tl == "g" else Color("#9AA3B2")])
	if p.cloak_t > 0.0:
		chips.append(["투명 %.0f" % ceilf(p.cloak_t), Color("#B8A6F0")])
	if p.scout_t > 0.0:
		chips.append(["정찰 %.0f" % ceilf(p.scout_t), Color("#F0A050")])
	var BN := {"rally": "작전 개시", "carrot": "당근 질주", "nut": "견과 방어", "seed": "씨앗 기력", "iron": "강철 피부", "swift": "질풍", "focus": "집중"}
	for b in p.buffs.keys():
		chips.append(["%s %.0f" % [BN.get(b, b), ceilf(float(p.buffs[b]))], DB.C_LEGEND])
	if raid.bag.load_ratio() > 0.75:
		chips.append(["짐이 무겁다 (느림·시끄러움)", DB.C_DANGER])
	var tot := 0.0
	for c in chips:
		tot += font_b.get_string_size(c[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 24
	var cx := vs.x * 0.5 - tot * 0.5
	for c in chips:
		var cw := font_b.get_string_size(c[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 18
		var cr := Rect2(Vector2(cx, vs.y - 112), Vector2(cw, 24))
		UITheme.box(Color(0.08, 0.09, 0.12, 0.85), 12, Color(c[1], 0.9), 2).draw(canvas.get_canvas_item(), cr)
		_txt(cr.position + Vector2(9, 17), c[0], 13, c[1], false, HORIZONTAL_ALIGNMENT_LEFT, -1, font_b)
		cx += cw + 6
	var hpk := p.hp / p.max_hp
	var hpcol := Color("#6CCB5F") if hpk > 0.6 else (DB.C_LEGEND if hpk > 0.3 else DB.C_DANGER)
	Sprites.draw_fit(canvas, Sprites.ui_tex("heart"), Rect2(r.position + Vector2(84, 8), Vector2(22, 22)))
	_txt(r.position + Vector2(110, 26), "체력", 14, DB.C_MUTED, false, HORIZONTAL_ALIGNMENT_LEFT, -1, font_b)
	_txt(r.position + Vector2(86, 26), "%d / %d" % [ceili(p.hp), int(p.max_hp)], 15, DB.C_TEXT, false, HORIZONTAL_ALIGNMENT_RIGHT, 228)
	_bar(Rect2(r.position + Vector2(86, 32), Vector2(228, 16)), hpk, hpcol)
	Sprites.draw_fit(canvas, Sprites.ui_tex("bolt"), Rect2(r.position + Vector2(84, 52), Vector2(20, 20)))
	_txt(r.position + Vector2(108, 68), "기력", 13, DB.C_MUTED, false, HORIZONTAL_ALIGNMENT_LEFT, -1, font_b)
	_bar(Rect2(r.position + Vector2(150, 57), Vector2(164, 12)), p.stamina / 100.0, Color("#9AA3B2") if p.exhausted else DB.C_LEGEND)
	if p.exhausted:
		_txt(r.position + Vector2(160, 68), "탈진", 11, DB.C_DANGER, false)
	if p.muddy > 0.0:
		_txt(Vector2(r.position.x + 86, r.end.y + 18), "진흙 발자국이 남는 중", 13, Color("#C9A27A"))
	# 갑옷 내구도 (상태창 오른쪽 옆)
	var ay := r.position.y + 10.0
	for aslot in ["helmet", "vest"]:
		var aid: String = p.helmet if aslot == "helmet" else p.vest
		if aid == "":
			continue
		var dur: float = p.helmet_dur if aslot == "helmet" else p.vest_dur
		var mx := float(DB.ITEMS[aid].dur)
		var ax := r.end.x + 8.0
		var ir := Rect2(Vector2(ax, ay), Vector2(30, 30))
		UITheme.box(Color(0.08, 0.09, 0.12, 0.82), 6, Color(1, 1, 1, 0.12), 1).draw(canvas.get_canvas_item(), ir)
		Art.draw_item_icon(canvas, aid, ir.grow(-3))
		_bar(Rect2(Vector2(ax + 34, ay + 18), Vector2(52, 8)), dur / mx, Color("#8FB3C9") if dur > 0.0 else DB.C_DANGER)
		_txt(Vector2(ax + 34, ay + 13), "%d%%" % int(round(dur / mx * 100.0)), 11, DB.C_MUTED, true)
		ay += 36.0

func _draw_weapon(p: Player, vs: Vector2) -> void:
	var r := Rect2(Vector2(vs.x - 318, vs.y - 104), Vector2(300, 86))
	_panel(r)
	var wid := p.current_weapon()
	if wid == "":
		_txt(r.position + Vector2(20, 50), "근접 무기만 보유 (V)", 18, DB.C_MUTED)
		return
	var w: Dictionary = p.wstat(wid)
	canvas.draw_circle(r.position + Vector2(52, 44), 34, Color(1, 1, 1, 0.04))
	Art.draw_weapon_icon(canvas, wid, r.position + Vector2(52, 44), 1.5)
	_txt(r.position + Vector2(104, 26), w.name, 15, DB.C_MUTED, false, HORIZONTAL_ALIGNMENT_LEFT, -1, font_b)
	var mag := int(p.mags[wid])
	var magcol := DB.C_TEXT if mag > int(w.mag) * 0.3 else DB.C_DANGER
	_txt(r.position + Vector2(104, 66), str(mag), 36, magcol, false)
	var mw := font.get_string_size(str(mag), HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	_txt(r.position + Vector2(108 + mw, 66), "/ %d" % int(p.reserve[w.ammo]), 18, DB.C_MUTED, false)
	if p.reload_t > 0.0:
		_txt(r.position + Vector2(104, 82), "재장전 중...", 12, DB.C_LEGEND, false)
	elif mag == 0:
		_txt(r.position + Vector2(104, 82), "R 재장전", 12, DB.C_DANGER, false)
	# 슬롯
	var sx := r.end.x - 96
	for i in p.weapons.size():
		var sr := Rect2(Vector2(sx + i * 32, r.position.y + 12), Vector2(26, 22))
		var sb := UITheme.box(DB.C_HERO if i == p.cur else Color(1, 1, 1, 0.08), 5)
		sb.draw(canvas.get_canvas_item(), sr)
		_txt(sr.position + Vector2(8, 17), str(i + 1), 14, Color("#1B1A22") if i == p.cur else DB.C_MUTED, false)
	var vr := Rect2(Vector2(sx + 64, r.position.y + 12), Vector2(26, 22))
	UITheme.box(Color(1, 1, 1, 0.08), 5).draw(canvas.get_canvas_item(), vr)
	_txt(vr.position + Vector2(8, 17), "V", 14, DB.C_MUTED if p.melee_cd <= 0.0 else Color(1, 1, 1, 0.2), false)

## 화면 아래 가운데 무기·회복 슬롯 (레퍼런스 스타일)
func _draw_hotbar(p: Player, vs: Vector2) -> void:
	var slots := []
	for i in p.weapons.size():
		slots.append({"key": str(i + 1), "w": p.weapons[i], "sel": i == p.cur})
	slots.append({"key": "V", "icon": "w_" + p.melee_id, "sel": p.melee_cd > 0.0})
	var qn := 0
	var qfirst := "bandage"
	for qid in ["potion_big", "medkit", "potion_heal", "bandage"]:
		var qc: int = raid.bag.count(qid)
		if qc > 0 and qn == 0:
			qfirst = qid
		qn += qc
	slots.append({"key": "Q", "item": qfirst, "n": qn})
	var sn := 0
	var sfirst := "sunflower_seed"
	for sid in ["sunflower_seed", "nut_mix", "cheese", "carrot_juice", "canned_food", "churu", "energy_drink"]:
		var c: int = raid.bag.count(sid)
		if c > 0 and sn == 0:
			sfirst = sid
		sn += c
	slots.append({"key": "G", "item": sfirst, "n": sn})
	slots.append({"key": "F", "skill": true, "sel": p.skill_cd <= 0.0})
	var sz := 58.0
	var gap := 8.0
	var total := slots.size() * sz + (slots.size() - 1) * gap
	var x0 := vs.x * 0.5 - total * 0.5
	var y0 := vs.y - sz - 18.0
	for i in slots.size():
		var sl: Dictionary = slots[i]
		var r := Rect2(Vector2(x0 + i * (sz + gap), y0), Vector2(sz, sz))
		var sel: bool = sl.get("sel", false)
		UITheme.box(Color(0.08, 0.09, 0.12, 0.82), 10, DB.C_HERO if sel else Color(1, 1, 1, 0.14), 3 if sel else 2).draw(canvas.get_canvas_item(), r)
		var ir := r.grow(-8)
		if sl.has("w"):
			var wid: String = sl.w
			var wt := Sprites.icon_tex("w_" + wid)
			if wt:
				Sprites.draw_fit(canvas, wt, ir)
			elif wid != "" and DB.WEAPONS.has(wid):
				Art.draw_weapon_icon(canvas, wid, ir.get_center(), 0.9)
			if wid != "" and DB.WEAPONS.has(wid):
				var w: Dictionary = DB.WEAPONS[wid]
				_txt(Vector2(r.position.x, r.end.y - 5), "%d/%d" % [int(p.mags[wid]), int(p.reserve[w.ammo])], 11, DB.C_TEXT, true, HORIZONTAL_ALIGNMENT_RIGHT, sz - 6)
		elif sl.has("icon"):
			Sprites.draw_fit(canvas, Sprites.icon_tex(sl.icon), ir.grow(-4), Color(1, 1, 1, 0.45 if p.melee_cd > 0.0 else 1.0))
		elif sl.has("skill"):
			_draw_skill_slot(p, r)
		elif sl.has("item"):
			Art.draw_item_icon(canvas, sl.item, ir)
			_txt(Vector2(r.position.x, r.end.y - 5), "×%d" % int(sl.n), 12, DB.C_TEXT if int(sl.n) > 0 else DB.C_DANGER, true, HORIZONTAL_ALIGNMENT_RIGHT, sz - 6)
		_txt(r.position + Vector2(6, 15), sl.key, 12, DB.C_HERO if sel else DB.C_MUTED, true)

## F 스킬 슬롯: 햄스터 털빛 원 + 스킬 이름, 쿨타임은 어두운 부채꼴로 걷힌다
func _draw_skill_slot(p: Player, r: Rect2) -> void:
	var hd: Dictionary = p.hdata
	if hd.is_empty():
		return
	var c := r.get_center()
	var fur := Color(str(hd.fur))
	var rdy := p.skill_cd <= 0.0
	canvas.draw_circle(c, 22, Color(fur, 0.9 if rdy else 0.35))
	canvas.draw_arc(c, 22, 0, TAU, 32, Color(1, 1, 1, 0.5), 2.0, true)
	var nm: String = hd.skill_name
	_txt(Vector2(r.position.x, c.y + 5), nm.substr(0, 3), 13, Color("#1B1A22") if rdy else DB.C_MUTED, false, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, font_b)
	if not rdy:
		var k := clampf(p.skill_cd / float(hd.cd), 0.0, 1.0)
		var pts := PackedVector2Array([c])
		var n := 28
		for i in n + 1:
			pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * k * i / n) * 24.0)
		if k > 0.01:
			canvas.draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
		_txt(Vector2(r.position.x, r.end.y - 5), "%d" % ceili(p.skill_cd), 13, DB.C_TEXT, true, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 6)
	else:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		canvas.draw_arc(c, 25, 0, TAU, 32, Color(DB.C_LEGEND, 0.4 + 0.5 * pulse), 2.0, true)

func _draw_equipment(p: Player, vs: Vector2) -> void:
	var bag: Backpack = raid.bag
	var x := 18.0
	var y := vs.y - 228.0
	var r := Rect2(Vector2(x, y), Vector2(200, 112))
	_panel(r, 0.7)
	_txt(r.position + Vector2(14, 26), "배낭", 14, DB.C_MUTED, false, HORIZONTAL_ALIGNMENT_LEFT, -1, font_b)
	var used := bag.used_cells()
	var total := bag.w * bag.h
	_txt(r.position + Vector2(14, 26), "%d / %d칸" % [used, total], 14, DB.C_TEXT if used < total else DB.C_DANGER, false, HORIZONTAL_ALIGNMENT_RIGHT, 172)
	_bar(Rect2(r.position + Vector2(14, 34), Vector2(172, 8)), float(used) / total, DB.C_HERO if used < total else DB.C_DANGER)
	_txt(r.position + Vector2(14, 66), "전리품 가치", 13, DB.C_MUTED, false, HORIZONTAL_ALIGNMENT_LEFT, -1, font_b)
	_txt(r.position + Vector2(14, 66), "%s 냥" % _fmt(bag.total_value()), 15, DB.C_LEGEND, false, HORIZONTAL_ALIGNMENT_RIGHT, 172)
	var pots := bag.count("potion_heal") + bag.count("potion_big")
	var meds := bag.count("bandage") + bag.count("medkit") + pots
	_txt(r.position + Vector2(14, 96), "Q 회복", 13, DB.C_MUTED, false, HORIZONTAL_ALIGNMENT_LEFT, -1, font_b)
	_txt(r.position + Vector2(14, 96), "붕대 %d · 구급 %d · 물약 %d" % [bag.count("bandage"), bag.count("medkit"), pots], 13, DB.C_TEXT if meds > 0 else DB.C_DANGER, false, HORIZONTAL_ALIGNMENT_RIGHT, 172)
	_txt(Vector2(x + 2, y - 10), "Tab 배낭 열기", 12, Color(1, 1, 1, 0.45), true)

static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out

func _draw_minimap(p: Player, vs: Vector2) -> void:
	var scale_k := 3.6
	var size := Vector2(LevelData.width(), LevelData.height()) * scale_k
	var r := Rect2(Vector2(vs.x - size.x - 26, 18), size + Vector2(8, 8))
	_panel(r)
	var mr := Rect2(r.position + Vector2(4, 4), size)
	canvas.draw_texture_rect(minimap_tex, mr, false, Color(1, 1, 1, 0.95))
	_minimap_marks(p, mr, scale_k, 1.0)
	# 시간
	var left := maxf(0.0, raid.time_left)
	var tcol := DB.C_TEXT if left > 180.0 else DB.C_DANGER
	var tr := Rect2(Vector2(r.position.x, r.end.y + 8), Vector2(r.size.x, 34))
	_panel(tr)
	_txt(tr.position + Vector2(12, 24), "남은 시간", 13, DB.C_MUTED, false, HORIZONTAL_ALIGNMENT_LEFT, -1, font_b)
	_txt(tr.position + Vector2(12, 25), "%02d:%02d" % [int(left) / 60, int(left) % 60], 20, tcol, false, HORIZONTAL_ALIGNMENT_RIGHT, tr.size.x - 24)
	if raid.storm_k > 0.0:
		_txt(Vector2(tr.position.x, tr.end.y + 20), "폭풍 접근 중 — 적이 늘어난다", 13, DB.C_DANGER)
	_txt(Vector2(r.position.x + 4, r.end.y + 62 + (18 if raid.storm_k > 0.0 else 0)), "M 지도", 12, Color(1, 1, 1, 0.45))

func _minimap_marks(p: Player, mr: Rect2, k: float, dot: float) -> void:
	var T := float(DB.TILE)
	for ex in raid.exits:
		var er := Rect2(mr.position + ex.rect.position / T * k, ex.rect.size / T * k)
		canvas.draw_rect(er, Color(DB.C_DANGER if ex.locked else Color("#6CCB5F"), 0.85))
		_txt(er.position + Vector2(er.size.x * 0.5 - 4 * dot, er.size.y * 0.5 + 5 * dot), ex.label.substr(0, 1), int(12 * dot), Color.WHITE)
	for lb in raid.lost_bag_nodes:
		if is_instance_valid(lb) and not (lb.searched and lb.items.is_empty()):
			var bp: Vector2 = mr.position + lb.global_position / T * k
			canvas.draw_circle(bp, 5.0 * dot, Art.OUTLINE)
			canvas.draw_circle(bp, 3.8 * dot, Color("#F2C14E"))
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.dead:
			continue
		var visible_e: bool = e.is_aware() or p.scout_t > 0.0 or e.global_position.distance_to(p.global_position) < 260.0
		if visible_e:
			canvas.draw_circle(mr.position + e.global_position / T * k, 2.6 * dot, DB.C_DANGER)
	var pp := mr.position + p.global_position / T * k
	canvas.draw_circle(pp, 4.5 * dot, Art.OUTLINE)
	canvas.draw_circle(pp, 3.2 * dot, DB.C_HERO)
	canvas.draw_line(pp, pp + p.aim_dir * 9.0 * dot, DB.C_HERO, 2)

func _draw_big_map(p: Player, vs: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
	var k := minf((vs.x - 160) / LevelData.width(), (vs.y - 160) / LevelData.height())
	var size := Vector2(LevelData.width(), LevelData.height()) * k
	var r := Rect2((vs - size) * 0.5, size)
	_panel(r.grow(10), 0.95)
	canvas.draw_texture_rect(minimap_tex, r, false)
	_minimap_marks(p, r, k, 2.0)
	_txt(Vector2(r.position.x, r.position.y - 18), str(Regions.cur().short), 22, DB.C_TEXT)
	_txt(Vector2(r.position.x, r.end.y + 36), "초록 %s(항상 열림)   ·   %s(창고 발전기를 켜야 열림)   ·   노란 점: 내 가방   ·   빨간 점: 감지된 적" % [raid.exits[0].label, raid.exits[1].label], 15, DB.C_MUTED, true, HORIZONTAL_ALIGNMENT_LEFT, -1, font_b)

func _draw_notes(vs: Vector2) -> void:
	var y := 64.0
	for n in notes:
		var a := minf(1.0, n[2] * 2.0)
		var s: String = n[0]
		var w := font_b.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 36
		var r := Rect2(Vector2(vs.x * 0.5 - w * 0.5, y), Vector2(w, 36))
		UITheme.box(Color(DB.C_UI_SOLID, 0.8 * a), 18, Color(n[1], 0.6 * a), 2).draw(canvas.get_canvas_item(), r)
		_txt(r.position + Vector2(18, 25), s, 19, Color(n[1], a), false, HORIZONTAL_ALIGNMENT_LEFT, -1, font_b)
		y += 42

func _draw_prompt(vs: Vector2) -> void:
	var it = raid.focus
	var ch: float = raid.channel_t
	if ch > 0.0 and raid.channel_target:
		var k: float = 1.0 - ch / raid.channel_total
		var c := Vector2(vs.x * 0.5, vs.y * 0.5 + 70)
		canvas.draw_circle(c, 26, Color(0, 0, 0, 0.55))
		canvas.draw_arc(c, 22, -PI * 0.5, -PI * 0.5 + TAU * k, 32, DB.C_HERO, 6, true)
		var s := "뒤지는 중..." if not (raid.channel_target is Generator) else "가동 중..."
		_txt(c + Vector2(-60, 52), s, 16, DB.C_TEXT, true, HORIZONTAL_ALIGNMENT_CENTER, 120)
		return
	if it == null:
		return
	var txt: String = it.prompt()
	var w := font_b.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 40
	var r := Rect2(Vector2(vs.x * 0.5 - w * 0.5, vs.y - 150), Vector2(w, 40))
	_panel(r, 0.85)
	if txt.begins_with("E "):
		var kr := Rect2(r.position + Vector2(10, 7), Vector2(26, 26))
		UITheme.box(DB.C_TEXT, 6).draw(canvas.get_canvas_item(), kr)
		_txt(kr.position + Vector2(7, 20), "E", 17, Color("#1B1A22"), false)
		_txt(r.position + Vector2(44, 27), txt.substr(2).strip_edges(), 18, DB.C_TEXT, false, HORIZONTAL_ALIGNMENT_LEFT, -1, font_b)
	else:
		_txt(r.position + Vector2(20, 27), txt, 18, DB.C_MUTED, false, HORIZONTAL_ALIGNMENT_LEFT, -1, font_b)

func _draw_hurt(vs: Vector2) -> void:
	var c := vs * 0.5
	for h in hurt_dirs:
		var a: float = h[0]
		canvas.draw_arc(c, 120, a - 0.35, a + 0.35, 16, Color(DB.C_DANGER, h[1] * 0.85), 10, true)

func _draw_extract(vs: Vector2) -> void:
	if not raid.extract_active:
		return
	var ex: ExitZone = raid.extract_zone
	var k := 1.0 - raid.extract_t / ex.need
	var c := Vector2(vs.x * 0.5, 150)
	var r := Rect2(c - Vector2(180, 30), Vector2(360, 68))
	UITheme.box(Color(DB.C_UI_SOLID, 0.85), 16, Color(DB.C_LEGEND, 0.8), 3).draw(canvas.get_canvas_item(), r)
	_txt(r.position + Vector2(0, 30), "탈출 중 · %.1f초" % maxf(0.0, raid.extract_t), 22, DB.C_LEGEND, false, HORIZONTAL_ALIGNMENT_CENTER, 360)
	_bar(Rect2(r.position + Vector2(20, 44), Vector2(320, 12)), k, DB.C_LEGEND)

func _draw_exit_arrows(p: Player, vs: Vector2) -> void:
	# 화면 밖 탈출구 방향 표시 (UI 없이도 어디로 가야 할지)
	var cam := p.camera()
	var center := cam.get_screen_center_position()
	var half := vs * 0.5 / cam.zoom
	for ex in raid.exits:
		var tgt: Vector2 = ex.rect.get_center()
		var d := tgt - center
		if absf(d.x) < half.x * 0.9 and absf(d.y) < half.y * 0.9:
			continue
		var dir := d.normalized()
		var edge := vs * 0.5 + Vector2(dir.x * (vs.x * 0.5 - 70), dir.y * (vs.y * 0.5 - 70))
		edge.x = clampf(edge.x, 60, vs.x - 60)
		edge.y = clampf(edge.y, 150, vs.y - 140)
		var col := Color("#6CCB5F") if not ex.locked else Color(DB.C_DANGER, 0.7)
		var pts := PackedVector2Array([edge + dir * 16, edge + dir.rotated(2.5) * 12, edge + dir.rotated(-2.5) * 12])
		canvas.draw_colored_polygon(pts, col)
		var dist := int(d.length() / DB.TILE)
		_txt(edge - dir * 22 + Vector2(-30, 6), "%s %dm" % [ex.label.substr(0, 1), dist], 14, col, true, HORIZONTAL_ALIGNMENT_CENTER, 60)
	# 내 가방 (쓰러진 자리)
	for lb in raid.lost_bag_nodes:
		if not is_instance_valid(lb) or (lb.searched and lb.items.is_empty()):
			continue
		var d2: Vector2 = lb.global_position - center
		if absf(d2.x) < half.x * 0.9 and absf(d2.y) < half.y * 0.9:
			continue
		var dir2 := d2.normalized()
		var edge2 := vs * 0.5 + Vector2(dir2.x * (vs.x * 0.5 - 70), dir2.y * (vs.y * 0.5 - 70))
		edge2.x = clampf(edge2.x, 60, vs.x - 60)
		edge2.y = clampf(edge2.y, 150, vs.y - 140)
		var bcol := Color("#F2C14E")
		canvas.draw_circle(edge2, 13, Color(0, 0, 0, 0.5))
		var bt := Sprites.fx_tex("bag")
		if bt:
			Sprites.draw_fit(canvas, bt, Rect2(edge2 - Vector2(11, 11), Vector2(22, 22)))
		_txt(edge2 - dir2 * 26 + Vector2(-40, 6), "내 가방 %dm" % int(d2.length() / DB.TILE), 13, bcol, true, HORIZONTAL_ALIGNMENT_CENTER, 80)

## 진행 중인 의뢰 (화면 왼쪽 위)
func _draw_contracts(_vs: Vector2) -> void:
	var y := 22.0
	var shown := 0
	for c in GameState.contracts:
		if str(c.kind) == "fetch":
			continue
		var reg := str(c.get("region", ""))
		if reg != "" and reg != LevelData.region:
			continue
		var txt := GameState.contract_text(c)
		var prog := "완료!" if c.done else "%d/%d" % [int(c.have), int(c.need)]
		if str(c.kind) == "extract" and not c.done:
			prog = "%d/%d냥" % [raid.bag.total_value(), int(c.need)]
		var w := font_b.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 90
		var r := Rect2(Vector2(18, y), Vector2(w, 28))
		_panel(r, 0.7)
		_txt(r.position + Vector2(10, 19), txt, 14, DB.C_LEGEND if c.done else DB.C_TEXT, false, HORIZONTAL_ALIGNMENT_LEFT, -1, font_b)
		_txt(r.position + Vector2(10, 19), prog, 13, Color("#6CCB5F") if c.done else DB.C_MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT, w - 20)
		y += 32.0
		shown += 1
		if shown >= 3:
			break

## 대장 고양이 체력 막대 (화면 위 가운데)
func _draw_boss(p: Player, vs: Vector2) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.elite or e.dead:
			continue
		if not e.is_aware() and e.global_position.distance_to(p.global_position) > 520.0:
			continue
		var r := Rect2(Vector2(vs.x * 0.5 - 230, 96), Vector2(460, 40))
		_panel(r, 0.85)
		_txt(r.position + Vector2(14, 17), str(e.data.name), 15, DB.C_LEGEND, true, HORIZONTAL_ALIGNMENT_LEFT, -1, font_b)
		_txt(r.position + Vector2(14, 17), "%d / %d" % [ceili(e.hp), int(e.max_hp)], 13, DB.C_TEXT, true, HORIZONTAL_ALIGNMENT_RIGHT, 432)
		_bar(Rect2(r.position + Vector2(14, 23), Vector2(432, 10)), clampf(e.hp / e.max_hp, 0.0, 1.0), DB.C_DANGER)
		return

func _draw_crosshair(p: Player) -> void:
	var m := canvas.get_local_mouse_position()
	var wid := p.current_weapon()
	var spread := (8.0 + p.recoil * 1.5) * lerpf(1.0, 0.6, p.aim_k)
	if wid != "":
		spread += float(p.wstat(wid).spread) * 0.6
	var col := Color(1, 1, 1, 0.9)
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		var d := Vector2.from_angle(a)
		canvas.draw_line(m + d * spread, m + d * (spread + 8), Art.OUTLINE, 4)
		canvas.draw_line(m + d * spread, m + d * (spread + 8), col, 2)
	canvas.draw_circle(m, 2.5, DB.C_HERO)
	if p.reload_t > 0.0:
		var k := 1.0 - p.reload_t / p.reload_total
		canvas.draw_arc(m, spread + 14, -PI * 0.5, -PI * 0.5 + TAU * k, 24, DB.C_LEGEND, 3, true)
