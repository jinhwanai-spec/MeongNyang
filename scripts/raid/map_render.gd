class_name MapRender
extends Node2D
## 바닥·벽·장식물을 한 번에 그린다 (정적인 배경 레이어).

const T := DB.TILE
var font: Font
var baked_tex: Texture2D

static func h01(x: int, y: int, salt: int = 0) -> float:
	var n := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	return float(n & 0xFFFF) / 65535.0

func _ready() -> void:
	font = load("res://assets/fonts/NotoSansKR-Black.otf")
	if ResourceLoader.exists(BAKED):
		baked_tex = load(BAKED)
	z_index = -10
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

const BAKED := "res://assets/sprites/map/map.png"

func _draw() -> void:
	var W := LevelData.width()
	var H := LevelData.height()
	# 블렌더로 렌더한 3D 맵(격자에 맞춰 편 것)이 있으면 그것을 깐다
	if baked_tex:
		draw_texture_rect(baked_tex, Rect2(0, 0, W * T, H * T), false)
		return
	for y in H:
		for x in W:
			var c := LevelData.code(x, y)
			if c == "#":
				continue
			_draw_floor(x, y, LevelData.floor_code(x, y))
	_draw_markings()
	for y in H:
		for x in W:
			if LevelData.code(x, y) == "#":
				_draw_wall(x, y)
	_draw_storefront()
	# 장식물(진열대·자동차 등)은 Raid에서 블렌더 스프라이트로 배치한다

# ── 바닥 ─────────────────────────────────────────────
func _draw_floor(x: int, y: int, c: String) -> void:
	var r := Rect2(x * T, y * T, T, T)
	var hv := h01(x, y)
	match c:
		".", "-", "1", "h":
			draw_rect(r, Color("#383D48").lerp(Color("#3E4350"), hv))
			for i in 4:
				var p := r.position + Vector2(h01(x, y, i) * T, h01(x, y, i + 9) * T)
				draw_rect(Rect2(p, Vector2(2, 2)), Color(1, 1, 1, 0.05))
			if hv > 0.86:
				var p0 := r.position + Vector2(8, 10 + hv * 20)
				draw_polyline(PackedVector2Array([p0, p0 + Vector2(12, 6), p0 + Vector2(20, 2), p0 + Vector2(32, 10)]), Color(0, 0, 0, 0.35), 1.5)
			if c == "-":
				draw_rect(Rect2(r.position + Vector2(6, T * 0.5 - 3), Vector2(T - 12, 6)), Color("#C9A43A", 0.75))
		",", "2", "p":
			draw_rect(r, Color("#5A616E").lerp(Color("#616876"), hv))
			draw_rect(Rect2(r.position, Vector2(T, 2)), Color(0, 0, 0, 0.18))
			draw_rect(Rect2(r.position, Vector2(2, T)), Color(0, 0, 0, 0.18))
			draw_rect(Rect2(r.position + Vector2(0, T * 0.5), Vector2(T, 1)), Color(0, 0, 0, 0.1))
			if hv > 0.9:
				_grass_tuft(r.position + Vector2(hv * 30 + 6, 30), 0.8)
		"_":
			var checker := (x + y) % 2 == 0
			draw_rect(r, Color("#A9A08C") if checker else Color("#998F7B"))
			draw_rect(Rect2(r.position, Vector2(T, 1)), Color(0, 0, 0, 0.08))
			if hv > 0.88:
				draw_colored_polygon(Art.ellipse_pts(r.get_center() + Vector2(hv * 10 - 5, 4), 10 + hv * 6, 6, 14), Color(0.35, 0.28, 0.2, 0.18))
		"=":
			draw_rect(r, Color("#6B5844").lerp(Color("#735F49"), hv))
			for i in 3:
				draw_rect(Rect2(r.position + Vector2(0, i * 16), Vector2(T, 1.5)), Color(0, 0, 0, 0.25))
			draw_rect(Rect2(r.position + Vector2(fmod(hv * 97.0, T), 0), Vector2(1.5, 16)), Color(0, 0, 0, 0.2))
		"g":
			draw_rect(r, DB.C_GRASS.darkened(0.12 + hv * 0.08))
			for i in 3:
				_grass_tuft(r.position + Vector2(h01(x, y, i) * 40 + 4, h01(x, y, i + 4) * 40 + 6), 1.0)
			if hv > 0.8:
				var fp := r.position + Vector2(10 + hv * 20, 14)
				var fc: Color = [Color("#F29BB0"), Color("#F2C14E"), Color("#F3EEE6")][int(hv * 100) % 3]
				for k in 5:
					draw_circle(fp + Vector2.from_angle(TAU * k / 5.0) * 3.0, 2.2, fc)
				draw_circle(fp, 1.8, Color("#F2994A"))
		"m":
			draw_rect(r, Color("#4F3F2E").lerp(Color("#58473A"), hv))
			for i in 3:
				draw_colored_polygon(Art.ellipse_pts(r.position + Vector2(h01(x, y, i) * T, h01(x, y, i + 3) * T), 6 + hv * 6, 3 + hv * 3, 12), Color(0.2, 0.14, 0.1, 0.3))
		"w":
			_draw_floor(x, y, ".")
			var pc := r.get_center() + Vector2(hv * 6 - 3, 0)
			draw_colored_polygon(Art.ellipse_pts(pc, 22, 13, 20), Color("#2C3E5C", 0.85))
			draw_colored_polygon(Art.ellipse_pts(pc + Vector2(-2, -1), 17, 9, 20), Color("#3E5C8A", 0.7))
			draw_line(pc + Vector2(-10, -3), pc + Vector2(6, -6), Color(0.85, 0.45, 0.65, 0.55), 2)
			draw_line(pc + Vector2(-4, 3), pc + Vector2(10, 1), Color(0.6, 0.9, 1, 0.35), 1.5)
		_:
			draw_rect(r, Color("#383D48"))

