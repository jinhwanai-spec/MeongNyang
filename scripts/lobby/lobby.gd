class_name Lobby
extends Node2D
## 3D 은신처 로비: 햄스터로 돌아다니며 장소(작업대·시장·보관함·출발 준비)에서 E,
## 북쪽 출구로 나가는 순간 원정이 시작된다.

signal start_raid
signal to_title

const T := float(DB.TILE)

var room: HideoutRoom
var view: Node3D
var cam: Camera3D
var player: LobbyPlayer
var avatar: Node3D
var ui: CanvasLayer
var prompt: Label
var info: Label
var hint: Label
var panel: Control
var near := ""
var leaving := false
var cam_pos := Vector3.ZERO
var shown_hamster := ""
var t := 0.0
var _just_opened := false

func _ready() -> void:
	Sfx.music("hideout")
	GameState.ensure_starter_kit()
	GameState.validate_loadout()
	GameState.save_game()
	view = Node3D.new()
	add_child(view)
	room = HideoutRoom.new()
	view.add_child(room)
	# 충돌 (2D): 방 테두리 + 가구
	var body := StaticBody2D.new()
	add_child(body)
	var rects := room.colliders.duplicate()
	rects.append([Vector2(-0.4, 5.0), Vector2(0.45, 6.0)])      # 서쪽 벽
	rects.append([Vector2(14.4, 5.0), Vector2(0.45, 6.0)])      # 동쪽 벽
	rects.append([Vector2(7.0, 10.3), Vector2(8.0, 0.4)])       # 남쪽 턱
	rects.append([Vector2(11.7, -1.0), Vector2(1.2, 0.4)])      # 터널 끝
	for r in rects:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = (r[1] as Vector2) * 2.0 * T
		cs.shape = rs
		cs.position = (r[0] as Vector2) * T
		body.add_child(cs)
	player = LobbyPlayer.new()
	var sp := room.marker("spawn")
	player.position = Vector2(sp.x, sp.z) * T
	add_child(player)
	_make_avatar()
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.current = true
	view.add_child(cam)
	cam_pos = Vector3(sp.x, 0, sp.z)
	_build_ui()
	if not GameState.seen.has("v19"):
		_whats_new()

func _make_avatar() -> void:
	if avatar:
		avatar.queue_free()
	player.hdata = DB.HAMSTERS.get(GameState.hamster, DB.HAMSTERS.baragi)
	if ModelChar.available():
		var mc := ModelChar.new()
		view.add_child(mc)
		mc.setup(player)
		avatar = mc
	else:
		var cb := CharBillboard.new()
		view.add_child(cb)
		cb.setup(player, 52.0)
		avatar = cb
	shown_hamster = GameState.hamster

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	ui.add_child(root)
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UITheme.box(Color(DB.C_UI_SOLID, 0.82), 14, Color(1, 1, 1, 0.08), 2, 14))
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top.position = Vector2(-500, 18)
	top.custom_minimum_size = Vector2(480, 0)
	root.add_child(top)
	var tv := VBoxContainer.new()
	top.add_child(tv)
	tv.add_child(UITheme.label("멍냥 발자국 은신처", 22, DB.C_HERO, true))
	info = UITheme.label("", 15, DB.C_MUTED)
	tv.add_child(info)
	prompt = UITheme.label("", 22, DB.C_TEXT, true)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-300, -130)
	prompt.size = Vector2(600, 40)
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	prompt.add_theme_constant_override("outline_size", 8)
	root.add_child(prompt)
	hint = UITheme.label("WASD 이동 · E 상호작용 · Esc 메뉴 — 북쪽 초록 출구로 나가면 원정이 시작돼요", 15, Color(1, 1, 1, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-420, -48)
	hint.size = Vector2(840, 30)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 6)
	root.add_child(hint)

