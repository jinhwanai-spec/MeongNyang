class_name HideoutArt
extends Control
## 은신처 일러스트: 따뜻한 조명의 지하 은신처, 작업대·라디오·잠자리와 주인공

var t := 0.0
var font: Font

func _ready() -> void:
	font = UITheme.black()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

const BG := "res://assets/sprites/hideout.png"
var bg_tex: Texture2D

## 블렌더로 렌더한 은신처 방 배경 (1176x1190 기준 좌표를 패널 좌표로)
func _draw_baked(s: Vector2) -> void:
	var ts := Vector2(bg_tex.get_size())
	var k := maxf(s.x / ts.x, s.y / ts.y)
	var off := (s - ts * k) * 0.5
	draw_texture_rect(bg_tex, Rect2(off, ts * k), false)
	var P := func(x: float, y: float) -> Vector2: return off + Vector2(x, y) * k
	# 포스터 (벽의 노란 판)
	var pc: Vector2 = P.call(686, 236)
	Sprites.draw_char(self, "hamster", Sprites.char_frame("hamster", "portrait_happy", 0), pc + Vector2(0, 40 * k * 2), 0.5 * k * 2)
	# 무전기 깜빡임
	var rp: Vector2 = P.call(1005, 384)
	draw_circle(rp, 4.0 * k * 2, DB.C_DANGER if fmod(t, 1.2) < 0.6 else Color(0, 0, 0, 0))
	# 전구 빛
	var bulb: Vector2 = P.call(630, 330)
	for r in [240.0, 160.0, 90.0]:
		draw_circle(bulb, r * k * 2, Color(1, 0.8, 0.45, 0.04))
	# 물자 (시트 소품)
	Sprites.draw_sprop(self, "ammo_locker", P.call(1110, 640), Color(0.85, 0.8, 0.75), 1.5)
	Sprites.draw_sprop(self, "crate", P.call(980, 1050), Color(0.9, 0.85, 0.8), 1.6)
	Sprites.draw_sprop(self, "crate_small", P.call(1110, 1050), Color(0.9, 0.85, 0.8), 1.4)
	Sprites.draw_sprop(self, "sandbags", P.call(120, 1110), Color(0.85, 0.8, 0.75), 1.6)
	Sprites.draw_sprop(self, "barrel_blue", P.call(70, 640), Color(0.85, 0.85, 0.88), 1.5)
	# 주인공
	var hp: Vector2 = P.call(640, 800)
	var hk := "hamster_" + GameState.hamster
	if Sprites.char_info(hk).is_empty():
		hk = "hamster"
	var hf := Sprites.char_frame(hk, "idle_front", 0)
	if fmod(t, 7.0) < 0.6:
		hf = Sprites.char_frame(hk, "happy", 0)
	draw_colored_polygon(Art.ellipse_pts(hp, 40, 10, 20), Color(0, 0, 0, 0.3))
	Sprites.draw_char(self, hk, hf, hp, 1.15, sin(t * 0.3) < -0.7)
	# 방석 위 졸고 있는 동료
	var cp: Vector2 = P.call(205, 712)
	Sprites.draw_char(self, "hamster", Sprites.char_frame("hamster", "sleep", 0), cp, 0.55, false, Color(0.9, 0.88, 0.92))
	var zk := fmod(t, 2.0) / 2.0
	draw_string(font, cp + Vector2(10, -60 - zk * 20), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 14 + int(zk * 8), Color(1, 1, 1, 1.0 - zk))

