class_name FX
extends Node2D
## 짧게 살다 사라지는 시각 효과들 (총구 화염, 털 뭉치, 발자국, 획득 연출 등)

static var _light_tex: Texture2D
static var NO_CORPSE := false   # 3D 화면: 쓰러진 3D 모델이 대신한다
static var _font: Font

var kind := ""
var t := 0.0
var life := 0.5
var dir := Vector2.RIGHT
var col := Color.WHITE
var parts: Array = []   # [pos, vel, size, rot, spin]
var text := ""
var item_id := ""

static func light_texture() -> Texture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 128
		tex.height = 128
		_light_tex = tex
	return _light_tex

static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/NotoSansKR-Black.otf")
	return _font

static func _make(layer: Node, k: String, pos: Vector2, lifetime: float) -> FX:
	var f := FX.new()
	f.kind = k
	f.life = lifetime
	f.position = pos
	layer.add_child(f)
	return f

static func muzzle(layer: Node, pos: Vector2, d: Vector2, big: bool) -> void:
	var f := _make(layer, "muzzle", pos, 0.07 if not big else 0.09)
	f.dir = d
	f.col = Color("#FFD27A")
	f.rotation = d.angle()
	f.scale = Vector2.ONE * (1.5 if big else 1.0)
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.texture_scale = 2.4 if big else 1.6
	l.energy = 1.2
	l.color = Color("#FFC870")
	f.add_child(l)

## 쓰러진 고양이 (X눈) — 잠시 남았다가 사라짐
static func corpse(layer: Node, pos: Vector2, char_kind: String, flip: bool, tint: Color) -> void:
	if NO_CORPSE:
		return
	var f := _make(layer, "corpse", pos, 2.6)
	f.text = char_kind
	f.dir = Vector2(-1 if flip else 1, 0)
	f.col = tint
	f.z_index = -3

static func explosion(layer: Node, pos: Vector2, radius: float) -> void:
	var f := _make(layer, "boom", pos, 0.55)
	f.dir = Vector2(radius, 0)
	f.z_index = 6
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.texture_scale = radius / 30.0
	l.energy = 1.4
	l.color = Color("#FFB060")
	f.add_child(l)
	var c := _make(layer, "crater", pos, 6.0)
	c.z_index = -6

static func shell(layer: Node, pos: Vector2, side: float) -> void:
	var f := _make(layer, "shell", pos, 0.6)
	f.parts = [[Vector2.ZERO, Vector2(side * randf_range(60, 110), randf_range(-160, -110)), 3.0, randf() * TAU, randf_range(-14, 14)]]

static func dust(layer: Node, pos: Vector2, n: int) -> void:
	var f := _make(layer, "dust", pos, 0.45)
	for i in n:
		f.parts.append([Vector2(randf_range(-8, 8), randf_range(-4, 2)), Vector2(randf_range(-60, 60), randf_range(-40, -5)), randf_range(4, 8), 0.0, 0.0])

static func footprint(layer: Node, pos: Vector2, ang: float, wet: bool) -> FX:
	var f := _make(layer, "print", pos, 9.0)
	f.rotation = ang
	f.z_index = -5
	f.col = Color(0.75, 0.8, 0.95, 0.4) if wet else Color(0.18, 0.12, 0.08, 0.5)
	f.parts = [[Vector2(0, -5 if randf() > 0.5 else 5), Vector2.ZERO, 1.0, 0.0, 0.0]]
	return f

static func swoosh(layer: Node, pos: Vector2, d: Vector2) -> void:
	var f := _make(layer, "swoosh", pos, 0.18)
	f.rotation = d.angle()

static func heal_burst(layer: Node, pos: Vector2) -> void:
	var f := _make(layer, "heal", pos, 0.8)
	for i in 8:
		f.parts.append([Vector2(randf_range(-16, 16), randf_range(-6, 6)), Vector2(randf_range(-15, 15), randf_range(-70, -40)), randf_range(4, 7), 0.0, 0.0])

static func fur_puff(layer: Node, pos: Vector2, c: Color, n: int = 16) -> void:
	var f := _make(layer, "fur", pos, 1.1)
	f.col = c
	for i in n:
		var a := randf() * TAU
		f.parts.append([Vector2.ZERO, Vector2.from_angle(a) * randf_range(40, 170), randf_range(4, 9), randf() * TAU, randf_range(-6, 6)])
	var fog := _make(layer, "fog", pos, 1.3)
	fog.col = Color(0.9, 0.9, 1.0, 0.5)

## 풀숲이 흔들림: 초록 잎 몇 장이 튀어 오른다
static func rustle(layer: Node, pos: Vector2) -> void:
	var f := _make(layer, "fur", pos + Vector2(0, -6), 0.7)
	f.col = Color(0.42, 0.72, 0.32)
	for i in 6:
		var a := randf_range(-PI * 0.9, -PI * 0.1)
		f.parts.append([Vector2(randf_range(-10, 10), 0), Vector2.from_angle(a) * randf_range(40, 110), randf_range(3, 6), randf() * TAU, randf_range(-8, 8)])

