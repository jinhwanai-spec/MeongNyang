class_name Art
extends RefCounted
## 코드로 그리는 카툰 아트. 2~3등신 둥근 동물 + 두꺼운 외곽선.
## 나중에 직접 만든 스프라이트로 바꾸려면 이 함수들을 호출하는 곳만 교체하면 된다.

const OUTLINE := Color("#1B1A22")
const OL := 2.5

# ── 기본 도형 ────────────────────────────────────────
static func ellipse_pts(c: Vector2, rx: float, ry: float, n: int = 28, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var p := Vector2(cos(a) * rx, sin(a) * ry)
		pts.append(c + p.rotated(rot))
	return pts

static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
	ci.draw_colored_polygon(ellipse_pts(c, rx, ry, 28, rot), col)

static func blob(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, ol: float = OL, rot: float = 0.0) -> void:
	if ol > 0.0:
		ellipse(ci, c, rx + ol, ry + ol, OUTLINE, rot)
	ellipse(ci, c, rx, ry, col, rot)

static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, ol: float = OL) -> void:
	if ol > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, OUTLINE, ol * 2.0, true)
	ci.draw_colored_polygon(pts, col)

static func rrect(ci: CanvasItem, r: Rect2, col: Color, radius: float = 4.0, ol: float = OL) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	if ol > 0.0:
		sb.border_color = OUTLINE
		sb.set_border_width_all(int(ol))
		sb.draw(ci.get_canvas_item(), r.grow(ol * 0.5))
	else:
		sb.draw(ci.get_canvas_item(), r)

static func shadow(ci: CanvasItem, c: Vector2, rx: float, ry: float, a: float = 0.32) -> void:
	ellipse(ci, c, rx, ry, Color(0, 0, 0, a))

static func eye(ci: CanvasItem, c: Vector2, r: float, iris: Color, closed: bool = false, angry: bool = false, f: float = 1.0) -> void:
	if closed:
		ci.draw_arc(c + Vector2(0, -1), r, 0.2, PI - 0.2, 10, OUTLINE, 2.5, true)
		return
	ci.draw_circle(c, r + 1.2, OUTLINE)
	ci.draw_circle(c, r, iris)
	ci.draw_circle(c + Vector2(f * r * 0.15, 0), r * 0.55, OUTLINE)
	ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.4), r * 0.35, Color(1, 1, 1, 0.95))
	if angry:
		ci.draw_line(c + Vector2(-f * r * 1.4, -r * 1.7), c + Vector2(f * r * 1.2, -r * 0.9), OUTLINE, 3.0, true)

static func darker(c: Color, k: float = 0.2) -> Color:
	return c.darkened(k)

static func lighter(c: Color, k: float = 0.25) -> Color:
	return c.lightened(k)

