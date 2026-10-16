class_name Hideout
extends Control
## 은신처: 출발 준비 · 작업대(제작) · 냥이 시장(판매/구매) · 보관함
## 모든 화면에 "이 행동이 다음 원정에 어떤 이득을 주는가"를 한 줄로 보여준다.

signal start_raid
signal to_title

var tabs: TabContainer
var coin_label: Label
var toast: Label
var toast_t := 0.0
var prep_box: VBoxContainer
var craft_box: VBoxContainer
var potion_box: VBoxContainer
var armor_box: VBoxContainer
var market_box: VBoxContainer
var stash_box: VBoxContainer
var market_mult := {}
var overlay_mode := false   # 3D 로비 위에 띄우는 창 (왼쪽 일러스트 없음)
var start_tab := 0

func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Sfx.music("hideout")
	_roll_market()
	var given := GameState.ensure_starter_kit()
	GameState.validate_loadout()
	GameState.save_game()
	var bg := ColorRect.new()
	bg.color = Color("#1E1A1E") if not overlay_mode else Color(0.05, 0.04, 0.05, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	# 왼쪽: 일러스트
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.85
	root.add_child(left)
	if overlay_mode:
		left.size_flags_stretch_ratio = 0.6
	var art: Control = HideoutArt.new() if not overlay_mode else Control.new()
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(art)
	var stat := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		stat.add_theme_constant_override("margin_" + side, 18)
	left.add_child(stat)
	stat.visible = not overlay_mode
	var stat_panel := PanelContainer.new()
	stat.add_child(stat_panel)
	var sv := VBoxContainer.new()
	stat_panel.add_child(sv)
	sv.add_child(UITheme.label("멍냥 발자국 은신처", 26, DB.C_HERO, true))
	var s := GameState.stats
	sv.add_child(UITheme.label("원정 %d회 · 탈출 %d회 · 실종 %d회 · 처치 %d · 최고 전리품 %s냥" % [int(s.raids), int(s.extracts), int(s.deaths), int(s.kills), HUD._fmt(int(s.best_haul))], 15, DB.C_MUTED))
	# 오른쪽: 메뉴
	var right := MarginContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if overlay_mode:
		var rbg := Panel.new()
		rbg.add_theme_stylebox_override("panel", UITheme.box(Color(0.09, 0.08, 0.1, 0.94), 0))
		rbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rbg.show_behind_parent = true
		right.add_child(rbg)
	for side in ["left", "right", "top", "bottom"]:
		right.add_theme_constant_override("margin_" + side, 22)
	root.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	right.add_child(rv)
	var top := HBoxContainer.new()
	rv.add_child(top)
	var title := UITheme.label("멍냥서바이벌", 30, DB.C_TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	coin_label = UITheme.label("", 22, DB.C_LEGEND, true)
	top.add_child(coin_label)
	var menu_btn := UITheme.button("메뉴" if not overlay_mode else "닫기 (E)", 15)
	menu_btn.pressed.connect(func(): to_title.emit())
	top.add_child(menu_btn)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tab_changed.connect(func(_i): Sfx.play("click", -10.0))
	rv.add_child(tabs)
	prep_box = _tab("출발 준비")
	craft_box = _tab("무기 제작소")
	potion_box = _tab("물약 제작소")
	armor_box = _tab("갑옷 제작소")
	market_box = _tab("냥이 시장")
	stash_box = _tab("보관함")
	toast = UITheme.label("", 16, DB.C_LEGEND)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(toast)
	var go := UITheme.button("원정 출발  ▶" if not overlay_mode else "바로 출구로 나가기  ▶", 26, true)
	go.custom_minimum_size = Vector2(0, 62)
	go.pressed.connect(func(): start_raid.emit())
	rv.add_child(go)
	refresh()
	tabs.current_tab = clampi(start_tab, 0, tabs.get_tab_count() - 1)
	if not given.is_empty() and int(GameState.stats.raids) > 0:
		show_toast("기본 보급 지급: " + ", ".join(given))

func _tab(name_: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = name_
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 10)
	sc.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(v)
	return v

func _process(delta: float) -> void:
	if toast_t > 0.0:
		toast_t -= delta
		toast.modulate.a = minf(1.0, toast_t)

func show_toast(s: String, c: Color = DB.C_LEGEND) -> void:
	toast.text = s
	toast.add_theme_color_override("font_color", c)
	toast_t = 3.5

func refresh() -> void:
	coin_label.text = "%s 냥  " % HUD._fmt(GameState.coins)
	for box in [prep_box, craft_box, potion_box, armor_box, market_box, stash_box]:
		for c in box.get_children():
			c.queue_free()
	_build_prep()
	_build_station(craft_box, "weapon")
	_build_station(potion_box, "potion")
	_build_station(armor_box, "armor")
	_build_market()
	_build_stash()

func _card(parent: Control, border: Color = Color(1, 1, 1, 0.06)) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.box(Color(DB.C_UI_SOLID, 0.9), 12, border, 2, 16))
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	return v

func _benefit(parent: Control, text: String) -> void:
	var l := UITheme.label("▶ " + text, 14, Color("#6CCB5F"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)

# ── 출발 준비 ────────────────────────────────────────
func _build_prep() -> void:
	var lo := GameState.loadout
	var region := _card(prep_box, Color(DB.C_HERO, 0.6))
	var rsel := HBoxContainer.new()
	rsel.add_theme_constant_override("separation", 8)
	region.add_child(rsel)
	rsel.add_child(UITheme.label("원정 지역", 17, DB.C_TEXT, true))
	for rid in Regions.ORDER:
		var rb := UITheme.button(str(Regions.DATA[rid].short), 15, GameState.region == rid)
		rb.pressed.connect(func():
			GameState.region = rid
			GameState.save_game()
			Sfx.play("pick", -6.0)
			refresh())
		rsel.add_child(rb)
	var rd: Dictionary = Regions.get_info(GameState.region)
	# 지역 지도 미리보기 + 설명
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 12)
	region.add_child(rrow)
	var thumb_tex = load(str(rd.minimap))
	if thumb_tex:
		var tp := PanelContainer.new()
		tp.add_theme_stylebox_override("panel", UITheme.box(Color(0, 0, 0, 0.35), 8, Color(DB.C_HERO, 0.5), 2, 3))
		var th := TextureRect.new()
		th.texture = thumb_tex
		th.custom_minimum_size = Vector2(150, 106)
		th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tp.add_child(th)
		tp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		rrow.add_child(tp)
	var rcol := VBoxContainer.new()
	rcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rrow.add_child(rcol)
	var rh := HBoxContainer.new()
	rcol.add_child(rh)
	var rl := UITheme.label(str(rd.name), 21, DB.C_TEXT, true)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rh.add_child(rl)
	rh.add_child(UITheme.label("위험 %s  보상 %s" % [rd.danger, rd.reward], 15, DB.C_LEGEND))
	var info := UITheme.label(str(rd.info), 14, DB.C_MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rcol.add_child(info)
	if rd.has("boss"):
		rcol.add_child(UITheme.label("보스: %s (처치하면 좋은 갑옷·무기)" % str(rd.boss[1]), 14, DB.C_DANGER.lightened(0.25), true))
	var nbag := 0
	for b in GameState.lost_bags:
		if str(b.get("region", "mart")) == GameState.region:
			nbag += 1
	if nbag > 0:
		rcol.add_child(UITheme.label("이 지역에 두고 온 내 가방 %d개" % nbag, 14, DB.C_LEGEND, true))

	# 출격 용병 선택
	var hc := _card(prep_box, Color(DB.C_LEGEND, 0.5))
	hc.add_child(UITheme.label("출격할 햄스터 용병", 17, DB.C_TEXT, true))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	hc.add_child(chips)
	for id in DB.HAMSTER_ORDER:
		var ch := HamsterChip.make(id, GameState.hamster == id)
		ch.pressed.connect(func():
			GameState.hamster = id
			GameState.save_game()
			Sfx.play("pick", -6.0)
			refresh())
		chips.add_child(ch)
	var hd: Dictionary = DB.HAMSTERS.get(GameState.hamster, DB.HAMSTERS.baragi)
	var hh := HBoxContainer.new()
	hc.add_child(hh)
	var hn := UITheme.label("%s  ·  %s %s" % [hd.name, hd.breed, hd.role], 19, Color(str(hd.fur)).lightened(0.25), true)
	hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(hn)
	hh.add_child(UITheme.label("체력 %d · 속도 %d%% · 소음 %d%%" % [int(hd.hp), int(round(float(hd.speed) * 100)), int(round(float(hd.noise) * 100))], 14, DB.C_MUTED))
	var sk := UITheme.label("[F] %s  (재사용 %d초) — %s" % [hd.skill_name, int(hd.cd), hd.desc], 15, DB.C_LEGEND)
	sk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hc.add_child(sk)
	_benefit(hc, "특성: " + str(hd.trait))

	_build_contracts(prep_box)
	_build_difficulty(prep_box)

	var w := _card(prep_box)
	w.add_child(UITheme.label("주무기", 17, DB.C_TEXT))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	w.add_child(row)
	for opt in _owned_weapons("primary"):
		var have := GameState.weapon_count(opt) if opt != "" else 1
		if opt != "" and have <= 0:
			continue
		var nm: String = "없음" if opt == "" else "%s ×%d" % [DB.WEAPONS[opt].name, have]
		var b := UITheme.button(nm, 15, lo.primary == opt)
		b.pressed.connect(func():
			GameState.loadout.primary = opt
			GameState.save_game()
			refresh())
		row.add_child(b)
	w.add_child(UITheme.label("보조무기", 17, DB.C_TEXT))
	var row2 := HFlowContainer.new()
	row2.add_theme_constant_override("h_separation", 8)
	row2.add_theme_constant_override("v_separation", 6)
	w.add_child(row2)
	for opt in _owned_weapons("sidearm"):
		if opt != "" and GameState.weapon_count(opt) <= 0:
			continue
		var nm2: String = "없음" if opt == "" else "%s ×%d" % [DB.WEAPONS[opt].name, GameState.weapon_count(opt)]
		var b2 := UITheme.button(nm2, 15, lo.sidearm == opt)
		b2.pressed.connect(func():
			GameState.loadout.sidearm = opt
			GameState.save_game()
			refresh())
		row2.add_child(b2)
	w.add_child(UITheme.label("근접무기 (V)", 17, DB.C_TEXT))
	var row3 := HFlowContainer.new()
	row3.add_theme_constant_override("h_separation", 8)
	row3.add_theme_constant_override("v_separation", 6)
	w.add_child(row3)
	for mid in DB.MELEES:
		if mid != "bat" and GameState.weapon_count(mid) <= 0:
			continue
		var nm4: String = DB.MELEES[mid].name if mid == "bat" else "%s ×%d" % [DB.MELEES[mid].name, GameState.weapon_count(mid)]
		var b3 := UITheme.button(nm4, 15, str(lo.get("melee", "bat")) == mid)
		b3.tooltip_text = "피해 %d · 사거리 %d · %s" % [int(DB.MELEES[mid].dmg), int(DB.MELEES[mid].range), DB.MELEES[mid].desc]
		b3.pressed.connect(func():
			GameState.loadout.melee = mid
			GameState.save_game()
			refresh())
		row3.add_child(b3)
	for aslot in ["helmet", "vest"]:
		w.add_child(UITheme.label("헬멧" if aslot == "helmet" else "조끼", 17, DB.C_TEXT))
		var arow := HFlowContainer.new()
		arow.add_theme_constant_override("h_separation", 8)
		arow.add_theme_constant_override("v_separation", 6)
		w.add_child(arow)
		var none := UITheme.button("없음", 15, str(lo.get(aslot, "")) == "")
		none.pressed.connect(func():
			GameState.loadout[aslot] = ""
			GameState.save_game()
			refresh())
		arow.add_child(none)
		for k in 3:
			var aid := "%s_%d" % [aslot, k + 1]
			if int(GameState.armor.get(aid, 0)) <= 0:
				continue
			var ab := UITheme.button("%s ×%d (%d%%)" % [DB.ITEMS[aid].name, int(GameState.armor[aid]), int(round(GameState.armor_left(aid) / GameState.armor_max(aid) * 100))], 15, str(lo.get(aslot, "")) == aid)
			ab.tooltip_text = DB.ITEMS[aid].desc
			ab.pressed.connect(func():
				GameState.loadout[aslot] = aid
				GameState.save_game()
				refresh())
			arow.add_child(ab)
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 8)
	w.add_child(mrow)
	var ml := UITheme.label("붕대 챙기기: %d / %d" % [int(lo.meds), int(GameState.stash.get("bandage", 0))], 17)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mrow.add_child(ml)
	var minus := UITheme.button(" − ", 16)
	minus.pressed.connect(func():
		GameState.loadout.meds = maxi(0, int(GameState.loadout.meds) - 1)
		refresh())
	mrow.add_child(minus)
	var plus := UITheme.button(" + ", 16)
	plus.pressed.connect(func():
		GameState.loadout.meds = mini(int(GameState.stash.get("bandage", 0)), int(GameState.loadout.meds) + 1)
		refresh())
	mrow.add_child(plus)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 8)
	w.add_child(srow)
	var sl := UITheme.label("간식 챙기기 (G): %d / %d" % [mini(int(lo.get("snacks", 0)), GameState.snack_count()), GameState.snack_count()], 17)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(sl)
	var sminus := UITheme.button(" − ", 16)
	sminus.pressed.connect(func():
		GameState.loadout.snacks = maxi(0, mini(int(GameState.loadout.get("snacks", 0)), GameState.snack_count()) - 1)
		refresh())
	srow.add_child(sminus)
	var splus := UITheme.button(" + ", 16)
	splus.pressed.connect(func():
		GameState.loadout.snacks = mini(GameState.snack_count(), int(GameState.loadout.get("snacks", 0)) + 1)
		refresh())
	srow.add_child(splus)
	var cheek := UITheme.label("뺨주머니(배낭 왼쪽 위 분홍 칸)에 넣은 물건은 쓰러져도 지켜낸다.", 13, Color("#F2A0B8"))
	cheek.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	w.add_child(cheek)

	# 사망 시 잃는 것
	var risk := _card(prep_box, Color(DB.C_DANGER, 0.85))
	risk.add_child(UITheme.label("사망 시 잃는 것", 17, DB.C_DANGER, true))
	var icons := HFlowContainer.new()
	icons.add_theme_constant_override("h_separation", 8)
	risk.add_child(icons)
	var ammo_line := []
	for slot in ["primary", "sidearm"]:
		var wid: String = lo[slot]
		if wid != "":
			var ic := ItemIcon.make(wid, 44, true)
			ic.danger = true
			icons.add_child(ic)
			var at: String = DB.WEAPONS[wid].ammo
			var nm3: String = DB.ITEMS["ammo_" + at].name
			var line := "%s %d발" % [nm3, int(GameState.ammo.get(at, 0))]
			if not ammo_line.has(line):
				ammo_line.append(line)
	if int(lo.meds) > 0:
		var bi := ItemIcon.make("bandage", 44, false, int(lo.meds))
		bi.danger = true
		icons.add_child(bi)
	var rl2 := UITheme.label("휴대 탄약: %s · 원정에서 주운 전리품 전부" % (", ".join(ammo_line) if not ammo_line.is_empty() else "없음"), 14, DB.C_MUTED)
	rl2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	risk.add_child(rl2)
	risk.add_child(UITheme.label("보관함·코인·제작품은 안전하게 남는다.", 14, DB.C_MUTED))
	var rule := str(GameState.diff("bag_rule"))
	var bag_txt := "쓰러지면 들고 있던 것은 전부 가방에 담겨 그 자리에 남는다 — 다음 원정에서 회수! (%s)" % DB.BAG_RULES[rule]
	if rule == "instant":
		bag_txt = "어려운 규칙: 쓰러지면 가방이 바로 사라진다."
	var bl := UITheme.label(bag_txt, 14, DB.C_LEGEND)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	risk.add_child(bl)
	for b in GameState.lost_bags:
		var lb := UITheme.label("● 회수 못 한 가방: 물건 %d개 · 지도에 노란 가방 표시" % (b.items as Array).size(), 14, Color("#F2C14E"))
		risk.add_child(lb)
	if lo.primary == "" and lo.sidearm == "":
		_benefit(risk, "무장 없이 출발: 잃을 건 없지만 근접 공격(V)만 가능")
	elif lo.primary == "crossbow":
		_benefit(risk, "석궁: 조용히 처치하고 화살을 회수할 수 있다")
	else:
		_benefit(risk, "산탄총은 실내 근거리, 권총은 비상용")

	var keys := UITheme.label("WASD 이동 · 마우스 조준/사격 · R 재장전 · Space 구르기 · V 근접 · E 뒤지기 · Tab 배낭 · Q 회복 · G 간식 · F 스킬 · C 웅크리기(풀숲 은신) · M 지도", 13, DB.C_MUTED)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prep_box.add_child(keys)