func _grass_tuft(p: Vector2, s: float) -> void:
	var col := Color("#7FB069")
	draw_line(p, p + Vector2(-3, -7) * s, col, 1.6)
	draw_line(p, p + Vector2(0, -9) * s, col, 1.6)
	draw_line(p, p + Vector2(3, -7) * s, col, 1.6)

func _draw_markings() -> void:
	# 주차 칸 (북동쪽 주차장)
	for i in 6:
		var x := (39 + i * 3) * T
		draw_rect(Rect2(x, 13 * T + 6, 3, T * 2.6), Color(1, 1, 1, 0.35))
	# 횡단보도
	for i in 6:
		draw_rect(Rect2(28 * T + 6, (20 + i) * T + 8, T * 2 - 12, 22), Color(1, 1, 1, 0.22))

# ── 벽 ───────────────────────────────────────────────
func _wall_style(x: int, y: int) -> String:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var n := LevelData.code(x + d.x, y + d.y)
		if n == "_" or "SsFQCRMLV".contains(n):
			return "store"
		if n == "=" or n == "G" or n == "K":
			return "storage"
	return "concrete"

func _draw_wall(x: int, y: int) -> void:
	var r := Rect2(x * T, y * T, T, T)
	var below := LevelData.code(x, y + 1)
	var all_wall := true
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		if LevelData.code(x + d.x, y + d.y) != "#":
			all_wall = false
			break
	var style := _wall_style(x, y)
	var top: Color
	var face: Color
	match style:
		"store":
			top = Color("#E8E1D3"); face = Color("#B8AE9C")
		"storage":
			top = Color("#6E7C93"); face = Color("#4C586B")
		_:
			top = Color("#4A505E"); face = Color("#343945")
	if all_wall:
		# 지붕
		var hv := h01(x, y, 7)
		draw_rect(r, Color("#2A2E38").lerp(Color("#2F3440"), hv))
		draw_rect(Rect2(r.position, Vector2(T, 1)), Color(1, 1, 1, 0.03))
		if hv > 0.975:
			Art.rrect(self, Rect2(r.position + Vector2(8, 8), Vector2(30, 26)), Color("#8D96A3"), 3, 2)
			draw_circle(r.position + Vector2(23, 21), 9, Color("#4A505E"))
		elif hv < 0.05:
			draw_rect(Rect2(r.position + Vector2(10, 14), Vector2(26, 4)), Color(0, 0, 0, 0.3))
		return
	if below != "#":
		var face_h := 20.0
		draw_rect(Rect2(r.position, Vector2(T, T - face_h)), top)
		draw_rect(Rect2(r.position + Vector2(0, T - face_h), Vector2(T, face_h)), face)
		draw_rect(Rect2(r.position + Vector2(0, T - face_h), Vector2(T, 2)), Color(0, 0, 0, 0.25))
		if style == "concrete":
			for i in 2:
				draw_line(r.position + Vector2(0, T - face_h + 7 + i * 7), r.position + Vector2(T, T - face_h + 7 + i * 7), Color(0, 0, 0, 0.2), 1)
		elif style == "storage":
			for i in 6:
				draw_line(r.position + Vector2(i * 8 + 4, T - face_h), r.position + Vector2(i * 8 + 4, T), Color(0, 0, 0, 0.22), 1.5)
		else:
			draw_rect(Rect2(r.position + Vector2(0, T - face_h + 4), Vector2(T, 4)), DB.C_HERO)
		# 바닥에 드리우는 그림자
		draw_rect(Rect2(r.position + Vector2(0, T), Vector2(T, 10)), Color(0, 0, 0, 0.22))
	else:
		draw_rect(r, top)
	# 벽 윗면 테두리
	draw_rect(Rect2(r.position, Vector2(T, 3)), top.lightened(0.15))