# ── 주인공 (멍멍 용병) ───────────────────────────────
## f: 바라보는 방향(1=오른쪽,-1=왼쪽), walk: 걷기 위상, moving: 이동 중, mood: "", "hurt", "happy", "focus"
static func draw_hero(ci: CanvasItem, f: float, walk: float, moving: bool, flash: float, mood: String = "", species: String = "dog") -> void:
	var fur := DB.C_HERO
	var belly := Color("#FFE1BE")
	var bob := absf(sin(walk * 2.0)) * -3.0 if moving else sin(walk * 0.5) * -0.8
	shadow(ci, Vector2(0, 0), 20, 7)
	# 발
	var step := sin(walk * 2.0) * 5.0 if moving else 0.0
	blob(ci, Vector2(-7 + step, -3), 6, 4.5, darker(fur, 0.15))
	blob(ci, Vector2(7 - step, -3), 6, 4.5, darker(fur, 0.15))
	# 꼬리
	var tw := sin(walk * 3.0) * 0.25
	if species == "dog":
		var tc := Vector2(-f * 15, -22 + bob)
		ci.draw_arc(tc, 7, PI * 0.9 + tw, PI * 2.4 + tw, 14, OUTLINE, 9, true)
		ci.draw_arc(tc, 7, PI * 0.9 + tw, PI * 2.4 + tw, 14, fur, 5, true)
	else:
		var pts := PackedVector2Array([Vector2(-f * 10, -14 + bob), Vector2(-f * 22, -18 + bob), Vector2(-f * 26, -32 + bob + tw * 10)])
		ci.draw_polyline(pts, OUTLINE, 8, true)
		ci.draw_polyline(pts, fur, 4.5, true)
	# 배낭 (등 쪽)
	rrect(ci, Rect2(Vector2(-f * 13 - 9, -34 + bob), Vector2(18, 20)), Color("#6E7B4A"), 5)
	rrect(ci, Rect2(Vector2(-f * 13 - 7, -24 + bob), Vector2(14, 7)), Color("#5A6539"), 3, 1.5)
	# 몸통
	blob(ci, Vector2(0, -17 + bob), 13, 13, fur)
	ellipse(ci, Vector2(f * 3, -14 + bob), 8, 8.5, belly)
	# 전술 조끼
	rrect(ci, Rect2(Vector2(-11, -25 + bob), Vector2(22, 11)), Color("#3B4252"), 3, 1.5)
	ci.draw_rect(Rect2(Vector2(f * 2 - 3, -23 + bob), Vector2(6, 5)), Color("#F2C14E"))
	# 머리
	var hc := Vector2(f * 2, -40 + bob)
	if species == "dog":
		pass
	else:
		poly(ci, PackedVector2Array([hc + Vector2(-14, -4), hc + Vector2(-12, -24), hc + Vector2(-2, -13)]), fur)
		poly(ci, PackedVector2Array([hc + Vector2(14, -4), hc + Vector2(12, -24), hc + Vector2(2, -13)]), fur)
	blob(ci, hc, 16, 14.5, fur)
	if species == "dog":
		# 늘어진 귀
		var ear := darker(fur, 0.28)
		blob(ci, hc + Vector2(-f * 13, 0), 6, 11, ear, OL, f * 0.35)
		blob(ci, hc + Vector2(f * 10, -6), 5, 9, ear, OL, -f * 0.6)
	ellipse(ci, hc + Vector2(f * 7, 5), 9, 6.5, belly)
	ellipse(ci, hc + Vector2(-f * 6, 6), 5, 3.5, Color("#FFB3A0", 0.55))
	# 헤드셋
	ci.draw_arc(hc + Vector2(0, -2), 15, PI * 1.12, PI * 1.88, 16, Color("#2A2F3A"), 4, true)
	blob(ci, hc + Vector2(-f * 8, -11), 3.5, 4, Color("#3B4252"), 1.5)
	# 코·입
	var nose := hc + Vector2(f * 13.5, 1.5)
	ellipse(ci, nose, 3.3, 2.5, OUTLINE)
	ci.draw_circle(nose + Vector2(-f * 0.8, -0.9), 0.9, Color(1, 1, 1, 0.6))
	var hurt := mood == "hurt"
	eye(ci, hc + Vector2(f * 6, -3), 4.2, Color("#3A2A20"), mood == "happy", false, f)
	var mc := hc + Vector2(f * 11.5, 5.5)
	if hurt:
		ci.draw_line(hc + Vector2(f * 2, -9), hc + Vector2(f * 10, -7), OUTLINE, 2.2, true)
		ci.draw_arc(mc + Vector2(-f * 1, 3), 2.6, PI * 1.15, PI * 1.85, 8, OUTLINE, 1.6, true)
	elif mood == "happy":
		ellipse(ci, mc + Vector2(-f * 1.5, 2), 3, 2.6, Color("#C0504D"))
		ci.draw_arc(mc + Vector2(-f * 1.5, 0.5), 3, 0.15, PI - 0.15, 8, OUTLINE, 1.4, true)
	else:
		ci.draw_arc(mc + Vector2(-f * 1.0, 0.0), 2.4, 0.5, PI - 0.5, 8, Color(OUTLINE, 0.75), 1.1, true)
	if flash > 0.0:
		ellipse(ci, Vector2(0, -26 + bob), 22, 30, Color(1, 1, 1, flash * 0.85))