# ── 의뢰 게시판 ──────────────────────────────────────
func _build_contracts(box: VBoxContainer) -> void:
	var c := _card(box, Color(DB.C_LEGEND, 0.7))
	var h := HBoxContainer.new()
	c.add_child(h)
	var t := UITheme.label("의뢰 게시판", 17, DB.C_LEGEND, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	h.add_child(UITheme.label("완료 %d건" % int(GameState.stats.get("contracts", 0)), 13, DB.C_MUTED))
	for i in GameState.contracts.size():
		var ct: Dictionary = GameState.contracts[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		c.add_child(row)
		var icon_id: String = str(ct.target) if str(ct.kind) == "fetch" else str(ct.item)
		row.add_child(ItemIcon.make(icon_id, 40))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		v.add_child(UITheme.label(GameState.contract_text(ct), 15, DB.C_TEXT, true))
		var prog := ""
		match str(ct.kind):
			"fetch": prog = "보관함 %d/%d" % [int(GameState.stash.get(ct.target, 0)), int(ct.need)]
			"extract": prog = "완료!" if ct.done else "다음 원정에서 도전"
			_: prog = "완료!" if ct.done else "%d/%d" % [int(ct.have), int(ct.need)]
		v.add_child(UITheme.label("%s  ·  보상 %d냥 + %s" % [prog, int(ct.coins), DB.ITEMS[ct.item].name], 13, Color("#6CCB5F") if GameState.can_turn_in(ct) else DB.C_MUTED))
		var ok := GameState.can_turn_in(ct)
		var b := UITheme.button("납품하기" if str(ct.kind) == "fetch" and not ct.done else "보상 받기", 14, ok)
		b.disabled = not ok
		var idx := i
		b.pressed.connect(func():
			var got := GameState.claim_contract(idx)
			if got != "":
				Sfx.play("coin", -2.0)
				show_toast("의뢰 완료! " + got, Color("#6CCB5F"))
			refresh())
		row.add_child(b)
		if not ct.done:
			var rb := UITheme.button("교체 30냥", 12)
			rb.disabled = GameState.coins < 30
			rb.pressed.connect(func():
				GameState.reroll_contract(idx)
				refresh())
			row.add_child(rb)

# ── 난이도 ───────────────────────────────────────────
func _build_difficulty(box: VBoxContainer) -> void:
	var c := _card(box, Color(DB.C_RARE, 0.5))
	var h := HBoxContainer.new()
	c.add_child(h)
	var t := UITheme.label("난이도", 17, DB.C_TEXT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var pr := str(GameState.diff("preset"))
	for p in ["easy", "normal", "hard", "custom"]:
		var b := UITheme.button(DB.DIFFICULTY_NAMES[p], 14, pr == p)
		b.pressed.connect(func():
			GameState.set_difficulty_preset(p)
			Sfx.play("pick", -6.0)
			refresh())
		h.add_child(b)
	# 항목별 직접 조절 (누를 때마다 다음 값)
	var g := HFlowContainer.new()
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 6)
	c.add_child(g)
	var rule := str(GameState.diff("bag_rule"))
	var rb := UITheme.button("쓰러지면 가방: %s" % DB.BAG_RULES[rule], 14)
	rb.pressed.connect(func():
		var i := DB.BAG_RULE_ORDER.find(rule)
		GameState.set_difficulty_value("bag_rule", DB.BAG_RULE_ORDER[(i + 1) % DB.BAG_RULE_ORDER.size()])
		refresh())
	g.add_child(rb)
	for key in ["enemy_dmg", "enemy_hp", "loot"]:
		var nm: String = {"enemy_dmg": "적 공격력", "enemy_hp": "적 체력", "loot": "전리품 양"}[key]
		var v := float(GameState.diff(key))
		var b2 := UITheme.button("%s ×%.2f" % [nm, v], 14)
		var k2: String = key
		b2.pressed.connect(func():
			var steps: Array = DB.DIFF_STEPS[k2]
			var idx := 0
			for i in steps.size():
				if absf(float(steps[i]) - v) < 0.01:
					idx = i
			GameState.set_difficulty_value(k2, steps[(idx + 1) % steps.size()])
			refresh())
		g.add_child(b2)
	var hint := UITheme.label("프리셋을 고르거나 버튼을 눌러 항목별로 바꾸면 '직접 설정'이 된다.", 12, DB.C_MUTED)
	c.add_child(hint)

## 보유한 무기 목록 (슬롯별, "" = 없음)
func _owned_weapons(slot: String) -> Array:
	var out := [""]
	for wid in DB.WEAPONS:
		if DB.WEAPONS[wid].slot == slot and GameState.weapon_count(wid) > 0:
			out.append(wid)
	return out

# ── 작업대 ───────────────────────────────────────────
const STATION_INFO := {
	"weapon": ["cat_tabby", "기술 고양이 '나비'의 무기 제작소 — 총·탄약·총 부품을 만들고, 총에 부품을 끼운다"],
	"potion": ["cat_white", "약초 냥이 '쑥냥'의 물약 제작소 — 약초와 빈 병으로 물약을 달인다"],
	"armor": ["cat_black", "대장장이 흑냥이 '무쇠'의 갑옷 제작소 — 헬멧과 조끼를 두드려 만든다"],
}

func _build_station(box: VBoxContainer, station: String) -> void:
	var info: Array = STATION_INFO[station]
	var head := UITheme.label(str(info[1]), 15, DB.C_MUTED)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 10)
	hh.add_child(_npc_face(str(info[0])))
	hh.add_child(head)
	box.add_child(hh)
	_build_facility(box, station)
	if station == "weapon":
		_build_mods(box)
	elif station == "armor":
		_build_armor_list(box)
	var sub := UITheme.label("제작", 19, DB.C_HERO, true)
	box.add_child(sub)
	for rec in DB.RECIPES:
		if str(rec.get("station", "weapon")) != station:
			continue
		var can := GameState.has_items(rec.cost) and GameState.coins >= int(rec.coins)
		var c := _card(box, Color(DB.C_HERO, 0.7) if can else Color(1, 1, 1, 0.06))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		c.add_child(h)
		if rec.kind == "weapon":
			h.add_child(ItemIcon.make(rec.id, 52, true))
		elif rec.kind == "repair":
			h.add_child(ItemIcon.make("metal_sheet", 52))
		else:
			h.add_child(ItemIcon.make(rec.get("item", "ammo_" + str(rec.get("ammo", ""))), 52))
		var nv := VBoxContainer.new()
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nv)
		var have_n := ""
		if rec.kind == "weapon":
			have_n = "  (보유 %d)" % GameState.weapon_count(rec.id)
		elif rec.kind == "armor":
			have_n = "  (보유 %d)" % int(GameState.armor.get(rec.item, 0))
		elif rec.kind == "item":
			have_n = "  (보유 %d)" % int(GameState.stash.get(rec.item, 0))
		nv.add_child(UITheme.label(rec.name + have_n, 19, DB.C_TEXT, true))
		if rec.kind == "weapon":
			var wl := UITheme.label(DB.WEAPONS[rec.id].desc, 13, DB.C_MUTED)
			wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nv.add_child(wl)
		var b := UITheme.button("제작", 17, can)
		b.disabled = not can
		b.custom_minimum_size = Vector2(96, 0)
		b.pressed.connect(func(): _craft(rec))
		h.add_child(b)
		var mats := HFlowContainer.new()
		mats.add_theme_constant_override("h_separation", 10)
		c.add_child(mats)
		var missing := []
		for id in rec.cost:
			var need := int(rec.cost[id])
			var have := int(GameState.stash.get(id, 0))
			var hb := HBoxContainer.new()
			var ic := ItemIcon.make(id, 34)
			ic.dim = have < need
			hb.add_child(ic)
			hb.add_child(UITheme.label("%s %d/%d" % [DB.ITEMS[id].name, have, need], 14, Color("#6CCB5F") if have >= need else DB.C_DANGER))
			mats.add_child(hb)
			if have < need:
				missing.append("%s → %s" % [DB.ITEMS[id].name, rec.hint.get(id, "원정 지역")])
		if int(rec.coins) > 0:
			mats.add_child(UITheme.label("+ %d냥" % int(rec.coins), 14, DB.C_LEGEND if GameState.coins >= int(rec.coins) else DB.C_DANGER))
		if not missing.is_empty():
			var ml := UITheme.label("부족한 재료 획득처: " + " · ".join(missing), 13, DB.C_LEGEND)
			ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			c.add_child(ml)
		_benefit(c, rec.benefit)