static func hit_spark(layer: Node, pos: Vector2, d: Vector2, c: Color = Color.WHITE) -> void:
	var f := _make(layer, "spark", pos, 0.2)
	f.col = c
	for i in 5:
		f.parts.append([Vector2.ZERO, d.rotated(randf_range(-0.9, 0.9)) * randf_range(120, 260), randf_range(2, 3.5), 0.0, 0.0])

static func icon_pop(layer: Node, pos: Vector2, k: String) -> void:
	var f := _make(layer, "icon", pos, 0.55)
	f.text = k
	f.z_index = 20

static func text_pop(layer: Node, pos: Vector2, s: String, c: Color, lifetime: float = 1.2) -> void:
	var f := _make(layer, "text", pos, lifetime)
	f.text = s
	f.col = c
	f.z_index = 30

static func loot_rise(layer: Node, pos: Vector2, id: String) -> void:
	var f := _make(layer, "loot", pos, 1.0)
	f.item_id = id
	f.col = DB.rarity_color(int(DB.ITEMS[id].r))
	f.z_index = 25

static func ring(layer: Node, pos: Vector2, radius: float, c: Color, lifetime: float = 0.6) -> void:
	var f := _make(layer, "ring", pos, lifetime)
	f.col = c
	f.dir = Vector2(radius, 0)
	f.z_index = -4

func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	for p in parts:
		p[0] += p[1] * delta
		p[3] += p[4] * delta
		match kind:
			"shell":
				p[1].y += 600.0 * delta
				if p[0].y > 18.0:
					p[1] = p[1] * Vector2(0.4, -0.3)
					p[0].y = 18.0
			"fur", "dust", "spark":
				p[1] *= pow(0.04, delta)
	queue_redraw()