# ── 적: 하이에나 ─────────────────────────────────────
static func draw_hyena(ci: CanvasItem, f: float, walk: float, moving: bool, flash: float, angry: bool, eye_col: Color) -> void:
	var fur := Color("#B9935A")
	var dark := Color("#6B5233")
	var bob := absf(sin(walk * 2.4)) * -3.0 if moving else 0.0
	shadow(ci, Vector2(0, 0), 20, 6)
	var step := sin(walk * 2.4) * 6.0 if moving else 0.0
	for sx in [-10.0, -3.0, 5.0, 12.0]:
		var s := step if int(sx) % 2 == 0 else -step
		ci.draw_line(Vector2(sx, -12 + bob), Vector2(sx + s * 0.4, -3), OUTLINE, 7, true)
		ci.draw_line(Vector2(sx, -12 + bob), Vector2(sx + s * 0.4, -3), dark, 4, true)
		ellipse(ci, Vector2(sx + s * 0.4 + 1, -2), 3.5, 2.2, Color("#3A2E22"))
	# 꼬리 (털뭉치)
	blob(ci, Vector2(-f * 18, -20 + bob), 5, 4, dark)
	# 몸통 (앞이 높은 구부정 자세)
	blob(ci, Vector2(0, -17 + bob), 15, 9, fur, OL, -f * 0.25)
	for i in 4:
		ci.draw_circle(Vector2(-f * 8 + f * i * 5, -19 + bob + (i % 2) * 4), 2.2, dark)
	# 갈기
	ci.draw_line(Vector2(-f * 8, -26 + bob), Vector2(f * 8, -30 + bob), dark, 4, true)
	var hc := Vector2(f * 13, -28 + bob)
	blob(ci, hc + Vector2(-f * 4, -11), 4.5, 5.5, fur)
	blob(ci, hc + Vector2(f * 3, -12), 4.5, 5.5, fur)
	ci.draw_circle(hc + Vector2(-f * 4, -11), 2.4, Color("#4A3A28"))
	blob(ci, hc, 11, 9.5, fur)
	blob(ci, hc + Vector2(f * 9, 3), 6, 4.5, Color("#5C4630"), 1.5)
	ci.draw_circle(hc + Vector2(f * 14, 2), 2.2, OUTLINE)
	eye(ci, hc + Vector2(f * 3, -2), 3.2, eye_col, false, angry, f)
	if angry:
		ci.draw_line(hc + Vector2(f * 5, 7), hc + Vector2(f * 12, 6), Color.WHITE, 2, true)
	if flash > 0.0:
		ellipse(ci, Vector2(0, -20), 24, 18, Color(1, 1, 1, flash * 0.85))