## 시설 강화 카드: 현재 단계·다음 효과·필요한 재료
func _build_facility(box: VBoxContainer, station: String) -> void:
	if not DB.FACILITY.has(station):
		return
	var fd: Dictionary = DB.FACILITY[station]
	var lv := GameState.fac(station)
	var c := _card(box, Color(DB.C_LEGEND, 0.55))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	c.add_child(h)
	var stars := ""
	for i in 3:
		stars += "★" if i < lv else "☆"
	h.add_child(UITheme.label("시설 Lv.%d  %s" % [lv, stars], 19, DB.C_LEGEND, true))
	var now := UITheme.label("지금: " + str(fd.effect[lv - 1]), 15, DB.C_TEXT)
	now.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(now)
	if lv >= 3:
		h.add_child(UITheme.label("최고 단계", 15, DB.C_MUTED, true))
		return
	var nx: Dictionary = fd.levels[lv]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	c.add_child(row)
	row.add_child(UITheme.label("강화하면 → " + str(fd.effect[lv]), 15, Color("#6CCB5F"), true))
	var mats := HFlowContainer.new()
	mats.add_theme_constant_override("h_separation", 10)
	mats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mats)
	for id in nx.cost:
		var have := int(GameState.stash.get(id, 0))
		var need := int(nx.cost[id])
		var mb := HBoxContainer.new()
		var ic := ItemIcon.make(id, 28)
		ic.dim = have < need
		mb.add_child(ic)
		mb.add_child(UITheme.label("%s %d/%d" % [DB.ITEMS[id].name, have, need], 13, Color("#6CCB5F") if have >= need else DB.C_DANGER))
		mats.add_child(mb)
	mats.add_child(UITheme.label("+ %d냥" % int(nx.coins), 13, DB.C_LEGEND if GameState.coins >= int(nx.coins) else DB.C_DANGER))
	var ub := UITheme.button("강화", 16, GameState.can_upgrade(station))
	ub.disabled = not GameState.can_upgrade(station)
	ub.pressed.connect(func():
		if GameState.upgrade_facility(station):
			Sfx.play({"weapon": "craft_weapon", "potion": "craft_potion", "armor": "craft_armor"}[station], 0.0)
			show_toast("%s Lv.%d 강화 완료! %s" % [fd.name, GameState.fac(station), fd.effect[GameState.fac(station) - 1]], DB.C_LEGEND)
			refresh())
	row.add_child(ub)

