class_name MainMenu
extends Node
## 3D 메인 화면: 은신처 방을 배경으로 선택한 햄스터가 서 있고 카메라가 천천히 돈다.
## 시작하기 · 새 게임 · 멀티플레이 · 설정 · 나가기

signal play
signal new_game
signal multi

var room: HideoutRoom
var cam: Camera3D
var ham: Node3D
var t := 0.0
var ui: CanvasLayer
var menu: VBoxContainer
var overlay: Control
var center := Vector3(7.5, 0, 6.2)

func _ready() -> void:
	Settings.apply()
	Sfx.music("title")
	var v := Node3D.new()
	add_child(v)
	room = HideoutRoom.new()
	v.add_child(room)
	for k in room.labels:
		room.labels[k].visible = false
	# 선택한 햄스터 — 레퍼런스 시트 그림 그대로
	var sheet := "hamster_" + GameState.hamster
	if Sprites.char_info(sheet).is_empty():
		sheet = "hamster"
	if ModelChar.available():
		ham = ModelChar.load_model()
		ham.position = center
		ham.scale = Vector3.ONE * 1.25
		v.add_child(ham)
	else:
		var hb := CharBillboard.new()
		hb.position = center
		v.add_child(hb)
		hb.setup_static(sheet, "idle_front", 30.0, 1.25)
		ham = hb
	var spot := SpotLight3D.new()
	spot.position = center + Vector3(0, 4.5, 1.5)
	spot.rotation_degrees = Vector3(-75, 0, 0)
	spot.light_color = Color(1.0, 0.86, 0.62)
	spot.light_energy = 2.4
	spot.spot_range = 8.0
	spot.spot_angle = 30.0
	spot.shadow_enabled = true
	v.add_child(spot)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.current = true
	v.add_child(cam)
	_build_ui()

func _recolor(root: Node, c: Color) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var m := m3.mesh.surface_get_material(i)
			if m and m.resource_name == "fur":
				var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.albedo_color = c
				m3.set_surface_override_material(i, d)

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	# 왼쪽 어둡게 (글씨가 잘 보이도록)
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.05, 0.04, 0.05, 0.92))
	g.set_color(1, Color(0.05, 0.04, 0.05, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_bottom = 1.0
	shade.offset_right = 620
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var box := VBoxContainer.new()
	box.position = Vector2(70, 90)
	box.add_theme_constant_override("separation", 6)
	root.add_child(box)
	var logo := UITheme.label("멍냥서바이벌", 64, DB.C_HERO, true)
	logo.add_theme_color_override("font_outline_color", Color("#2A1A10"))
	logo.add_theme_constant_override("outline_size", 14)
	box.add_child(logo)
	var sub := UITheme.label("작은 햄스터 용병들의 고양이 도시 탈출기", 19, Color("#F1E6CF"))
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 46)
	box.add_child(gap)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	box.add_child(menu)
	var has_save := int(GameState.stats.get("raids", 0)) > 0 or FileAccess.file_exists("user://save.json")
	_btn("이어하기" if has_save else "시작하기", true, func(): play.emit())
	_btn("새 게임", false, func():
		if has_save:
			_confirm("저장된 진행을 지우고 새로 시작할까요?", func(): new_game.emit())
		else:
			new_game.emit())
	_btn("멀티플레이", false, func(): multi.emit())
	_btn("설정", false, func(): _open_settings())
	_btn("나가기", false, func(): get_tree().quit())
	var ver := UITheme.label("v0.5 · 3D", 13, Color(1, 1, 1, 0.45))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(24, -34)
	root.add_child(ver)
	var hd: Dictionary = DB.HAMSTERS.get(GameState.hamster, DB.HAMSTERS.baragi)
	var who := UITheme.label("오늘의 용병: %s · %s" % [hd.name, hd.role], 16, Color("#FFE7B0"))
	who.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	who.position = Vector2(-330, -40)
	who.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	who.add_theme_constant_override("outline_size", 6)
	root.add_child(who)

func _btn(text: String, accent: bool, cb: Callable) -> void:
	var b := UITheme.button(text, 24, accent)
	b.custom_minimum_size = Vector2(320, 58)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func():
		Sfx.play("click", -4.0)
		cb.call())
	b.mouse_entered.connect(func(): Sfx.play("hover", -14.0))
	menu.add_child(b)

func _modal() -> CenterContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.theme = UITheme.get_theme()
	ui.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(c)
	overlay = dim
	return c

func _close_modal() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null

func _open_settings() -> void:
	var c := _modal()
	var sp := SettingsPanel.new()
	c.add_child(sp)
	sp.closed.connect(_close_modal)

func _confirm(text: String, yes: Callable) -> void:
	var c := _modal()
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.box(Color(DB.C_UI_SOLID, 0.96), 18, Color(DB.C_DANGER, 0.7), 2, 26))
	c.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pc.add_child(v)
	v.add_child(UITheme.label(text, 20, DB.C_TEXT, true))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var y := UITheme.button("새로 시작", 18, true)
	y.pressed.connect(func():
		_close_modal()
		yes.call())
	h.add_child(y)
	var n := UITheme.button("취소", 18)
	n.pressed.connect(_close_modal)
	h.add_child(n)

func _process(delta: float) -> void:
	t += delta
	var a := t * 0.12 + 0.35
	cam.position = center + Vector3(sin(a) * 5.2 - 1.6, 3.2, cos(a) * 5.2)
	cam.look_at(center + Vector3(-1.4, 0.75, 0), Vector3.UP)
	# 햄스터 숨쉬기·가끔 깡충 (가끔 반가운 표정)
	var hop := maxf(0.0, sin(t * 1.3)) ** 12 * 0.25
	ham.position.y = hop
	if ham is CharBillboard:
		(ham as CharBillboard).static_anim = "happy" if fmod(t, 6.0) > 5.2 else "idle_front"
	else:
		# 카메라 쪽을 보면서 숨쉬고 가끔 고개 갸웃
		ham.rotation.y = atan2(cam.position.x - ham.position.x, cam.position.z - ham.position.z) - 0.35
		ham.rotation.z = sin(t * 0.9) * 0.05
		ham.scale = Vector3(1.25, 1.25 * (1.0 + sin(t * 2.4) * 0.015), 1.25)