func _draw_storefront() -> void:
	# 편의점 정면 유리창 (16행)
	for x in range(9, 37):
		if LevelData.code(x, 16) != "#" or x == 30:
			continue
		var r := Rect2(x * T + 3, 16 * T + 5, T - 6, T - 26)
		draw_rect(r, Color("#7FB3D5", 0.55))
		draw_line(r.position + Vector2(6, r.size.y - 4), r.position + Vector2(18, 4), Color(1, 1, 1, 0.45), 2)
		if MapRender.h01(x, 16, 3) > 0.7:
			draw_line(r.position + Vector2(10, 2), r.position + Vector2(30, r.size.y - 2), Color(0.1, 0.1, 0.12, 0.8), 1.5)
			draw_line(r.position + Vector2(20, 2), r.position + Vector2(8, r.size.y - 6), Color(0.1, 0.1, 0.12, 0.8), 1.5)
	# 네온 간판
	var sign_r := Rect2(18 * T, 16 * T - 30, T * 8, 30)
	Art.rrect(self, sign_r, Color("#1A1F2B"), 8, 3)
	if font:
		draw_string(font, sign_r.position + Vector2(18, 23), "멍냥마트 24", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#F29BB0"))
		draw_string(font, sign_r.position + Vector2(T * 6 - 2, 23), "OPEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#3FC1C9"))
	# 창고 표지
	if font:
		Art.rrect(self, Rect2(41 * T, 12 * T + 6, T * 2, 22), Color("#F2C14E"), 3, 2)
		draw_string(font, Vector2(41 * T + 8, 12 * T + 23), "창고 STAFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#1B1A22"))
		Art.rrect(self, Rect2(52 * T + 4, 3 * T + 8, T * 3 + 4, 24), Color("#D64545"), 3, 2)
		draw_string(font, Vector2(52 * T + 14, 3 * T + 26), "하역장 · 출구", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	# 가로등 (장식)
	for lx in [6, 17, 33, 45, 54]:
		var p := Vector2(lx * T + T * 0.5, 19 * T + 40)
		draw_rect(Rect2(p + Vector2(-3, -70), Vector2(6, 70)), Color("#2A2F3A"))
		draw_circle(p + Vector2(0, -74), 9, Color("#2A2F3A"))
		draw_circle(p + Vector2(0, -74), 6, Color("#FFE3A3"))

# ── 장식용 장애물 ────────────────────────────────────
func _draw_decor(x: int, y: int, c: String) -> void:
	var r := Rect2(x * T, y * T, T, T)
	match c:
		"s":
			_shelf(r, false)
		"Q":
			_fridge(r, false)
		"C":
			Art.rrect(self, Rect2(r.position + Vector2(-1, 4), Vector2(T + 2, T - 8)), Color("#8A5A3B"), 3, 2)
			draw_rect(Rect2(r.position + Vector2(0, 6), Vector2(T, 8)), Color("#A8774F"))
		"o":
			Art.rrect(self, Rect2(r.position + Vector2(4, 14), Vector2(40, 32)), Color("#A8774F"), 3)
			Art.rrect(self, Rect2(r.position + Vector2(10, -4), Vector2(30, 24)), Color("#B8875C"), 3)
			draw_line(r.position + Vector2(4, 30), r.position + Vector2(44, 30), Color(0, 0, 0, 0.25), 2)
			draw_line(r.position + Vector2(25, -4), r.position + Vector2(25, 20), Color(0, 0, 0, 0.25), 2)
		"f":
			draw_line(r.position + Vector2(T * 0.5, -8), r.position + Vector2(T * 0.5, T), Color("#2A2F3A"), 4)
			for i in 6:
				draw_line(r.position + Vector2(T * 0.5 - 14, i * 9 - 8), r.position + Vector2(T * 0.5 + 14, i * 9 + 1), Color("#9AA3B2", 0.7), 1.2)
				draw_line(r.position + Vector2(T * 0.5 + 14, i * 9 - 8), r.position + Vector2(T * 0.5 - 14, i * 9 + 1), Color("#9AA3B2", 0.7), 1.2)
			if LevelData.code(x, y + 1) == "f":
				draw_line(r.position + Vector2(T * 0.5, 0), r.position + Vector2(T * 0.5, T + 10), Color("#2A2F3A"), 2)
		"X":
			if LevelData.code(x - 1, y) != "X":
				_car(Rect2(r.position + Vector2(-4, -6), Vector2(T * 2 + 8, T + 10)), h01(x, y, 5))

func _shelf(r: Rect2, full: bool) -> void:
	Art.rrect(self, Rect2(r.position + Vector2(2, -10), Vector2(T - 4, T + 6)), Color("#8D96A3"), 3, 2)
	for i in 3:
		var yy := r.position.y - 4 + i * 16
		draw_rect(Rect2(r.position.x + 5, yy + 10, T - 10, 3), Color("#5A616E"))
		if full or h01(int(r.position.x), int(yy), 1) > 0.6:
			for k in 3:
				var col: Color = [Color("#D64545"), Color("#F2C14E"), Color("#3FC1C9"), Color("#5F8F4E")][int(h01(int(r.position.x) + k, int(yy), 2) * 4) % 4]
				draw_rect(Rect2(r.position.x + 7 + k * 12, yy, 9, 10), col)

func _fridge(r: Rect2, full: bool) -> void:
	Art.rrect(self, Rect2(r.position + Vector2(1, -14), Vector2(T - 2, T + 10)), Color("#D8DEE6"), 3, 2)
	draw_rect(Rect2(r.position + Vector2(5, -10), Vector2(T - 10, T)), Color("#3A5A78") if full else Color("#26303C"))
	for i in 3:
		draw_line(r.position + Vector2(6, -2 + i * 14), r.position + Vector2(T - 6, -2 + i * 14), Color(1, 1, 1, 0.25), 1)
	draw_line(r.position + Vector2(10, -8), r.position + Vector2(18, 30), Color(1, 1, 1, 0.3), 2)

func _car(r: Rect2, hv: float) -> void:
	var body: Color = [Color("#7A3B3B"), Color("#3E5C8A"), Color("#6B7280")][int(hv * 3.0) % 3]
	Art.shadow(self, r.get_center() + Vector2(4, r.size.y * 0.4), r.size.x * 0.52, 12, 0.4)
	Art.rrect(self, Rect2(r.position + Vector2(0, 14), Vector2(r.size.x, r.size.y - 18)), body, 12, 3)
	Art.rrect(self, Rect2(r.position + Vector2(r.size.x * 0.22, 2), Vector2(r.size.x * 0.55, r.size.y * 0.5)), body.darkened(0.15), 10, 3)
	draw_rect(Rect2(r.position + Vector2(r.size.x * 0.27, 7), Vector2(r.size.x * 0.2, r.size.y * 0.3)), Color("#8FB3C9", 0.7))
	draw_rect(Rect2(r.position + Vector2(r.size.x * 0.52, 7), Vector2(r.size.x * 0.2, r.size.y * 0.3)), Color("#2B303A", 0.9))
	for wx in [0.2, 0.8]:
		Art.blob(self, r.position + Vector2(r.size.x * wx, r.size.y - 4), 9, 6, Color("#1B1A22"), 0)
	# 녹·이끼
	draw_colored_polygon(Art.ellipse_pts(r.position + Vector2(r.size.x * 0.8, r.size.y * 0.5), 10, 6, 12), Color("#8A5A3B", 0.6))
	draw_colored_polygon(Art.ellipse_pts(r.position + Vector2(r.size.x * 0.15, r.size.y * 0.55), 8, 4, 12), Color("#5F8F4E", 0.7))