func _craft(rec: Dictionary) -> void:
	if not GameState.has_items(rec.cost) or GameState.coins < int(rec.coins):
		return
	for id in rec.cost:
		GameState.remove_item(id, int(rec.cost[id]))
	GameState.coins -= int(rec.coins)
	match rec.kind:
		"weapon":
			GameState.weapons[rec.id] = GameState.weapon_count(rec.id) + 1
			if GameState.loadout.primary == "":
				GameState.loadout.primary = rec.id
			if rec.id == "crossbow" and int(GameState.ammo.get("bolt", 0)) < 6:
				GameState.ammo["bolt"] = int(GameState.ammo.get("bolt", 0)) + 6
		"ammo":
			GameState.ammo[rec.ammo] = int(GameState.ammo.get(rec.ammo, 0)) + int(round(int(rec.amount) * float(DB.FACILITY.weapon.mul[GameState.fac("weapon") - 1])))
		"item":
			var extra := int(DB.FACILITY.potion.mul[GameState.fac("potion") - 1]) if str(rec.get("station", "")) == "potion" else 0
			GameState.add_item(rec.item, int(rec.amount) + extra)
		"armor":
			GameState.armor[rec.item] = int(GameState.armor.get(rec.item, 0)) + 1
			GameState.armor_dur[rec.item] = GameState.armor_max(rec.item)
			var aslot: String = DB.ITEMS[rec.item].slot
			if str(GameState.loadout.get(aslot, "")) == "":
				GameState.loadout[aslot] = rec.item
		"repair":
			GameState.armor_dur = {}
	GameState.crafted[rec.id] = int(GameState.crafted.get(rec.id, 0)) + 1
	GameState.save_game()
	Sfx.play({"weapon": "craft_weapon", "potion": "craft_potion", "armor": "craft_armor"}.get(str(rec.get("station", "weapon")), "craft"), -2.0)
	show_toast("%s 제작 완료!%s" % [rec.name, " (석궁 화살 6발 보너스)" if rec.id == "crossbow" else ""], Color("#6CCB5F"))
	refresh()

