class_name TitleScreen
extends Control
## 타이틀 화면

signal play
signal new_game

var t := 0.0
var art: Control

func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art = Control.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(_draw_art)
	add_child(art)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	v.offset_bottom = -70
	v.offset_top = -70
	v.offset_left = -170
	v.offset_right = 170
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var has_save := int(GameState.stats.raids) > 0
	var b1 := UITheme.button("계속하기" if has_save else "게임 시작", 24, true)
	b1.custom_minimum_size = Vector2(340, 58)
	b1.pressed.connect(func(): play.emit())
	v.add_child(b1)
	if has_save:
		var b2 := UITheme.button("처음부터 새로 시작", 17)
		b2.pressed.connect(func():
			b2.text = "정말? 한 번 더 누르면 초기화" if b2.text == "처음부터 새로 시작" else b2.text
			if b2.has_meta("armed"):
				new_game.emit()
			b2.set_meta("armed", true))
		v.add_child(b2)
	var b3 := UITheme.button("종료", 17)
	b3.pressed.connect(func(): get_tree().quit())
	v.add_child(b3)
	var ver := UITheme.label("v%s · 프로토타입 · 수직 슬라이스" % ProjectSettings.get_setting("application/config/version", "0.1"), 13, Color(1, 1, 1, 0.35))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.offset_right = -14
	ver.offset_left = -14
	ver.offset_top = -8
	ver.offset_bottom = -8
	add_child(ver)
	Sfx.music("hideout")

func _process(delta: float) -> void:
	t += delta
	art.queue_redraw()

func _draw_art() -> void:
	var s := art.size
	# 밤하늘 그라데이션
	for i in 24:
		var k := i / 24.0
		art.draw_rect(Rect2(0, s.y * k, s.x, s.y / 24.0 + 1), Color("#1A1F2B").lerp(Color("#3A2E40"), k))
	for i in 40:
		var p := Vector2(fmod(i * 137.0, s.x), fmod(i * 71.0, s.y * 0.5))
		art.draw_circle(p, 1.4, Color(1, 1, 1, 0.3 + 0.3 * sin(t * 1.5 + i)))
	art.draw_circle(Vector2(s.x * 0.82, s.y * 0.16), 46, Color("#F3EEE6", 0.9))
	art.draw_circle(Vector2(s.x * 0.82 + 16, s.y * 0.16 - 8), 42, Color("#1E2232"))
	# 폐허 도시 실루엣
	var bx := 0.0
	var i2 := 0
	while bx < s.x:
		var w := 60.0 + fmod(i2 * 53.0, 90.0)
		var h := 140.0 + fmod(i2 * 97.0, 220.0)
		art.draw_rect(Rect2(bx, s.y * 0.72 - h, w, h + s.y), Color("#202434"))
		for wy in range(int(h / 30)):
			for wx in range(int(w / 26)):
				if fmod((i2 * 7 + wx * 3 + wy * 5) * 1.0, 7.0) < 1.0:
					art.draw_rect(Rect2(bx + 8 + wx * 26, s.y * 0.72 - h + 12 + wy * 30, 10, 14), Color("#F2C14E", 0.55))
		bx += w + 6
		i2 += 1
	art.draw_rect(Rect2(0, s.y * 0.72, s.x, s.y), Color("#262A36"))
	# 주인공 + 고양이 동료
	var c := Vector2(s.x * 0.5, s.y * 0.72)
	var dim := Color(0.8, 0.82, 0.92)
	var gy := s.y * 0.92
	# 왼쪽: 주인공 햄스터 / 오른쪽: 고양이 부대 (버튼과 겹치지 않게 양옆에 배치)
	art.draw_circle(Vector2(s.x * 0.19, gy - 120), 170, Color(1, 0.7, 0.4, 0.07))
	art.draw_colored_polygon(Art.ellipse_pts(Vector2(s.x * 0.19, gy), 90, 18, 24), Color(0, 0, 0, 0.35))
	var hb := sin(t * 2.4) * 3.0
	Sprites.draw_char(art, "hamster", Sprites.char_frame("hamster", "idle_front", 0), Vector2(s.x * 0.19, gy + hb * 0.0), 2.0 + sin(t * 2.4) * 0.015)
	for e in [["cat_white", 0.70, -34.0, 1.35, 0.0], ["cat_black", 0.86, -16.0, 1.75, 1.0], ["cat_tabby", 0.76, 4.0, 1.55, 2.0]]:
		var p: Vector2 = Vector2(s.x * float(e[1]), gy + float(e[2]))
		art.draw_colored_polygon(Art.ellipse_pts(p, 70.0 * float(e[3]) / 1.6, 14, 20), Color(0, 0, 0, 0.3))
		Sprites.draw_char(art, e[0], Sprites.char_frame(e[0], "idle", 0), p, float(e[3]) + sin(t * 2.0 + float(e[4])) * 0.012, true, dim)
	# 로고
	var f := UITheme.black()
	var title := "멍냥서바이벌"
	var size := 96
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var tp := Vector2(s.x * 0.5 - tw * 0.5, s.y * 0.2 + sin(t * 1.2) * 4)
	art.draw_string_outline(f, tp + Vector2(0, 6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 22, Color("#1B1A22"))
	art.draw_string_outline(f, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 14, Color("#1B1A22"))
	art.draw_string(f, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, DB.C_HERO)
	var sub := "살아서 집으로 돌아오는 것이 승리다"
	var sw := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	art.draw_string_outline(f, Vector2(s.x * 0.5 - sw * 0.5, tp.y + 46), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 8, Color("#1B1A22"))
	art.draw_string(f, Vector2(s.x * 0.5 - sw * 0.5, tp.y + 46), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, DB.C_TEXT)
