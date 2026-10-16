class_name ResultScreen
extends Control
## 원정 결과: 생존 여부, 시간, 처치, 가져온(또는 잃은) 전리품

signal done
signal next_raid(region: String)

var result: Dictionary

func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ok: bool = result.get("survived", false)
	var bg := ColorRect.new()
	bg.color = Color("#141821") if ok else Color("#1A1216")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# 양옆 캐릭터 연출 (성공: 기뻐하는 햄스터 / 실패: 쓰러진 햄스터 옆 고양이)
	var deco := Control.new()
	deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(func():
		var vs := deco.size
		if ok:
			Sprites.draw_char(deco, "hamster", Sprites.char_frame("hamster", "happy", 0), Vector2(vs.x * 0.12, vs.y * 0.78), 1.5)
			Sprites.draw_fit(deco, Sprites.fx_tex("coin"), Rect2(Vector2(vs.x * 0.84, vs.y * 0.36), Vector2(56, 56)))
			Sprites.draw_char(deco, "hamster", Sprites.char_frame("hamster", "portrait_happy", 0), Vector2(vs.x * 0.88, vs.y * 0.78), 1.2, true)
		else:
			Sprites.draw_char(deco, "hamster", Sprites.char_frame("hamster", "hurt", 0), Vector2(vs.x * 0.12, vs.y * 0.8), 1.3, false, Color(0.8, 0.75, 0.8))
			Sprites.draw_char(deco, "cat_black", Sprites.char_frame("cat_black", "idle", 0), Vector2(vs.x * 0.89, vs.y * 0.8), 1.6, true, Color(0.75, 0.75, 0.85)))
	add_child(deco)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(DB.C_UI_SOLID, 0.96), 18, DB.C_LEGEND if ok else DB.C_DANGER, 3, 28))
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var title := UITheme.label("탈출 성공!" if ok else "실종 (MIA)", 46, DB.C_LEGEND if ok else DB.C_DANGER, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := "%s 통해 무사히 귀환했다." % _josa(str(result.get("reason", ""))) if ok else ("원정을 포기했다." if result.get("reason", "") == "원정 포기" else "털 뭉치만 남기고 사라졌다... 휴대 장비와 전리품을 잃었다.")
	var sl := UITheme.label(sub, 17, DB.C_MUTED)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sl)
	if not ok and result.has("bag_rule"):
		var bt := "가방이 쓰러진 자리에 남았다! 다음 원정에서 노란 표시를 따라가 회수하자."
		if not bool(result.get("bag_left", false)):
			bt = "난이도 규칙: 가방이 바로 사라졌다."
		elif str(result.bag_rule) == "two":
			bt += "  (회수하기 전에 또 쓰러지면 이 가방은 사라진다)"
		var bl := UITheme.label(bt, 16, DB.C_LEGEND, true)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(bl)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 40)
	v.add_child(stats)
	var tm := float(result.get("time", 0))
	_stat(stats, "생존 시간", "%d:%02d" % [int(tm) / 60, int(tm) % 60])
	_stat(stats, "처치", str(int(result.get("kills", 0))))
	_stat(stats, "전리품 가치", "%s냥" % HUD._fmt(int(result.get("value", 0))))
	var items: Array = result.get("items", []) if ok else result.get("lost_items", [])
	v.add_child(UITheme.label("가져온 전리품" if ok else ("가방에 남긴 것" if bool(result.get("bag_left", false)) else "잃어버린 것"), 18, DB.C_TEXT if ok else DB.C_DANGER, true))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	v.add_child(flow)
	if not ok:
		for wid in result.get("weapons", []):
			var wi := ItemIcon.make(wid, 52, true)
			wi.danger = true
			flow.add_child(wi)
	var counts := {}
	for id in items:
		counts[id] = int(counts.get(id, 0)) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return int(DB.ITEMS[a].v) > int(DB.ITEMS[b].v))
	for id in keys:
		var ic := ItemIcon.make(id, 58, false, counts[id])
		ic.danger = not ok
		flow.add_child(ic)
	if items.is_empty() and (ok or result.get("weapons", []).is_empty()):
		v.add_child(UITheme.label("빈손이다. 다음엔 조금 더 깊이 들어가 볼까?" if ok else "잃은 장비가 없다.", 15, DB.C_MUTED))
	var kept: Array = result.get("kept_items", [])
	if not ok and not kept.is_empty():
		v.add_child(UITheme.label("뺨주머니에 숨겨 지켜낸 것", 18, Color("#F5A3A8"), true))
		var kf := HFlowContainer.new()
		kf.add_theme_constant_override("h_separation", 8)
		v.add_child(kf)
		for kid in kept:
			kf.add_child(ItemIcon.make(kid, 58, false, 1))
	var keep := UITheme.label("은신처 보관함 · 코인 · 제작품은 그대로 남아 있다. 기본 권총·탄약·식량은 항상 지급된다." if not ok else "전리품은 보관함으로 옮겨졌다. 냥이 시장에서 팔거나 작업대에서 제작에 쓰자.", 15, Color("#6CCB5F"))
	keep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(keep)
	var b := UITheme.button("은신처로 돌아가기", 22, true)
	b.custom_minimum_size = Vector2(0, 56)
	b.pressed.connect(func(): done.emit())
	if ok and not Net.active:
		# 연속 원정: 은신처에 들르지 않고 다음 지역으로 바로 이동 (전리품은 이미 보관함에 안전)
		var i := Regions.ORDER.find(LevelData.region)
		var nx: String = Regions.ORDER[(i + 1) % Regions.ORDER.size()]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		var nb := UITheme.button("다음 지역으로 바로 출격 ▶  %s" % str(Regions.get_info(nx).short), 18, false)
		nb.custom_minimum_size = Vector2(0, 56)
		nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nb.pressed.connect(func(): next_raid.emit(nx))
		row.add_child(nb)
	else:
		v.add_child(b)
	Sfx.music("hideout")

func _josa(s: String) -> String:
	if s == "":
		return "탈출구를"
	var c := s.unicode_at(s.length() - 1)
	if c >= 0xAC00 and c <= 0xD7A3 and (c - 0xAC00) % 28 != 0:
		return s + "을"
	return s + "를"

func _stat(parent: Control, label: String, value: String) -> void:
	var v := VBoxContainer.new()
	parent.add_child(v)
	var a := UITheme.label(value, 30, DB.C_TEXT, true)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(a)
	var b := UITheme.label(label, 14, DB.C_MUTED)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
