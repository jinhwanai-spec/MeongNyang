class_name MultiplayerMenu
extends Node
## 협동 멀티 메뉴 (LAN 2~4명): 방 만들기 / IP로 참가 → 대기실(용병 고르기·준비) → 호스트가 출발

signal back
signal start_coop

var room: HideoutRoom
var cam: Camera3D
var ui: CanvasLayer
var root: Control
var body: VBoxContainer
var status: Label
var t := 0.0
var stand: Node3D
var center := Vector3(7.5, 0, 6.2)
var is_ready := false

func _ready() -> void:
	Settings.apply()
	var v := Node3D.new()
	add_child(v)
	room = HideoutRoom.new()
	v.add_child(room)
	for k in room.labels:
		room.labels[k].visible = false
	stand = Node3D.new()
	v.add_child(stand)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.current = true
	v.add_child(cam)
	ui = CanvasLayer.new()
	add_child(ui)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.box(Color(DB.C_UI_SOLID, 0.9), 18, Color(DB.C_HERO, 0.5), 2, 24))
	pc.position = Vector2(48, 48)
	pc.custom_minimum_size = Vector2(520, 0)
	root.add_child(pc)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	pc.add_child(body)
	Net.players_changed.connect(_refresh)
	Net.connected_ok.connect(_refresh)
	Net.connect_failed.connect(func(): _start_screen("연결하지 못했어요. 주소와 방화벽을 확인해 주세요."))
	Net.session_ended.connect(func(r): _start_screen(r))
	Net.coop_start.connect(func(): start_coop.emit())
	if Net.active:
		_refresh()
	else:
		_start_screen("")

func _clear() -> void:
	for c in body.get_children():
		c.queue_free()