# ── 적: 망치 불독 ────────────────────────────────────
static func draw_bulldog(ci: CanvasItem, f: float, walk: float, moving: bool, flash: float, angry: bool, eye_col: Color) -> void:
	var fur := Color("#B07A4F")
	var light := Color("#EBD6BE")
	var bob := absf(sin(walk * 1.6)) * -2.5 if moving else 0.0
	shadow(ci, Vector2(0, 0), 27, 9)
	var step := sin(walk * 1.6) * 5.0 if moving else 0.0
	blob(ci, Vector2(-11 + step, -4), 8, 5.5, darker(fur))
	blob(ci, Vector2(11 - step, -4), 8, 5.5, darker(fur))
	# 넓은 몸통 + 방탄 조끼
	blob(ci, Vector2(0, -24 + bob), 21, 18, fur)
	ellipse(ci, Vector2(f * 3, -20 + bob), 13, 12, light)
	rrect(ci, Rect2(Vector2(-17, -36 + bob), Vector2(34, 16)), Color("#4B5A3A"), 5, 2)
	ci.draw_line(Vector2(-13, -30 + bob), Vector2(13, -30 + bob), Color("#3A4630"), 2)
	# 가시 목걸이
	var hc := Vector2(f * 3, -49 + bob)
	ci.draw_arc(hc + Vector2(0, 7), 15, 0.15, PI - 0.15, 12, Color("#D64545"), 5, true)
	for i in 5:
		var a := 0.4 + i * 0.6
		ci.draw_circle(hc + Vector2(cos(a) * 15, 7 + sin(a) * 15), 2.2, Color("#D8D8D8"))
	# 머리 (넓적한 얼굴 + 늘어진 볼살 + 주걱턱)
	var mask := darker(fur, 0.35)
	poly(ci, PackedVector2Array([hc + Vector2(-20, -8), hc + Vector2(-17, -19), hc + Vector2(-9, -12)]), mask)
	poly(ci, PackedVector2Array([hc + Vector2(20, -8), hc + Vector2(17, -19), hc + Vector2(9, -12)]), mask)
	blob(ci, hc, 21, 14, fur)
	# 이마 주름
	for i in 3:
		ci.draw_arc(hc + Vector2(f * 3, -6 + i * 3.5), 7 - i, PI * 1.2, PI * 1.8, 8, darker(fur, 0.3), 1.6, true)
	# 볼살
	blob(ci, hc + Vector2(f * 3 - 9, 8), 9, 7, light, 2)
	blob(ci, hc + Vector2(f * 3 + 9, 8), 9, 7, light, 2)
	# 아래턱 + 이빨
	blob(ci, hc + Vector2(f * 3, 13), 8, 4.5, Color("#5C2E2E"), 2)
	ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(f * 3 - 6, 12), hc + Vector2(f * 3 - 4, 5), hc + Vector2(f * 3 - 2, 12)]), Color.WHITE)
	ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(f * 3 + 2, 12), hc + Vector2(f * 3 + 4, 5), hc + Vector2(f * 3 + 6, 12)]), Color.WHITE)
	# 코
	blob(ci, hc + Vector2(f * 3, 1), 5, 3.5, OUTLINE, 0)
	ci.draw_circle(hc + Vector2(f * 3 - 1.5, 0), 1, Color(1, 1, 1, 0.5))
	eye(ci, hc + Vector2(f * 3 - 9, -5), 3.4, eye_col, false, true, f)
	eye(ci, hc + Vector2(f * 3 + 9, -5), 3.4, eye_col, false, true, -f)
	if flash > 0.0:
		ellipse(ci, Vector2(0, -32), 30, 32, Color(1, 1, 1, flash * 0.85))

static func draw_hammer(ci: CanvasItem) -> void:
	# 원점 = 손잡이 끝, +x 방향으로 뻗음
	ci.draw_line(Vector2(0, 0), Vector2(34, 0), OUTLINE, 7, true)
	ci.draw_line(Vector2(0, 0), Vector2(34, 0), Color("#9C6B3E"), 4, true)
	rrect(ci, Rect2(Vector2(28, -11), Vector2(14, 22)), Color("#8D96A3"), 3)
	ci.draw_rect(Rect2(Vector2(30, -9), Vector2(3, 18)), Color("#B9C1CC"))