# ── 총 부품 장착 (무기 제작소) ───────────────────────
func _stat_line(w: Dictionary) -> String:
	return "피해 %d×%d · 장탄 %d · 퍼짐 %.1f° · 반동 %.1f · 재장전 %.1f초 · 소음 %d" % [int(round(float(w.dmg))), int(w.pellets), int(w.mag), float(w.spread), float(w.recoil), float(w.reload), int(float(w.noise))]

func _build_mods(box: VBoxContainer) -> void:
	var c := _card(box, Color(DB.C_RARE, 0.6))
	c.add_child(UITheme.label("총 부품 장착", 19, DB.C_RARE, true))
	var guide := UITheme.label("총마다 끼울 수 있는 부품이 다르다. 끼운 부품은 그 종류의 총 전부에 적용되고, 원정에서 주운 같은 총에도 붙는다.", 13, DB.C_MUTED)
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(guide)
	var owned := []
	for wid in DB.WEAPONS:
		if GameState.weapon_count(wid) > 0 or GameState.loadout.primary == wid or GameState.loadout.sidearm == wid:
			owned.append(wid)
	owned.sort_custom(func(x, y): return int(x == GameState.loadout.primary or x == GameState.loadout.sidearm) > int(y == GameState.loadout.primary or y == GameState.loadout.sidearm))
	if owned.is_empty():
		c.add_child(UITheme.label("가진 총이 없다.", 14, DB.C_MUTED))
		return
	for wid in owned:
		var gc := _card(box)
		var gh := HBoxContainer.new()
		gh.add_theme_constant_override("separation", 12)
		gc.add_child(gh)
		gh.add_child(GunPreview.make(wid, GameState.mods.get(wid, {})))
		var gv := VBoxContainer.new()
		gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gh.add_child(gv)
		gv.add_child(UITheme.label(DB.WEAPONS[wid].name, 18, DB.C_TEXT, true))
		var st := UITheme.label(_stat_line(GameState.weapon_stats(wid)), 13, Color("#6CCB5F") if not GameState.mods.get(wid, {}).is_empty() else DB.C_MUTED)
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gv.add_child(st)
		for slot in DB.ATT_SLOTS:
			var fits := []
			for att in DB.ATTACHMENTS:
				if DB.ATTACHMENTS[att].slot == slot and DB.att_fits(att, wid):
					fits.append(att)
			if fits.is_empty():
				continue
			var row := HFlowContainer.new()
			row.add_theme_constant_override("h_separation", 6)
			row.add_theme_constant_override("v_separation", 4)
			gc.add_child(row)
			var cur := GameState.mod_of(wid, slot)
			var sl := UITheme.label("%s: %s" % [DB.ATT_SLOT_NAMES[slot], DB.ATTACHMENTS[cur].name if cur != "" else "없음"], 14, DB.C_LEGEND if cur != "" else DB.C_MUTED)
			sl.custom_minimum_size = Vector2(190, 0)
			row.add_child(sl)
			for att in fits:
				if att == cur:
					continue
				var have := int(GameState.stash.get("att_" + att, 0))
				var b := UITheme.button("%s 끼우기 (%d)" % [DB.ATTACHMENTS[att].name, have], 13, have > 0)
				b.disabled = have <= 0
				b.tooltip_text = DB.ITEMS["att_" + att].desc
				var a2: String = att
				b.pressed.connect(func():
					if GameState.install_mod(wid, a2):
						Sfx.play("attach", -2.0)
						show_toast("%s에 %s 장착!" % [DB.WEAPONS[wid].name, DB.ATTACHMENTS[a2].name], Color("#6CCB5F"))
						refresh())
				row.add_child(b)
			if cur != "":
				var rb := UITheme.button("빼기", 13)
				var s2: String = slot
				rb.pressed.connect(func():
					GameState.remove_mod(wid, s2)
					Sfx.play("click", -6.0)
					refresh())
				row.add_child(rb)