func _start_screen(msg: String) -> void:
	_clear()
	is_ready = false
	body.add_child(UITheme.label("협동 멀티플레이", 30, DB.C_HERO, true))
	var d := UITheme.label("같은 와이파이·공유기에 있는 친구와 2~4명이 함께 원정을 떠나요.\n고양이는 함께 상대하고, 전리품은 각자 챙겨요.", 15, DB.C_MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(d)
	var nk := HBoxContainer.new()
	var nl := UITheme.label("닉네임", 17)
	nl.custom_minimum_size = Vector2(90, 0)
	nk.add_child(nl)
	var le := LineEdit.new()
	le.text = Settings.nickname
	le.max_length = 12
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(func(tx):
		Settings.nickname = tx.strip_edges() if tx.strip_edges() != "" else "햄찌"
		Settings.save_settings())
	nk.add_child(le)
	body.add_child(nk)
	var hb := UITheme.button("방 만들기 (호스트)", 22, true)
	hb.custom_minimum_size = Vector2(0, 56)
	hb.pressed.connect(func():
		var err := Net.host()
		if err != OK:
			_start_screen("방을 만들지 못했어요 (포트 %d 사용 중?)" % Net.PORT)
		else:
			_refresh())
	body.add_child(hb)
	body.add_child(UITheme.label("친구 방에 참가", 17, DB.C_LEGEND, true))
	var jr := HBoxContainer.new()
	jr.add_theme_constant_override("separation", 8)
	var ip := LineEdit.new()
	ip.placeholder_text = "호스트 주소 (예: 192.168.0.12)"
	ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jr.add_child(ip)
	var jb := UITheme.button("참가", 20)
	jb.pressed.connect(func():
		if Net.join(ip.text) != OK:
			_start_screen("참가하지 못했어요.")
		else:
			_status_screen("연결 중…"))
	jr.add_child(jb)
	body.add_child(jr)
	if msg != "":
		var m := UITheme.label(msg, 15, DB.C_DANGER)
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(m)
	var bk := UITheme.button("뒤로", 18)
	bk.pressed.connect(func():
		Net.leave()
		back.emit())
	body.add_child(bk)
	_stand_players()

func _status_screen(msg: String) -> void:
	_clear()
	body.add_child(UITheme.label("협동 멀티플레이", 30, DB.C_HERO, true))
	body.add_child(UITheme.label(msg, 18, DB.C_TEXT))
	var bk := UITheme.button("취소", 18)
	bk.pressed.connect(func():
		Net.leave()
		_start_screen(""))
	body.add_child(bk)

func _refresh() -> void:
	if not Net.active:
		return
	if Net.players.is_empty():
		_status_screen("연결 중…")
		return
	_clear()
	body.add_child(UITheme.label("대기실", 30, DB.C_HERO, true))
	if Net.is_host():
		var ips := Net.local_ips()
		var a := UITheme.label("친구에게 알려줄 주소: %s" % (", ".join(ips) if not ips.is_empty() else "127.0.0.1"), 16, DB.C_LEGEND, true)
		a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(a)
	# 용병 고르기
	body.add_child(UITheme.label("내 용병", 16, DB.C_MUTED))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	body.add_child(chips)
	for id in DB.HAMSTER_ORDER:
		var ch := HamsterChip.make(id, GameState.hamster == id)
		ch.pressed.connect(func():
			GameState.hamster = id
			GameState.save_game()
			Net.set_my_info(is_ready)
			_refresh())
		chips.add_child(ch)
	# 플레이어 목록
	body.add_child(UITheme.label("참가자 %d / %d" % [Net.players.size(), Net.MAX_PLAYERS], 16, DB.C_MUTED))
	var ids := Net.players.keys()
	ids.sort()
	for id in ids:
		var p: Dictionary = Net.players[id]
		var hd: Dictionary = DB.HAMSTERS.get(str(p.hamster), DB.HAMSTERS.baragi)
		var row := HBoxContainer.new()
		var nm := UITheme.label("%s%s · %s(%s)" % ["★ " if id == 1 else "", p.name, hd.name, hd.role], 18, DB.C_TEXT, id == Net.my_id())
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		row.add_child(UITheme.label("준비 완료" if bool(p.ready) else "준비 중", 16, Color("#6CCB5F") if bool(p.ready) else DB.C_MUTED, true))
		body.add_child(row)
	if Net.is_host():
		var go := UITheme.button("원정 출발 ▶", 24, true)
		go.custom_minimum_size = Vector2(0, 58)
		go.disabled = not Net.all_ready()
		go.pressed.connect(func(): Net.host_start())
		body.add_child(go)
		if not Net.all_ready():
			body.add_child(UITheme.label("모두 준비하면 출발할 수 있어요", 14, DB.C_MUTED))
	else:
		var rb := UITheme.button("준비 취소" if is_ready else "준비 완료", 22, not is_ready)
		rb.custom_minimum_size = Vector2(0, 56)
		rb.pressed.connect(func():
			is_ready = not is_ready
			Net.set_my_info(is_ready))
		body.add_child(rb)
	var lv := UITheme.button("방 나가기", 18)
	lv.pressed.connect(func():
		Net.leave()
		_start_screen(""))
	body.add_child(lv)
	_stand_players()

## 대기실 참가자 햄스터를 러그 위에 나란히 세우기
func _stand_players() -> void:
	for c in stand.get_children():
		c.queue_free()
	var list := []
	if Net.active and not Net.players.is_empty():
		var ids := Net.players.keys()
		ids.sort()
		for id in ids:
			list.append(str(Net.players[id].hamster))
	else:
		list.append(GameState.hamster)
	for i in list.size():
		var sheet: String = "hamster_" + list[i]
		if Sprites.char_info(sheet).is_empty():
			sheet = "hamster"
		var b := CharBillboard.new()
		b.position = center + Vector3((i - (list.size() - 1) * 0.5) * 1.3, 0, 0)
		stand.add_child(b)
		b.setup_static(sheet, "idle_front", 30.0, 1.0)

func _process(delta: float) -> void:
	t += delta
	var a := sin(t * 0.15) * 0.3 + 0.25
	cam.position = center + Vector3(sin(a) * 5.5 - 2.2, 3.0, cos(a) * 5.5)
	cam.look_at(center + Vector3(-1.8, 0.7, 0), Vector3.UP)