## 새 기능 안내 (한 번만)
func _whats_new() -> void:
	GameState.seen["v19"] = true
	GameState.save_game()
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.box(Color(DB.C_UI_SOLID, 0.94), 14, Color(DB.C_LEGEND, 0.7), 2, 18))
	pc.position = Vector2(24, 24)
	pc.custom_minimum_size = Vector2(520, 0)
	ui.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	v.add_child(UITheme.label("은신처가 넓어졌어요!", 22, DB.C_LEGEND, true))
	for line in [
		"• 무기 제작소: 총·탄약·총 부품 제작, 총에 부품 끼우기 (3D 미리보기)",
		"• 물약 제작소: 약초·빈 병으로 체력·기력·강철 피부·질풍·그림자 물약",
		"• 갑옷 제작소: 헬멧·조끼 3단계 + 수리 (입으면 몸에 보여요)",
		"• 쓰러지면 가방이 그 자리에 남아요 — 다음 원정에서 회수!",
		"• 출발 준비: 난이도(가방 규칙 등) · 새 지역 '냥냥 항구'·'냥냥 주택가' 선택",
		"• 의뢰 게시판: 납품·처치·탈출 의뢰를 깨고 보상 받기 (항구 대장도 있어요)",
		"• 원정 중 우클릭: 조준 (스코프를 달면 더 멀리 보여요)",
	]:
		var l := UITheme.label(line, 15, DB.C_TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	v.add_child(UITheme.label("(12초 뒤 사라져요)", 12, DB.C_MUTED))
	var tw := pc.create_tween()
	tw.tween_interval(12.0)
	tw.tween_property(pc, "modulate:a", 0.0, 0.8)
	tw.tween_callback(pc.queue_free)

func _info_text() -> String:
	var hd: Dictionary = DB.HAMSTERS.get(GameState.hamster, DB.HAMSTERS.baragi)
	var lo := GameState.loadout
	var w := []
	for slot in ["primary", "sidearm"]:
		if str(lo[slot]) != "":
			w.append(DB.WEAPONS[lo[slot]].name)
	return "%s 냥 · 용병 %s(%s) · 무기 %s" % [HUD._fmt(GameState.coins), hd.name, hd.role, ", ".join(w) if not w.is_empty() else "없음"]

func _process(delta: float) -> void:
	t += delta
	if shown_hamster != GameState.hamster:
		_make_avatar()
	info.text = _info_text()
	# 카메라
	var pp := player.global_position / T
	cam_pos = cam_pos.lerp(Vector3(pp.x, 0, pp.y), 1.0 - exp(-6.0 * delta))
	var tgt := Vector3(clampf(cam_pos.x, 4.0, 10.0), 0, clampf(cam_pos.z, 3.0, 6.2))
	var pr := deg_to_rad(52.0)
	cam.position = tgt + Vector3(0, sin(pr) * 12.5, cos(pr) * 12.5)
	cam.look_at(tgt, Vector3.UP)
	if panel or leaving:
		prompt.text = ""
		if panel is Hideout and Input.is_action_just_pressed("interact") and not _just_opened:
			_close_panel()
		_just_opened = false
		return
	# 가까운 장소
	near = ""
	var best := 1.7
	for k in HideoutRoom.STATIONS:
		if k == "st_door" or not room.markers.has(k):
			continue
		var m: Vector3 = room.markers[k]
		var d := Vector2(m.x, m.z).distance_to(pp)
		if d < best:
			best = d
			near = k
	if near != "":
		var st: Array = HideoutRoom.STATIONS[near]
		prompt.text = "[E] %s — %s" % [st[0], st[1]]
	else:
		var dm := room.marker("st_door")
		prompt.text = "출구로 나가면 원정 시작 ▲" if Vector2(dm.x, dm.z).distance_to(pp) < 2.4 else ""
	if Input.is_action_just_pressed("interact") and near != "":
		_open_station(near)
		return
	# 출구: 터널 안으로 들어가면 출발
	if pp.y < 0.35 and pp.x > 10.9 and pp.x < 12.5:
		_leave()

func _unhandled_input(e: InputEvent) -> void:
	if leaving:
		return
	if panel:
		if e.is_action_pressed("pause"):
			_close_panel()
			get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("pause"):
		_open_menu()
		get_viewport().set_input_as_handled()

func _open_station(k: String) -> void:
	Sfx.play("click", -4.0)
	var h := Hideout.new()
	h.overlay_mode = true
	h.start_tab = int(HideoutRoom.STATIONS[k][2])
	h.start_raid.connect(_leave)
	h.to_title.connect(_close_panel)
	ui.add_child(h)
	panel = h
	_just_opened = true
	player.input_locked = true

func _close_panel() -> void:
	if panel:
		panel.queue_free()
		panel = null
	player.input_locked = false
	Sfx.play("click", -8.0)

func _open_menu() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.theme = UITheme.get_theme()
	ui.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(c)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.box(Color(DB.C_UI_SOLID, 0.96), 18, Color(DB.C_HERO, 0.6), 2, 26))
	c.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pc.add_child(v)
	v.add_child(UITheme.label("일시정지", 26, DB.C_TEXT, true))
	var b1 := UITheme.button("계속하기", 20, true)
	b1.pressed.connect(func(): _close_panel())
	v.add_child(b1)
	var b2 := UITheme.button("설정", 20)
	b2.pressed.connect(func():
		var sp := SettingsPanel.new()
		c.add_child(sp)
		pc.visible = false
		sp.closed.connect(func(): pc.visible = true))
	v.add_child(b2)
	var b3 := UITheme.button("메인 화면으로", 20)
	b3.pressed.connect(func(): to_title.emit())
	v.add_child(b3)
	panel = dim
	player.input_locked = true

func _leave() -> void:
	if leaving:
		return
	leaving = true
	player.input_locked = true
	Sfx.play("door", -2.0)
	GameState.save_game()
	start_raid.emit()