# ── 갑옷 목록 (갑옷 제작소) ───────────────────────────
func _build_armor_list(box: VBoxContainer) -> void:
	var c := _card(box, Color(DB.C_LEGEND, 0.5))
	c.add_child(UITheme.label("내 갑옷", 19, DB.C_LEGEND, true))
	var any := false
	for aid in ["helmet_1", "helmet_2", "helmet_3", "vest_1", "vest_2", "vest_3"]:
		var n := int(GameState.armor.get(aid, 0))
		if n <= 0:
			continue
		any = true
		var it: Dictionary = DB.ITEMS[aid]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		c.add_child(row)
		row.add_child(ItemIcon.make(aid, 44, false, n))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		v.add_child(UITheme.label(it.name, 16, DB.rarity_color(int(it.r)), true))
		var left := GameState.armor_left(aid)
		var mx := GameState.armor_max(aid)
		v.add_child(UITheme.label("피해 -%d%% · 내구도 %d/%d" % [int(round(float(it.prot) * 100)), int(left), int(mx)], 13, DB.C_MUTED if left > mx * 0.3 else DB.C_DANGER))
		var worn: bool = str(GameState.loadout.get(it.slot, "")) == aid
		var b := UITheme.button("착용 중" if worn else "착용", 14, worn)
		b.pressed.connect(func():
			GameState.loadout[it.slot] = "" if worn else aid
			GameState.save_game()
			Sfx.play("equip_armor", -4.0)
			refresh())
		row.add_child(b)
	if not any:
		c.add_child(UITheme.label("갑옷이 없다. 아래에서 만들거나 시장에서 사자.", 14, DB.C_MUTED))
	_benefit(c, "입고 나간 갑옷은 쓰러지면 가방과 함께 그 자리에 남는다")

