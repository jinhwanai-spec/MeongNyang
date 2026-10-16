class_name DeployCard
extends Control
## 출격 연출: 은신처 → 원정 지역으로 이동하는 카드 (지도 이름·경로·위험도·남은 가방)

const TIPS := [
	"오른쪽 클릭으로 조준하면 덜 퍼지고 더 멀리 보인다",
	"웅크리면(Ctrl) 풀숲에서 냥이들 눈에 덜 띈다",
	"쓰러진 자리에는 가방이 남는다 — 다음 원정에서 되찾자",
	"무기 제작소에서 총마다 맞는 부품을 끼울 수 있다",
	"갑옷은 내구도가 다 닳으면 부서진다 — 갑옷 제작소에서 수리",
	"엘리트 냥이는 이름표가 붙어 있고 좋은 물건을 떨군다",
	"발전기를 켜야 열리는 탈출구는 셔터가 올라가는 소리로 알 수 있다",
]

var t := 0.0
var dur := 2.4
var route: Control
var region := "mart"
var from_region := ""

static func make(region_id: String, from_id: String = "") -> DeployCard:
	var c := DeployCard.new()
	c.region = region_id
	c.from_region = from_id
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c._build()
	return c

func _build() -> void:
	var info := Regions.get_info(region)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# 뒤에 지역 지도를 흐릿하게
	var tex = load(str(info.minimap))
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.modulate = Color(0.55, 0.6, 0.75, 0.16)
		add_child(tr)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.custom_minimum_size = Vector2(760, 0)
	vb.position = Vector2(-380, -170)
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	var top := UITheme.label("연속 원정 — 다음 지역으로 이동" if from_region != "" else "출격", 20, DB.C_HERO, true)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(top)
	var nm := UITheme.label(str(info.name), 40, Color.WHITE, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nm)
	route = Control.new()
	route.custom_minimum_size = Vector2(760, 70)
	route.draw.connect(_draw_route)
	vb.add_child(route)
	var bags := 0
	for b in GameState.lost_bags:
		if str(b.get("region", "mart")) == region:
			bags += 1
	var diff_name: String = DB.DIFFICULTY_NAMES.get(str(GameState.difficulty.get("preset", "normal")), "보통")
	var line := "위험도 %s   ·   보상 %s   ·   난이도 %s" % [info.danger, info.reward, diff_name]
	var l1 := UITheme.label(line, 19, Color(0.86, 0.88, 0.93))
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l1)
	if bags > 0:
		var l2 := UITheme.label("이 지역에 두고 온 내 가방 %d개 — 지도에 표시된다" % bags, 18, DB.C_LEGEND, true)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l2)
	var tip := UITheme.label("TIP  " + TIPS[randi() % TIPS.size()], 16, Color(0.6, 0.65, 0.75))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tip)

func _process(delta: float) -> void:
	t += delta
	if route:
		route.queue_redraw()

func _draw_route() -> void:
	var w := route.size.x
	var y := 34.0
	var a := Vector2(70, y)
	var b := Vector2(w - 70, y)
	var k := clampf(t / (dur - 0.5), 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 2.0)
	# 점선 경로
	var n := 40
	for i in n:
		if i % 2 == 0:
			var p0 := a.lerp(b, float(i) / n)
			var p1 := a.lerp(b, float(i + 1) / n)
			var done := float(i) / n < k
			route.draw_line(p0, p1, DB.C_HERO if done else Color(0.35, 0.38, 0.46), 4.0, true)
	route.draw_circle(a, 12, Color(0.35, 0.75, 0.45))
	route.draw_circle(b, 12, DB.C_DANGER)
	var f := UITheme.bold()
	route.draw_string(f, a + Vector2(-90, 34), "은신처" if from_region == "" else str(Regions.get_info(from_region).short), HORIZONTAL_ALIGNMENT_CENTER, 180, 15, Color(0.8, 0.85, 0.9))
	route.draw_string(f, b + Vector2(-90, 34), str(Regions.get_info(region).short), HORIZONTAL_ALIGNMENT_CENTER, 180, 15, Color(0.8, 0.85, 0.9))
	# 이동 중인 햄스터 표시 (주황 동그라미 + 귀)
	var h := a.lerp(b, k) + Vector2(0, -2 + sin(t * 14.0) * 2.0)
	route.draw_circle(h + Vector2(-7, -10), 5, DB.C_HERO.darkened(0.2))
	route.draw_circle(h + Vector2(7, -10), 5, DB.C_HERO.darkened(0.2))
	route.draw_circle(h, 12, DB.C_HERO)
	route.draw_circle(h + Vector2(-4, -2), 2, Color.BLACK)
	route.draw_circle(h + Vector2(4, -2), 2, Color.BLACK)
