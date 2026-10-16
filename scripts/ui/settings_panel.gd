class_name SettingsPanel
extends PanelContainer
## 설정 창: 소리 · 화면 · 그래픽 품질 · 게임

signal closed

func _ready() -> void:
	Settings.load_settings()
	add_theme_stylebox_override("panel", UITheme.box(Color(DB.C_UI_SOLID, 0.96), 18, Color(DB.C_HERO, 0.7), 2, 26))
	custom_minimum_size = Vector2(520, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	v.add_child(UITheme.label("설정", 28, DB.C_TEXT, true))
	v.add_child(_section("소리"))
	v.add_child(_slider("전체 음량", Settings.master, func(x): Settings.master = x; Settings.apply()))
	v.add_child(_slider("효과음", Settings.sfx, func(x): Settings.sfx = x; Settings.apply()))
	v.add_child(_slider("배경 음악", Settings.music, func(x): Settings.music = x; Settings.apply()))
	v.add_child(_section("화면"))
	v.add_child(_toggle("전체 화면", Settings.fullscreen, func(b): Settings.fullscreen = b; Settings.apply()))
	v.add_child(_toggle("수직 동기화", Settings.vsync, func(b): Settings.vsync = b; Settings.apply()))
	v.add_child(_choice("그래픽 품질", ["낮음", "보통", "높음"], Settings.quality, func(i): Settings.quality = i))
	v.add_child(_section("게임"))
	v.add_child(_slider("화면 흔들림", Settings.shake, func(x): Settings.shake = x))
	var nk := HBoxContainer.new()
	var nl := UITheme.label("닉네임 (멀티)", 17)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nk.add_child(nl)
	var le := LineEdit.new()
	le.text = Settings.nickname
	le.max_length = 12
	le.custom_minimum_size = Vector2(200, 0)
	le.text_changed.connect(func(t): Settings.nickname = t.strip_edges() if t.strip_edges() != "" else "햄찌")
	nk.add_child(le)
	v.add_child(nk)
	var keys := UITheme.label("조작: WASD 이동 · 마우스 조준/사격 · Shift 달리기 · Space 구르기 · E 상호작용 · F 스킬 · T 연막 · 우클릭 조준 · C 웅크리기 · Tab 배낭 · Esc 메뉴", 13, DB.C_MUTED)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(keys)
	var ok := UITheme.button("저장하고 닫기", 20, true)
	ok.pressed.connect(func():
		Settings.save_settings()
		Settings.apply()
		Sfx.play("click", -6.0)
		closed.emit()
		queue_free())
	v.add_child(ok)

func _section(t: String) -> Control:
	var l := UITheme.label(t, 15, DB.C_LEGEND, true)
	return l

func _row(t: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := UITheme.label(t, 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h

func _slider(t: String, val: float, cb: Callable) -> Control:
	var h := _row(t)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(220, 24)
	var pct := UITheme.label("%d%%" % int(round(val * 100)), 15, DB.C_MUTED)
	pct.custom_minimum_size = Vector2(52, 0)
	s.value_changed.connect(func(x):
		pct.text = "%d%%" % int(round(x * 100))
		cb.call(x))
	h.add_child(s)
	h.add_child(pct)
	return h

func _toggle(t: String, val: bool, cb: Callable) -> Control:
	var h := _row(t)
	var c := CheckButton.new()
	c.button_pressed = val
	c.toggled.connect(func(b): cb.call(b))
	h.add_child(c)
	return h

func _choice(t: String, opts: Array, val: int, cb: Callable) -> Control:
	var h := _row(t)
	var btns: Array[Button] = []
	for i in opts.size():
		var b := UITheme.button(opts[i], 15, i == val)
		b.toggle_mode = true
		b.button_pressed = i == val
		btns.append(b)
		h.add_child(b)
	for i in btns.size():
		var bi := i
		btns[i].pressed.connect(func():
			for j in btns.size():
				btns[j].button_pressed = j == bi
			cb.call(bi))
	return h