# ── 냥이 시장 ────────────────────────────────────────
func _roll_market() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(GameState.stats.raids) * 7919 + 13
	for cat in ["food", "med", "part", "valuable"]:
		market_mult[cat] = snappedf(r.randf_range(0.8, 1.3), 0.05)

func sell_price(id: String) -> int:
	var it: Dictionary = DB.ITEMS[id]
	return maxi(1, int(round(float(it.v) * float(market_mult.get(it.cat, 1.0)))))

## NPC 얼굴 (시트 캐릭터 스프라이트)
func _npc_face(kind: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(48, 46)
	c.draw.connect(func():
		c.draw_circle(Vector2(24, 23), 22, Color(1, 1, 1, 0.08))
		Sprites.draw_char(c, kind, Sprites.char_frame(kind, "idle", 0), Vector2(24, 46), 0.4, true))
	c.clip_contents = true
	return c

func _build_market() -> void:
	var npc := _card(market_box, Color(DB.C_CAT, 0.9))
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 10)
	npc.add_child(nh)
	nh.add_child(_npc_face("cat_white"))
	nh.add_child(UITheme.label("고양이 상인 '미야'", 19, Color("#8FA3C7"), true))
	var lines := ["\"오늘은 반짝이는 게 좋아. 냥.\"", "\"무거운 사료는 개 상인한테나 팔라구.\"", "\"살아 돌아왔네? 장사 좀 해볼까.\""]
	npc.add_child(UITheme.label(lines[int(GameState.stats.raids) % lines.size()], 15, DB.C_TEXT))
	var trend := HFlowContainer.new()
	trend.add_theme_constant_override("h_separation", 14)
	npc.add_child(trend)
	var names := {"food": "식량", "med": "약품", "part": "재료", "valuable": "귀중품"}
	for cat in names:
		var m: float = market_mult[cat]
		var col := Color("#6CCB5F") if m > 1.05 else (DB.C_DANGER if m < 0.95 else DB.C_MUTED)
		trend.add_child(UITheme.label("%s ×%.2f %s" % [names[cat], m, "▲" if m > 1.05 else ("▼" if m < 0.95 else "–")], 14, col))
	_benefit(npc, "판 돈으로 탄약·붕대를 사서 다음 원정 생존력을 높이자 (시세는 원정마다 바뀐다)")

	var sell := _card(market_box)
	var sh := HBoxContainer.new()
	sell.add_child(sh)
	var sl := UITheme.label("팔기", 19, DB.C_TEXT, true)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(sl)
	var val_total := 0
	for id in GameState.stash:
		if DB.ITEMS[id].cat == "valuable":
			val_total += sell_price(id) * int(GameState.stash[id])
	var sell_val := UITheme.button("귀중품 모두 팔기 (+%d냥)" % val_total, 14)
	sell_val.disabled = val_total == 0
	sell_val.pressed.connect(func():
		for id in GameState.stash.keys():
			if DB.ITEMS[id].cat == "valuable":
				GameState.coins += sell_price(id) * int(GameState.stash[id])
				GameState.stash.erase(id)
		GameState.save_game()
		Sfx.play("coin", -2.0)
		show_toast("귀중품을 모두 팔았다! +%d냥" % val_total)
		refresh())
	sh.add_child(sell_val)
	if GameState.stash.is_empty():
		sell.add_child(UITheme.label("팔 물건이 없다. 원정에서 전리품을 가져오자.", 14, DB.C_MUTED))
	var ids := GameState.stash.keys()
	ids.sort_custom(func(a, b): return sell_price(a) > sell_price(b))
	for id in ids:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		sell.add_child(row)
		row.add_child(ItemIcon.make(id, 40, false, int(GameState.stash[id])))
		var it: Dictionary = DB.ITEMS[id]
		var nl := UITheme.label(it.name, 15, DB.rarity_color(int(it.r)))
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		var used := _used_in_recipe(id)
		if used != "":
			row.add_child(UITheme.label(used, 12, DB.C_LEGEND))
		row.add_child(UITheme.label("%d냥" % sell_price(id), 15, DB.C_LEGEND))
		var b1 := UITheme.button("1개 팔기", 14)
		b1.pressed.connect(func():
			if GameState.remove_item(id, 1):
				GameState.coins += sell_price(id)
				GameState.save_game()
				Sfx.play("coin", -4.0)
				refresh())
		row.add_child(b1)

	var buy := _card(market_box)
	buy.add_child(UITheme.label("사기", 19, DB.C_TEXT, true))
	for s in DB.SHOP:
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 10)
		buy.add_child(row2)
		if s.kind == "weapon":
			row2.add_child(ItemIcon.make(s.weapon, 40, true))
		else:
			row2.add_child(ItemIcon.make(str(s.get("item", s.id)) if s.kind != "ammo" else "ammo_" + str(s.ammo), 40))
		var nl2 := UITheme.label(s.name, 15)
		nl2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(nl2)
		var own := ""
		match s.kind:
			"ammo": own = "보유 %d" % int(GameState.ammo.get(s.ammo, 0))
			"item": own = "보유 %d" % int(GameState.stash.get(s.item, 0))
			"armor": own = "보유 %d" % int(GameState.armor.get(s.item, 0))
			"weapon": own = "보유 %d" % GameState.weapon_count(s.weapon)
		row2.add_child(UITheme.label(own, 13, DB.C_MUTED))
		var bb := UITheme.button("%d냥" % int(s.price), 15, GameState.coins >= int(s.price))
		bb.disabled = GameState.coins < int(s.price)
		bb.custom_minimum_size = Vector2(90, 0)
		bb.pressed.connect(func(): _buy(s))
		row2.add_child(bb)