# ── 적: 석궁 고양이 ──────────────────────────────────
static func draw_cat(ci: CanvasItem, f: float, walk: float, moving: bool, flash: float, angry: bool, eye_col: Color) -> void:
	var fur := DB.C_CAT
	var hood := Color("#2B3A55")
	var bob := absf(sin(walk * 2.0)) * -2.5 if moving else sin(walk * 0.6) * -0.6
	shadow(ci, Vector2(0, 0), 17, 6)
	var step := sin(walk * 2.0) * 5.0 if moving else 0.0
	blob(ci, Vector2(-6 + step, -3), 5, 4, darker(fur, 0.1))
	blob(ci, Vector2(6 - step, -3), 5, 4, darker(fur, 0.1))
	# 긴 꼬리
	var tw := sin(walk * 1.5) * 4.0
	var tail := PackedVector2Array([Vector2(-f * 8, -10 + bob), Vector2(-f * 20, -12 + bob), Vector2(-f * 25, -26 + bob + tw), Vector2(-f * 20, -36 + bob + tw)])
	ci.draw_polyline(tail, OUTLINE, 8, true)
	ci.draw_polyline(tail, fur, 4.5, true)
	# 몸통 (가는 허리) + 후드 망토
	blob(ci, Vector2(0, -16 + bob), 10, 12, hood)
	ellipse(ci, Vector2(f * 2, -14 + bob), 5, 7, lighter(fur, 0.35))
	# 스카프
	ci.draw_line(Vector2(-9, -27 + bob), Vector2(9, -27 + bob), OUTLINE, 7, true)
	ci.draw_line(Vector2(-9, -27 + bob), Vector2(9, -27 + bob), Color("#D64545"), 4, true)
	ci.draw_line(Vector2(-f * 6, -27 + bob), Vector2(-f * 12, -18 + bob + tw * 0.4), Color("#D64545"), 4, true)
	var hc := Vector2(f * 2, -39 + bob)
	poly(ci, PackedVector2Array([hc + Vector2(-13, -2), hc + Vector2(-12, -23), hc + Vector2(-1, -12)]), hood)
	poly(ci, PackedVector2Array([hc + Vector2(13, -2), hc + Vector2(12, -23), hc + Vector2(1, -12)]), hood)
	ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(-10, -8), hc + Vector2(-10, -18), hc + Vector2(-4, -11)]), Color("#8FA3C7"))
	ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(10, -8), hc + Vector2(10, -18), hc + Vector2(4, -11)]), Color("#8FA3C7"))
	blob(ci, hc, 14, 12.5, fur)
	# 후드 테두리
	ci.draw_arc(hc, 14.5, PI * 1.05, PI * 1.95, 14, hood, 5, true)
	ellipse(ci, hc + Vector2(f * 5, 5), 6, 4, lighter(fur, 0.4))
	ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(f * 9, 2), hc + Vector2(f * 12, 2), hc + Vector2(f * 10.5, 4.5)]), Color("#F29BB0"))
	# 수염
	for i in 2:
		ci.draw_line(hc + Vector2(f * 11, 5 + i * 3), hc + Vector2(f * 20, 3 + i * 5), Color(1, 1, 1, 0.7), 1.2, true)
	# 가늘게 뜬 눈
	var ec := hc + Vector2(f * 4, -3)
	ci.draw_circle(ec, 4.4, OUTLINE)
	ci.draw_circle(ec, 3.4, eye_col)
	ci.draw_line(ec + Vector2(0, -3), ec + Vector2(0, 3), OUTLINE, 1.8)
	if angry:
		ci.draw_line(ec + Vector2(-f * 5, -7), ec + Vector2(f * 5, -4), OUTLINE, 2.5, true)
	if flash > 0.0:
		ellipse(ci, Vector2(0, -24), 20, 28, Color(1, 1, 1, flash * 0.85))