func _draw() -> void:
	var k := t / life
	match kind:
		"muzzle":
			var s := 1.0 - k
			var mt := Sprites.fx_tex("flash1" if scale.x < 1.2 else "flash2")
			if mt:
				var ms := Vector2(mt.get_size()) * 0.4 * (0.8 + s * 0.4)
				draw_texture_rect(mt, Rect2(Vector2(-4, -ms.y * 0.5), ms), false, Color(1, 1, 1, 0.6 + s * 0.4))
				return
			draw_colored_polygon(PackedVector2Array([Vector2(0, -7 * s), Vector2(26 * s + 6, 0), Vector2(0, 7 * s), Vector2(6, 0)]), Color("#FFF2C2"))
			draw_colored_polygon(PackedVector2Array([Vector2(0, -11 * s), Vector2(16 * s, -3), Vector2(36 * s, 0), Vector2(16 * s, 3), Vector2(0, 11 * s)]), Color(1, 0.75, 0.3, 0.65))
		"shell":
			for p in parts:
				draw_set_transform(p[0], p[3], Vector2.ONE)
				draw_rect(Rect2(-3, -1.5, 6, 3), Color("#D9A63A", 1.0 - k * 0.5))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"dust":
			var dt := Sprites.fx_tex("puff1")
			if dt:
				for p in parts:
					var ds: Vector2 = Vector2(dt.get_size()) * (0.18 + k * 0.22) * (float(p[2]) / 6.0)
					draw_texture_rect(dt, Rect2(p[0] - ds * 0.5, ds), false, Color(1, 1, 1, 0.55 * (1.0 - k)))
				return
			for p in parts:
				draw_circle(p[0], p[2] * (1.0 + k), Color(0.85, 0.82, 0.75, 0.45 * (1.0 - k)))
		"print":
			var a := col.a * (1.0 - maxf(0.0, k - 0.6) / 0.4)
			var c := Color(col, a)
			var o: Vector2 = parts[0][0]
			draw_colored_polygon(Art.ellipse_pts(o, 4.5, 3.5, 10), c)
			for i in 3:
				draw_circle(o + Vector2(5, -3.5 + i * 3.5), 1.6, c)
			if col.r > 0.95 and col.g > 0.8:
				# 탈출 시 빛나는 발자국용
				draw_circle(o, 7, Color(1, 0.8, 0.4, a * 0.4))
		"swoosh":
			var a2 := 1.0 - k
			var st := Sprites.fx_tex("slash")
			if st:
				var ss := Vector2(st.get_size()) * (0.55 + k * 0.25)
				draw_set_transform(Vector2(28, 0), -0.6 + k * 1.2, Vector2.ONE)
				draw_texture_rect(st, Rect2(-ss * 0.5, ss), false, Color(1, 1, 1, a2))
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
				return
			draw_arc(Vector2.ZERO, 50, -1.0, 1.0, 16, Color(1, 1, 1, 0.65 * a2), 6 * a2 + 1, true)
			draw_arc(Vector2.ZERO, 40, -0.8, 0.8, 12, Color(1, 1, 1, 0.3 * a2), 3, true)
		"heal":
			var ht := Sprites.fx_tex("heal")
			if ht:
				for i in range(0, parts.size(), 3):
					var p: Array = parts[i]
					var hs := Vector2(ht.get_size()) * 0.28
					draw_texture_rect(ht, Rect2(p[0] - hs * 0.5, hs), false, Color(1, 1, 1, 1.0 - k))
				return
			for p in parts:
				var c2 := Color("#6CCB5F", 1.0 - k)
				draw_rect(Rect2(p[0] - Vector2(1.5, p[2]), Vector2(3, p[2] * 2)), c2)
				draw_rect(Rect2(p[0] - Vector2(p[2], 1.5), Vector2(p[2] * 2, 3)), c2)
		"fur":
			for p in parts:
				var c3 := Color(col, 1.0 - k)
				draw_colored_polygon(Art.ellipse_pts(p[0], p[2], p[2] * 0.6, 10, p[3]), c3)
				draw_colored_polygon(Art.ellipse_pts(p[0] + Vector2(1, -1), p[2] * 0.5, p[2] * 0.3, 8, p[3]), Color(1, 1, 1, 0.35 * (1.0 - k)))
		"boom":
			var bt := Sprites.fx_tex("explosion")
			if bt:
				var bs := Vector2(bt.get_size()) * (dir.x / 55.0) * (0.7 + k * 0.5)
				draw_texture_rect(bt, Rect2(Vector2(0, -bs.y * 0.35) - bs * 0.5, bs), false, Color(1, 1, 1, 1.0 - k * k))
			draw_arc(Vector2.ZERO, dir.x * (0.4 + k * 0.7), 0, TAU, 40, Color(1, 0.8, 0.5, 0.5 * (1.0 - k)), 4.0, true)
		"crater":
			var ct := Sprites.fx_tex("decal_scorch")
			if ct:
				var cs := Vector2(ct.get_size()) * 0.9
				draw_texture_rect(ct, Rect2(-cs * 0.5, cs), false, Color(1, 1, 1, 0.7 * (1.0 - maxf(0.0, k - 0.7) / 0.3)))
		"corpse":
			var a6 := 1.0 - maxf(0.0, (k - 0.7) / 0.3)
			var fr := Sprites.char_frame(text, "dead", 0)
			Sprites.draw_char(self, text, fr, Vector2.ZERO, Sprites.char_scale(text) * Sprites.char_info(text).h / 140.0, dir.x < 0, Color(col, a6))
		"fog":
			var pt := Sprites.fx_tex("smoke")
			if pt:
				var ps := Vector2(pt.get_size()) * (0.5 + k * 0.6)
				draw_texture_rect(pt, Rect2(Vector2(0, -10) - ps * 0.5, ps), false, Color(1, 1, 1, 0.85 * (1.0 - k)))
				return
			draw_circle(Vector2.ZERO, 20 + k * 40, Color(col, col.a * (1.0 - k)))
			draw_circle(Vector2(-14, 6), 14 + k * 30, Color(col, col.a * 0.7 * (1.0 - k)))
			draw_circle(Vector2(16, 4), 12 + k * 28, Color(col, col.a * 0.7 * (1.0 - k)))
		"spark":
			for p in parts:
				draw_line(p[0], p[0] - p[1].normalized() * 8.0, Color(col, 1.0 - k), p[2])
		"icon":
			var y := -k * 26.0
			var a3 := 1.0 - k * k
			match text:
				"hit":
					var it := Sprites.fx_tex("impact")
					if it:
						var hs2 := Vector2(it.get_size()) * 0.42 * (1.0 + (1.0 - k) * 0.3)
						draw_texture_rect(it, Rect2(Vector2(0, y * 0.4) - hs2 * 0.5, hs2), false, Color(1, 1, 1, a3))
					else:
						_star(Vector2(0, y), 9 * (1.0 + (1.0 - k) * 0.4), Color(1, 1, 1, a3))
				"crit":
					_star(Vector2(0, y), 13 * (1.0 + (1.0 - k) * 0.5), Color(DB.C_LEGEND, a3))
				"block":
					draw_circle(Vector2(0, y), 8, Color(DB.C_CONCRETE, a3))
				"alert":
					pass
		"text":
			var a4 := 1.0 - maxf(0.0, (k - 0.6) / 0.4)
			var y2 := -24.0 * minf(1.0, k * 3.0)
			var fnt := font()
			var w := fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_string_outline(fnt, Vector2(-w * 0.5, y2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, Color(0.1, 0.1, 0.13, a4))
			draw_string(fnt, Vector2(-w * 0.5, y2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(col, a4))
		"loot":
			var y3 := -50.0 * (1.0 - pow(1.0 - minf(1.0, k * 1.6), 3.0))
			var a5 := 1.0 - maxf(0.0, (k - 0.7) / 0.3)
			draw_circle(Vector2(0, y3), 22, Color(col, 0.28 * a5))
			draw_circle(Vector2(0, y3), 15, Color(col, 0.35 * a5))
			modulate.a = a5
			Art.draw_item_icon(self, item_id, Rect2(Vector2(-16, y3 - 16), Vector2(32, 32)))
		"ring":
			var r := dir.x * (0.3 + k * 0.7)
			draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(col, col.a * (1.0 - k)), 3.0, true)

func _star(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * i / 10.0) * rr)
	draw_colored_polygon(pts, color)