func _used_in_recipe(id: String) -> String:
	for rec in DB.RECIPES:
		if rec.cost.has(id):
			return "제작 재료"
	return ""

func _buy(s: Dictionary) -> void:
	if GameState.coins < int(s.price):
		return
	GameState.coins -= int(s.price)
	match s.kind:
		"ammo": GameState.ammo[s.ammo] = int(GameState.ammo.get(s.ammo, 0)) + int(s.amount)
		"item": GameState.add_item(s.item, int(s.amount))
		"armor":
			GameState.armor[s.item] = int(GameState.armor.get(s.item, 0)) + 1
			GameState.armor_dur[s.item] = GameState.armor_max(s.item)
		"weapon":
			GameState.weapons[s.weapon] = GameState.weapon_count(s.weapon) + 1
			var wslot: String = str(DB.WEAPONS[s.weapon].slot) if DB.WEAPONS.has(s.weapon) else "melee"
			if wslot != "melee" and str(GameState.loadout.get(wslot, "")) == "":
				GameState.loadout[wslot] = s.weapon
	GameState.save_game()
	Sfx.play("coin", -2.0)
	show_toast("%s 구매!" % s.name)
	refresh()

# ── 보관함 ───────────────────────────────────────────
func _build_stash() -> void:
	var c := _card(stash_box)
	var h := HBoxContainer.new()
	c.add_child(h)
	var t := UITheme.label("보관함 (사망해도 안전)", 19, DB.C_TEXT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	h.add_child(UITheme.label("총 가치 %s냥" % HUD._fmt(GameState.stash_value()), 15, DB.C_LEGEND))
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	c.add_child(grid)
	var ids := GameState.stash.keys()
	ids.sort_custom(func(a, b): return int(DB.ITEMS[a].r) > int(DB.ITEMS[b].r))
	for id in ids:
		grid.add_child(ItemIcon.make(id, 58, false, int(GameState.stash[id])))
	if ids.is_empty():
		c.add_child(UITheme.label("비어 있다.", 14, DB.C_MUTED))
	var wc := _card(stash_box)
	wc.add_child(UITheme.label("무기 · 탄약", 19, DB.C_TEXT, true))
	var wg := HFlowContainer.new()
	wg.add_theme_constant_override("h_separation", 8)
	wc.add_child(wg)
	for wid in GameState.weapons:
		if int(GameState.weapons[wid]) > 0:
			var ic := ItemIcon.make(wid, 50, true, int(GameState.weapons[wid]))
			wg.add_child(ic)
	wc.add_child(UITheme.label("권총탄 %d · 산탄 %d · 소총탄 %d · 석궁 화살 %d" % [int(GameState.ammo.get("pistol", 0)), int(GameState.ammo.get("shell", 0)), int(GameState.ammo.get("rifle", 0)), int(GameState.ammo.get("bolt", 0))], 15, DB.C_MUTED))
	var ac := _card(stash_box)
	ac.add_child(UITheme.label("갑옷", 19, DB.C_TEXT, true))
	var ag := HFlowContainer.new()
	ag.add_theme_constant_override("h_separation", 8)
	ac.add_child(ag)
	var any_a := false
	for aid in GameState.armor:
		if int(GameState.armor[aid]) > 0:
			ag.add_child(ItemIcon.make(aid, 58, false, int(GameState.armor[aid])))
			any_a = true
	if not any_a:
		ac.add_child(UITheme.label("갑옷이 없다. 갑옷 제작소에서 만들 수 있다.", 14, DB.C_MUTED))