# ── 무기 (원점=손, +x=조준 방향) ─────────────────────
static func draw_weapon(ci: CanvasItem, id: String) -> void:
	match id:
		"pistol":
			rrect(ci, Rect2(Vector2(2, -4), Vector2(20, 8)), Color("#3B4252"), 2)
			rrect(ci, Rect2(Vector2(2, 0), Vector2(7, 10)), Color("#5A4636"), 2, 2)
			ci.draw_rect(Rect2(Vector2(5, -3), Vector2(15, 2)), Color("#6C778A"))
			ci.draw_circle(Vector2(20, -5), 1.6, Color("#F2994A"))
		"shotgun":
			rrect(ci, Rect2(Vector2(-6, -4), Vector2(14, 9)), Color("#7A4E2D"), 3)
			rrect(ci, Rect2(Vector2(6, -5), Vector2(32, 7)), Color("#3B4252"), 2)
			rrect(ci, Rect2(Vector2(12, 1), Vector2(14, 6)), Color("#9C6B3E"), 2, 2)
			ci.draw_rect(Rect2(Vector2(8, -4), Vector2(28, 2)), Color("#6C778A"))
		"crossbow":
			rrect(ci, Rect2(Vector2(-2, -3), Vector2(28, 7)), Color("#8D96A3"), 2)
			ci.draw_rect(Rect2(Vector2(0, -2), Vector2(24, 2)), Color("#B9C1CC"))
			ci.draw_arc(Vector2(22, 0), 13, -PI * 0.5, PI * 0.5, 12, OUTLINE, 6, true)
			ci.draw_arc(Vector2(22, 0), 13, -PI * 0.5, PI * 0.5, 12, Color("#D64545"), 3, true)
			ci.draw_line(Vector2(22, -13), Vector2(10, 0), Color(1, 1, 1, 0.8), 1.2)
			ci.draw_line(Vector2(22, 13), Vector2(10, 0), Color(1, 1, 1, 0.8), 1.2)
			ci.draw_line(Vector2(10, 0), Vector2(34, 0), Color("#F2C14E"), 2)
		"melee":
			ci.draw_line(Vector2(0, 0), Vector2(36, 0), OUTLINE, 8, true)
			ci.draw_line(Vector2(0, 0), Vector2(36, 0), Color("#9AA3B2"), 5, true)
			ci.draw_line(Vector2(0, 0), Vector2(9, 0), Color("#D64545"), 5, true)
		"enemy_crossbow":
			rrect(ci, Rect2(Vector2(-2, -3), Vector2(24, 6)), Color("#5C4630"), 2)
			ci.draw_arc(Vector2(20, 0), 11, -PI * 0.5, PI * 0.5, 12, OUTLINE, 5, true)
			ci.draw_arc(Vector2(20, 0), 11, -PI * 0.5, PI * 0.5, 12, Color("#B9C1CC"), 2.5, true)
			ci.draw_line(Vector2(8, 0), Vector2(30, 0), Color("#D64545"), 2)