func _draw() -> void:
	var s := size
	if bg_tex == null and ResourceLoader.exists(BG):
		bg_tex = load(BG)
	if bg_tex:
		_draw_baked(s)
		return
	# 벽
	draw_rect(Rect2(Vector2.ZERO, s), Color("#3A2E2A"))
	for i in int(s.x / 60) + 1:
		draw_rect(Rect2(i * 60, 0, 2, s.y * 0.62), Color(0, 0, 0, 0.12))
	for j in 6:
		draw_rect(Rect2(0, j * 34 + (17 if j % 2 else 0), s.x, 2), Color(0, 0, 0, 0.08))
	# 바닥
	var fy := s.y * 0.62
	draw_rect(Rect2(0, fy, s.x, s.y - fy), Color("#5A4232"))
	for i in 8:
		draw_rect(Rect2(0, fy + i * 22, s.x, 2), Color(0, 0, 0, 0.15))
	Art.ellipse(self, Vector2(s.x * 0.5, fy + 70), s.x * 0.36, 42, Color("#7A3B3B"))
	Art.ellipse(self, Vector2(s.x * 0.5, fy + 70), s.x * 0.3, 32, Color("#9C4E4E"))
	# 창문 (밤)
	var wr := Rect2(s.x * 0.08, s.y * 0.12, 130, 96)
	Art.rrect(self, wr, Color("#1B2440"), 6, 3)
	draw_circle(wr.position + Vector2(96, 30), 14, Color("#F3EEE6"))
	draw_circle(wr.position + Vector2(102, 26), 12, Color("#1B2440"))
	for k in 6:
		draw_circle(wr.position + Vector2(14 + k * 19, 70 - (k % 3) * 18), 1.5, Color(1, 1, 1, 0.6 + 0.4 * sin(t * 2.0 + k)))
	draw_line(wr.position + Vector2(wr.size.x * 0.5, 0), wr.position + Vector2(wr.size.x * 0.5, wr.size.y), Color("#5A4232"), 4)
	draw_line(wr.position + Vector2(0, wr.size.y * 0.5), wr.position + Vector2(wr.size.x, wr.size.y * 0.5), Color("#5A4232"), 4)
	# 포스터
	var pr := Rect2(s.x * 0.38, s.y * 0.1, 92, 120)
	Art.rrect(self, pr, Color("#F2C14E"), 4, 3)
	Art.rrect(self, Rect2(pr.position + Vector2(8, 8), Vector2(76, 78)), Color("#FFF3D6"), 3)
	Sprites.draw_char(self, "hamster", Sprites.char_frame("hamster", "portrait_happy", 0), pr.position + Vector2(46, 84), 0.5)
	draw_string(font, pr.position + Vector2(10, 108), "멍냥 발자국", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#1B1A22"))
	# 작업대
	var bx := s.x * 0.62
	Art.rrect(self, Rect2(bx, fy - 70, 200, 26), Color("#8A5A3B"), 4)
	draw_rect(Rect2(bx + 10, fy - 44, 12, 60), Color("#6B4630"))
	draw_rect(Rect2(bx + 178, fy - 44, 12, 60), Color("#6B4630"))
	Art.rrect(self, Rect2(bx + 20, fy - 96, 40, 26), Color("#D64545"), 3)
	Art.rrect(self, Rect2(bx + 120, fy - 100, 60, 30), Color("#3B4252"), 4)
	draw_rect(Rect2(bx + 126, fy - 94, 32, 16), Color("#6CCB5F", 0.6 + 0.3 * sin(t * 3.0)))
	draw_circle(Vector2(bx + 168, fy - 86), 4, Color("#9AA3B2"))
	# 무전기 안테나
	draw_line(Vector2(bx + 172, fy - 100), Vector2(bx + 186, fy - 140), Color("#9AA3B2"), 3)
	draw_circle(Vector2(bx + 186, fy - 140), 4, DB.C_DANGER if fmod(t, 1.2) < 0.6 else Color("#5A2A2A"))
	# 공구 걸이
	for k in 4:
		draw_line(Vector2(bx + 30 + k * 40, fy - 190), Vector2(bx + 30 + k * 40, fy - 140), Color("#9AA3B2"), 4)
	# 잠자리 (방석)
	Art.blob(self, Vector2(s.x * 0.2, fy + 30), 80, 28, Color("#3E5C8A"))
	Art.blob(self, Vector2(s.x * 0.2, fy + 22), 62, 18, Color("#5A7BB0"), 0)
	# 은신처 물자 (시트 소품)
	Sprites.draw_sprop(self, "ammo_locker", Vector2(s.x * 0.93, fy + 8), Color(0.9, 0.88, 0.85), 1.5)
	Sprites.draw_sprop(self, "crate", Vector2(s.x * 0.84, fy + 120), Color(0.95, 0.93, 0.9), 1.6)
	Sprites.draw_sprop(self, "crate_small", Vector2(s.x * 0.94, fy + 122), Color(0.95, 0.93, 0.9), 1.4)
	Sprites.draw_sprop(self, "sandbags", Vector2(s.x * 0.08, fy + 150), Color(0.9, 0.88, 0.85), 1.6)
	Sprites.draw_sprop(self, "barrel_blue", Vector2(s.x * 0.06, fy + 10), Color(0.9, 0.9, 0.92), 1.5)
	# 매달린 전구 + 빛
	var bulb := Vector2(s.x * 0.5, s.y * 0.08)
	draw_line(Vector2(bulb.x, 0), bulb, Color("#1B1A22"), 2)
	for r in [220.0, 150.0, 90.0]:
		draw_circle(bulb + Vector2(0, 10), r, Color(1, 0.8, 0.45, 0.035))
	draw_circle(bulb + Vector2(0, 10), 10, Color("#FFE3A3"))
	# 주인공 (숨쉬기 + 꼬리)
	var hp := Vector2(s.x * 0.56, fy + 64)
	var hf := Sprites.char_frame("hamster", "idle_front", 0)
	if fmod(t, 7.0) < 0.6:
		hf = Sprites.char_frame("hamster", "happy", 0)
	Sprites.draw_char(self, "hamster", hf, hp, 1.35, sin(t * 0.3) < -0.7)
	# 은신처 동료 (졸고 있는 햄스터 인형)
	var cp := Vector2(s.x * 0.2, fy + 34)
	Sprites.draw_char(self, "hamster", Sprites.char_frame("hamster", "sleep", 0), cp, 0.55, false, Color(0.88, 0.88, 0.96))
	var zk := fmod(t, 2.0) / 2.0
	draw_string(font, cp + Vector2(10, -64 - zk * 20), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 14 + int(zk * 8), Color(1, 1, 1, 1.0 - zk))

func poly_ear(p: Vector2) -> void:
	Art.poly(self, PackedVector2Array([p + Vector2(-6, 6), p + Vector2(0, -8), p + Vector2(6, 6)]), Color("#9AA3B2"), 2)