# ── 아이템 아이콘 (rect 안에 맞춰 그림) ──────────────
static func draw_item_icon(ci: CanvasItem, id: String, r: Rect2) -> void:
	if Sprites.draw_item(ci, id, r):
		return
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y) / 48.0
	if DB.ITEMS.has(id):
		var it: Dictionary = DB.ITEMS[id]
		s = minf(r.size.x / (float(it.w) * 48.0), r.size.y / (float(it.h) * 48.0))
	match id:
		"canned_food":
			rrect(ci, Rect2(c + Vector2(-13, -11) * s, Vector2(26, 22) * s), Color("#C9D1DA"), 4)
			ci.draw_rect(Rect2(c + Vector2(-13, -5) * s, Vector2(26, 10) * s), Color("#3E5C8A"))
			ci.draw_circle(c + Vector2(0, 0) * s, 3.5 * s, Color("#F2994A"))
		"kibble":
			rrect(ci, Rect2(c + Vector2(-13, -30) * s, Vector2(26, 58) * s), Color("#C0392B"), 6)
			ci.draw_circle(c + Vector2(0, -6) * s, 8 * s, Color("#F3EEE6"))
			ci.draw_circle(c + Vector2(-2, -8) * s, 2.5 * s, Color("#8A5A3B"))
			ci.draw_circle(c + Vector2(3, -4) * s, 2.5 * s, Color("#8A5A3B"))
			ci.draw_rect(Rect2(c + Vector2(-13, -30) * s, Vector2(26, 6) * s), Color("#922B21"))
		"churu":
			poly(ci, PackedVector2Array([c + Vector2(-5, -16) * s, c + Vector2(5, -16) * s, c + Vector2(7, 16) * s, c + Vector2(-7, 16) * s]), Color("#F29BB0"))
			ci.draw_rect(Rect2(c + Vector2(-6, -2) * s, Vector2(12, 7) * s), Color("#FFFFFF"))
		"energy_drink":
			rrect(ci, Rect2(c + Vector2(-8, -16) * s, Vector2(16, 32) * s), Color("#3FC1C9"), 4)
			poly(ci, PackedVector2Array([c + Vector2(2, -10) * s, c + Vector2(-4, 1) * s, c + Vector2(1, 1) * s, c + Vector2(-2, 10) * s, c + Vector2(5, -2) * s, c + Vector2(0, -2) * s]), Color("#F2C14E"), 1.0)
		"bandage":
			rrect(ci, Rect2(c + Vector2(-15, -8) * s, Vector2(30, 16) * s), Color("#F3EEE6"), 6)
			ci.draw_rect(Rect2(c + Vector2(-4, -8) * s, Vector2(8, 16) * s), Color("#E8C8B0"))
		"medkit":
			rrect(ci, Rect2(c + Vector2(-26, -20) * s, Vector2(52, 42) * s), Color("#F3EEE6"), 6)
			ci.draw_rect(Rect2(c + Vector2(-5, -14) * s, Vector2(10, 28) * s), Color("#D64545"))
			ci.draw_rect(Rect2(c + Vector2(-14, -5) * s, Vector2(28, 10) * s), Color("#D64545"))
			ci.draw_rect(Rect2(c + Vector2(-8, -26) * s, Vector2(16, 6) * s), Color("#6B7280"))
		"screws":
			for i in 3:
				var p := c + Vector2(-8 + i * 8, -4 + (i % 2) * 8) * s
				ci.draw_line(p, p + Vector2(4, 9) * s, OUTLINE, 5 * s, true)
				ci.draw_line(p, p + Vector2(4, 9) * s, Color("#B9C1CC"), 3 * s, true)
				ci.draw_circle(p, 4 * s, Color("#8D96A3"))
		"pipe":
			rrect(ci, Rect2(c + Vector2(-6, -60) * s, Vector2(12, 120) * s), Color("#8D96A3"), 4)
			ci.draw_rect(Rect2(c + Vector2(-3, -58) * s, Vector2(3, 116) * s), Color("#C9D1DA"))
		"rope":
			ci.draw_arc(c, 11 * s, 0, TAU, 20, OUTLINE, 7 * s, true)
			ci.draw_arc(c, 11 * s, 0, TAU, 20, Color("#F2C14E"), 4 * s, true)
			ci.draw_arc(c, 6 * s, 0, TAU, 16, Color("#D9A63A"), 3 * s, true)
		"spring":
			for i in 5:
				ci.draw_arc(c + Vector2(0, -12 + i * 6) * s, 9 * s, PI, TAU, 10, Color("#B9C1CC"), 3 * s, true)
		"duct_tape":
			ci.draw_circle(c, 14 * s, OUTLINE)
			ci.draw_circle(c, 12 * s, Color("#9AA3B2"))
			ci.draw_circle(c, 6 * s, Color("#2B303A"))
		"battery":
			rrect(ci, Rect2(c + Vector2(-8, -14) * s, Vector2(16, 28) * s), Color("#2B303A"), 3)
			ci.draw_rect(Rect2(c + Vector2(-8, -14) * s, Vector2(16, 9) * s), Color("#F2C14E"))
			ci.draw_rect(Rect2(c + Vector2(-3, -17) * s, Vector2(6, 3) * s), Color("#B9C1CC"))
		"circuit":
			rrect(ci, Rect2(c + Vector2(-16, -38) * s, Vector2(32, 76) * s), Color("#2E7D4F"), 3)
			for i in 4:
				ci.draw_line(c + Vector2(-10, -28 + i * 18) * s, c + Vector2(10, -24 + i * 18) * s, Color("#F2C14E"), 2 * s)
				ci.draw_rect(Rect2(c + Vector2(-6, -20 + i * 18) * s, Vector2(10, 6) * s), Color("#1B1A22"))
		"toy_mouse":
			blob(ci, c + Vector2(2, 2) * s, 12 * s, 8 * s, Color("#9AA3B2"))
			ci.draw_circle(c + Vector2(-6, -6) * s, 4 * s, Color("#F29BB0"))
			ci.draw_line(c + Vector2(14, 2) * s, c + Vector2(20, -6) * s, Color("#F29BB0"), 2 * s)
			ci.draw_circle(c + Vector2(-7, 1) * s, 1.6 * s, OUTLINE)
		"catnip":
			rrect(ci, Rect2(c + Vector2(-40, -16) * s, Vector2(80, 32) * s), Color("#5F8F4E"), 5)
			for i in 3:
				ci.draw_colored_polygon(ellipse_pts(c + Vector2(-18 + i * 18, 0) * s, 7 * s, 4 * s, 12, 0.6), Color("#A8D08D"))
		"silver_bell":
			ci.draw_circle(c + Vector2(0, 2) * s, 12 * s, OUTLINE)
			ci.draw_circle(c + Vector2(0, 2) * s, 10 * s, Color("#D8DEE6"))
			ci.draw_line(c + Vector2(-8, 4) * s, c + Vector2(8, 4) * s, Color("#6B7280"), 2 * s)
			ci.draw_circle(c + Vector2(-3, -2) * s, 3 * s, Color.WHITE)
		"lucky_coin":
			ci.draw_circle(c, 13 * s, OUTLINE)
			ci.draw_circle(c, 11 * s, Color("#F2C14E"))
			ci.draw_circle(c, 7 * s, Color("#D9A63A"))
			ci.draw_circle(c + Vector2(-3, -3) * s, 2 * s, Color("#FFF2C2"))
		"old_camera":
			rrect(ci, Rect2(c + Vector2(-30, -20) * s, Vector2(60, 40) * s), Color("#E8DCC8"), 6)
			ci.draw_circle(c + Vector2(0, 3) * s, 13 * s, OUTLINE)
			ci.draw_circle(c + Vector2(0, 3) * s, 10 * s, Color("#3E5C8A"))
			ci.draw_circle(c + Vector2(-3, 0) * s, 3 * s, Color("#8FC1E3"))
			ci.draw_rect(Rect2(c + Vector2(14, -16) * s, Vector2(10, 6) * s), Color("#D64545"))
		"gold_collar":
			ci.draw_arc(c, 13 * s, 0, TAU, 24, OUTLINE, 8 * s, true)
			ci.draw_arc(c, 13 * s, 0, TAU, 24, Color("#F2C14E"), 5 * s, true)
			ci.draw_circle(c + Vector2(0, 13) * s, 5 * s, Color("#3FC1C9"))
		"ammo_pistol", "ammo_shell", "ammo_bolt":
			var col := Color("#D9A63A") if id == "ammo_pistol" else (Color("#D64545") if id == "ammo_shell" else Color("#9C6B3E"))
			for i in 3:
				var p := c + Vector2(-9 + i * 9, 0) * s
				if id == "ammo_bolt":
					ci.draw_line(p + Vector2(0, 12) * s, p + Vector2(0, -12) * s, col, 3 * s)
					ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -10) * s, p + Vector2(3, -10) * s, p + Vector2(0, -16) * s]), Color("#B9C1CC"))
				else:
					rrect(ci, Rect2(p + Vector2(-3.5, -8) * s, Vector2(7, 18) * s), col, 2, 1.5)
					ci.draw_rect(Rect2(p + Vector2(-3.5, 6) * s, Vector2(7, 4) * s), Color("#B9C1CC"))
		_:
			rrect(ci, r.grow(-6), Color("#6B7280"), 4)

static func draw_weapon_icon(ci: CanvasItem, id: String, c: Vector2, scale_k: float = 1.4) -> void:
	var tex := Sprites.icon_tex("w_" + id)
	if tex == null:
		tex = Sprites.weapon_tex("hamster", id)
	if tex:
		var ts := Vector2(tex.get_size())
		var k := (46.0 * scale_k) / maxf(ts.x, ts.y * 2.2)
		ci.draw_texture_rect(tex, Rect2(c - ts * k * 0.5, ts * k), false)
		return
	ci.draw_set_transform(c - Vector2(16, 0) * scale_k, 0.0, Vector2(scale_k, scale_k))
	draw_weapon(ci, id)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
